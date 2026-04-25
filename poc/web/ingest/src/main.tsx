import React from "react";
import ReactDOM from "react-dom/client";
import {QueryClient, QueryClientProvider} from "@tanstack/react-query";
import {BrowserRouter, Route, Routes, Navigate} from "react-router-dom";

import "./styles/globals.css";
import {App} from "./App";
import {Ingest} from "./routes/Ingest";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      retry: 1,
    },
  },
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route element={<App />}>
            <Route index element={<Ingest />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
);
