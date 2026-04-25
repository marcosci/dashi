import {useQuery} from "@tanstack/react-query";
import {api} from "../api/client";

export function useDomains() {
  return useQuery({
    queryKey: ["domains"],
    queryFn: api.domains,
    staleTime: 5 * 60_000,
  });
}
