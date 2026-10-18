# Fechamento dos cartões adiantados — 18/10/2026

A revisão dos dez cartões está em [resultado-homem-aranha-3.tsv](resultado-homem-aranha-3.tsv). Cada linha separa o trabalho do app da dependência externa. Resultado: 5 `BLOQUEADO-CAUE` e 5 `BLOQUEADO-TERCEIRO`; nenhum cartão tem prova integral para `CONCLUIR`.

- Os patches de endereços do piloto e do botão de retry já estavam na main pelo [PR #392](https://github.com/FrilaApp/frila-frontend/pull/392), commit `4cc4a5a`. Esta revisão corrige uma segunda referência contraditória ao retry.
- Os modelos de atualização e problema completam os seis tipos de comunicação do piloto. Antes de enviar, faltam preencher dados confirmados e validar o link de instalação. Nenhuma mensagem foi enviada aos participantes.
- A aprovação dos textos já foi dada por Nick Fury por delegação do Cauê em 16/10. Os documentos agora ligam os comentários originais; faltam os frames e sua conferência.
- A compatibilidade dos textos com a tela bloqueada do SE fica explicitamente pendente. Contagem de caracteres e testes com dublês não substituem capturas.
- Nenhum novo critério foi marcado: os restantes exigem prova física, aprovação visual, configuração da ficha ou confirmação operacional; os critérios compostos continuam abertos. Nenhum cartão foi movido.

As consultas completas dos cartões e os comentários, a justificativa por critério e os resumos de verificação ficam em `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/evidencias-fechar-adiantados-18-10/`. As provas de 17/10 citadas no TSV ficam na pasta irmã `evidencias-varredura-17-10/`; seus resultados não são apresentados como execução nova.

Validação desta rodada: `conferir-textos.sh` e `git diff --check` aprovados; seis modelos e ausência de endereços rejeitados conferidos por script. Regressão focal pelo `xcb.sh` aprovada: 37 testes em cinco suítes, zero falhas e zero pulados (`PadroesDeEstadoTests`, `AcessibilidadeEstadoECorTests`, `TextosDeNotificacaoTests`, `NotificationServiceTests` e `ExclusaoDeContaViewModelTests`). Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261018-071117-48058.log`. A primeira tentativa encerrou antes de testar (código 66: projeto ainda não gerado); `xcodegen generate` corrigiu a preparação. O workflow iOS exclui Markdown e `iOS/Docs/**`; nenhuma execução remota foi disparada para este PR documental. Sem alteração em SwiftUI, backend, contrato, assinatura ou PRs de outros autores.

Não executado nesta rodada:

1. Instalação/ciclo TestFlight, vídeo externo e crash simbolizado: dependem de aparelhos e do Cauê; missão proíbe envio à Apple/TestFlight.
2. Entrega FCM, reinstalação real e extensão com duas contas: exigem iPhone físico e build assinado; dublês não comprovam APNs.
3. Exclusão/recadastro reais: dependem de SDK/backend e conta de teste; não se apagou conta de ninguém.
4. Preenchimento/conferência de App Privacy: exige decisão do Cauê/jurídico e acesso à ficha; escrita na Apple fora do escopo.
5. Capturas de textos na tela bloqueada do SE: o simulador autorizado é iPhone 17 (iOS 26.5), conferido por `simctl list devices available -j`; não se trocou nem criou simulador.
6. Percurso com VoiceOver por pessoa independente e aceite dos frames: exigem participação humana e referências aprovadas do design.

São 10 cartões bloqueados; as seis atividades acima não são resultados aprovados nem testes pulados da suíte automática.
