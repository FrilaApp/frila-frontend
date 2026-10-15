# Direitos de Conteúdo, Licenças de Terceiros e Diretrizes do Selo App Store

**Data:** 11/10/2026  
**Auditor/Responsável:** Loki (QA e Conformidade Regulatória)  
**Repositório:** `FrilaApp/frila-frontend`  
**Referência Trello:** [6br4qElo](https://trello.com/c/6br4qElo) — *S3 · Jurídico + iOS · Licenças de terceiros, direitos de conteúdo e selo da App Store*  
**Requisitos e Normas Vinculadas:**
- Apple App Store Review Guidelines: Diretriz 1.2 (User Generated Content) e Diretriz 5.2 (Intellectual Property)
- App Store Connect Help: Declaração de Direitos de Conteúdo (*Content Rights*)
- Apple App Store Marketing and Identity Guidelines (Regras de uso de marcas, selos e mockups de hardware)
- CBL C18 (Apple Developer Academy): *Learning Goals* de Aspectos Legais, Propriedade Intelectual e Conformidade de Publicação

---

## 1. Contexto e Objetivos

O Frila é uma plataforma de conexão operacional entre estabelecimentos do setor de gastronomia/eventos e profissionais autônomos no Distrito Federal. Durante o ciclo de publicação de vagas, candidaturas, execução e avaliação de turnos:
1. O aplicativo embute SDKs e bibliotecas de código aberto de terceiros que exigem atribuição legal de direitos.
2. Os usuários inserem informações públicas (títulos de vagas, descrições, razões sociais, nomes de estabelecimentos, avaliações mútuas e comentários de turno) caracterizando Conteúdo Gerado pelo Usuário (*User Generated Content - UGC*).
3. As peças de marketing, materiais de recrutamento do piloto e landing page pública utilizam a marca nominativa da Apple, o selo oficial *"Baixar na App Store"* e renderizações de hardware (iPhone).

Este documento consolida as bases normativas exigidas pela Apple, os rascunhos das declarações obrigatórias para submissão, a cláusula contratual de conteúdo para os Termos de Uso e o manual de conformidade para o marketing e o CBL.

---

## 2. Licenças de Terceiros no Build 1.0 (Concluído)

Conforme critério já auditado e atendido no app (PRs #34 e #178):
- **Localização no Código:** `iOS/Sources/Apresentacao/TelaLicencas.swift` (inclui a visualização de detalhe da licença).
- **Acesso pelo Usuário:** Acessível via Perfil > Ajuda e Suporte (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift`) com navegação nativa e acessibilidade completa.
- **Fonte da Auditoria:** Extraído diretamente dos 20 pacotes resolvidos em `iOS/Package.resolved` e catalogados no recurso de produção `iOS/Resources/Licencas.json` por meio do script de automação `iOS/Scripts/gerar-licencas.py`.
- **Dependências Catalogadas (20 pacotes em `iOS/Package.resolved` e `iOS/Resources/Licencas.json`):**
  1. `abseil-cpp-binary` (v1.2024072200.0) — Apache-2.0
  2. `app-check` (v11.3.2) — Apache-2.0
  3. `firebase-ios-sdk` (v12.19.2) — Apache-2.0
  4. `google-ads-on-device-conversion-ios-sdk` (v3.7.0) — Apache-2.0
  5. `googleappmeasurement` (v12.19.2) — Apache-2.0
  6. `googledatatransport` (v10.1.1) — Apache-2.0
  7. `googleutilities` (v8.1.3) — Apache-2.0
  8. `grpc-binary` (v1.69.1) — Apache-2.0
  9. `gtm-session-fetcher` (v5.3.1) — Apache-2.0
  10. `interop-ios-for-google-sdks` (v101.0.0) — Apache-2.0
  11. `leveldb` (v1.22.5) — BSD-3-Clause
  12. `nanopb` (v2.30910.1) — Zlib
  13. `promises` (v2.4.1) — Apache-2.0
  14. `supabase-swift` (v2.55.2) — MIT
  15. `swift-asn1` (v1.7.3) — Apache-2.0
  16. `swift-clocks` (v1.1.1) — MIT
  17. `swift-concurrency-extras` (v1.4.1) — MIT
  18. `swift-crypto` (v4.5.2) — Apache-2.0
  19. `swift-http-types` (v1.8.0) — Apache-2.0
  20. `xctest-dynamic-overlay` (v1.13.1) — MIT

Todas as dependências possuem textos de licença integrais e avisos de direitos autorais exibidos no aplicativo, em plena conformidade com as cláusulas de redistribuição de cada mantenedor.

---

## 3. Cláusula de Conteúdo Gerado pelo Usuário (UGC) para os Termos de Uso

Para cumprimento da **Diretriz 1.2 da App Store (User-Generated Content)** e suporte à declaração de direitos de conteúdo, os Termos de Uso oficiais da plataforma (publicados na página de termos e referenciados em `EnderecosOficiais.swift`) devem conter a seguinte cláusula formal:

### 3.1 Rascunho da Cláusula Contratual (Termos de Uso do Frila)

> **CLÁUSULA — CONTEÚDO GERADO PELO USUÁRIO E DIREITOS DE PROPRIEDADE INTELECTUAL**
>
> **1. Titularidade e Licença:** Ao publicar anúncios de vagas, descrições operacionais, nomes e identificadores de estabelecimentos, avaliações de turnos, relatos e qualquer outro conteúdo na plataforma Frila ("Conteúdo do Usuário"), você declara ser o único e legítimo titular de todos os direitos autorais, marcas e direitos da personalidade relacionados a tal conteúdo, ou possuir todas as licenças, autorizações e consentimentos necessários para veiculá-lo.
>
> **2. Concessão de Licença à Plataforma:** Você concede à plataforma Frila uma licença gratuita, não-exclusiva, irrevogável, passível de sublicenciamento e de âmbito mundial, pelo prazo necessário para a operação e divulgação da plataforma, para utilizar, hospedar, armazenar, reproduzir, modificar para fins de adaptação técnica, exibir publicamente e distribuir o Conteúdo do Usuário exclusivamente no contexto dos serviços prestados pelo Frila.
>
> **3. Vedações e Conteúdo Proibido:** É expressamente vedado publicar conteúdos que:
> - Sejam ilícitos, difamatórios, injuriosos, caluniosos, discriminatórios, abusivos, ameaçadores ou que violem a legislação brasileira;
> - Violem segredos industriais, direitos autorais, marcas ou direitos de propriedade intelectual de terceiros;
> - Veiculem publicidade enganosa, dados de contato fraudulentos ou informações em desacordo com as diretrizes do Frila;
> - Promovam discriminação por gênero, raça, orientação sexual, deficiência, credo ou idade.
>
> **4. Tolerância Zero a Abusos (Diretriz 1.2 Apple):** A plataforma Frila adota política de tolerância zero contra condutas e conteúdos abusivos ou ofensivos. As denúncias são atendidas o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Conteúdos que violarem as regras poderão ser removidos, sujeitando o infrator ao bloqueio cautelar ou exclusão definitiva da conta.
>
> **5. Responsabilidade e Isenção:** O usuário é integral e exclusivamente responsável por todo o conteúdo que inserir na plataforma, assumindo a obrigação de indenizar e manter indene a plataforma Frila, seus desenvolvedores e sócios contra quaisquer reclamações judiciais ou extrajudiciais de terceiros decorrentes da violação de direitos autorais, marcas ou direitos da personalidade.

---

## 4. Declaração de Direitos de Conteúdo no App Store Connect (*Content Rights*)

No portal **App Store Connect**, sob a seção **Informações do App (*App Information*) > Direitos de Conteúdo (*Content Rights*)**, a Apple exige a resposta a um questionário formal antes da primeira submissão de versão para a loja.

### 4.1 Questionário Oficial e Respostas Fundamentadas

#### Pergunta 1:
> *"Does your app contain, display, or access third-party content?"*  
> ("O seu aplicativo contém, exibe ou acessa conteúdo de terceiros?")

- **Resposta Recomendada:** **Sim (*Yes*)**.
- **Fundamentação Técnica e Jurídica:**
  O Frila exibe conteúdo alimentado diretamente por terceiros (UGC: vagas criadas por contratantes, razões sociais cadastradas e avaliações mútuas fornecidas por profissionais e gestores), além de renderizar mapas e anotações geográficas fornecidas pelo serviço MapKit da Apple e dados de bibliotecas terceiras de código aberto.

#### Pergunta 2 (Apresentada caso a Pergunta 1 seja "Sim"):
> *"Do you have all necessary rights to display this content, or are you otherwise permitted to display it under the law?"*  
> ("Você possui todos os direitos necessários para exibir este conteúdo ou possui autorização legal para exibi-lo?")

- **Resposta Recomendada:** **Sim (*Yes*)**.
- **Fundamentação Técnica e Jurídica:**
  1. **Conteúdo dos Usuários (UGC):** O Frila possui licença contratual expressa, conferida por meio do aceite obrigatório dos Termos de Uso no momento do primeiro acesso e cadastro no app (`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift`, botão `cadastro-termos`), conforme Cláusula de Licença de Conteúdo detalhada na Seção 3 deste documento.
  2. **Bibliotecas de Terceiros:** Todos os SDKs embutidos são regidos por licenças de código aberto permissivas (Apache-2.0, MIT, BSD-3-Clause, Zlib), cujas exigências de atribuição são plenamente cumpridas na tela nativa `TelaLicencas.swift` com base no catálogo derivado de `iOS/Package.resolved` e consolidado em `iOS/Resources/Licencas.json`.
  3. **Serviços de Mapa (MapKit):** O uso do MapKit decorre da adesão regular ao *Apple Developer Program License Agreement*.

### 4.2 Rascunho da Declaração Formal para a Equipe de Revisão da Apple (App Review Notes)

Caso a equipe de App Review solicite esclarecimentos ou comprovação de direitos sob a **Diretriz 5.2.3** da App Store, o texto abaixo está pronto para inserção no campo de notas de revisão:

```
[Declaração de Direitos de Conteúdo / Content Rights Declaration]

App: Frila (Bundle ID: br.com.frila.app)
Versão: 1.0.0

Declaramos à Apple Inc. que todos os conteúdos de terceiros exibidos ou acessados pelo aplicativo Frila são devidamente licenciados e autorizados:
1. Conteúdo Gerado pelo Usuário (UGC): O aplicativo exibe vagas operacionais e avaliações fornecidas por contratantes e profissionais cadastrados. Todos os usuários aceitam os Termos de Uso da plataforma (https://frila.app/termos), que concedem ao Frila licença expressa, mundial e gratuita para exibição do conteúdo e impõem total responsabilidade autoral ao publicador.
2. Conformidade com a Diretriz 1.2: O app possui mecanismos nativos de moderação com bloqueio mútuo definitivo e folha de denúncia. O atendimento ocorre o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos.
3. Bibliotecas de Terceiros: Todos os componentes de código aberto utilizados no binário possuem suas licenças e avisos de direitos autorais integralmente exibidos dentro do aplicativo no caminho: Perfil > Ajuda > Licenças de código aberto.
4. Mapeamento e Geolocalização: O aplicativo consome os serviços de mapa oficiais da Apple (MapKit) em conformidade com o Apple Developer Program License Agreement.
```

---

## 5. Diretrizes de Marketing: Uso do Selo da App Store e Imagens de iPhone

Para garantir que os materiais de marketing do piloto (cartão Trello `zN1hjaz4`), as apresentações de Apple Review (cartões `lPHiAPMZ` e `xaDu8IOa`) e as divulgações externas cumpram estritamente as **Diretrizes de Identidade da Apple (Apple Identity Guidelines)**:

### 5.1 Selo Oficial "Baixar na App Store" (*App Store Badge*)

1. **Ativo Oficial e Idioma:**
   - Para comunicações em português (Brasil), utilizar exclusivamente o selo oficial aprovado com a grafia: **"Baixar na App Store"** ou **"Disponível na App Store"**.
   - O selo vetorial (.SVG / .EPS) deve ser baixado diretamente do portal oficial da Apple (*Apple Design Resources*). Nunca recriar o selo, desenhar o logotipo ou aplicar tipografia própria.
2. **Área de Respiro (*Clear Space*):**
   - O selo exige uma margem mínima desobstruída em todos os lados igual a **1/4 da altura do selo** ($0,25 \times H$).
   - Nenhum texto, logotipo, borda ou elemento gráfico pode invadir esse espaço demarcado.
3. **Dimensões Mínimas:**
   - **Telas Digitais / Web / Redes Sociais:** Altura mínima de **40 pixels**.
   - **Mídia Impressa (cartazes, panfletos, banners físicos do piloto):** Altura mínima de **10 mm** (0,4 polegadas).
4. **Cores e Contrastes Homologados:**
   - **Selo Padrão (Fundo Preto):** Usar preferencialmente sobre fundos claros ou fotografias que ofereçam alto contraste.
   - **Selo Alternativo (Fundo Branco com Borda):** Usar sobre fundos totalmente escuros onde o selo preto não teria contraste adequado.
   - **Proibições Estritas da Apple:**
     - Nunca alterar as cores internas do selo (não colorir o ícone da maçã ou as letras).
     - Nunca aplicar sombras projetadas (*drop shadows*), contornos brilhantes, transparências parciais ou filtros coloridos.
     - Nunca distorcer as proporções (largura × altura), girar, rotacionar ou inverter o selo.
5. **Relação com Outras Lojas:**
   - Se divulgado ao lado do selo da Google Play, ambos devem ter altura visual idêntica e peso gráfico equivalente. O selo da App Store nunca deve figurar em posição secundária ou com destaque reduzido.

### 5.2 Uso de Imagens de Produtos Apple (Mockups de iPhone)

1. **Modelos Autorizados:**
   - Utilizar apenas representações de modelos recentes de iPhone (com *Dynamic Island*, ex.: iPhone 16 ou iPhone 17), em seus acabamentos de cor oficiais de fábrica.
   - Não utilizar modelos descontinuados com *notch* antigo ou botão Home frontal para representar a v1.0.
2. **Fidelidade da Interface:**
   - A tela exibida no mockup de iPhone deve representar telas reais do aplicativo Frila, sem sobrepor elementos fictícios sobre a área da *Dynamic Island* ou a barra indicadora de início (*Home Indicator*).
   - O aplicativo deve ser mostrado na proporção exata da tela nativa, sem cortes laterais ou distorções de aspecto.
3. **Proibições:**
   - É proibido exibir imagens de aparelhos que pareçam quebrados, amassados, distorcidos ou descaracterizados.
   - Não utilizar ilustrações que simulem mãos segurando o aparelho com proporções anatômicas incorretas geradas por IA.

### 5.3 Aviso Legal Obrigatório de Marcas Registradas (*Legal Disclaimer*)

Todo material promocional (landing page, deck do CBL, folhetos físicos do DF e postagens de redes sociais) que contenha o selo ou mencione a marca iPhone/App Store deve estampar obrigatoriamente a seguinte nota de rodapé:

> *"Apple, o logotipo da Apple e iPhone são marcas da Apple Inc., registradas nos EUA e em outros países. App Store é uma marca de serviço da Apple Inc."*

---

## 6. Integração com o CBL C18 (Apple Developer Academy)

O Desafio C18 estabelece como meta de aprendizado (*Learning Goal*) o domínio das diretrizes legais e regulatórias de publicação de ecossistema iOS.
- **Evidência Documental para o CBL:** Este documento cumpre a evidência formal exigida para demonstrar que o time Frila estruturou as políticas de licença de terceiros, proteção de propriedade intelectual e alinhamento de marketing de acordo com os padrões da Apple.
- **Rastreabilidade no Vault da Bancada:** Este relatório serve de subsídio direto para o dossiê `CBL_C18` e para a apresentação do marco de entrega (*Apple Review 2*).

---

## 7. O Que Ficou Pendente para o Cauê (Execução no App Store Connect e Jurídico)

Conforme delimitação da missão, as atividades estritamente documentais e de engenharia foram concluídas neste relatório. Ficam reservadas para a execução humana do Cauê as seguintes etapas no App Store Connect e na administração societária:

1. **No App Store Connect (Conta de Desenvolvedor):**
   - `[ ]` Acessar **App Store Connect > Meus Apps > Frila > Informações do App**.
   - `[ ]` Na seção **Direitos de Conteúdo (*Content Rights*)**, clicar em "Configurar Direitos de Conteúdo".
   - `[ ]` Responder **"Sim"** à pergunta sobre exibição de conteúdo de terceiros e **"Sim"** à pergunta de posse/licenciamento legal dos direitos, salvando a configuração.
   - `[ ]` Incluir, se solicitado no formulário de submissão, a declaração de notas da Seção 4.2.
2. **Nos Termos de Uso Oficiais do Frila:**
   - `[ ]` Publicar a versão atualizada dos Termos de Uso em `https://frila.app/termos` incorporando a Cláusula de Licença de UGC e Indenidade da Seção 3.
   - `[ ]` Colher o aceite formal da PO (Júlia) no texto normativo final.
3. **Nas Peças de Marketing e Lançamento:**
   - `[ ]` Conferir que os arquivos vetoriais utilizados pela equipe de Design no cartão `zN1hjaz4` seguem o selo oficial e incluem a nota de rodapé de marcas registradas da Apple.
