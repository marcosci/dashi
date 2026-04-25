import type {ScanResponse} from "../api/client";

const KIND_BADGE: Record<string, string> = {
  vector:     "bg-kombu/10 text-kombu border-kombu/30",
  raster:     "bg-amber/10 text-amber-deep border-amber/30",
  pointcloud: "bg-amber-light/15 text-amber-deep border-amber/40",
  unknown:    "bg-seal/10 text-seal border-seal/30",
};

export function ScanPreview({scan}: {scan: ScanResponse}) {
  if (scan.rows.length === 0) {
    return (
      <div className="rounded-lg border border-seal/30 bg-seal/5 px-4 py-3 text-sm text-seal">
        no recognised content in this upload
      </div>
    );
  }

  return (
    <div className="rounded-lg border border-line bg-paper overflow-hidden shadow-sm">
      <div className="px-4 py-2.5 bg-cream/60 border-b border-line text-xs text-ink-soft font-mono flex items-center justify-between">
        <span>
          {scan.primary_count} primary target{scan.primary_count === 1 ? "" : "s"}
          {scan.rows.length !== scan.primary_count
            ? ` · ${scan.rows.length - scan.primary_count} skipped`
            : ""}
        </span>
        <span>{scan.rows.length} row{scan.rows.length === 1 ? "" : "s"}</span>
      </div>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-xs uppercase tracking-wide text-ink-soft text-left">
            <th className="px-4 py-2.5 font-medium">kind</th>
            <th className="px-4 py-2.5 font-medium">driver</th>
            <th className="px-4 py-2.5 font-medium">layer</th>
            <th className="px-4 py-2.5 font-medium">file</th>
            <th className="px-4 py-2.5 font-medium">note</th>
          </tr>
        </thead>
        <tbody className="font-mono">
          {scan.rows.map((r, i) => (
            <tr key={i} className="border-t border-line">
              <td className="px-4 py-2.5">
                <span
                  className={
                    "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] " +
                    (KIND_BADGE[r.kind] ?? "bg-line text-ink-soft border-line")
                  }
                >
                  {r.kind}
                </span>
              </td>
              <td className="px-4 py-2.5 text-ink-soft">{r.driver ?? "—"}</td>
              <td className="px-4 py-2.5 text-ink-soft">{r.layer ?? "—"}</td>
              <td className="px-4 py-2.5 text-ink">{r.path}</td>
              <td className="px-4 py-2.5 text-ink-soft">{r.reason ?? ""}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
