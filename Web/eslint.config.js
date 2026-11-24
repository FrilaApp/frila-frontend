import js from "@eslint/js";
import tseslint from "typescript-eslint";

const importsProibidos = {
  paths: [
    {
      name: "react-router-dom",
      message: "No React Router v8 tudo vem de \"react-router\". O pacote react-router-dom não existe mais.",
    },
  ],
  patterns: [
    {
      group: ["@remix-run/*"],
      message: "API antiga do Remix. Use \"react-router\".",
    },
    {
      group: ["@supabase/ssr"],
      message: "A sessão da web é cookie HttpOnly gravado pelo Worker; o @supabase/ssr exige cookie legível por script.",
    },
  ],
};

export default tseslint.config(
  {
    ignores: ["build/", ".react-router/", ".wrangler/", "node_modules/", "worker-configuration.d.ts", "**/*.gerado.ts"],
  },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    rules: {
      "no-restricted-imports": ["error", importsProibidos],
    },
  },
  {
    // Política de Privacidade: o log do Worker não leva dado pessoal; só console.error (achado da Bússola, 24/11).
    files: ["app/servidor/**/*.{ts,tsx}", "app/entry.server.tsx", "app/**/*.server.{ts,tsx}", "workers/**/*.ts"],
    rules: {
      "no-console": ["error", { allow: ["error"] }],
    },
  },
  {
    files: ["scripts/**/*.mjs"],
    languageOptions: { globals: { console: "readonly", process: "readonly", fetch: "readonly", setTimeout: "readonly", URLSearchParams: "readonly", URL: "readonly" } },
  },
  {
    files: ["public/app/sw.js"],
    languageOptions: { globals: { self: "readonly", caches: "readonly", fetch: "readonly", Request: "readonly", Response: "readonly", URL: "readonly" } },
  },
);
