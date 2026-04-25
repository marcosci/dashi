import {useState} from "react";
import {useMutation} from "@tanstack/react-query";

import {api, presignedPut, type ScanResponse, type TriggerResponse} from "../api/client";
import {DomainPicker} from "../components/DomainPicker";
import {FileDropzone} from "../components/FileDropzone";
import {ScanPreview} from "../components/ScanPreview";
import {RunStatus} from "../components/RunStatus";

const UPLOAD_MAX_BYTES = 1024 * 1024 * 1024; // 1 GiB; matches API default

type Stage =
  | {kind: "idle"}
  | {kind: "uploading"; progress: number}
  | {kind: "scanning"; s3_uri: string}
  | {kind: "scanned"; s3_uri: string; scan: ScanResponse}
  | {kind: "triggering"; s3_uri: string; scan: ScanResponse}
  | {kind: "done"; run: TriggerResponse}
  | {kind: "error"; message: string};

export function Ingest() {
  const [domain, setDomain] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [stage, setStage] = useState<Stage>({kind: "idle"});

  const uploadAndScan = useMutation({
    mutationFn: async () => {
      if (!file || !domain) throw new Error("pick a domain and a file first");
      setStage({kind: "uploading", progress: 0});
      const presign = await api.presign({
        domain,
        filename: file.name,
        content_type: file.type || "application/octet-stream",
        content_length: file.size,
      });
      await presignedPut(presign.url, file);
      setStage({kind: "scanning", s3_uri: presign.s3_uri});
      const scan = await api.scan(presign.s3_uri);
      setStage({kind: "scanned", s3_uri: presign.s3_uri, scan});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const trigger = useMutation({
    mutationFn: async () => {
      if (stage.kind !== "scanned") throw new Error("scan not complete");
      setStage({kind: "triggering", s3_uri: stage.s3_uri, scan: stage.scan});
      const run = await api.trigger({s3_uri: stage.s3_uri, domain});
      setStage({kind: "done", run});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const reset = () => {
    setFile(null);
    setStage({kind: "idle"});
  };

  const busy = stage.kind === "uploading" || stage.kind === "scanning" || stage.kind === "triggering";

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-amber-light">Ingest a dataset</h1>
        <p className="text-sm text-cream/70 mt-1">
          Drop a file, pick a domain, preview detection, submit. The Prefect run takes it from there.
        </p>
      </div>

      <section className="space-y-2">
        <label className="text-xs uppercase tracking-wide text-cream/50">Domain</label>
        <DomainPicker value={domain} onChange={setDomain} disabled={busy} />
      </section>

      <section className="space-y-2">
        <label className="text-xs uppercase tracking-wide text-cream/50">File</label>
        <FileDropzone
          file={file}
          onFile={(f) => {
            setFile(f);
            if (stage.kind !== "idle") setStage({kind: "idle"});
          }}
          disabled={busy}
          maxBytes={UPLOAD_MAX_BYTES}
        />
      </section>

      {stage.kind === "idle" && (
        <button
          type="button"
          disabled={!file || !domain}
          onClick={() => uploadAndScan.mutate()}
          className="rounded-md bg-amber text-ink px-5 py-2 text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed hover:bg-amber-light"
        >
          Upload + scan
        </button>
      )}

      {stage.kind === "uploading" && (
        <div className="text-sm text-cream/70 font-mono">uploading {file?.name}…</div>
      )}
      {stage.kind === "scanning" && (
        <div className="text-sm text-cream/70 font-mono">running detect.discover…</div>
      )}

      {stage.kind === "scanned" && (
        <div className="space-y-4">
          <ScanPreview scan={stage.scan} />
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => trigger.mutate()}
              disabled={stage.scan.primary_count === 0}
              className="rounded-md bg-kombu text-cream px-5 py-2 text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed hover:bg-kombu/80"
            >
              Submit ingest run
            </button>
            <button
              type="button"
              onClick={reset}
              className="text-xs text-cream/60 hover:text-seal"
            >
              cancel + start over
            </button>
          </div>
        </div>
      )}

      {stage.kind === "triggering" && (
        <div className="text-sm text-cream/70 font-mono">creating Prefect flow run…</div>
      )}

      {stage.kind === "done" && (
        <div className="space-y-4">
          <RunStatus run={stage.run} />
          <button
            type="button"
            onClick={reset}
            className="text-sm text-amber hover:underline"
          >
            ingest another →
          </button>
        </div>
      )}

      {stage.kind === "error" && (
        <div className="rounded-md border border-seal/40 bg-seal/10 px-4 py-3 text-sm">
          <div className="text-seal font-mono">✗ {stage.message}</div>
          <button
            type="button"
            onClick={reset}
            className="mt-2 text-xs text-cream/60 hover:text-amber"
          >
            try again →
          </button>
        </div>
      )}
    </div>
  );
}
