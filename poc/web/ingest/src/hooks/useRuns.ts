import {useQuery} from "@tanstack/react-query";
import {api} from "../api/client";

export function useRuns(opts: {limit?: number; all_users?: boolean} = {}) {
  return useQuery({
    queryKey: ["runs", opts],
    queryFn: () => api.runs(opts),
    staleTime: 10_000,
    refetchInterval: 15_000,
  });
}
