// Browser-side S3 multipart uploader. Drives the /multipart/start →
// per-part PUT loop → /multipart/complete handshake from the client.
//
// Design notes:
//   - We slice the File using `Blob.slice()`, which is zero-copy in
//     Chromium / Firefox. The slices are streamed via `fetch` PUT — no
//     ArrayBuffer materialisation.
//   - Per-part ETag must be read from the response header. The presigned
//     URL points at our nginx (`/landing/...`) which forwards to RustFS,
//     so it's same-origin → no CORS, ETag is readable.
//   - Concurrency is conservative (4 in-flight). Browsers cap per-origin
//     to 6 anyway, and we want to leave headroom for /api requests.
//   - On any part failure the upload aborts server-side via /multipart/abort
//     so RustFS doesn't retain orphaned parts.

import {api, type MultipartStartResponse} from "../api/client";

export interface MultipartProgress {
  uploadedParts: number;
  totalParts: number;
  uploadedBytes: number;
  totalBytes: number;
}

export interface MultipartOptions {
  concurrency?: number;
  signal?: AbortSignal;
  onProgress?: (p: MultipartProgress) => void;
}

interface PartResult {
  part_number: number;
  etag: string;
}

const DEFAULT_CONCURRENCY = 4;

async function putPart(
  url: string,
  body: Blob,
  signal?: AbortSignal,
): Promise<string> {
  const r = await fetch(url, {method: "PUT", body, signal});
  if (!r.ok) {
    throw new Error(`part PUT failed: ${r.status} ${r.statusText}`);
  }
  // S3 ETag wraps an MD5 in quotes. We forward it verbatim — server-side
  // CompleteMultipartUpload accepts the quoted form.
  const etag = r.headers.get("etag") ?? r.headers.get("ETag");
  if (!etag) {
    throw new Error(
      "part PUT succeeded but no ETag header was returned " +
        "(check nginx Access-Control-Expose-Headers / proxy_pass_header)",
    );
  }
  return etag;
}

export async function multipartUpload(
  file: File,
  domain: string,
  options: MultipartOptions = {},
): Promise<{s3_uri: string}> {
  const {concurrency = DEFAULT_CONCURRENCY, signal, onProgress} = options;

  // 1. Initiate the multipart upload + collect per-part presigned URLs.
  const start: MultipartStartResponse = await api.multipartStart({
    domain,
    filename: file.name,
    content_type: file.type || "application/octet-stream",
    content_length: file.size,
  });

  const {bucket, key, upload_id, part_size, part_count, urls} = start;
  if (urls.length !== part_count) {
    throw new Error(
      `multipart/start returned ${urls.length} URLs but advertised ${part_count} parts`,
    );
  }

  // Plan: assign each part its byte range up-front. Last part may be short.
  const plan = Array.from({length: part_count}, (_, i) => {
    const partNumber = i + 1;
    const offset = i * part_size;
    const end = Math.min(file.size, offset + part_size);
    return {partNumber, url: urls[i], blob: file.slice(offset, end), size: end - offset};
  });

  const results: PartResult[] = [];
  let uploadedBytes = 0;

  const tick = () => {
    onProgress?.({
      uploadedParts: results.length,
      totalParts: part_count,
      uploadedBytes,
      totalBytes: file.size,
    });
  };
  tick();

  // 2. Bounded-concurrency worker loop. Workers pull from a shared cursor.
  let cursor = 0;
  const errors: unknown[] = [];

  async function worker() {
    while (cursor < plan.length && errors.length === 0) {
      const idx = cursor++;
      const part = plan[idx];
      try {
        const etag = await putPart(part.url, part.blob, signal);
        results.push({part_number: part.partNumber, etag});
        uploadedBytes += part.size;
        tick();
      } catch (e) {
        errors.push(e);
        return;
      }
    }
  }

  const workers = Array.from(
    {length: Math.min(concurrency, plan.length)},
    () => worker(),
  );
  await Promise.all(workers);

  if (errors.length > 0 || (signal?.aborted ?? false)) {
    // Best-effort cleanup. Server logs the abort.
    try {
      await api.multipartAbort({bucket, key, upload_id});
    } catch {
      // swallow — RustFS GC sweeps stale uploads
    }
    if (signal?.aborted) {
      throw new DOMException("upload aborted", "AbortError");
    }
    throw errors[0] instanceof Error ? errors[0] : new Error(String(errors[0]));
  }

  // 3. Complete. Server sorts parts by part_number defensively.
  const done = await api.multipartComplete({
    bucket,
    key,
    upload_id,
    parts: results,
  });

  return {s3_uri: done.s3_uri};
}
