# Integração contínua

O workflow `.github/workflows/ios.yml` roda em pull requests e pushes que mexem em `iOS/**` ou no próprio workflow, num runner `macos-26`, com permissão só de leitura e limite de 45 minutos. Um push novo cancela a execução anterior do mesmo PR ou branch.

Etapas, na ordem:

1. Seleciona o Xcode 26 mais novo do runner.
2. Instala o XcodeGen 2.45.3 do release oficial e confere o SHA-256.
3. `Scripts/contrato-em-dia.sh`: o espelho `Contrato/openapi.yaml` bate com a soma gravada; com o secret `FRILA_DOCS_TOKEN`, também com o frila-docs.
4. `python3 Scripts/validate-fixtures.py`: cada fixture contra o schema do contrato, com tipos, formatos, enums e campos fora do contrato.
5. Falha se algum arquivo fora de `Sources/Dados` importar o Supabase.
6. `xcodegen generate` e falha se o `Frila.xcodeproj` versionado divergir do `project.yml`.
7. Injeta os plists do Firebase Dev e Prod.
8. Escolhe o simulador de iPhone disponível com o iOS mais novo, sem aparelho fixo.
9. `xcodebuild test` do `Frila-Local`: testes unitários, de contrato e de interface, sem backend.
10. Gera o `Secrets.xcconfig` de Dev e compila o `Frila-Dev`.
11. Gera o `Secrets.xcconfig` de Prod e compila o `Frila-Prod`.
12. Apaga `Secrets.xcconfig`, plists, DerivedData e temporários, mesmo quando uma etapa falha.

Nenhuma etapa assina código (o simulador usa a assinatura local ad-hoc) nem publica artefato. As fases de script do Xcode não exportam variáveis para o log, e o GitHub mascara os segredos.

Falha esperada hoje: a etapa 11 para em `FRILA_SUPABASE_PROD_URL is not set` enquanto o projeto `frila-prod` não existir ([Dependências externas](ExternalSetup.md), item 9). Isso é intencional: Prod sem Supabase não compila em silêncio.

Custo: o repositório é privado e cada minuto macOS consome cerca de dez vezes a cota de um minuto Linux. O orçamento de Actions da organização está em US$ 0 com bloqueio de uso adicional, então esgotar a cota interrompe a CI sem gerar cobrança.
