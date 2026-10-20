# FLUXOS.md: escopo do primeiro TestFlight com o design do Fabrício

São quatro fluxos e doze telas. O resto do app (turno, check-in, avaliação, conta, ajuda) não muda nesta rodada. A linguagem visual está em [`DESIGN.md`](DESIGN.md).

Como ver cada coisa:
- **Quadro de referência:** `http://127.0.0.1:8792/quadro.html?n=<Quadro>&<prop>=<valor>`, por exemplo `?n=Main&estado=sem%20conexão`. As imagens prontas do estado padrão estão em `~/dev/FrilaMidPhase/referencia-midfi/png/<Quadro>.png`.
- **App no simulador:** `xcrun simctl launch <UDID> com.frila.org.app -FRILA_SCENARIO <cenário> -FRILA_SEM_ANIMACOES`, no esquema `Frila-Local`, sem rede real.

## 1. Entrada (os dois perfis)
Main → Codigo → Perfil. Depois, o contratante segue para o fluxo 2 e o profissional para o fluxo 3. Conta que já existe vai do Código direto para Minhas vagas ou para Vagas.

| Tela | Quadro | Swift | Cenário | Estados a cobrir |
|---|---|---|---|---|
| Entrada | Main | `Autenticacao/TelaEntrada.swift` | `entrada` | normal, campo vazio, e-mail inválido, enviando, sem conexão, falha de envio |
| Código no e-mail | Codigo | `Autenticacao/TelaCodigo.swift` | `entrada` | normal, código errado, código expirado, sem conexão, reenviar com contagem |
| Perfil e dados | Perfil | `Autenticacao/TelaCadastro.swift` | `primeiro-acesso` | nenhum perfil escolhido (CTA desabilitado e ajuda), escolhido, menor de 18 |

Os textos legais da Entrada continuam: termos e privacidade, e "Classificação indicativa: 18 anos".

## 2. Contratante: cadastrar e publicar
Estabelecimento → "Salvar e publicar a primeira vaga" → Publicar (folha) → Minhas vagas → Vaga aberta.

| Tela | Quadro | Swift | Cenário | Estados a cobrir |
|---|---|---|---|---|
| Dados do negócio | Estabelecimento | `Contratante/CadastroEstabelecimento.swift` | `contratante-sem-estabelecimento` | disponível, carregando, erro, documento já cadastrado, endereço não encontrado |
| Nova vaga | Publicar | `Contratante/PublicarVaga.swift` | `contratante` | disponível, início em menos de 3 h, erro |
| Minhas vagas | Acompanhar | `Contratante/MinhasVagas.swift` | `contratante` | disponível, com e sem "Precisa de atenção", vazio, carregando, erro |
| Vaga aberta | VagaAberta | `Contratante/MinhasVagas.swift`, `CandidatosDaVaga.swift` | `contratante` | aberta e avisados, nenhum profissional disponível |

## 3. Profissional: perfil, vagas e candidatura
Perfil → Funções e horários → "Salvar e começar" → Permissão de aviso → Vagas no DF → Detalhe da vaga → "Aceitar turno" → turno confirmado (tela que já existe) ou Vaga preenchida.

| Tela | Quadro | Swift | Cenário | Estados a cobrir |
|---|---|---|---|---|
| Funções e horários | Disponibilidade | `Profissional/TelaPerfilProfissional.swift` | `sem-perfil-profissional` | cadastro com horários, grade vazia, erro |
| Permissão de aviso | PermissaoNotificacao | `Push/TelasDaPermissaoDePush.swift` | `sem-perfil-profissional` | único |
| Vagas no DF | Vagas | `Profissional/TelaVagas.swift` | `success` | disponível, sem vagas, sem ponto base, carregando, erro, sem rede |
| Detalhe da vaga | Vaga | `Profissional/TelaDetalheVaga.swift` | `success` | disponível, enviando, confirmado, conflito, sem resposta |
| Vaga preenchida | Preenchida | `Profissional/TelasDaCandidatura.swift` | `vaga-preenchida` | preenchida, encerrada |

## 4. Fora do escopo desta rodada
Turnos (os dois lados), Meu turno, mapas, denúncia, avaliação, conta e perfil completos, ajuda, republicar, repetir, trocar local e mais opções. Quando uma tela do escopo leva até elas, o link continua levando para a tela atual do app.
