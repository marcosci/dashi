import type {TriggerResponse} from "../api/client";

export function RunStatus({run}: {run: TriggerResponse}) {
  return (
    <div className="rounded-lg border border-kombu/30 bg-kombu/5 px-5 py-4 shadow-sm">
      <div className="flex items-start gap-3">
        <span className="mt-0.5 inline-flex h-5 w-5 items-center justify-center rounded-full bg-kombu text-paper text-xs">
          ✓
        </span>
        <div className="flex-1">
          <div className="text-sm text-ink">
            Flow run created ·{" "}
            <span className="font-mono text-kombu">{run.flow_run_name}</span>
          </div>
          <div className="text-xs text-ink-soft font-mono mt-1">
            state: {run.state} · id: {run.flow_run_id.slice(0, 8)}…
          </div>
          <a
            href={run.ui_url}
            target="_blank"
            rel="noreferrer"
            className="inline-block mt-3 text-xs font-medium text-amber-deep hover:text-amber underline-offset-2 hover:underline"
          >
            open in Prefect UI →
          </a>
        </div>
      </div>
    </div>
  );
}
