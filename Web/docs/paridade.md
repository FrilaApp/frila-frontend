# Mapa de paridade da web do Frila

Atualizado em 16/11/2026. Este mapa define a ordem de construção da web (`Web/`).

Ele compara, recurso por recurso, o que duas webs de referência do mesmo mercado oferecem (**A** e **B**) com
o que o Frila já tem no contrato da API (`frila-documentacao/api/openapi.yaml`, versão 0.2.97, 87 operações).
A comparação é só de **função**: o que o produto faz. Código, textos, imagens, cores, nomes e dados das
referências não entram aqui nem na web do Frila. Textos, visual e marca são do Frila.

**Como ler**

- **A / B:** `sim`, `não` ou `parcial` (existe, mas incompleto ou só para um caso).
- **Frila hoje:** a operação do contrato que cobre o recurso. `—` quer dizer que nenhum cliente do Frila tem.
- **Falta:** o que precisa existir fora da web (backend, contrato ou decisão). Vazio = só trabalho de web.
- **Fase:** `0` fundação · `1` acesso · `2C` contratante · `2P` profissional (2C e 2P andam em paralelo) ·
  `3` páginas públicas · `4` PWA e push · `5` o que sobra · `D` só com decisão dos sócios (não se constrói agora).

A regra de negócio fica no servidor. A web mostra o que o servidor decide e nunca refaz a conta no navegador.

---

## 1. Fundação e casca

| # | Recurso | A | B | Frila hoje | Falta | Fase |
|---|---|---|---|---|---|---|
| 1.1 | Web que abre em celular e computador, com menu que vira barra inferior ou gaveta em tela pequena | sim | sim | — | | 0 |
| 1.2 | Telas carregadas sob demanda (o navegador baixa só a tela aberta) | sim | não | — | | 0 |
| 1.3 | Versão mínima: aba antiga é avisada e recarrega | sim | não | `configuracao_do_app` | linha `web` no backend (pedida) | 0 |
| 1.4 | Recursos ligados e desligados pelo servidor, sem publicar versão | parcial | sim | `configuracao_do_app` (recursos por versão) | linhas da plataforma `web` | 0 |
| 1.5 | Cabeçalhos de segurança | parcial | não consta | — | | 0 |
| 1.6 | Sessão fora do alcance de script da página | não | não | contrato pede cookie `HttpOnly` na web | | 1 |
| 1.7 | Página de erro e de "não encontrado" na língua do produto | sim | não | — | | 0 |
| 1.8 | Aviso para sair do navegador embutido de rede social | sim | não | — | | 4 |
| 1.9 | Instalar na tela de início (PWA), com guia no iPhone | sim | sim | — | | 4 |
| 1.10 | Casca mínima sem internet (abre e avisa que está sem conexão) | não | não consta | — | | 4 |
| 1.11 | Passeio guiado na primeira vez | não | sim | — | | 5 |

## 2. Acesso e conta

| # | Recurso | A | B | Frila hoje | Falta | Fase |
|---|---|---|---|---|---|---|
| 2.1 | Entrar | e-mail e senha, conta de terceiro | e-mail e senha | código de 6 dígitos por e-mail (`/otp`, `/verify`, `/token`) | | 1 |
| 2.2 | Recuperar acesso sem revelar se o e-mail existe | sim | sim | não se aplica (sem senha); a resposta do pedido de código não revela | | 1 |
| 2.3 | Reenvio do código com espera | sim | sim | `/otp` | conferir o limite por IP quando o pedido sai do Worker | 1 |
| 2.4 | Ficar logado ao recarregar e renovar a sessão | sim | não (sem renovação) | `/token` | | 1 |
| 2.5 | Sair | sim | sim | — (apaga os cookies e encerra no Auth) | | 1 |
| 2.6 | Criar conta escolhendo o papel | sim | sim | `criar_conta`, `minha_conta` | | 1 |
| 2.7 | Aceite dos termos, e novo aceite quando mudam | sim | sim | `aceitar_termos` | | 1 |
| 2.8 | Cadastro do profissional em passos | sim | sim (uma tela) | `criar_perfil_profissional`, `definir_servicos`, `definir_regioes_atendidas` | | 2P |
| 2.9 | Cadastro do estabelecimento | sim | sim | `cadastrar_estabelecimento` | | 2C |
| 2.10 | Conta suspensa: ver o motivo e contestar | sim | parcial | `situacao_da_conta`, `contestar_suspensao` | | 2C/2P |
| 2.11 | Exportar os próprios dados e excluir a conta | não consta | parcial (desativar) | `exportar-meus-dados`, `excluir-conta` | | 5 |
| 2.12 | Entrar com conta de demonstração (para teste) | não | não | `entrar-demonstracao` | | 1 (só em teste) |

## 3. Contratante

| # | Recurso | A | B | Frila hoje | Falta | Fase |
|---|---|---|---|---|---|---|
| 3.1 | Painel inicial com o que acontece hoje e em breve | sim | sim | `painel_estabelecimento` | | 2C |
| 3.2 | Publicar vaga (função, horário, valor, pessoas) | sim | sim | `publicar_vaga`, `funcao`, `especialidade`, `resolver_servico` | | 2C |
| 3.3 | Publicar um evento com várias funções de uma vez | sim | não | `publicar_escala` (só contrato) | backend da escala | 5 |
| 3.4 | Lista das vagas por situação e detalhe da vaga | sim | sim | `painel_estabelecimento`, `detalhe_vaga` | | 2C |
| 3.5 | Ver candidatos e escolher | sim | sim | `candidatos_da_vaga`, `escolher_candidato` | | 2C |
| 3.6 | Repetir uma vaga (duplicar, republicar o que sobrou) | sim | sim | `republicar_vaga`, `republicar_posicoes_restantes` | | 2C |
| 3.7 | Cancelar vaga | sim | não | `cancelar_vaga` | | 2C |
| 3.8 | Buscar profissionais e chamar direto | sim | sim | `buscar_profissionais`, `chamar_profissional`, `minhas_chamadas`, `detalhe_chamada`, `cancelar_chamada`, `publicar_a_partir_da_chamada` | | 2C |
| 3.9 | Guardar quem já trabalhou bem | sim (favoritos) | sim (favoritos) | `equipe_de_confianca`, `incluir_na_equipe`, `remover_da_equipe` | | 2C |
| 3.10 | Ver o perfil de um profissional | sim | sim | `perfil_publico`, `ler-midia` | | 2C |
| 3.11 | Tela do dia do turno: quem vem, quem está a caminho, quem chegou | sim | parcial | `painel_estabelecimento`, `contato_do_turno` | sem tempo real: atualizar por consulta periódica | 2C |
| 3.12 | Presença por código dito no local | sim | não (botão sem prova) | `gerar_codigo_checkin`, `validar_codigo_checkin` | | 2C |
| 3.13 | Confirmar presença à mão | sim | sim | `confirmar_checkin_manual` | | 2C |
| 3.14 | Falta e atraso: liberar o lugar e reabrir | sim | parcial | `cancelar_posicao`, `reabrir_por_atraso` | | 2C |
| 3.15 | Avaliar depois do turno | sim (nota e critérios) | sim (nota) | `avaliar` (resposta única) | | 2C |
| 3.16 | Vários membros no mesmo estabelecimento | não | sim | `convidar_membro`, `aceitar_convite_membro`, `remover_membro`, `transferir_administracao`, `meus_estabelecimentos` | | 5 |
| 3.17 | Relatório dos turnos para baixar | sim | não (anunciado) | `exportar-turnos` | | 5 |
| 3.18 | Denunciar e bloquear | sim | parcial | `denunciar`, `bloquear`, `listar_bloqueios`, `desbloquear` | | 2C |
| 3.19 | Mapa com quem está a caminho | sim | não | `avisar_a_caminho` (sem posição ao vivo) | decisão de produto e contrato | D |

## 4. Profissional

| # | Recurso | A | B | Frila hoje | Falta | Fase |
|---|---|---|---|---|---|---|
| 4.1 | Vagas abertas perto, com filtros | sim | sim | `vagas_abertas`, `regiao_administrativa` | | 2P |
| 4.2 | Detalhe da vaga, com o endereço completo só para quem foi aceito | sim | parcial | `detalhe_vaga`, `contato_do_turno` | | 2P |
| 4.3 | Candidatar-se com um toque e retirar a candidatura | sim | sim | `candidatar`, `retirar_candidatura`, `minhas_candidaturas` | | 2P |
| 4.4 | Receber chamada direta e responder | sim | sim | `minhas_chamadas`, `detalhe_chamada`, `responder_chamada`, `definir_preferencia_chamadas` | | 2P |
| 4.5 | Agenda: meus turnos | sim | sim | `meus_turnos` | | 2P |
| 4.6 | Avisar que está a caminho | sim | não | `avisar_a_caminho` | | 2P |
| 4.7 | Check-in por código (a localização é só sinal extra) | sim | não | `validar_codigo_checkin`, `fazer_checkin` | contrato: `sinais` sem `localizacao_simulada` na web | 2P |
| 4.8 | Check-out | não | não (o servidor encerra) | `fazer_checkout` | | 2P |
| 4.9 | Desistir de um turno aceito, com a regra mostrada antes | sim | sim | `cancelar_posicao` | | 2P |
| 4.10 | Avaliar o contratante | sim | não consta | `avaliar` | | 2P |
| 4.11 | Perfil: dados, apresentação, serviços e regiões | sim | sim | `meu_perfil_profissional`, `meu_perfil_detalhado`, `atualizar_perfil_profissional`, `atualizar_apresentacao_profissional` | | 2P |
| 4.12 | Foto de perfil e mídias | sim | sim | `solicitar_upload_midia`, `confirmar_upload_midia`, `minhas_midias`, `remover_midia`, `pedir_nova_analise_midia` | Storage aceitar a origem da web | 2P |
| 4.13 | Verificação de identidade | sim (opcional) | parcial | `minha_identidade_status`, `solicitar_upload_verificacao`, `confirmar_envio_verificacao` | selo desligado até o consentimento ficar no servidor | 5 |
| 4.14 | Sair da equipe de um contratante | não consta | não | `sair_da_equipe` | | 2P |
| 4.15 | Denunciar e bloquear | sim | não consta | `denunciar`, `bloquear`, `listar_bloqueios`, `desbloquear` | | 2P |
| 4.16 | Avisar atraso com um toque | sim | não | — | decisão de produto e contrato | D |
| 4.17 | Confirmar presença dias antes do turno | sim | sim (por link) | — | decisão de produto e contrato | D |

## 5. Páginas públicas (sem login)

| # | Recurso | A | B | Frila hoje | Falta | Fase |
|---|---|---|---|---|---|---|
| 5.1 | Página "em breve" enquanto a web está com a chave desligada | — | — | — | | 0 |
| 5.2 | Página pública de cada vaga, com dados estruturados de emprego e cartão de compartilhamento | sim | parcial (lista) | — | leitura pública da vaga (só campos publicáveis) + decisão do que aparece | 3 |
| 5.3 | Lista pública de vagas abertas | sim | sim | — | a mesma leitura pública | 3 |
| 5.4 | Mapa do site e regras para buscadores | sim | não | — | | 3 |
| 5.5 | Páginas por função e cidade com número vivo | sim | não | — | leitura pública agregada; só com volume real no DF | 5 |
| 5.6 | Página pública do estabelecimento com as vagas dele, com link e QR | não | sim | `perfil_publico` (logado) | leitura pública do estabelecimento | 5 |
| 5.7 | Link de convite que abre a web já no destino | sim | parcial | `aceitar_convite_membro` | | 5 |
| 5.8 | Pedido de equipe sem criar conta | sim | não | — | decisão de produto e backend | D |
| 5.9 | Termos e privacidade | sim | sim | já existem em `frilabr.com` | só o link | 1 |

## 6. Avisos e comunicação

| # | Recurso | A | B | Frila hoje | Falta | Fase |
|---|---|---|---|---|---|---|
| 6.1 | Push no navegador | sim | sim | `registrar_dispositivo`, `remover_dispositivo` (plataforma `web` no contrato) | envio com bloco de web no backend | 4 |
| 6.2 | Lista do que precisa de atenção dentro do app | sim | sim (sino) | parcial: painel, turnos e chamadas já dizem o que está pendente | | 2C/2P |
| 6.3 | Falar com o suporte | sim (chamados) | sim (atalho de mensagem) | `abrir_suporte` | | 2C/2P |
| 6.4 | Contato do outro lado perto do turno | sim | parcial | `contato_do_turno` | | 2C/2P |
| 6.5 | Conversa dentro do app | sim | sim | — | decisão de produto | D |
| 6.6 | Registro de eventos de uso | sim (próprio) | não | `registrar_evento` | | 5 |

## 7. O que as referências têm e o Frila não tem em nenhum cliente

Nada disto entra na web sem decisão dos sócios: ou muda o modelo do produto, ou ainda não existe no contrato.
Ficam listados para a decisão, não como fila de trabalho.

| Recurso | A | B | Por que não entra agora |
|---|---|---|---|
| Pagamento dentro do produto (cobrança antes do turno, carteira, saque, crédito) | sim | sim | O Frila decidiu: pagamento fora do app; "pagamento no app" está em próximas ideias |
| Taxa, plano pago e assinatura | sim | sim | O Frila é gratuito hoje |
| Conversa 1:1 e grupo da equipe, mensagens automáticas | sim | sim | Não existe no contrato |
| Nota de 1 a 5 com critérios, níveis e selos | sim | parcial | A avaliação do Frila é de resposta única |
| Valor sugerido ao publicar | sim | não | Sem operação no contrato |
| Escala que se repete toda semana | sim | não | Sem operação no contrato |
| Indicação com prêmio e programa de parceiros | sim | não | Decisão comercial |
| Recrutamento para vaga fixa | não | sim | Outro produto |
| Painel interno de operação | sim | sim (separado) | Se existir um dia: outro Worker, outro endereço, atrás de login próprio. Nunca no pacote público |

## 8. Soluções técnicas: o que adotamos e o que evitamos

| Tema | O que as referências fazem | O que a web do Frila faz |
|---|---|---|
| Sessão | Guardada onde script da página lê | Cookie `HttpOnly` gravado pelo Worker; o token nunca chega ao JavaScript |
| Chamadas ao servidor | Do navegador direto para a API | Do navegador para o próprio endereço; o Worker chama o Supabase com o token do usuário e a chave publicável, nunca `service_role` |
| Regras | Parte das contas e da ordenação no navegador | Tudo no servidor; a web só mostra |
| Dados que mudam | Consulta periódica (de 3 s a 60 s) | Revalidação ao voltar à tela e consulta periódica só no dia do turno |
| Filtros de lista | No navegador, sobre uma página só | Parâmetros da operação; o servidor filtra |
| Erros | Só "sessão expirada" tratado; o resto vira lista vazia | Cada recusa do contrato vira mensagem do catálogo; falha de rede tem tela própria |
| Pacote | De ~0,5 MB dividido por tela até um arquivo único de alguns MB | Divisão por rota e orçamento na CI |
| Atualização | Arquivo de versão conferido de tempos em tempos | `configuracao_do_app` com a plataforma `web` |
| Serviços de terceiros | Chamados direto do navegador | Só pelo Worker, e só quando precisar |
| Painel interno | No mesmo pacote, ou em endereço separado | Fora da web pública |
| Textos | Espalhados nas telas | Catálogo único em `app/textos/pt-BR.ts` |

## 9. Fases e critério de pronto

| Fase | O que entra | Pronto quando |
|---|---|---|
| 0. Fundação | Itens 1.1 a 1.5, 1.7 e 5.1; contrato espelhado e tipos gerados; CI | Uma página em prévia e em produção lê `configuracao_do_app` pelo Worker; CI verde |
| 1. Acesso | Itens 1.6, 2.1 a 2.7, 2.12 e 5.9 | Entrar, ficar logado ao recarregar, renovar e sair; cookie `HttpOnly` conferido em teste; revisão de segurança |
| 2C. Contratante | Seção 3 marcada 2C | Publicar → candidatos → escolher → dia do turno com código → avaliar, de ponta a ponta contra o dev |
| 2P. Profissional | Seção 4 marcada 2P | Vagas → candidatar → turno → check-in por código → check-out → avaliar, de ponta a ponta contra o dev |
| 3. Públicas | Itens 5.2 a 5.4 | Página da vaga com dados estruturados válidos; vaga vencida responde como removida |
| 4. PWA e push | Itens 1.8 a 1.10 e 6.1 | Instala no Android e no iPhone; push chega com a web instalada |
| 5. O que sobra | Itens marcados 5 | Um a um, pela ordem deste mapa |

## 10. Pedidos ao backend (vão pela Forja, PR para `develop`)

| # | Pedido | Para qual fase | Estado |
|---|---|---|---|
| B1 | Linha `web` em `configuracao_do_app` e recursos da plataforma `web` | 0 | pedido |
| B2 | Limite de pedidos de código por IP quando saem do Worker | 1 | a conferir no dev |
| B3 | `sinais` do check-in sem `localizacao_simulada` na web (contrato) | 2P | a pedir |
| B4 | Storage aceitar a origem da web no envio de mídia | 2P | a conferir |
| B5 | Leitura pública da vaga, só com campos publicáveis | 3 | depende da decisão do que é público |
| B6 | Envio de push com bloco de web | 4 | a pedir |
| B7 | Backend da escala em lote (`publicar_escala`) | 5 | contrato pronto, falta o servidor |
