// Minimal fetch wrapper. All requests go through `/api/...` which Vite's
// dev server proxies to the FastAPI shim, and which production nginx
// forwards on the same origin.

const API_BASE = "/api";

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const r = await fetch(`${API_BASE}${path}`, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
    ...init,
  });
  if (!r.ok) {
    let detail = `${r.status} ${r.statusText}`;
    try {
      const body = await r.json();
      if (body?.detail) detail = String(body.detail);
    } catch {
      // not JSON
    }
    throw new Error(detail);
  }
  return (await r.json()) as T;
}

export interface Me {
  user: string;
  groups: string[];
}

export interface Domain {
  id: string;
  title: string;
  description: string | null;
  max_classification: string;
  retention: string;
}

export interface DomainsResponse {
  domains: Domain[];
}

export interface PresignResponse {
  url: string;
  bucket: string;
  key: string;
  s3_uri: string;
  expires_in: number;
}

export interface ScanRow {
  path: string;
  kind: "vector" | "raster" | "pointcloud" | "unknown";
  driver: string | null;
  layer: string | null;
  reason: string | null;
  ok: boolean;
  warnings: string[];
  errors: string[];
}

export interface ScanResponse {
  rows: ScanRow[];
  primary_count: number;
  blocking_errors: number;
}

export interface TriggerResponse {
  flow_run_id: string;
  flow_run_name: string;
  state: string;
  ui_url: string;
}

export interface CatalogItem {
  id: string;
  collection: string;
  datetime: string | null;
  kind: string | null;
  classification: string;
  source_name: string | null;
  object_count: number | null;
  bbox: number[] | null;
  prefect_flow_run_id: string | null;
  prefect_flow_run_url: string | null;
  prefect_flow_name: string | null;
  asset_keys: string[];
}

export interface CatalogResponse {
  items: CatalogItem[];
  next: string | null;
}

export interface FlowRun {
  id: string;
  name: string;
  state: string;
  domain: string | null;
  created: string;
  started: string | null;
  ended: string | null;
  ui_url: string;
}

export interface RunsResponse {
  runs: FlowRun[];
}

function qs(params: Record<string, string | number | boolean | undefined | null>): string {
  const s = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null || v === "") continue;
    s.set(k, String(v));
  }
  const out = s.toString();
  return out ? `?${out}` : "";
}

export const api = {
  me: () => request<Me>("/me"),
  domains: () => request<DomainsResponse>("/domains"),
  presign: (body: {
    domain: string;
    filename: string;
    content_type: string;
    content_length: number;
  }) =>
    request<PresignResponse>("/presign", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  scan: (s3_uri: string) =>
    request<ScanResponse>("/scan", {method: "POST", body: JSON.stringify({s3_uri})}),
  trigger: (body: {s3_uri: string; domain: string; collection_description?: string}) =>
    request<TriggerResponse>("/trigger", {method: "POST", body: JSON.stringify(body)}),
  catalog: (filters: {
    collection?: string;
    classification?: string;
    kind?: string;
    limit?: number;
  } = {}) => request<CatalogResponse>(`/catalog/items${qs(filters)}`),
  runs: (opts: {limit?: number; all_users?: boolean} = {}) =>
    request<RunsResponse>(`/runs${qs(opts)}`),
};

export async function presignedPut(url: string, file: File): Promise<void> {
  const r = await fetch(url, {
    method: "PUT",
    headers: {"Content-Type": file.type || "application/octet-stream"},
    body: file,
  });
  if (!r.ok) {
    throw new Error(`upload failed: ${r.status} ${r.statusText}`);
  }
}
