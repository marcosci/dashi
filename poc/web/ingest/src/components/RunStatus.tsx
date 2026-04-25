import type {TriggerResponse} from "../api/client";

export function RunStatus({run}: {run: TriggerResponse}) {
  return (
    <div className="rounded-md border border-kombu/40 bg-kombu/10 px-4 py-3 text-sm">
      <div className="font-mono text-cream">
        ✓ flow run created · <span className="text-amber-light">{run.flow_run_name}</span>
      </div>
      <div className="text-xs text-cream/60 mt-1">
        state: <span className="font-mono">{run.state}</span> · id: <span className="font-mono">{run.flow_run_id.slice(0, 8)}…</span>
      </div>
      <a
        href={run.ui_url}
        target="_blank"
        rel="noreferrer"
        className="inline-block mt-2 text-xs text-amber hover:underline font-mono"
      >
        open in Prefect UI →
      </a>
    </div>
  );
}
