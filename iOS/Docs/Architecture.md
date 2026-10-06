# Arquitetura iOS

As dependências apontam para o domínio:

```text
App -> Apresentacao -> Dominio
App -> Dados --------> Dominio
App -> Infraestrutura -> Dominio
```

- `FrilaDominio`: entidades, objetos de valor e portas. Não importa SwiftUI, Supabase, SwiftData nem CoreLocation.
- `FrilaDados`: cliente Supabase, DTOs, dublê em memória, fixtures, cache SwiftData e fila offline.
- `FrilaApresentacao`: views SwiftUI, componentes e view models `@Observable` isolados no `MainActor`.
- `FrilaInfraestrutura`: Keychain auxiliar e integrações de plataforma. O CoreLocation fica aqui (`LeitorDeLocalizacaoDoSistema`), atrás da porta `LeitorDeLocalizacao` do domínio; a apresentação só conhece a porta. O MetricKit foi substituído pelo Firebase Crashlytics (#198).
- `Frila`: composição das dependências e ciclo de vida. A cortina de privacidade (`.cortinaDePrivacidade()`, #137) é ligada na raiz da cena (`FrilaApp.swift:84`), cobrindo a interface fora de `.active` (proteção no seletor de tarefas do sistema).

`DespachoService`, `NotificacaoService` e `ElegibilidadeSpec` não entram no app na v1.0. Elegibilidade, despacho, teto e agrupamento são regras críticas do backend; o cliente apenas consome vagas e recebe push. Isso resolve a divergência entre os diagramas antigos e o cartão mais recente da Sprint 0.

`PerfilConta` é fixo em `SessaoUsuario`: não há troca de perfil na sessão.

## Por que recebo vagas e revisão do despacho (#18)

A tela "Por que recebo vagas" (folha de Meu perfil, `Fluxos/Perfil/TelaPorQueReceboVagas.swift`) mantém o texto explicativo do app e mostra os critérios reais de `criteriosDeNotificacao` (função, grade semanal, distância máxima do ponto base, equipes de confiança e teto de notificações), com estados de carregando, vazio, sem rede e erro no `PorQueReceboVagasViewModel`. "Contestar" pede o relato e chama `pedirRevisaoDespacho`, que devolve um `Protocolo` do tipo `revisao_despacho` com o prazo de resposta; as recusas do contrato (campo, conta suspensa, limite) têm mensagem própria. O despacho em si é do servidor: o app só lê os critérios e registra o pedido. O dublê guarda a equipe de confiança de cada casa (`equipesDeConfianca`), que a frente do contratante reutiliza.

## Equipe de confiança (#24)

Em Estabelecimento, "Equipe de confiança" (`Fluxos/Equipe/TelaEquipeDeConfianca.swift`) lista `equipeDeConfianca` e remove com `removerDaEquipe`, depois de uma confirmação. "Incluir na equipe" (`BotaoIncluirNaEquipe`) aparece no turno do contratante só quando a presença foi verificada, que é a condição de `incluir_na_equipe` (UC11); a regra vale no servidor, e o `403 sem_permissao` com `sem_turno_cumprido` tem mensagem própria (`MensagensDaEquipe`), como a conta suspensa e o papel de operador. No dublê, a equipe começa vazia na conta de contratante (cenário `equipe-de-confianca-com-membro` a põe cheia) e com o profissional das fixtures na conta de profissional, de onde saem os critérios de "Por que recebo vagas".

## Cache e fila offline (#111)

O banco local é um `ModelContainer` do SwiftData em `Application Support/Frila/Frila.store`, com a proteção de arquivo `completeUntilFirstUserAuthentication` na pasta. Os arquivos criados nela herdam a classe. É a mesma proteção padrão do iOS para dados de app: o conteúdo fica cifrado até o primeiro desbloqueio depois de ligar o aparelho, e legível depois disso, inclusive em segundo plano, que é quando a fila precisa sair. A classe `complete` travaria a fila com a tela bloqueada.

- **O que fica guardado:** turnos confirmados, catálogo de funções, sessão do app e a fila de ações pendentes: check-in, check-out, avaliação, publicação de vaga, republicação de vaga, cancelamento de posição e cancelamento de vaga (`TipoAcaoPendente`, `Dominio/Cache.swift:31-41`). Candidatura nunca entra na fila: no modo urgência, candidatar horas depois engana o profissional; escolha e retirada de candidatura no modo seleção também não entram (#10).
- **Prazos, pelo relógio do aparelho, porque sem rede não há outro:**
  - o turno sai do cache 24 h depois do fim;
  - o contato some depois de `visivel_ate` (RN10).
- **`TurnosComCache`:** lê da API e regrava o cache. Só com `sem_rede` devolve o cache, marcado como `origem: .cache`. Qualquer outro erro sobe, para um 401 não mostrar os turnos de uma sessão encerrada.
- **`ReenvioAoReconectar`:** manda a fila na passagem para conectado (`NWPathMonitor`) e ao abrir o app já com rede. Cada ação sai com o instante do toque, em ISO-8601 com precisão de segundo. O `SincronizadorAcoes` (`Dados/SincronizadorAcoes.swift:20-29`) consulta a identidade uma única vez antes do lote e despacha apenas ações correspondentes à conta autenticada (#139).
- **`SaidaDaConta`:** apaga cache e fila ao sair e também quando a sessão é encerrada sem pedido (401 de conta excluída ou suspensa).
- **Autoria e isolamento por conta (#139):** novas ações na fila gravam o `contaID` da sessão ativa (`Dominio/Cache.swift:62`, `Dados/CacheSwiftData.swift:189`). Ações de outra conta permanecem na fila sem envio indevido.
- **Recusas, avisos e reatividade (#139):** recusas definitivas saem da fila de reenvio e geram registros persistidos de aviso (`AcaoRecusada`, `CacheSwiftData.swift:239-340`). Fechar um aviso reconhece a recusa (`reconhecerRecusa`) mantendo a ação impedida de voltar a ser reenviada; uma nova tentativa aceita resolve as recusas anteriores da mesma operação (`resolverRecusas`). O `NotificationCenter` emite `.filaDeAcoesAtualizada` (`Cache.swift:183`, `SincronizadorAcoes.swift:75,94`), atualizando as telas reativas (`TelaMeuTurno.swift:62`, `TelaAvaliacao.swift:50`, `PublicarVaga.swift:417`, `RepublicarVaga.swift:339`).
- **Tolerância a registros ilegíveis (#137):** a leitura do SwiftData (`CacheSwiftData.swift:125-150`) decodifica item a item; registros ilegíveis são descartados individualmente com log, sem inutilizar o cache ou travar a fila.
- **Prazo na abertura (#137):** `PrazoDaAbertura.padrao` (8 s) corre a avaliação da sessão e da identidade (`DestinoAposEntrada.swift:66-69, 102-103`, `IdentidadeDaAvaliacao.swift:8-21`); vencido o prazo, cancela a chamada e aciona o fallback offline (sessão do cache e destino guardado).

**Evolução pós-#111:**
- Meus turnos lê o cache e conserva dados e contato offline (`TelaMeuTurno`, `MeuTurnoViewModel`, #73, #133);
- indicadores discretos de "sem conexão" e de lista vinda do cache foram integrados com `AvisoFrila` (`aviso-cache-turnos`, #130).
