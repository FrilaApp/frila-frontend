import type { Config } from "@react-router/dev/config";

export default {
  // A web mora em frilabr.com/app: toda rota fica debaixo de /app, em qualquer ambiente.
  basename: "/app",
  ssr: true,
} satisfies Config;
