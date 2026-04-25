import {useQuery} from "@tanstack/react-query";
import {api} from "../api/client";

export function useCatalog(filters: {
  collection?: string;
  classification?: string;
  kind?: string;
  limit?: number;
} = {}) {
  return useQuery({
    queryKey: ["catalog", filters],
    queryFn: () => api.catalog(filters),
    staleTime: 30_000,
  });
}
