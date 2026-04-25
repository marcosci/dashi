import {NavLink, Outlet} from "react-router-dom";
import {useMe} from "./hooks/useMe";

const NAV: {to: string; label: string}[] = [
  {to: "/", label: "Ingest"},
  {to: "/catalog", label: "Catalog"},
  {to: "/runs", label: "Runs"},
  {to: "/viewer", label: "Viewer"},
];

export function App() {
  const me = useMe();

  return (
    <div className="min-h-screen flex flex-col bg-paper text-ink">
      <header className="border-b border-line">
        <div className="max-w-5xl w-full mx-auto px-6 py-5 flex items-center justify-between gap-6">
          <div className="flex items-center gap-3">
            <img src="/dashi-favicon.svg" alt="" className="w-7 h-7" />
            <span className="font-semibold tracking-tight text-ink">dashi</span>
          </div>
          <nav className="flex items-center gap-1">
            {NAV.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                end={n.to === "/"}
                className={({isActive}) =>
                  [
                    "px-3 py-1.5 text-sm rounded-md transition",
                    isActive
                      ? "bg-cream-deep text-ink font-medium"
                      : "text-ink-soft hover:text-ink hover:bg-cream",
                  ].join(" ")
                }
              >
                {n.label}
              </NavLink>
            ))}
          </nav>
          <div className="text-xs font-mono text-ink-soft text-right">
            {me.isPending ? (
              "…"
            ) : me.data ? (
              <>
                <div className="text-ink">{me.data.user}</div>
                <div>{me.data.groups.join(", ") || "no groups"}</div>
              </>
            ) : (
              "not signed in"
            )}
          </div>
        </div>
      </header>

      <main className="flex-1">
        <div className="max-w-5xl w-full mx-auto px-6 py-12">
          <Outlet />
        </div>
      </main>

      <footer className="border-t border-line">
        <div className="max-w-5xl w-full mx-auto px-6 py-4 text-xs text-ink-soft text-center">
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
