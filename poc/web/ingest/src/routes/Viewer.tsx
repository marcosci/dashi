import {useEffect, useRef, useState} from "react";
import {useQuery} from "@tanstack/react-query";

const POINTCLOUD_URL = "/viewer/pointcloud.html";
const MARTIN = "/martin";

interface MartinSource {
  content_type?: string;
  description?: string;
  name?: string;
}

interface MartinCatalog {
  tiles?: Record<string, MartinSource>;
  fonts?: Record<string, unknown>;
  sprites?: Record<string, unknown>;
  // older Martin: just an object of source-id → source
  [k: string]: unknown;
}

function useMartinCatalog() {
  return useQuery({
    queryKey: ["martin-catalog"],
    queryFn: async () => {
      const r = await fetch(`${MARTIN}/catalog`);
      if (!r.ok) throw new Error(`martin /catalog ${r.status}`);
      return (await r.json()) as MartinCatalog;
    },
    staleTime: 60_000,
  });
}

function MartinMap({sourceId}: {sourceId: string}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let map: any;
    let cancelled = false;
    (async () => {
      const maplibregl = (await import("maplibre-gl")).default;
      await import("maplibre-gl/dist/maplibre-gl.css" as any).catch(() => undefined);
      if (cancelled || !ref.current) return;
      const tjUrl = `${MARTIN}/${sourceId}`;
      const tj = await (await fetch(tjUrl)).json();
      const layers: any[] = [];
      for (const vl of tj.vector_layers ?? []) {
        const fields = vl.fields ?? {};
        const isLine = (fields.highway || fields.railway || fields.waterway) !== undefined;
        const isPoly = !isLine;
        layers.push({
          id: `${sourceId}-${vl.id}-${isPoly ? "fill" : "line"}`,
          type: isPoly ? "fill" : "line",
          source: sourceId,
          "source-layer": vl.id,
          paint: isPoly
            ? {"fill-color": "rgba(200,130,31,0.18)", "fill-outline-color": "#8a5410"}
            : {"line-color": "#8a5410", "line-width": 1.2},
        });
      }
      map = new maplibregl.Map({
        container: ref.current,
        style: {
          version: 8,
          sources: {
            osm: {
              type: "raster",
              tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
              tileSize: 256,
              attribution: "© OpenStreetMap contributors",
            },
            [sourceId]: {type: "vector", url: tjUrl},
          },
          layers: [{id: "osm", type: "raster", source: "osm"}, ...layers],
        },
        center: tj.center
          ? [tj.center[0], tj.center[1]]
          : tj.bounds
          ? [(tj.bounds[0] + tj.bounds[2]) / 2, (tj.bounds[1] + tj.bounds[3]) / 2]
          : [13.74, 51.05],
        zoom: tj.center?.[2] ?? 11,
        attributionControl: {compact: true},
      });
      map.addControl(new maplibregl.NavigationControl({}), "top-right");
    })();
    return () => {
      cancelled = true;
      if (map) map.remove();
    };
  }, [sourceId]);

  return <div ref={ref} className="w-full" style={{height: "70vh"}} />;
}

export function Viewer() {
  const [tab, setTab] = useState<"pointcloud" | "tiles">("pointcloud");
  const cat = useMartinCatalog();
  const sources = cat.data?.tiles
    ? Object.keys(cat.data.tiles)
    : Object.keys((cat.data ?? {}) as Record<string, unknown>).filter((k) =>
        ["string", "object"].includes(typeof (cat.data as any)?.[k]),
      );
  const [sourceId, setSourceId] = useState<string>("");

  useEffect(() => {
    if (!sourceId && sources.length > 0) setSourceId(sources[0]);
  }, [sources, sourceId]);

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight text-ink">Viewer</h1>
        <p className="text-sm text-ink-soft">
          Browser-side renderers for the data dashi serves. Point clouds via{" "}
          <a
            href="https://github.com/opengeos/maplibre-gl-lidar"
            target="_blank"
            rel="noreferrer"
            className="text-amber-deep hover:text-amber underline-offset-2 hover:underline"
          >
            maplibre-gl-lidar
          </a>
          ; vector tiles via Martin + MapLibre.
        </p>
      </header>

      <nav className="inline-flex border border-line rounded-lg bg-cream/60 p-1 text-sm font-mono">
        <button
          type="button"
          onClick={() => setTab("pointcloud")}
          className={
            "px-3 py-1.5 rounded-md transition " +
            (tab === "pointcloud" ? "bg-paper text-ink shadow-sm" : "text-ink-soft hover:text-ink")
          }
        >
          point cloud
        </button>
        <button
          type="button"
          onClick={() => setTab("tiles")}
          className={
            "px-3 py-1.5 rounded-md transition " +
            (tab === "tiles" ? "bg-paper text-ink shadow-sm" : "text-ink-soft hover:text-ink")
          }
        >
          vector tiles
        </button>
      </nav>

      {tab === "pointcloud" && (
        <section className="space-y-3">
          <p className="text-sm text-ink-soft">
            Paste a presigned COPC URL (mint with <code className="font-mono text-ink">make pointcloud-presign</code>).
            Streams viewport-by-viewport via HTTP-range, no full download.
          </p>
          <div className="rounded-lg overflow-hidden border border-line shadow-sm bg-paper">
            <iframe
              src={POINTCLOUD_URL}
              title="dashi point cloud viewer"
              className="w-full"
              style={{height: "70vh", border: "none"}}
            />
          </div>
          <a
            href={POINTCLOUD_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-block text-xs text-amber-deep hover:text-amber underline-offset-2 hover:underline font-mono"
          >
            open viewer in new tab →
          </a>
        </section>
      )}

      {tab === "tiles" && (
        <section className="space-y-4">
          {cat.isPending && <div className="text-sm text-ink-soft">loading martin catalog…</div>}
          {cat.isError && (
            <div className="rounded-lg border border-seal/30 bg-seal/5 px-4 py-3 text-sm text-seal">
              martin not reachable: {String((cat.error as Error)?.message ?? "")}
            </div>
          )}
          {cat.data && (
            <>
              <div className="flex items-center gap-3">
                <label className="text-xs uppercase tracking-wider text-ink-soft">
                  Source
                </label>
                <select
                  value={sourceId}
                  onChange={(e) => setSourceId(e.target.value)}
                  className="rounded-lg bg-paper text-ink px-3 py-2 text-sm font-mono border border-line shadow-sm focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber"
                >
                  {sources.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
                <span className="text-xs text-ink-soft">
                  {sources.length} layer{sources.length === 1 ? "" : "s"}
                </span>
              </div>
              {sourceId && (
                <div className="rounded-lg overflow-hidden border border-line shadow-sm bg-paper">
                  <MartinMap sourceId={sourceId} />
                </div>
              )}
            </>
          )}
        </section>
      )}
    </div>
  );
}
