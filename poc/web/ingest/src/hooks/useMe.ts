import {useQuery} from "@tanstack/react-query";
import {api} from "../api/client";

export function useMe() {
  return useQuery({
    queryKey: ["me"],
    queryFn: api.me,
    staleTime: 5 * 60_000,
    retry: false,
  });
}
