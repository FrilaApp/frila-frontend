# Qual build mandar para a loja

**Só o `Frila-Prod` vai para a loja.** O `Frila-Beta` é para testar: aponta para o servidor de teste (`frila-dev`) e traz o selo BETA e o modo de design (escondido e desligado). Beta e Prod usam o mesmo identificador de app, então não coexistem no aparelho e, no App Store Connect, a lista de builds mistura os dois. Por isso cada build diz de qual esquema veio.

## Como reconhecer

| | `Frila-Prod` (loja) | `Frila-Beta` (só teste) |
|---|---|---|
| Nome sob o ícone | **Frila** | **Frila Beta** |
| Notas do build ("O que testar") | `Frila-Prod · frila-prod · LOJA` | `Frila-Beta · frila-dev` |
| Dentro do app | nada de BETA | selo "BETA · servidor de teste" na entrada e na Conta |
| Servidor | `frila-prod` | `frila-dev` |

Antes de escolher um build para a revisão da Apple, confira o texto das notas. Se não disser `LOJA`, não é o da loja.

## Como o envio se protege

O `Scripts/enviar-testflight.sh` (e o workflow TestFlight, que o chama) escreve o rótulo do esquema no log, no topo do resumo da execução da CI e no arquivo `o-que-testar.txt` (pasta de saída do envio, `FRILA_SAIDA`), e chama o `Scripts/conferir-release.sh` com `FRILA_ESQUEMA_ESPERADO=<esquema>`. Se o `.app` compilado não bater (`FRILA_ENVIRONMENT` errado, ou, no Prod, qualquer rastro do selo ou do modo de design), o envio falha com mensagem clara, antes de subir qualquer coisa.

**Por enquanto a gravação em "O que testar" é manual:** depois que o build terminar de processar no App Store Connect, cole o rótulo (do resumo da execução ou do `o-que-testar.txt`) no campo "O que testar" do build. A gravação automática pela API ainda não existe (fica para um PR seguinte).

Quem escolhe o build no App Store Connect continua sendo uma pessoa: leia as notas.
