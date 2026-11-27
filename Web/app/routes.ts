import { type RouteConfig, index, prefix, route } from "@react-router/dev/routes";

export default [
  index("rotas/inicio.tsx"),
  route("entrar", "rotas/entrar.tsx"),
  // Login social (OAuth PKCE via autenticar-social). Só funciona no DEV com APPLE_ENTRAR / GOOGLE_ENTRAR = "ligado".
  route("entrar/apple", "rotas/entrar-apple.ts"),
  route("entrar/apple/retorno", "rotas/entrar-apple-retorno.ts"),
  route("entrar/google", "rotas/entrar-google.ts"),
  route("entrar/google/retorno", "rotas/entrar-google-retorno.ts"),
  route("criar-conta", "rotas/criar-conta.tsx"),
  route("recuperar-senha", "rotas/recuperar-senha.tsx"),
  route("definir-senha", "rotas/definir-senha.tsx"),
  route("sair", "rotas/sair.ts"),
  route("cadastro", "rotas/cadastro.tsx"),
  route("aceitar-termos", "rotas/aceitar-termos.ts"),
  route("saude", "rotas/saude.ts"),
  // Instalar na tela de início e a página que o service worker mostra sem rede (fase 4)
  route("instalar", "rotas/instalar.tsx"),
  route("sem-conexao", "rotas/sem-conexao.ts"),
  route("avisos", "rotas/avisos.tsx"),
  route("avisos/texto-neutro", "rotas/avisos-texto-neutro.ts"),
  // A vaga pelo link, sem login (para compartilhar)
  route("v/:vagaId", "rotas/publico/vaga.tsx"),

  // Conta suspensa, contestação e suporte (os dois lados)
  route("conta/suspensa", "rotas/conta/suspensa.tsx"),
  // Minha conta: exportar os dados e excluir a conta (2.11)
  route("conta", "rotas/conta/dados.tsx"),
  route("conta/aparencia", "rotas/conta/aparencia.tsx"),
  route("conta/meus-dados", "rotas/conta/meus-dados.ts"),
  // Relatório dos turnos para baixar (3.17)
  route("conta/relatorio", "rotas/conta/relatorio.tsx"),
  route("conta/relatorio/arquivo", "rotas/conta/relatorio-arquivo.ts"),
  route("suporte/:turnoId", "rotas/suporte.tsx"),

  // Páginas públicas (textos do marketing)
  route("como-funciona/casa", "rotas/publico/como-funciona-casa.tsx"),
  route("como-funciona/profissional", "rotas/publico/como-funciona-profissional.tsx"),
  route("perguntas", "rotas/publico/perguntas.tsx"),
  // Mapa do site para buscadores (5.4): só as páginas públicas acima
  route("sitemap.xml", "rotas/publico/sitemap.ts"),

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
  // "Por que recebo vagas" com os critérios da conta e o pedido de revisão do despacho (RF27)
  route("por-que-recebo-vagas", "rotas/profissional/por-que-recebo-vagas.tsx"),
  // Cadastro do profissional em passos (2.8): funções, ponto base e regiões atendidas
  route("perfil/cadastro", "rotas/profissional/cadastro.tsx"),

  // Lado do contratante
  // Contratante (2C, Citrino): painel da casa e publicar vaga. Só se acrescenta neste bloco.
  ...prefix("painel", [
    index("rotas/contratante/painel.tsx"),
    route("publicar", "rotas/contratante/publicar-vaga.tsx"),
    route("escala", "rotas/contratante/publicar-escala.tsx"),
    route("vagas/:vagaId", "rotas/contratante/vaga.tsx"),
  ]),

  // Dia do turno da casa (C4 e C5): bloco próprio, fora do prefixo do painel e das vagas
  route("casa/turnos", "rotas/contratante/turno/lista.tsx"),
  route("casa/turnos/:turnoId", "rotas/contratante/turno/detalhe.tsx"),
  route("casa/profissionais/:profissionalId", "rotas/contratante/profissional.tsx"),
  route("casa/denunciar", "rotas/contratante/moderacao/denunciar.tsx"),
  route("casa/bloqueados", "rotas/contratante/moderacao/bloqueados.tsx"),

  // Busca de profissionais e chamada direta da casa (3.8)
  route("casa/busca", "rotas/contratante/busca.tsx"),
  // Cadastro da casa (2.9)
  route("casa/cadastro", "rotas/contratante/cadastro-casa.tsx"),
  route("casa/chamadas", "rotas/contratante/chamadas.tsx"),
  // Pessoas da casa e o link de convite (3.16 e 5.7)
  route("casa/membros", "rotas/contratante/membros.tsx"),
  route("convite", "rotas/convite.tsx"),

  // Equipe de confiança da casa (3.9)
  route("casa/equipe", "rotas/contratante/equipe.tsx"),
] satisfies RouteConfig;
