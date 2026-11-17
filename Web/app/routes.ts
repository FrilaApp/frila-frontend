import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("rotas/inicio.tsx"),
  route("entrar", "rotas/entrar.tsx"),
  route("sair", "rotas/sair.ts"),
  route("cadastro", "rotas/cadastro.tsx"),
  route("aceitar-termos", "rotas/aceitar-termos.ts"),
  route("saude", "rotas/saude.ts"),

  // Lado do profissional
  route("vagas", "rotas/profissional/vagas.tsx"),
  route("vagas/:vagaId", "rotas/profissional/vaga.tsx"),
  route("candidaturas", "rotas/profissional/candidaturas.tsx"),
  route("turnos", "rotas/profissional/turnos.tsx"),
  route("turnos/:turnoId", "rotas/profissional/turno.tsx"),
  route("perfil", "rotas/profissional/perfil.tsx"),
  route("chamadas", "rotas/profissional/chamadas.tsx"),
  route("chamadas/:chamadaId", "rotas/profissional/chamada.tsx"),
  route("denunciar", "rotas/profissional/denunciar.tsx"),
  route("bloqueados", "rotas/profissional/bloqueados.tsx"),

  // Lado do contratante
] satisfies RouteConfig;
