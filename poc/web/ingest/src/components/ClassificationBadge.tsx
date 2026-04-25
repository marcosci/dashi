const STYLES: Record<string, string> = {
  pub: "bg-kombu/10 text-kombu border-kombu/30",
  int: "bg-amber/10 text-amber-deep border-amber/30",
  rst: "bg-amber-light/15 text-amber-deep border-amber/40",
  cnf: "bg-seal/10 text-seal border-seal/30",
};

export function ClassificationBadge({value}: {value: string}) {
  const cls = STYLES[value] ?? "bg-line text-ink-soft border-line";
  return (
    <span
      className={
        "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-mono " +
        cls
      }
      title={value}
    >
      {value}
    </span>
  );
}
