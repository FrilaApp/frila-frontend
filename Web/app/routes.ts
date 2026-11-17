import { type RouteConfig, index, prefix, route } from "@react-router/dev/routes";

export default [
  index("rotas/inicio.tsx"),
  route("entrar", "rotas/entrar.tsx"),
  route("sair", "rotas/sair.ts"),
  route("cadastro", "rotas/cadastro.tsx"),
  route("aceitar-termos", "rotas/aceitar-termos.ts"),
  route("saude", "rotas/saude.ts"),
  // Contratante (2C, Citrino): painel da casa e publicar vaga. Só se acrescenta neste bloco.
  ...prefix("painel", [index("rotas/contratante/painel.tsx"), route("publicar", "rotas/contratante/publicar-vaga.tsx")]),
] satisfies RouteConfig;
