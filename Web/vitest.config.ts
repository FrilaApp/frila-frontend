import { defineConfig } from "vitest/config";

// Os testes unitários rodam em Node, sem os plugins do React Router e da Cloudflare.
export default defineConfig({
  resolve: {
    tsconfigPaths: true,
  },
  test: {
    environment: "node",
    include: ["testes/**/*.test.ts"],
  },
});
