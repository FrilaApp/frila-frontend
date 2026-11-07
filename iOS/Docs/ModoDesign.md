# Modo de design (painel de variantes)

O modo de design mostra o painel de variantes de uma tela (menu de versões, decisões, moldura). Serve para o Fabrício comparar alternativas no aparelho. Ele existe só no `Frila-Beta` e nos esquemas de Debug (`Frila-Local`, `Frila-Dev`). No `Frila-Prod` o código nem é compilado: o `Scripts/conferir-release.sh` reprova o build se achar qualquer símbolo dele.

## Estado inicial

**Desligado.** Quem abre o Beta pelo TestFlight não vê painel, gesto nem marcador. A única pista é o selo discreto "BETA · servidor de teste" na tela de entrada e no fim da tela Conta.

## Como ligar (qualquer um dos três)

| Jeito | Quando usar | Como |
|---|---|---|
| Cinco toques no selo BETA | Aparelho do TestFlight, sem Xcode | Toque cinco vezes seguidas no texto "BETA · servidor de teste" (cada toque em até 1,5 s do anterior). O aparelho vibra: forte ao ligar, leve ao desligar. Repita para desligar. |
| Argumento de lançamento | Rodando pelo Xcode | Product > Scheme > Edit Scheme > Run > Arguments > Arguments Passed On Launch: `-FRILA_MODO_DESIGN` (o `-FRILA_DESIGN` também vale). Liga a cada execução com o argumento. |
| Chave no aparelho | Automação e testes | `UserDefaults` `frila_modo_design_ativo` = `true`. Os cinco toques gravam essa mesma chave, então a escolha sobrevive ao fechar o app. |

Com o modo ligado, o gesto de abrir o painel é pressionar a tela com dois dedos por 0,6 s. O argumento `-FRILA_DEMO_ENTRADA` mostra a tela de entrada de exemplo (só com o modo ligado).

## Onde está no código

- `Sources/Apresentacao/DebugDesign/ControleModoDesign.swift`: a chave de tempo de execução (`ControleModoDesign.compartilhado`).
- `Sources/Apresentacao/DebugDesign/SeloBeta.swift`: o selo e a contagem dos cinco toques (só `FRILA_BETA`).
- `Sources/Apresentacao/DebugDesign/ModoDebugDesign.swift` e `ExemploDebugEntrada.swift`: o painel e o exemplo.
- Tudo sob `#if DEBUG || FRILA_BETA`; o selo, só sob `#if FRILA_BETA`. `FRILA_BETA` vem de `Configurations/Beta.xcconfig`.

Para registrar uma tela nova no painel, use `RegistroDebugDesign` e `RegistroDebugModifier` como o `ExemploDebugEntrada` faz. Texto novo do painel segue a regra do projeto (catálogo, `Scripts/conferir-textos.sh`).

## Limites

- Ligar ou desligar troca a árvore de views: uma tela com texto digitado pode reiniciar. Alterne antes de testar.
- Nada disto vai para a loja. Qual build mandar: `Docs/QualBuildMandarParaLoja.md`.
