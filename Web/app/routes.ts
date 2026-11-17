import { type RouteConfig, index, prefix, route } from "@react-router/dev/routes";

export default [
  index("rotas/inicio.tsx"),
  route("entrar", "rotas/entrar.tsx"),
  route("sair", "rotas/sair.ts"),
  route("cadastro", "rotas/cadastro.tsx"),
  route("aceitar-termos", "rotas/aceitar-termos.ts"),
  route("saude", "rotas/saude.ts"),
  // A vaga pelo link, sem login (para compartilhar)
  route("v/:vagaId", "rotas/publico/vaga.tsx"),

  // Conta suspensa, contestação e suporte (os dois lados)
  route("conta/suspensa", "rotas/conta/suspensa.tsx"),
  route("suporte/:turnoId", "rotas/suporte.tsx"),

  // Páginas públicas (textos do marketing)
  route("como-funciona/casa", "rotas/publico/como-funciona-casa.tsx"),
  route("como-funciona/profissional", "rotas/publico/como-funciona-profissional.tsx"),
  route("perguntas", "rotas/publico/perguntas.tsx"),

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
  route("preferencias", "rotas/profissional/preferencias.tsx"),

  // Lado do contratante
  // Contratante (2C, Citrino): painel da casa e publicar vaga. Só se acrescenta neste bloco.
  ...prefix("painel", [
    index("rotas/contratante/painel.tsx"),
    route("publicar", "rotas/contratante/publicar-vaga.tsx"),
    route("vagas/:vagaId", "rotas/contratante/vaga.tsx"),
  ]),

  // Dia do turno da casa (C4 e C5): bloco próprio, fora do prefixo do painel e das vagas
  route("casa/turnos", "rotas/contratante/turno/lista.tsx"),
  route("casa/turnos/:turnoId", "rotas/contratante/turno/detalhe.tsx"),

  // Equipe de confiança da casa (3.9)
  route("casa/equipe", "rotas/contratante/equipe.tsx"),
] satisfies RouteConfig;
