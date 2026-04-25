import {useDomains} from "../hooks/useDomains";

interface Props {
  value: string;
  onChange: (id: string) => void;
  disabled?: boolean;
}

export function DomainPicker({value, onChange, disabled}: Props) {
  const q = useDomains();

  if (q.isPending) {
    return <div className="text-sm text-ink-soft">loading domains…</div>;
  }
  if (q.isError) {
    return (
      <div className="text-sm text-seal">
        could not load domains: {String(q.error?.message ?? "error")}
      </div>
    );
  }
  const domains = q.data?.domains ?? [];

  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value)}
      disabled={disabled || domains.length === 0}
      className="w-full rounded-lg bg-paper text-ink px-3.5 py-2.5 text-sm font-mono border border-line shadow-sm hover:border-ink-soft/60 focus:outline-none focus:ring-2 focus:ring-amber/40 focus:border-amber transition disabled:opacity-50"
    >
      <option value="" disabled>
        — pick a domain —
      </option>
      {domains.map((d) => (
        <option key={d.id} value={d.id}>
          {d.id} · {d.title} · {d.max_classification} · {d.retention}
        </option>
      ))}
    </select>
  );
}
