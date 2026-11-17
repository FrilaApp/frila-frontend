import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("rotas/inicio.tsx"),
  route("entrar", "rotas/entrar.tsx"),
  route("sair", "rotas/sair.ts"),
  route("saude", "rotas/saude.ts"),
] satisfies RouteConfig;
