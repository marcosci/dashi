import {useState} from "react";
import {useQuery} from "@tanstack/react-query";
import {useCatalog} from "../hooks/useCatalog";
import {useDomains} from "../hooks/useDomains";
import {ClassificationBadge} from "../components/ClassificationBadge";
import {api} from "../api/client";

function FragmentRow({k, v}: {k: string; v: unknown}) {
  return (
    <>
      <dt className="text-ink-soft truncate">{k.replace(/^dashi:/, "")}</dt>
      <dd className="col-span-2 break-all">
        {Array.isArray(v) ? v.join(", ") : v === null || v === undefined ? "—" : String(v)}
      </dd>
    </>
  );
}

function ItemDetailBody({item}: {item: any}) {
  const props = item.properties ?? {};
  const assets = item.assets ?? {};
  const dashiKeys = Object.keys(props).filter((k) => k.startsWith("dashi:")).sort();
  const lineageKeys = dashiKeys.filter(
    (k) => k.startsWith("dashi:prefect_") || k === "dashi:source_hash",
  );
  const otherKeys = dashiKeys.filter((k) => !lineageKeys.includes(k));
  return (
    <>
      <section>
        <h3 className="text-xs uppercase tracking-wider text-ink-soft mb-2">Identity</h3>
        <dl className="grid grid-cols-3 gap-x-3 gap-y-1 text-xs font-mono">
          <dt className="text-ink-soft">collection</dt><dd className="col-span-2">{item.collection}</dd>
          <dt className="text-ink-soft">id</dt><dd className="col-span-2 break-all">{item.id}</dd>
          <dt className="text-ink-soft">datetime</dt><dd className="col-span-2">{props.datetime ?? "—"}</dd>
          {item.bbox && (
            <>
              <dt className="text-ink-soft">bbox</dt>
              <dd className="col-span-2">{item.bbox.map((n: number) => n.toFixed(4)).join(", ")}</dd>
            </>
          )}
        </dl>
      </section>
      <section>
        <h3 className="text-xs uppercase tracking-wider text-ink-soft mb-2">dashi properties</h3>
        <dl className="grid grid-cols-3 gap-x-3 gap-y-1 text-xs font-mono">
          {otherKeys.map((k) => (
            <FragmentRow key={k} k={k} v={props[k]} />
          ))}
        </dl>
      </section>
      {lineageKeys.length > 0 && (
        <section>
          <h3 className="text-xs uppercase tracking-wider text-ink-soft mb-2">Lineage</h3>
          <dl className="grid grid-cols-3 gap-x-3 gap-y-1 text-xs font-mono">
            {lineageKeys.map((k) => {
              const v = props[k];
              if (k === "dashi:prefect_flow_run_url" && typeof v === "string") {
                return (
                  <div key={k} className="col-span-3">
                    <a href={v} target="_blank" rel="noreferrer" className="text-amber-deep hover:underline">
                      open prefect run →
                    </a>
                  </div>
                );
              }
              return <FragmentRow key={k} k={k} v={v} />;
            })}
          </dl>
        </section>
      )}
      <section>
        <h3 className="text-xs uppercase tracking-wider text-ink-soft mb-2">Assets</h3>
        <ul className="space-y-2 text-xs font-mono">
          {Object.entries(assets).map(([name, a]: any) => (
            <li key={name} className="rounded border border-line bg-cream/40 px-3 py-2">
              <div className="text-ink">{name}</div>
              <div className="text-ink-soft mt-0.5 break-all">{a.href}</div>
              <div className="text-ink-soft text-[11px] mt-0.5">
                {a.type ?? a.media_type ?? ""} · {(a.roles ?? []).join(", ")}
              </div>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}

function ItemDetail({collection, id, onClose}: {collection: string; id: string; onClose: () => void}) {
  const q = useQuery({
    queryKey: ["catalog-item", collection, id],
    queryFn: () => api.catalogItem(collection, id),
    staleTime: 30_000,
  });
  return (
    <aside className="fixed inset-y-0 right-0 w-full sm:w-[480px] bg-paper border-l border-line shadow-xl overflow-y-auto z-20">
      <div className="px-5 py-4 border-b border-line flex items-center justify-between bg-cream/60">
        <div className="font-mono text-sm text-ink truncate">{id}</div>
        <button
          onClick={onClose}
          className="text-xs text-ink-soft hover:text-ink"
          aria-label="close"
        >
          ✕ close
        </button>
      </div>
      <div className="p-5 space-y-4 text-sm">
        {q.isPending && <div className="text-ink-soft">loading…</div>}
        {q.isError && <div className="text-seal">{String((q.error as Error)?.message)}</div>}
        {q.data && <ItemDetailBody item={q.data as any} />}
      </div>
    </aside>
  );
}

const KINDS = ["", "vector", "raster", "pointcloud"] as const;
const CLASSES = ["", "pub", "int", "rst", "cnf"] as const;

export function Catalog() {
  const [collection, setCollection] = useState<string>("");
  const [kind, setKind] = useState<string>("");
  const [classification, setClassification] = useState<string>("");
  const [open, setOpen] = useState<{collection: string; id: string} | null>(null);

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
                  <tr
                    key={it.id}
                    className="border-t border-line hover:bg-cream/40 cursor-pointer"
                    onClick={() => setOpen({collection: it.collection, id: it.id})}
                  >
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
      {open && (
        <ItemDetail
          collection={open.collection}
          id={open.id}
          onClose={() => setOpen(null)}
        />
      )}
    </div>
  );
}
