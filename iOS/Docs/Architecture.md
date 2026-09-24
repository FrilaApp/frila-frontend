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
- `FrilaInfraestrutura`: MetricKit, Keychain auxiliar e integrações de plataforma.
- `Frila`: composição das dependências e ciclo de vida.

`DespachoService`, `NotificacaoService` e `ElegibilidadeSpec` não entram no app na v1.0. Elegibilidade, despacho, teto e agrupamento são regras críticas do backend; o cliente apenas consome vagas e recebe push. Isso resolve a divergência entre os diagramas antigos e o cartão mais recente da Sprint 0.

`PerfilConta` é fixo em `SessaoUsuario`: não há troca de perfil na sessão.
