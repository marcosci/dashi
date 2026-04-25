import {Outlet} from "react-router-dom";
import {useMe} from "./hooks/useMe";

export function App() {
  const me = useMe();

  return (
    <div className="min-h-screen flex flex-col bg-paper text-ink">
      <header className="border-b border-line">
        <div className="max-w-3xl w-full mx-auto px-6 py-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img src="/dashi-favicon.svg" alt="" className="w-7 h-7" />
            <div className="flex items-baseline gap-2">
              <span className="font-semibold tracking-tight text-ink">dashi</span>
              <span className="text-sm text-ink-soft">ingest</span>
            </div>
          </div>
          <div className="text-xs font-mono text-ink-soft">
            {me.isPending ? (
              "…"
            ) : me.data ? (
              <>
                <span className="text-ink">{me.data.user}</span>
                <span className="mx-2 text-line">·</span>
                <span>{me.data.groups.join(", ") || "no groups"}</span>
              </>
            ) : (
              "not signed in"
            )}
          </div>
        </div>
      </header>

      <main className="flex-1">
        <div className="max-w-3xl w-full mx-auto px-6 py-12">
          <Outlet />
        </div>
      </main>

      <footer className="border-t border-line">
        <div className="max-w-3xl w-full mx-auto px-6 py-4 text-xs text-ink-soft text-center">
          Apache-2.0 ·{" "}
          <a
            href="https://github.com/marcosci/dashi"
            className="text-amber-deep hover:text-amber underline-offset-2 hover:underline"
          >
            marcosci/dashi
          </a>
        </div>
      </footer>
    </div>
  );
}
