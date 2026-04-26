import {useState} from "react";
import {useMutation} from "@tanstack/react-query";

import {api, presignedPut, type ScanResponse, type TriggerResponse} from "../api/client";
import {DomainPicker} from "../components/DomainPicker";
import {FileDropzone} from "../components/FileDropzone";
import {ScanPreview} from "../components/ScanPreview";
import {RunStatus} from "../components/RunStatus";
import {multipartUpload, type MultipartProgress} from "../lib/multipart";

// Cap matches the API default (DASHI_API_UPLOAD_MAX_BYTES). Above the
// multipart threshold we switch to chunked PUT; this is the absolute
// ceiling that stops the user picking files we'd reject server-side.
const UPLOAD_MAX_BYTES = 50 * 1024 * 1024 * 1024; // 50 GiB
const MULTIPART_THRESHOLD = 500 * 1024 * 1024; // 500 MiB

interface PerFile {
  file: File;
  s3_uri: string;
  scan: ScanResponse;
}

interface UploadProgress {
  uploadedBytes: number;
  totalBytes: number;
  uploadedParts?: number;
  totalParts?: number;
}

type Stage =
  | {kind: "idle"}
  | {
      kind: "uploading";
      index: number;
      total: number;
      current: string;
      multipart: boolean;
      progress: UploadProgress;
    }
  | {kind: "scanning"; index: number; total: number; current: string}
  | {kind: "scanned"; entries: PerFile[]}
  | {kind: "triggering"; entries: PerFile[]}
  | {kind: "done"; runs: TriggerResponse[]}
  | {kind: "error"; message: string};

function StatusLine({label}: {label: string}) {
  return (
    <div className="flex items-center gap-2 text-sm text-ink-soft">
      <span className="inline-block h-2 w-2 rounded-full bg-amber animate-pulse" />
      <span className="font-mono">{label}</span>
    </div>
  );
}

function fmtBytes(n: number): string {
  if (n >= 1024 * 1024 * 1024) return `${(n / (1024 * 1024 * 1024)).toFixed(2)} GiB`;
  if (n >= 1024 * 1024) return `${(n / (1024 * 1024)).toFixed(1)} MiB`;
  if (n >= 1024) return `${(n / 1024).toFixed(0)} KiB`;
  return `${n} B`;
}

function UploadProgressLine({
  index,
  total,
  current,
  multipart,
  progress,
}: {
  index: number;
  total: number;
  current: string;
  multipart: boolean;
  progress: UploadProgress;
}) {
  const pct =
    progress.totalBytes > 0
      ? Math.min(100, Math.round((progress.uploadedBytes / progress.totalBytes) * 100))
      : 0;
  const partLabel =
    multipart && progress.totalParts
      ? ` · part ${progress.uploadedParts ?? 0}/${progress.totalParts}`
      : "";
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 text-sm text-ink-soft">
        <span className="inline-block h-2 w-2 rounded-full bg-amber animate-pulse" />
        <span className="font-mono">
          uploading {index + 1}/{total} · {current}
          {multipart ? " · multipart" : ""}
          {partLabel}
        </span>
      </div>
      <div className="h-1.5 w-full rounded-full bg-cream overflow-hidden">
        <div
          className="h-full bg-amber transition-[width] duration-200"
          style={{width: `${pct}%`}}
        />
      </div>
      <div className="text-xs font-mono text-ink-soft text-right">
        {fmtBytes(progress.uploadedBytes)} / {fmtBytes(progress.totalBytes)} · {pct}%
      </div>
    </div>
  );
}

const CLASSIFICATIONS: {value: string; label: string}[] = [
  {value: "pub", label: "pub — public, internet-publishable"},
  {value: "int", label: "int — internal, operational data"},
  {value: "rst", label: "rst — restricted, need-to-know"},
  {value: "cnf", label: "cnf — confidential, audited access"},
];

export function Ingest() {
  const [domain, setDomain] = useState("");
  const [classification, setClassification] = useState("int");
  const [files, setFiles] = useState<File[]>([]);
  const [stage, setStage] = useState<Stage>({kind: "idle"});

  const uploadAndScan = useMutation({
    mutationFn: async () => {
      if (files.length === 0 || !domain) throw new Error("pick a domain and at least one file");

      const entries: PerFile[] = [];
      for (let i = 0; i < files.length; i++) {
        const f = files[i];
        const useMultipart = f.size >= MULTIPART_THRESHOLD;

        setStage({
          kind: "uploading",
          index: i,
          total: files.length,
          current: f.name,
          multipart: useMultipart,
          progress: {uploadedBytes: 0, totalBytes: f.size},
        });

        let s3_uri: string;
        if (useMultipart) {
          const result = await multipartUpload(f, domain, {
            onProgress: (p: MultipartProgress) =>
              setStage({
                kind: "uploading",
                index: i,
                total: files.length,
                current: f.name,
                multipart: true,
                progress: {
                  uploadedBytes: p.uploadedBytes,
                  totalBytes: p.totalBytes,
                  uploadedParts: p.uploadedParts,
                  totalParts: p.totalParts,
                },
              }),
          });
          s3_uri = result.s3_uri;
        } else {
          const presign = await api.presign({
            domain,
            filename: f.name,
            content_type: f.type || "application/octet-stream",
            content_length: f.size,
          });
          await presignedPut(presign.url, f);
          s3_uri = presign.s3_uri;
        }

        setStage({kind: "scanning", index: i, total: files.length, current: f.name});
        const scan = await api.scan(s3_uri);
        entries.push({file: f, s3_uri, scan});
      }
      setStage({kind: "scanned", entries});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const trigger = useMutation({
    mutationFn: async () => {
      if (stage.kind !== "scanned") throw new Error("scan not complete");
      setStage({kind: "triggering", entries: stage.entries});
      const runs: TriggerResponse[] = [];
      for (const e of stage.entries) {
        const run = await api.trigger({
          s3_uri: e.s3_uri,
          domain,
          classification,
        });
        runs.push(run);
      }
      setStage({kind: "done", runs});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const reset = () => {
    setFiles([]);
    setStage({kind: "idle"});
  };

  const busy =
    stage.kind === "uploading" ||
    stage.kind === "scanning" ||
    stage.kind === "triggering";

  const totalPrimary =
    stage.kind === "scanned"
      ? stage.entries.reduce((s, e) => s + e.scan.primary_count, 0)
      : 0;

  return (
    <div className="space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight text-ink">
          Ingest a dataset
        </h1>
        <p className="text-sm text-ink-soft">
          Drop one or more files, pick a domain, preview detection, submit.
          One Prefect run per submitted file.
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="space-y-2">
          <label className="block text-xs font-medium uppercase tracking-wider text-ink-soft">
            Domain
          </label>
          <DomainPicker value={domain} onChange={setDomain} disabled={busy} />
        </div>
        <div className="space-y-2">
          <label className="block text-xs font-medium uppercase tracking-wider text-ink-soft">
            Classification
          </label>
          <select
            value={classification}
            onChange={(e) => setClassification(e.target.value)}
            disabled={busy}
            className="w-full rounded-lg bg-paper text-ink px-3.5 py-2.5 text-sm font-mono border border-line shadow-sm hover:border-ink-soft/60 focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber transition disabled:opacity-50"
          >
            {CLASSIFICATIONS.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </select>
        </div>
      </section>

      <section className="space-y-2">
        <label className="block text-xs font-medium uppercase tracking-wider text-ink-soft">
          File{files.length === 1 ? "" : "s"}
        </label>
        <FileDropzone
          files={files}
          onFiles={(fs) => {
            setFiles(fs);
            if (stage.kind !== "idle") setStage({kind: "idle"});
          }}
          disabled={busy}
          maxBytes={UPLOAD_MAX_BYTES}
        />
      </section>

      {stage.kind === "idle" && (
        <div>
          <button
            type="button"
            disabled={files.length === 0 || !domain}
            onClick={() => uploadAndScan.mutate()}
            className="inline-flex items-center justify-center rounded-lg bg-ink text-paper px-5 py-2.5 text-sm font-medium shadow-sm hover:bg-ink-soft transition disabled:opacity-40 disabled:cursor-not-allowed"
          >
            Upload + scan {files.length > 0 && `(${files.length})`}
          </button>
        </div>
      )}

      {stage.kind === "uploading" && (
        <UploadProgressLine
          index={stage.index}
          total={stage.total}
          current={stage.current}
          multipart={stage.multipart}
          progress={stage.progress}
        />
      )}
      {stage.kind === "scanning" && (
        <StatusLine
          label={`scanning ${stage.index + 1}/${stage.total} · ${stage.current}`}
        />
      )}

      {stage.kind === "scanned" && (
        <div className="space-y-6">
          {stage.entries.map((e, i) => (
            <div key={i} className="space-y-2">
              <div className="text-xs font-mono text-ink-soft">
                {e.file.name} · {(e.file.size / (1024 * 1024)).toFixed(2)} MiB
              </div>
              <ScanPreview scan={e.scan} />
            </div>
          ))}
          <div className="flex items-center gap-4 pt-2">
            <button
              type="button"
              onClick={() => trigger.mutate()}
              disabled={totalPrimary === 0}
              className="inline-flex items-center justify-center rounded-lg bg-amber text-ink px-5 py-2.5 text-sm font-medium shadow-sm hover:bg-amber-light transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Submit {stage.entries.length} ingest run{stage.entries.length === 1 ? "" : "s"} →
            </button>
            <button
              type="button"
              onClick={reset}
              className="text-sm text-ink-soft hover:text-seal underline-offset-2 hover:underline"
            >
              cancel
            </button>
          </div>
        </div>
      )}

      {stage.kind === "triggering" && (
        <StatusLine label="creating Prefect flow runs…" />
      )}

      {stage.kind === "done" && (
        <div className="space-y-3">
          {stage.runs.map((r) => (
            <RunStatus key={r.flow_run_id} run={r} />
          ))}
          <button
            type="button"
            onClick={reset}
            className="text-sm text-amber-deep hover:text-amber underline-offset-2 hover:underline font-medium"
          >
            ingest another →
          </button>
        </div>
      )}

      {stage.kind === "error" && (
        <div className="rounded-lg border border-seal/30 bg-seal/5 px-5 py-4 shadow-sm">
          <div className="flex items-start gap-3">
            <span className="mt-0.5 inline-flex h-5 w-5 items-center justify-center rounded-full bg-seal text-paper text-xs">
              !
            </span>
            <div className="flex-1">
              <div className="text-sm text-seal font-mono">{stage.message}</div>
              <button
                type="button"
                onClick={reset}
                className="mt-3 text-xs text-ink-soft hover:text-amber-deep underline-offset-2 hover:underline"
              >
                try again →
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
