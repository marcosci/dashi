import {render, screen} from "@testing-library/react";
import {QueryClient, QueryClientProvider} from "@tanstack/react-query";
import {MemoryRouter} from "react-router-dom";
import {describe, it, expect, vi, beforeEach} from "vitest";

import {Ingest} from "../src/routes/Ingest";

function renderInRouter() {
  const qc = new QueryClient({defaultOptions: {queries: {retry: false}}});
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter>
        <Ingest />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  // Stub /api/domains so DomainPicker resolves.
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string) => {
      if (typeof url === "string" && url.endsWith("/domains")) {
        return new Response(
          JSON.stringify({
            domains: [
              {
                id: "gelaende-umwelt",
                title: "Terrain & environment",
                description: null,
                max_classification: "int",
                retention: "indefinite",
              },
            ],
          }),
          {status: 200, headers: {"Content-Type": "application/json"}},
        );
      }
      return new Response("{}", {status: 200});
    }),
  );
});

describe("Ingest happy path", () => {
  it("renders heading + dropzone + disabled submit", async () => {
    renderInRouter();
    expect(screen.getByRole("heading", {name: /ingest a dataset/i})).toBeInTheDocument();
    expect(await screen.findByRole("button", {name: /upload \+ scan/i})).toBeDisabled();
    expect(screen.getByText(/drop file\(s\) here/i)).toBeInTheDocument();
  });
});
