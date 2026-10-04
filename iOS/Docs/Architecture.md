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
- `FrilaInfraestrutura`: MetricKit, Keychain auxiliar e integrações de plataforma. O CoreLocation fica aqui (`LeitorDeLocalizacaoDoSistema`), atrás da porta `LeitorDeLocalizacao` do domínio; a apresentação só conhece a porta.
- `Frila`: composição das dependências e ciclo de vida.

`DespachoService`, `NotificacaoService` e `ElegibilidadeSpec` não entram no app na v1.0. Elegibilidade, despacho, teto e agrupamento são regras críticas do backend; o cliente apenas consome vagas e recebe push. Isso resolve a divergência entre os diagramas antigos e o cartão mais recente da Sprint 0.

`PerfilConta` é fixo em `SessaoUsuario`: não há troca de perfil na sessão.

## Cache e fila offline (#111)

O banco local é um `ModelContainer` do SwiftData em `Application Support/Frila/Frila.store`, com a proteção de arquivo `completeUntilFirstUserAuthentication` na pasta. Os arquivos criados nela herdam a classe. É a mesma proteção padrão do iOS para dados de app: o conteúdo fica cifrado até o primeiro desbloqueio depois de ligar o aparelho, e legível depois disso, inclusive em segundo plano, que é quando a fila precisa sair. A classe `complete` travaria a fila com a tela bloqueada.

- **O que fica guardado:** turnos confirmados, catálogo de funções, sessão do app e a fila de check-in, check-out e avaliação. Candidatura nunca entra na fila: no modo urgência, candidatar horas depois engana o profissional.
- **Prazos, pelo relógio do aparelho, porque sem rede não há outro:**
  - o turno sai do cache 24 h depois do fim;
  - o contato some depois de `visivel_ate` (RN10).
- **`TurnosComCache`:** lê da API e regrava o cache. Só com `sem_rede` devolve o cache, marcado como `origem: .cache`. Qualquer outro erro sobe, para um 401 não mostrar os turnos de uma sessão encerrada.
- **`ReenvioAoReconectar`:** manda a fila na passagem para conectado (`NWPathMonitor`) e ao abrir o app já com rede. Cada ação sai com o instante do toque, em ISO-8601 com precisão de segundo.
- **`SaidaDaConta`:** apaga cache e fila ao sair e também quando a sessão é encerrada sem pedido (401 de conta excluída ou suspensa).

**Evolução pós-#111:**
- Meus turnos lê o cache e conserva dados e contato offline (`TelaMeuTurno`, `MeuTurnoViewModel`, #73, #133);
- indicadores discretos de "sem conexão" e de lista vinda do cache foram integrados com `AvisoFrila` (`aviso-cache-turnos`, #130).
