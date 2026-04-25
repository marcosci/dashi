import {useState} from "react";
import {useRuns} from "../hooks/useRuns";
import {useMe} from "../hooks/useMe";

const STATE_STYLES: Record<string, string> = {
  COMPLETED: "bg-kombu/10 text-kombu border-kombu/30",
  RUNNING:   "bg-amber/10 text-amber-deep border-amber/30",
  PENDING:   "bg-line text-ink-soft border-line",
  SCHEDULED: "bg-line text-ink-soft border-line",
  FAILED:    "bg-seal/10 text-seal border-seal/30",
  CRASHED:   "bg-seal/10 text-seal border-seal/30",
  CANCELLED: "bg-line text-ink-soft border-line",
};

function StateBadge({value}: {value: string}) {
  const cls = STATE_STYLES[value] ?? "bg-line text-ink-soft border-line";
  return (
    <span
      className={
        "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-mono " +
        cls
      }
    >
      {value.toLowerCase()}
    </span>
  );
}

export function Runs() {
  const [allUsers, setAllUsers] = useState(false);
  const me = useMe();
  const q = useRuns({limit: 100, all_users: allUsers});

  return (
    <div className="space-y-8">
      <header className="flex items-end justify-between gap-6">
        <div className="space-y-2">
          <h1 className="text-3xl font-semibold tracking-tight text-ink">Runs</h1>
          <p className="text-sm text-ink-soft">
            Prefect flow runs you submitted via this UI. Auto-refreshes every 15 s.
          </p>
        </div>
        <label className="inline-flex items-center gap-2 text-xs text-ink-soft">
          <input
            type="checkbox"
            checked={allUsers}
            onChange={(e) => setAllUsers(e.target.checked)}
            className="accent-amber"
          />
          show runs from all users
        </label>
      </header>

      {!allUsers && me.data && (
        <div className="text-xs font-mono text-ink-soft">
          filter: <span className="text-ink">submitted-by:{me.data.user}</span>
        </div>
      )}

      {q.isPending && <div className="text-sm text-ink-soft">loading…</div>}
      {q.isError && (
        <div className="rounded-lg border border-seal/30 bg-seal/5 px-4 py-3 text-sm text-seal">
          {String(q.error?.message ?? "error")}
        </div>
      )}

      {q.data && (
        <div className="rounded-lg border border-line bg-paper overflow-hidden shadow-sm">
          <div className="px-4 py-2.5 bg-cream/60 border-b border-line text-xs text-ink-soft font-mono flex items-center justify-between">
            <span>
              {q.data.runs.length} run{q.data.runs.length === 1 ? "" : "s"}
            </span>
            <span>auto-refresh 15 s</span>
          </div>
          {q.data.runs.length === 0 ? (
            <div className="px-4 py-10 text-center text-sm text-ink-soft">
              no runs yet — submit one from the Ingest tab
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs uppercase tracking-wide text-ink-soft text-left">
                  <th className="px-4 py-2.5 font-medium">name</th>
                  <th className="px-4 py-2.5 font-medium">state</th>
                  <th className="px-4 py-2.5 font-medium">domain</th>
                  <th className="px-4 py-2.5 font-medium">started</th>
                  <th className="px-4 py-2.5 font-medium">ended</th>
                  <th className="px-4 py-2.5 font-medium"></th>
                </tr>
              </thead>
              <tbody className="font-mono">
                {q.data.runs.map((r) => (
                  <tr key={r.id} className="border-t border-line">
                    <td className="px-4 py-2.5 text-ink">{r.name}</td>
                    <td className="px-4 py-2.5">
                      <StateBadge value={r.state} />
                    </td>
                    <td className="px-4 py-2.5 text-ink-soft">{r.domain ?? "—"}</td>
                    <td className="px-4 py-2.5 text-ink-soft">
                      {r.started ? new Date(r.started).toLocaleString() : "—"}
                    </td>
                    <td className="px-4 py-2.5 text-ink-soft">
                      {r.ended ? new Date(r.ended).toLocaleString() : "—"}
                    </td>
                    <td className="px-4 py-2.5">
                      <a
                        href={r.ui_url}
                        target="_blank"
                        rel="noreferrer"
                        className="text-amber-deep hover:text-amber underline-offset-2 hover:underline text-xs"
                      >
                        open →
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}
