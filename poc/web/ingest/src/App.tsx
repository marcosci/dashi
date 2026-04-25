import {Outlet} from "react-router-dom";
import {useMe} from "./hooks/useMe";

export function App() {
  const me = useMe();

  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-cream/10 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <img src="/dashi-favicon.svg" alt="" className="w-7 h-7" />
          <span className="font-semibold tracking-tight text-amber">dashi</span>
          <span className="text-cream/60 text-sm">· ingest</span>
        </div>
        <div className="text-xs font-mono text-cream/70">
          {me.isPending ? "…" : me.data ? <>{me.data.user} <span className="text-cream/40">· {me.data.groups.join(", ") || "no groups"}</span></> : "no auth"}
        </div>
      </header>

      <main className="flex-1 px-6 py-10 max-w-3xl w-full mx-auto">
        <Outlet />
      </main>

      <footer className="border-t border-cream/10 px-6 py-4 text-xs text-cream/40 text-center">
        Apache-2.0 · <a href="https://github.com/marcosci/dashi" className="text-amber hover:underline">marcosci/dashi</a>
      </footer>
    </div>
  );
}
