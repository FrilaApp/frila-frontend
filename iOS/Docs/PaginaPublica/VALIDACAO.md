# Relatório de Validação e Rastreabilidade — Páginas Públicas do Frila

- **Data:** 12 de outubro de 2026
- **Revisão dos textos públicos:** 15 de outubro de 2026. Datas de revisão e notas internas ficam neste relatório; não integram as páginas públicas.
- **Auditor / Responsável:** Doutor Estranho (Diagnóstico, CI e Regressão)
- **Cartão do Trello:** [hi3NFcjI](https://trello.com/c/hi3NFcjI) (S1 · Infra + Design · Página pública do Frila: suporte, privacidade e termos)
- **Documentos gerados:**
  - `iOS/Docs/PaginaPublica/suporte.md`
  - `iOS/Docs/PaginaPublica/privacidade.md`
  - `iOS/Docs/PaginaPublica/termos.md`
  - `iOS/Docs/PaginaPublica/VALIDACAO.md`

---

## 1. Matriz de Fatos do Produto com Fonte no Código e Documentação

Todos os fatos descritos nas três páginas públicas foram extraídos diretamente do código-fonte do aplicativo e dos dossiês técnicos oficiais versionados no repositório.

| # | Fato do Produto | Comportamento no App / Implementação | Fonte (Arquivo e Linha) |
|---|---|---|---|
| 1 | **Nome civil** | Coletado no cadastro (`CadastroConta`), exibido em candidaturas e turnos confirmados. | `iOS/Sources/Dominio/Portas.swift:3`, `iOS/Sources/Dados/SupabaseApiCliente.swift:102`, `iOS/Docs/LGPD.md:33` |
| 2 | **E-mail (OTP sem senha)** | Autenticação por código numérico de uso único enviado por e-mail; sem uso nem armazenamento de senhas. | `iOS/Sources/Dados/SupabaseApiCliente.swift:49`, `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCodigo.swift:59`, `iOS/Docs/LGPD.md:34` |
| 3 | **Telefone (WhatsApp)** | Contato direto via link sanitizado (`https://wa.me/...`) exibido somente após turno confirmado. | `iOS/Sources/Dados/DTOsContrato.swift:588`, `iOS/Sources/Dados/CacheSwiftData.swift:133`, `iOS/Docs/LGPD.md:35` |
| 4 | **Endereço do estabelecimento** | Local físico do turno; preenchido pelo contratante e exibido aos profissionais. | `iOS/Sources/Apresentacao/Fluxos/Estabelecimento/CadastroEstabelecimento.swift:105`, `iOS/Docs/LGPD.md:36` |
| 5 | **Localização (GPS) no check-in** | Leitura pontual exclusiva com autorização "Ao Usar o App". **Apenas `distanciaMetros` é transmitida ao servidor; nenhuma coordenada de GPS crua trafega ou é salva em banco.** | `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:45`, `iOS/Sources/Dados/SupabaseApiCliente.swift:521-524`, `iOS/Docs/SegurancaEPrivacidade.md:108-111` |
| 6 | **Ponto base do profissional** | Endereço ou coordenada de referência fixada no perfil profissional para cálculo de proximidade no feed, sem rastreamento em tempo real. | `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfilProfissionalViewModel.swift:108-112`, `iOS/Docs/LGPD.md:38` |
| 7 | **Data de nascimento (18+)** | Informada no cadastro para validação mandatória de maioridade legal (requisito de elegibilidade trabalhista). | `iOS/Resources/PrivacyInfo.xcprivacy:97-106`, `iOS/Docs/Classificacao18ECA.md:18-80`, `iOS/Docs/LGPD.md:41` |
| 8 | **Identificadores técnicos** | `usuarioID` (UUID) para conta e token de push APNs/FCM para entrega de notificações transacionais de turnos. | `iOS/Sources/Dados/AparelhoDePush.swift:208`, `iOS/Docs/LGPD.md:39-40`, `iOS/Resources/PrivacyInfo.xcprivacy:121-130` |
| 9 | **Conteúdo gerado e avaliações** | Avaliações mútuas de turnos (Sim/Não), relatos de contestação e suporte. | `iOS/Sources/Apresentacao/Fluxos/Avaliacao/AvaliacaoTurnoViewModel.swift`, `iOS/Docs/LGPD.md:42` |
| 10 | **Diagnósticos técnicos** | Firebase Crashlytics e códigos de erro de API (`codigo`, `rpc`, `duracao_ns`) desvinculados de identidade (`setUserID` ausente). | `iOS/Sources/Infraestrutura/TelemetriaCrashlytics.swift:44-47`, `iOS/Docs/SegurancaEPrivacidade.md:38-40` |
| 11 | **Ausência de rastreamento** | `NSPrivacyTracking: false`, lista `NSPrivacyTrackingDomains` vazia, sem framework ATT, sem IDFA, sem data brokers. | `iOS/Resources/PrivacyInfo.xcprivacy:5-8`, `iOS/Docs/SegurancaEPrivacidade.md:82-87` |
| 12 | **Pagamento direto (RN01)** | Valor integral anunciado na vaga pago diretamente pelo contratante ao profissional, sem taxas da plataforma na v1.0. | `iOS/Docs/AjudaESuporte.md:72`, `iOS/Docs/SegurancaEPrivacidade.md`, Cartão hi3NFcjI |
| 13 | **Denúncia de conteúdo (Diretriz 1.2)** | Canal acessível na tela de detalhe da vaga com motivos categorizados e protocolo rastreável de ocorrência. | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:62-150`, `iOS/Docs/SegurancaEPrivacidade.md:134` |
| 14 | **Bloqueio mútuo (Diretriz 1.2)** | Ação de bloqueio imediato na tela de detalhe da vaga impedindo interações futuras entre as partes. | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:20-60`, `iOS/Docs/SegurancaEPrivacidade.md:135` |
| 15 | **Moderação de denúncias** | Compromisso operacional: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. | Decisão do Cauê de 15/10/2026; `iOS/Docs/SegurancaEPrivacidade.md`; `iOS/Docs/AjudaESuporte.md` |
| 16 | **Canal oficial de suporte** | E-mail `suportefrila@gmail.com` centralizado na infraestrutura de apresentação do app. | `iOS/Sources/Apresentacao/EnderecosOficiais.swift:22`, `iOS/Docs/AjudaESuporte.md:19-21` |
| 17 | **Exportação e exclusão de dados** | Ações de autoatendimento no app em Perfil: "Exportar meus dados" (JSON via RPC) e "Excluir conta" (purga remota e local). | `iOS/Sources/Apresentacao/Fluxos/Perfil/ExportarDadosViewModel.swift`, `iOS/Sources/Apresentacao/Fluxos/Perfil/ExclusaoDeContaViewModel.swift`, `iOS/Sources/Dominio/SaidaDaConta.swift:74-91` |

---

## 2. Matriz de Conformidade com as Obrigações da LGPD (Lei 13.709/2018)

| Obrigação Legal | Dispositivo da LGPD | Tratamento na Política de Privacidade (`privacidade.md`) | Status |
|---|---|---|:---:|
| **Identificação do Controlador** | Art. 9º, I e Art. 37 | Seção 1 identifica Cauê Carneiro Kilanovic, pessoa física responsável pelo projeto Frila (projeto de estudantes), com localidade Brasília/DF. | Localidade confirmada pelo Cauê |
| **Canal do Titular de Dados** | Art. 18 | Seções 1 e 8 indicam o canal do titular e do suporte (`suportefrila@gmail.com`), sem atribuir DPO ao projeto. | Canal definido; enquadramento jurídico a confirmar |
| **Finalidades Específicas do Tratamento** | Art. 6º, I e Art. 9º, II | Seção 2 discrimina com clareza a finalidade de cada tipo de dado em tabela acessível. | ✅ Implementado |
| **Indicação da Base Legal** | Art. 7º e Art. 9º, II | Seção 2 indica expressamente as bases legais (execução de contrato art. 7º V, obrigação legal art. 7º II, legítimo interesse art. 7º IX). | ✅ Implementado |
| **Forma e Duração do Tratamento (Retenção)** | Art. 9º, III e Art. 15 | Seção 6 detalha prazos de guarda: contato da outra parte disponível por até 7 dias após o fim do turno (RN10), com descarte do cache offline em 24 h; eventos de uso do app apagados em 90 dias; relatórios técnicos anônimos em até 90 dias; purga na exclusão. | ✅ Implementado |
| **Uso Compartilhado de Dados** | Art. 9º, V e Art. 18, VII | Seção 4 discrimina compartilhamento com contraparte do turno e operadores técnicos (Supabase, Firebase, Apple e Gmail, para o código de entrada). | ✅ Implementado |
| **Transferência Internacional de Dados** | Art. 33, II e Art. 9º | Seção 5 declara transferência para servidores nos EUA sob contratos com cláusulas padrão de proteção (DPA). | ✅ Implementado |
| **Direitos do Titular** | Art. 18 | Seção 8 lista e explica todos os direitos (confirmação, acesso, correção, anonimização, eliminação, portabilidade e revogação). | ✅ Implementado |
| **Procedimento e Prazo para Atendimento ao Titular** | Art. 19, II | Seção 8 informa procedimento via app (exportação/exclusão instantânea) e e-mail com prazo legal de resposta em até **15 dias corridos**. | ✅ Implementado |
| **Segurança e Medidas Técnicas** | Art. 46 | Seção 7 descreve criptografia TLS/HTTPS, Keychain protegido, cortina de privacidade e ausência de logs pessoais. | ✅ Implementado |
| **Comunicação de Incidentes de Segurança** | Art. 48 | Seção 10 prevê protocolo de contenção, notificação tempestiva à ANPD e comunicação individual aos titulares afetados. | ✅ Implementado |
| **Tratamento de Dados de Menores** | Art. 14 | Seção 9 estabelece proibição total de menores de 18 anos, dispensando necessidade de consentimento parental e determinando bloqueio/descarte imediato. | ✅ Implementado |

---

## 3. Fundamentação Legal e Normativa

| Norma / Marco Legal | Dispositivo Chave | Aplicação nos Textos Públicos | Fonte Oficial / Link |
|---|---|---|---|
| **Constituição Federal de 1988** | Art. 7º, XXXIII | Proibição de trabalho noturno, perigoso ou insalubre a menores de 18 anos. Base da proibição absoluta de menores no Frila. | [CF/88 no Planalto](https://www.planalto.gov.br/ccivil_03/constituicao/constituicao.htm) |
| **CLT (Decreto-Lei 5.452/1943)** | Arts. 402 a 441 | Proteção do trabalho do menor e exigência de condições especiais incompatíveis com turnos avulsos. | [CLT no Planalto](https://www.planalto.gov.br/ccivil_03/decreto-lei/del5452.htm) |
| **ECA (Lei nº 8.069/1990)** | Arts. 60 a 69 | Vedações a trabalhos penosos, perigosos ou noturnos e primazia da educação. | [ECA no Planalto](https://www.planalto.gov.br/ccivil_03/leis/l8069.htm) |
| **ECA Digital (Lei nº 15.211/2025)** | Em vigor desde 17/03/2026 | Fim da autodeclaração simples, proteção por padrão e responsabilidade por verificação de idade. | [Lei 15.211/2025 no Planalto](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm) |
| **Lei nº 14.811/2024** | Crimes digitais contra menores | Tipificação de cyberbullying e proteção penal no ambiente digital. | [Lei 14.811/2024 no Planalto](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2024/lei/L14811.htm) |
| **Decreto nº 6.481/2008** | Lista TIP | Convenção 182 da OIT: piores formas de trabalho infantil (inclui turnos noturnos em bares e eventos). | [Decreto 6.481/2008 no Planalto](https://www.planalto.gov.br/ccivil_03/_ato2007-2010/2008/decreto/d6481.htm) |
| **Portaria MJSP nº 1.048/2025** | Classificação Indicativa de Apps | Classificação 18+ por envolver contato entre adultos desconhecidos e trabalho. *(Nota de acesso: quando o site do MJSP retornar 403, a síntese consta em `iOS/Docs/Classificacao18ECA.md:73-80`)*. | [Portaria MJSP 1.048/2025](https://www.gov.br/mj/pt-br/assuntos/seus-direitos/classificacao-1/legislacao/portaria-1048.pdf/view) |
| **LGPD (Lei nº 13.709/2018)** | Arts. 6º, 7º, 9º, 14, 18, 33, 41, 46 e 48 | Marco regulatório principal de proteção de dados, direitos do titular, segurança e canal de atendimento ao titular. | [LGPD no Planalto](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm) |
| **Apple App Store Review Guidelines** | Guideline 1.2 (User-Generated Content) | Obrigatoriedade de termos claros, filtro de termos ofensivos, mecanismo de denúncia, bloqueio de usuários abusivos e moderação tempestiva. O compromisso operacional do Frila é o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. | [Apple Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#safety) |
| **Apple App Store Review Guidelines** | Guideline 5.1 (Privacy and Data Use) | Política de privacidade acessível via URL pública, consentimento, minimização e direito de exclusão de conta no app. | [Apple Guideline 5.1](https://developer.apple.com/app-store/review/guidelines/#legal) |

---

## 4. Skills e Referências do GitHub Consultadas

Conforme procedimento do método da missão (pesquisa em repositórios abertos, download isolado em diretório temporário, inspeção prévia de código e sem execução de scripts externos):

1. **`ricneves-ai/flowgrammers-skills`**
   - **Commit SHA:** `1ae2d4ae0b7ccecb9e49fbfaa4bd14165307462c`
   - **Arquivo consultado:** `financeiro-compliance/conformidade-lgpd/SKILL.md`
   - **Contribuição:** Estrutura modular de políticas de privacidade no modelo brasileiro, checklist de bases legais do Art. 7º e procedimentos de resposta a solicitações de titulares no prazo de 15 dias.
2. **`ericbsantana/llm-skills`**
   - **Commit SHA:** `a670767b4a2e5242681ffa29fd5288a9cc655dc7`
   - **Arquivo consultado:** `skills/lgpd-brasil/SKILL.md`
   - **Contribuição:** Síntese detalhada dos princípios do Art. 6º da LGPD, catálogo completo de direitos dos titulares do Art. 18, regras de tratamento para crianças/adolescentes (Art. 14) e diretrizes para canal do Encarregado/DPO.

---

## 5. Mapeamento das Diretrizes da Apple (Guidelines 1.2 e 5.1)

| Requisito da Apple | Exigência | Como está atendido no texto e no app |
|---|---|---|
| **Guideline 1.2 — Moderação de Conteúdo** | Moderação tempestiva de conteúdo. | Compromisso operacional definido pelo Cauê em 15/10/2026: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos, declarado em `suporte.md` e na seção 8 de `termos.md`. A operação usa `privado.moderacao_pendente()`; homologação operacional pendente. |
| **Guideline 1.2 — Mecanismo de Denúncia** | Ferramenta acessível para denúncia de conteúdo abusivo. | Explicado em `suporte.md:4` e `termos.md:8`. No app: `FolhaDeDenuncia` com protocolo rastreável em `AcoesDeSeguranca.swift:62-150`. |
| **Guideline 1.2 — Bloqueio de Usuários** | Mecanismo de bloqueio mútuo. | Explicado em `suporte.md:4` e `termos.md:8`. No app: `BotaoBloquear` em `AcoesDeSeguranca.swift:20-60`. |
| **Guideline 1.2 — Termos com Proibição de Conteúdo Ofensivo** | Termos de uso devem vedar condutas ilegais e abusos. | Cláusula 8 de `termos.md` estabelece tolerância zero para assédio, preconceito e condutas ilegais. |
| **Guideline 5.1.1 — URL de Política de Privacidade** | URL acessível publicamente explicando dados coletados e uso. | Texto disponível em `privacidade.md`; URL pública aprovada a confirmar antes da publicação. |
| **Guideline 5.1.1(v) — Exclusão de Conta** | App deve permitir exclusão direta pelo usuário. | Documentado em `privacidade.md:8` e `termos.md:12`. No app: tela nativa em Perfil → "Excluir conta" (`ExclusaoDeContaViewModel.swift`). |
| **Guideline 5.1.2 — Minimização de Dados** | Coleta estritamente necessária ao funcionamento. | Localização pontual no check-in/out sem envio de coordenadas cruas ao servidor (`distanciaMetros`). |

---

## 6. Identificação do Responsável e Confirmações Pendentes

Decisão do Cauê de 15/10/2026: o Frila é um projeto de estudantes, sem razão social, CNPJ, sede nem DPO. Os campos corporativos foram substituídos nos textos públicos pela identificação da pessoa física responsável.

| Documento | Localização / Cláusula | Informação | Confirmação Necessária |
|---|---|---|---|
| `privacidade.md` e `termos.md` | Seção 1 (Identificação) | Cauê Carneiro Kilanovic, pessoa física, responsável pelo projeto Frila (projeto de estudantes) | Identificação definida pelo Cauê. |
| `privacidade.md` e `termos.md` | Seção 1 (Identificação) | Localidade: Brasília/DF | Confirmada pelo Cauê. |
| `privacidade.md` | Seções 1, 8 e 12 | Canal do titular de dados e do suporte: `suportefrila@gmail.com` | Canal definido; avaliação jurídica sobre encarregado pendente, sem afirmar dispensa. |
| `termos.md` | Seção 14 (Foro) | Comarca de Brasília, Distrito Federal | Confirmado pelo Cauê. |

> Localidade Brasília/DF e foro da Comarca de Brasília, Distrito Federal confirmados pelo Cauê. Permanecem pendentes a avaliação jurídica sobre encarregado e a definição das URLs públicas aprovadas antes da publicação. Este ajuste documental não republica o site nem altera os textos ou prazos calculados pelo app e pelo backend.

---

## 7. Geração e Deploy

- **Como gerar:** `python3 iOS/Scripts/gerar-paginas-publicas.py <pasta_saida>` (lê os `.md` desta pasta e gera os HTMLs).
- **Deploy:** O deploy (`netlify deploy --prod`) é manual e restrito a quem tem acesso.

