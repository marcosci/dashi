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

function StatusLine({label}: {label: string}) {
  return (
    <div className="flex items-center gap-2 text-sm text-ink-soft">
      <span className="inline-block h-2 w-2 rounded-full bg-amber animate-pulse" />
      <span className="font-mono">{label}</span>
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
      const run = await api.trigger({s3_uri: stage.s3_uri, domain, classification});
      setStage({kind: "done", run});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const reset = () => {
    setFile(null);
    setStage({kind: "idle"});
  };

  const busy =
    stage.kind === "uploading" ||
    stage.kind === "scanning" ||
    stage.kind === "triggering";

  return (
    <div className="space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight text-ink">
          Ingest a dataset
        </h1>
        <p className="text-sm text-ink-soft">
          Drop a file, pick a domain, preview detection, submit. The Prefect
          run takes it from there.
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
          File
        </label>
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
        <div>
          <button
            type="button"
            disabled={!file || !domain}
            onClick={() => uploadAndScan.mutate()}
            className="inline-flex items-center justify-center rounded-lg bg-ink text-paper px-5 py-2.5 text-sm font-medium shadow-sm hover:bg-ink-soft transition disabled:opacity-40 disabled:cursor-not-allowed"
          >
            Upload + scan
          </button>
        </div>
      )}

      {stage.kind === "uploading" && (
        <StatusLine label={`uploading ${file?.name ?? ""}…`} />
      )}
      {stage.kind === "scanning" && (
        <StatusLine label="running detect.discover…" />
      )}

      {stage.kind === "scanned" && (
        <div className="space-y-4">
          <ScanPreview scan={stage.scan} />
          <div className="flex items-center gap-4">
            <button
              type="button"
              onClick={() => trigger.mutate()}
              disabled={stage.scan.primary_count === 0}
              className="inline-flex items-center justify-center rounded-lg bg-amber text-ink px-5 py-2.5 text-sm font-medium shadow-sm hover:bg-amber-light transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Submit ingest run →
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
        <StatusLine label="creating Prefect flow run…" />
      )}

      {stage.kind === "done" && (
        <div className="space-y-4">
          <RunStatus run={stage.run} />
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
