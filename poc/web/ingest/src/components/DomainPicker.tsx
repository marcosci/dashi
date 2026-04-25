import {useDomains} from "../hooks/useDomains";

interface Props {
  value: string;
  onChange: (id: string) => void;
  disabled?: boolean;
}

export function DomainPicker({value, onChange, disabled}: Props) {
  const q = useDomains();

  if (q.isPending) {
    return <div className="text-sm text-cream/50">loading domains…</div>;
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
      className="w-full rounded-md bg-cream-deep text-ink px-3 py-2 text-sm font-mono border border-cream/20 focus:outline-none focus:ring-2 focus:ring-amber"
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
