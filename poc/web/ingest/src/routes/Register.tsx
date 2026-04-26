// Register an existing s3:// object that's already in the landing bucket.
// Same downstream pipeline as the upload path (scan → classify → trigger),
// but skips the browser → RustFS PUT entirely. Useful when:
//   - rclone / aws-cli has already synced the file
//   - the dashi-ingest CLI dropped the file overnight
//   - a partner system pushed straight into the bucket

import {useState} from "react";
import {useMutation} from "@tanstack/react-query";

import {api, type ScanResponse, type TriggerResponse, type RegisterResponse} from "../api/client";
import {DomainPicker} from "../components/DomainPicker";
import {ScanPreview} from "../components/ScanPreview";
import {RunStatus} from "../components/RunStatus";

interface Registered {
  meta: RegisterResponse;
  scan: ScanResponse;
}

type Stage =
  | {kind: "idle"}
  | {kind: "checking"}
  | {kind: "scanning"; meta: RegisterResponse}
  | {kind: "scanned"; entry: Registered}
  | {kind: "triggering"; entry: Registered}
  | {kind: "done"; run: TriggerResponse}
  | {kind: "error"; message: string};

const CLASSIFICATIONS: {value: string; label: string}[] = [
  {value: "pub", label: "pub — public, internet-publishable"},
  {value: "int", label: "int — internal, operational data"},
  {value: "rst", label: "rst — restricted, need-to-know"},
  {value: "cnf", label: "cnf — confidential, audited access"},
];

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
  return `${(n / 1024).toFixed(0)} KiB`;
}

export function Register() {
  const [domain, setDomain] = useState("");
  const [classification, setClassification] = useState("int");
  const [s3Uri, setS3Uri] = useState("");
  const [stage, setStage] = useState<Stage>({kind: "idle"});

  const validate = useMutation({
    mutationFn: async () => {
      if (!domain) throw new Error("pick a domain");
      const trimmed = s3Uri.trim();
      if (!trimmed.startsWith("s3://")) {
        throw new Error("s3 URI must start with s3://");
      }
      setStage({kind: "checking"});
      const meta = await api.register({s3_uri: trimmed});
      setStage({kind: "scanning", meta});
      const scan = await api.scan(meta.s3_uri);
      setStage({kind: "scanned", entry: {meta, scan}});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const trigger = useMutation({
    mutationFn: async () => {
      if (stage.kind !== "scanned") throw new Error("scan not complete");
      setStage({kind: "triggering", entry: stage.entry});
      const run = await api.trigger({
        s3_uri: stage.entry.meta.s3_uri,
        domain,
        classification,
      });
      setStage({kind: "done", run});
    },
    onError: (e: Error) => setStage({kind: "error", message: e.message}),
  });

  const reset = () => {
    setS3Uri("");
    setStage({kind: "idle"});
  };

  const busy =
    stage.kind === "checking" ||
    stage.kind === "scanning" ||
    stage.kind === "triggering";

  return (
    <div className="space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight text-ink">
          Register existing object
        </h1>
        <p className="text-sm text-ink-soft">
          Object already in the landing bucket (rclone sync, dashi-ingest CLI,
          partner push)? Paste its <code className="text-amber-deep">s3://</code> URI
          and run scan + classify + trigger without re-uploading.
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
          S3 URI
        </label>
        <input
          type="text"
          value={s3Uri}
          onChange={(e) => {
            setS3Uri(e.target.value);
            if (stage.kind !== "idle") setStage({kind: "idle"});
          }}
          disabled={busy}
          placeholder="s3://landing/<domain>/<key>"
          className="w-full rounded-lg bg-paper text-ink px-3.5 py-2.5 text-sm font-mono border border-line shadow-sm hover:border-ink-soft/60 focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber transition disabled:opacity-50"
        />
        <p className="text-xs text-ink-soft">
          must point at the configured landing bucket; HEAD is run to verify
          the object exists.
        </p>
      </section>

      {stage.kind === "idle" && (
        <div>
          <button
            type="button"
            disabled={!domain || s3Uri.trim() === ""}
            onClick={() => validate.mutate()}
            className="inline-flex items-center justify-center rounded-lg bg-ink text-paper px-5 py-2.5 text-sm font-medium shadow-sm hover:bg-ink-soft transition disabled:opacity-40 disabled:cursor-not-allowed"
          >
            Validate + scan
          </button>
        </div>
      )}

      {stage.kind === "checking" && <StatusLine label="checking object exists…" />}
      {stage.kind === "scanning" && (
        <StatusLine label={`scanning ${stage.meta.key}`} />
      )}

      {stage.kind === "scanned" && (
        <div className="space-y-6">
          <div className="rounded-lg border border-line bg-cream/40 px-4 py-3 text-xs font-mono text-ink-soft space-y-0.5">
            <div>
              <span className="text-ink-soft">key:</span>{" "}
              <span className="text-ink break-all">{stage.entry.meta.key}</span>
            </div>
            <div>
              <span className="text-ink-soft">size:</span>{" "}
              <span className="text-ink">{fmtBytes(stage.entry.meta.content_length)}</span>
            </div>
            {stage.entry.meta.last_modified && (
              <div>
                <span className="text-ink-soft">last_modified:</span>{" "}
                <span className="text-ink">{stage.entry.meta.last_modified}</span>
              </div>
            )}
          </div>
          <ScanPreview scan={stage.entry.scan} />
          <div className="flex items-center gap-4 pt-2">
            <button
              type="button"
              onClick={() => trigger.mutate()}
              disabled={stage.entry.scan.primary_count === 0}
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
        <div className="space-y-3">
          <RunStatus run={stage.run} />
          <button
            type="button"
            onClick={reset}
            className="text-sm text-amber-deep hover:text-amber underline-offset-2 hover:underline font-medium"
          >
            register another →
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
