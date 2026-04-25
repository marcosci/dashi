import type {ScanResponse} from "../api/client";

const KIND_COLOR: Record<string, string> = {
  vector: "text-kombu",
  raster: "text-amber-light",
  pointcloud: "text-amber",
  unknown: "text-seal",
};

export function ScanPreview({scan}: {scan: ScanResponse}) {
  if (scan.rows.length === 0) {
    return <div className="text-sm text-seal">no recognised content in this upload</div>;
  }

  return (
    <div className="rounded-md border border-cream/15 overflow-hidden">
      <div className="px-4 py-2 bg-cream/5 text-xs text-cream/60 font-mono">
        {scan.primary_count} primary target{scan.primary_count === 1 ? "" : "s"}
        {scan.rows.length !== scan.primary_count
          ? ` · ${scan.rows.length - scan.primary_count} skipped`
          : ""}
      </div>
      <table className="w-full text-sm font-mono">
        <thead>
          <tr className="text-xs text-cream/50 text-left">
            <th className="px-4 py-2 font-normal">kind</th>
            <th className="px-4 py-2 font-normal">driver</th>
            <th className="px-4 py-2 font-normal">layer</th>
            <th className="px-4 py-2 font-normal">file</th>
            <th className="px-4 py-2 font-normal">note</th>
          </tr>
        </thead>
        <tbody>
          {scan.rows.map((r, i) => (
            <tr key={i} className="border-t border-cream/10">
              <td className={`px-4 py-2 ${KIND_COLOR[r.kind] ?? "text-cream"}`}>{r.kind}</td>
              <td className="px-4 py-2 text-cream/70">{r.driver ?? "—"}</td>
              <td className="px-4 py-2 text-cream/70">{r.layer ?? "—"}</td>
              <td className="px-4 py-2 text-cream/90">{r.path}</td>
              <td className="px-4 py-2 text-cream/50">{r.reason ?? ""}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
