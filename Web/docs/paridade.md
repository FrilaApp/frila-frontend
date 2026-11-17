# Mapa de paridade da web do Frila

Atualizado em 16/11/2026. Este mapa define a ordem de construção da web (`Web/`).

Ele lista, recurso por recurso, o que a web do Frila precisa ter e o que já existe para isso no contrato da API
(`frila-documentacao/api/openapi.yaml`, versão 0.2.97, 87 operações). Textos, visual e marca são do Frila.

**Como ler**

- **Frila hoje:** a operação do contrato que cobre o recurso. `—` quer dizer que nenhum cliente do Frila tem.
- **Falta:** o que precisa existir fora da web (backend, contrato ou decisão). Vazio = só trabalho de web.
- **Fase:** `0` fundação · `1` acesso · `2C` contratante · `2P` profissional (2C e 2P andam em paralelo) ·
  `3` páginas públicas · `4` PWA e push · `5` o que sobra · `D` só com decisão dos sócios (não se constrói agora).

A regra de negócio fica no servidor. A web mostra o que o servidor decide e nunca refaz a conta no navegador.

---

## 1. Fundação e casca

| # | Recurso | Frila hoje | Falta | Fase |
|---|---|---|---|---|
| 1.1 | Web que abre em celular e computador, com menu que vira barra inferior ou gaveta em tela pequena | — | | 0 |
| 1.2 | Telas carregadas sob demanda (o navegador baixa só a tela aberta) | — | | 0 |
| 1.3 | Versão mínima: aba antiga é avisada e recarrega | `configuracao_do_app` | linha `web` no backend (pedida) | 0 |
| 1.4 | Recursos ligados e desligados pelo servidor, sem publicar versão | `configuracao_do_app` (recursos por versão) | linhas da plataforma `web` | 0 |
| 1.5 | Cabeçalhos de segurança | — | | 0 |
| 1.6 | Sessão fora do alcance de script da página | contrato pede cookie `HttpOnly` na web | | 1 |
| 1.7 | Página de erro e de "não encontrado" na língua do produto | — | | 0 |
| 1.8 | Aviso para sair do navegador embutido de rede social | — | | 4 |
| 1.9 | Instalar na tela de início (PWA), com guia no iPhone | — | | 4 |
| 1.10 | Casca mínima sem internet (abre e avisa que está sem conexão) | — | | 4 |
| 1.11 | Passeio guiado na primeira vez | — | | 5 |

## 2. Acesso e conta

| # | Recurso | Frila hoje | Falta | Fase |
|---|---|---|---|---|
| 2.1 | Entrar | código de 6 dígitos por e-mail (`/otp`, `/verify`, `/token`) | | 1 |
| 2.2 | O pedido de código não revela se o e-mail existe | `/otp` | | 1 |
| 2.3 | Reenvio do código com espera | `/otp` | conferir o limite por IP quando o pedido sai do Worker | 1 |
| 2.4 | Ficar logado ao recarregar e renovar a sessão | `/token` | | 1 |
| 2.5 | Sair | — (apaga os cookies e encerra no Auth) | | 1 |
| 2.6 | Criar conta escolhendo o papel | `criar_conta`, `minha_conta` | | 1 |
| 2.7 | Aceite dos termos, e novo aceite quando mudam | `aceitar_termos` | | 1 |
| 2.8 | Cadastro do profissional em passos | `criar_perfil_profissional`, `definir_servicos`, `definir_regioes_atendidas` | | 2P |
| 2.9 | Cadastro do estabelecimento | `cadastrar_estabelecimento` | | 2C |
| 2.10 | Conta suspensa: ver o motivo e contestar | `situacao_da_conta`, `contestar_suspensao` | | 2C/2P |
| 2.11 | Exportar os próprios dados e excluir a conta | `exportar-meus-dados`, `excluir-conta` | | 5 |
| 2.12 | Entrar com conta de demonstração (para teste) | `entrar-demonstracao` | | 1 (só em teste) |

## 3. Contratante

| # | Recurso | Frila hoje | Falta | Fase |
|---|---|---|---|---|
| 3.1 | Painel inicial com o que acontece hoje e em breve | `painel_estabelecimento` | | 2C |
| 3.2 | Publicar vaga (função, horário, valor, pessoas) | `publicar_vaga`, `funcao`, `especialidade`, `resolver_servico` | | 2C |
| 3.3 | Publicar um evento com várias funções de uma vez | `publicar_escala` (só contrato) | backend da escala | 5 |
| 3.4 | Lista das vagas por situação e detalhe da vaga | `painel_estabelecimento`, `detalhe_vaga` | | 2C |
| 3.5 | Ver candidatos e escolher | `candidatos_da_vaga`, `escolher_candidato` | | 2C |
| 3.6 | Repetir uma vaga (duplicar, republicar o que sobrou) | `republicar_vaga`, `republicar_posicoes_restantes` | | 2C |
| 3.7 | Cancelar vaga | `cancelar_vaga` | | 2C |
| 3.8 | Buscar profissionais e chamar direto | `buscar_profissionais`, `chamar_profissional`, `minhas_chamadas`, `detalhe_chamada`, `cancelar_chamada`, `publicar_a_partir_da_chamada` | | 2C |
| 3.9 | Guardar quem já trabalhou bem | `equipe_de_confianca`, `incluir_na_equipe`, `remover_da_equipe` | | 2C |
| 3.10 | Ver o perfil de um profissional | `perfil_publico`, `ler-midia` | | 2C |
| 3.11 | Tela do dia do turno: quem vem, quem está a caminho, quem chegou | `painel_estabelecimento`, `contato_do_turno` | sem tempo real: atualizar por consulta periódica | 2C |
| 3.12 | Presença por código dito no local | `gerar_codigo_checkin`, `validar_codigo_checkin` | | 2C |
| 3.13 | Confirmar presença à mão | `confirmar_checkin_manual` | | 2C |
| 3.14 | Falta e atraso: liberar o lugar e reabrir | `cancelar_posicao`, `reabrir_por_atraso` | | 2C |
| 3.15 | Avaliar depois do turno | `avaliar` (resposta única) | | 2C |
| 3.16 | Vários membros no mesmo estabelecimento | `convidar_membro`, `aceitar_convite_membro`, `remover_membro`, `transferir_administracao`, `meus_estabelecimentos` | | 5 |
| 3.17 | Relatório dos turnos para baixar | `exportar-turnos` | | 5 |
| 3.18 | Denunciar e bloquear | `denunciar`, `bloquear`, `listar_bloqueios`, `desbloquear` | | 2C |
| 3.19 | Mapa com quem está a caminho | `avisar_a_caminho` (sem posição ao vivo) | decisão de produto e contrato | D |

## 4. Profissional

| # | Recurso | Frila hoje | Falta | Fase |
|---|---|---|---|---|
| 4.1 | Vagas abertas perto, com filtros | `vagas_abertas`, `regiao_administrativa` | | 2P |
| 4.2 | Detalhe da vaga, com o endereço completo só para quem foi aceito | `detalhe_vaga`, `contato_do_turno` | | 2P |
| 4.3 | Candidatar-se com um toque e retirar a candidatura | `candidatar`, `retirar_candidatura`, `minhas_candidaturas` | | 2P |
| 4.4 | Receber chamada direta e responder | `minhas_chamadas`, `detalhe_chamada`, `responder_chamada`, `definir_preferencia_chamadas` | | 2P |
| 4.5 | Agenda: meus turnos | `meus_turnos` | | 2P |
| 4.6 | Avisar que está a caminho | `avisar_a_caminho` | | 2P |
| 4.7 | Check-in por código (a localização é só sinal extra) | `validar_codigo_checkin`, `fazer_checkin` | a web não manda `sinais` (são opcionais no contrato) | 2P |
| 4.8 | Check-out | `fazer_checkout` | | 2P |
| 4.9 | Desistir de um turno aceito, com a regra mostrada antes | `cancelar_posicao` | | 2P |
| 4.10 | Avaliar o contratante | `avaliar` | | 2P |
| 4.11 | Perfil: ver dados e regiões, editar "Sobre mim" e "Onde já trabalhei" | `meu_perfil_detalhado`, `atualizar_apresentacao_profissional` | | 2P |
| 4.11b | Perfil: funções, ponto base e disponibilidade | `atualizar_perfil_profissional` | **fora da v1 da web, só no app** (decisão do O2, 17/11/2026): na web, o ponto base viria de um endereço digitado e geocodificado. Isso mandaria o endereço (às vezes a casa da pessoa) a um terceiro novo, o que pede mudar a Política e escolher o fornecedor | D |
| 4.12 | Foto de perfil e mídias | `solicitar_upload_midia`, `confirmar_upload_midia`, `minhas_midias`, `remover_midia`, `pedir_nova_analise_midia` | Storage aceitar a origem da web | 2P |
| 4.13 | Verificação de identidade | `minha_identidade_status`, `solicitar_upload_verificacao`, `confirmar_envio_verificacao` | selo desligado até o consentimento ficar no servidor | 5 |
| 4.14 | Sair da equipe de um contratante | `sair_da_equipe` | **fora da v1 da web** (decisão do O2, 17/11/2026): o iOS também não tem; entra depois nos dois apps, junto | D |
| 4.15 | Denunciar e bloquear | `denunciar`, `bloquear`, `listar_bloqueios`, `desbloquear` | | 2P |
| 4.16 | Avisar atraso com um toque | — | decisão de produto e contrato | D |
| 4.17 | Confirmar presença dias antes do turno | — | decisão de produto e contrato | D |

## 5. Páginas públicas (sem login)

| # | Recurso | Frila hoje | Falta | Fase |
|---|---|---|---|---|
| 5.1 | Página "em breve" enquanto a web está com a chave desligada | — | | 0 |
| 5.2 | Página pública de cada vaga, com dados estruturados de emprego e cartão de compartilhamento | — | leitura da vaga pelo link, sem login: contrato 0.2.100 e depois o backend | 3 |
| 5.3 | Lista pública de vagas abertas | — | a mesma leitura pública | 3 |
| 5.4 | Mapa do site e regras para buscadores | — | | 3 |
| 5.5 | Páginas por função e cidade com número vivo | — | leitura pública agregada; só com volume real no DF | 5 |
| 5.6 | Página pública do estabelecimento com as vagas dele, com link e QR | `perfil_publico` (logado) | leitura pública do estabelecimento | 5 |
| 5.7 | Link de convite que abre a web já no destino | `aceitar_convite_membro` | | 5 |
| 5.8 | Pedido de equipe sem criar conta | — | decisão de produto e backend | D |
| 5.9 | Termos e privacidade | já existem em `frilabr.com` | só o link | 1 |

## 6. Avisos e comunicação

| # | Recurso | Frila hoje | Falta | Fase |
|---|---|---|---|---|
| 6.1 | Push no navegador | `registrar_dispositivo`, `remover_dispositivo` (plataforma `web` no contrato) | envio com bloco de web no backend | 4 |
| 6.2 | Lista do que precisa de atenção dentro do app | parcial: painel, turnos e chamadas já dizem o que está pendente | | 2C/2P |
| 6.3 | Falar com o suporte | `abrir_suporte` | | 2C/2P |
| 6.4 | Contato do outro lado perto do turno | `contato_do_turno` | | 2C/2P |
| 6.5 | Conversa dentro do app | — | decisão de produto | D |
| 6.6 | Registro de eventos de uso | `registrar_evento` | | 5 |

## 7. Fora do contrato hoje

**Decisão do Cauê (pedido 2026-11-17-02, 17/11/2026): fora por agora, decidir depois.** Nada disto entra na web nem nos
apps sem ordem dele. A origem é esta comparação com o freela+ e o Scalador. O registro está em `frila-docs`, `produto/AGORA.md`,
na seção "Fora por agora", e nos módulos.

| Recurso | Por que não entra agora |
|---|---|
| Pagamento dentro do produto (cobrança antes do turno, carteira, saque, crédito) | O Frila decidiu: pagamento fora do app; "pagamento no app" está em próximas ideias |
| Taxa, plano pago e assinatura | O Frila é gratuito hoje |
| Conversa 1:1 e grupo da equipe, mensagens automáticas | Não existe no contrato |
| Nota de 1 a 5 com critérios, níveis e selos | A avaliação do Frila é de resposta única |
| Valor sugerido ao publicar | Sem operação no contrato |
| Escala que se repete toda semana | Sem operação no contrato |
| Indicação com prêmio e programa de parceiros | Decisão comercial |
| Recrutamento para vaga fixa | Outro produto |
| Painel interno (administração e CRM) | Ferramenta da equipe, fora do produto |

## 8. Soluções técnicas da web do Frila

| Tema | O que a web do Frila faz |
|---|---|
| Sessão | Cookie `HttpOnly` gravado pelo Worker; o token nunca chega ao JavaScript |
| Chamadas ao servidor | Do navegador para o próprio endereço; o Worker chama o Supabase com o token do usuário e a chave publicável, nunca `service_role` |
| Regras | Tudo no servidor; a web só mostra |
| Dados que mudam | Revalidação ao voltar à tela e consulta periódica só no dia do turno |
| Filtros de lista | Parâmetros da operação; o servidor filtra |
| Erros | Cada recusa do contrato vira mensagem do catálogo; falha de rede tem tela própria |
| Pacote | Divisão por rota e orçamento na CI |
| Atualização | `configuracao_do_app` com a plataforma `web` |
| Serviços de terceiros | Só pelo Worker, e só quando precisar |
| Painel interno | Fora da web pública: se existir um dia, outro Worker, outro endereço, atrás de login próprio |
| Textos | Catálogo único em `app/textos/pt-BR.ts` |

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
| B3 | Check-in na web sem `sinais` | 2P | não pede contrato nem backend |
| B4 | Storage aceitar a origem da web no envio de mídia | 2P | a conferir |
| B5 | Leitura da vaga pelo link, sem login | 3 | contrato 0.2.100 a caminho; depois o backend |
| B6 | Envio de push com bloco de web (o registro do aparelho `web` já é aceito) | 4 | pedido |
| B7 | Backend da escala em lote (`publicar_escala`) | 5 | contrato pronto, falta o servidor |

## Provas que faltam no Prod (web ligada em 17/11/2026)

- **Página pública da vaga, resposta 200:** provar na 1ª vaga real aberta, só com GET (sem gravar nada) e conferindo que
  aparecem só os campos públicos. No dia da ligação não havia vaga real aberta, e criar uma avisaria profissionais reais.
  O 410 (vaga cancelada) e o 404 (vaga de demonstração e id inexistente) já foram provados no Prod; o 200, no dev.
