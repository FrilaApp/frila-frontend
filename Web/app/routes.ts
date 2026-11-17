import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [index("rotas/inicio.tsx"), route("saude", "rotas/saude.ts")] satisfies RouteConfig;
