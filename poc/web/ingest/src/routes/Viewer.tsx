import {useState} from "react";

const POINTCLOUD_URL = "/viewer/pointcloud.html";
const TILES_BASE = "/martin";  // when wired through nginx; defaults to "open externally"

export function Viewer() {
  const [tab, setTab] = useState<"pointcloud" | "tiles">("pointcloud");

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
        <section className="space-y-3">
          <p className="text-sm text-ink-soft">
            Vector-tile demo backed by Martin. Phase-1 placeholder — open the
            Martin TileJSON catalog to see what's available, then wire a
            MapLibre style against it.
          </p>
          <div className="rounded-lg border border-line shadow-sm bg-paper p-6 space-y-3 text-sm">
            <div className="font-mono text-ink-soft text-xs uppercase tracking-wider">
              Endpoints
            </div>
            <ul className="font-mono text-sm space-y-1">
              <li>
                <span className="text-ink-soft">GET</span>{" "}
                <a
                  href={`${TILES_BASE}/catalog`}
                  target="_blank"
                  rel="noreferrer"
                  className="text-amber-deep hover:underline"
                >
                  {TILES_BASE}/catalog
                </a>{" "}
                <span className="text-ink-soft">— list tile sources</span>
              </li>
              <li>
                <span className="text-ink-soft">GET</span>{" "}
                <span className="text-ink">{TILES_BASE}/&lt;source&gt;</span>{" "}
                <span className="text-ink-soft">— TileJSON 3.0.0</span>
              </li>
              <li>
                <span className="text-ink-soft">GET</span>{" "}
                <span className="text-ink">{TILES_BASE}/&lt;source&gt;/{`{z}/{x}/{y}`}</span>{" "}
                <span className="text-ink-soft">— MVT</span>
              </li>
            </ul>
            <div className="text-xs text-ink-soft pt-2 border-t border-line">
              The ingest-web nginx does not yet proxy <code className="font-mono">{TILES_BASE}</code>{" "}
              — for now port-forward Martin and visit{" "}
              <code className="font-mono">http://localhost:3000/catalog</code>.
            </div>
          </div>
        </section>
      )}
    </div>
  );
}
