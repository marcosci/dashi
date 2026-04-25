import {useState} from "react";
import {useCatalog} from "../hooks/useCatalog";
import {useDomains} from "../hooks/useDomains";
import {ClassificationBadge} from "../components/ClassificationBadge";

const KINDS = ["", "vector", "raster", "pointcloud"] as const;
const CLASSES = ["", "pub", "int", "rst", "cnf"] as const;

export function Catalog() {
  const [collection, setCollection] = useState<string>("");
  const [kind, setKind] = useState<string>("");
  const [classification, setClassification] = useState<string>("");

  const dq = useDomains();
  const cq = useCatalog({collection, kind, classification, limit: 100});

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight text-ink">Catalog</h1>
        <p className="text-sm text-ink-soft">
          Every STAC item under the dashi collections, with classification + lineage links.
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div>
          <label className="block text-xs uppercase tracking-wider text-ink-soft mb-1">
            Collection
          </label>
          <select
            value={collection}
            onChange={(e) => setCollection(e.target.value)}
            className="w-full rounded-lg bg-paper text-ink px-3.5 py-2 text-sm font-mono border border-line shadow-sm focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber"
          >
            <option value="">all collections</option>
            {(dq.data?.domains ?? []).map((d) => (
              <option key={d.id} value={d.id}>
                {d.id}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs uppercase tracking-wider text-ink-soft mb-1">Kind</label>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value)}
            className="w-full rounded-lg bg-paper text-ink px-3.5 py-2 text-sm font-mono border border-line shadow-sm focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber"
          >
            {KINDS.map((k) => (
              <option key={k} value={k}>
                {k || "any kind"}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs uppercase tracking-wider text-ink-soft mb-1">
            Classification
          </label>
          <select
            value={classification}
            onChange={(e) => setClassification(e.target.value)}
            className="w-full rounded-lg bg-paper text-ink px-3.5 py-2 text-sm font-mono border border-line shadow-sm focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber"
          >
            {CLASSES.map((c) => (
              <option key={c} value={c}>
                {c || "any class"}
              </option>
            ))}
          </select>
        </div>
      </section>

      {cq.isPending && <div className="text-sm text-ink-soft">loading…</div>}
      {cq.isError && (
        <div className="rounded-lg border border-seal/30 bg-seal/5 px-4 py-3 text-sm text-seal">
          {String(cq.error?.message ?? "error")}
        </div>
      )}

      {cq.data && (
        <div className="rounded-lg border border-line bg-paper overflow-hidden shadow-sm">
          <div className="px-4 py-2.5 bg-cream/60 border-b border-line text-xs text-ink-soft font-mono flex items-center justify-between">
            <span>
              {cq.data.items.length} item{cq.data.items.length === 1 ? "" : "s"}
            </span>
            <span>limit 100</span>
          </div>
          {cq.data.items.length === 0 ? (
            <div className="px-4 py-10 text-center text-sm text-ink-soft">
              no items match the current filters
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs uppercase tracking-wide text-ink-soft text-left">
                  <th className="px-4 py-2.5 font-medium">id</th>
                  <th className="px-4 py-2.5 font-medium">collection</th>
                  <th className="px-4 py-2.5 font-medium">kind</th>
                  <th className="px-4 py-2.5 font-medium">class</th>
                  <th className="px-4 py-2.5 font-medium">source</th>
                  <th className="px-4 py-2.5 font-medium">objects</th>
                  <th className="px-4 py-2.5 font-medium">lineage</th>
                </tr>
              </thead>
              <tbody className="font-mono">
                {cq.data.items.map((it) => (
                  <tr key={it.id} className="border-t border-line">
                    <td className="px-4 py-2.5 text-ink">{it.id.slice(0, 16)}</td>
                    <td className="px-4 py-2.5 text-ink-soft">{it.collection}</td>
                    <td className="px-4 py-2.5 text-ink-soft">{it.kind ?? "—"}</td>
                    <td className="px-4 py-2.5">
                      <ClassificationBadge value={it.classification} />
                    </td>
                    <td className="px-4 py-2.5 text-ink-soft">
                      {it.source_name ?? "—"}
                    </td>
                    <td className="px-4 py-2.5 text-ink-soft">
                      {it.object_count ?? "—"}
                    </td>
                    <td className="px-4 py-2.5">
                      {it.prefect_flow_run_url ? (
                        <a
                          href={it.prefect_flow_run_url}
                          target="_blank"
                          rel="noreferrer"
                          className="text-amber-deep hover:text-amber underline-offset-2 hover:underline"
                          title={it.prefect_flow_run_id ?? ""}
                        >
                          {it.prefect_flow_name ?? "Prefect"} →
                        </a>
                      ) : (
                        <span className="text-ink-soft">—</span>
                      )}
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
