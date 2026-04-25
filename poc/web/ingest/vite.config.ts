import {defineConfig} from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    // dev convenience: forward /api/* to the FastAPI shim so we don't need
    // CORS hoops in `npm run dev`. Production builds talk to the shim
    // through the same Authelia-protected ingress, on the same origin.
    proxy: {
      "/api": {
        target: "http://localhost:8088",
        changeOrigin: true,
        rewrite: (p: string) => p.replace(/^\/api/, ""),
      },
    },
  },
  build: {
    outDir: "dist",
    sourcemap: true,
    target: "es2022",
  },
  test: {
    globals: true,
    environment: "happy-dom",
    setupFiles: ["./tests/setup.ts"],
    css: false,
  },
});
