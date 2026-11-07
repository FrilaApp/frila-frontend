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

**A gravação em "O que testar" é automática:** depois do envio, o passo "Gravar o esquema em O que testar" do workflow TestFlight espera o build ficar processado e grava o rótulo na primeira linha do campo pela API (`Scripts/app-store-connect.rb`, ação `notas-do-build`), sem apagar o que uma pessoa escreveu depois dele. Se a gravação falhar, o envio continua valendo e o resumo da execução avisa em destaque, com o texto para colar à mão (o `o-que-testar.txt` de sempre).

Quem escolhe o build no App Store Connect continua sendo uma pessoa: leia as notas.
