import { cloudflare } from "@cloudflare/vite-plugin";
import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    cloudflare({ viteEnvironment: { name: "ssr" } }),
    tailwindcss(),
    reactRouter(),
  ],
  build: {
    // Os arquivos saem em /app/assets para o Worker servir como estático (sem gastar CPU)
    // no mesmo caminho em que a web mora.
    assetsDir: "app/assets",
  },
  resolve: {
    tsconfigPaths: true,
  },
});
