# Integração contínua

O workflow `.github/workflows/ios.yml` roda em pull requests e pushes que mexem em `iOS/**` ou no próprio workflow, num runner `macos-26`, com permissão só de leitura e limite de 45 minutos. Um push novo cancela a execução anterior do mesmo PR ou branch.

Etapas, na ordem:

1. Seleciona o Xcode 26 mais novo do runner.
2. Instala o XcodeGen 2.45.3 do release oficial e confere o SHA-256.
3. `python3 Scripts/validate-fixtures.py`: falha se uma fixture perder campo obrigatório de `fixture-schemas.json`.
4. `xcodegen generate` e falha se o `Frila.xcodeproj` versionado divergir do `project.yml`.
5. Injeta os plists do Firebase Dev e Prod.
6. Escolhe o simulador de iPhone disponível com o iOS mais novo, sem aparelho fixo.
7. `xcodebuild test` do `Frila-Local`: testes unitários e de interface, sem backend.
8. Gera o `Secrets.xcconfig` de Dev e compila o `Frila-Dev`.
9. Gera o `Secrets.xcconfig` de Prod e compila o `Frila-Prod`.
10. Apaga `Secrets.xcconfig`, plists, DerivedData e temporários, mesmo quando uma etapa falha.

Nenhuma etapa assina código (o simulador usa a assinatura local ad-hoc) nem publica artefato. As fases de script do Xcode não exportam variáveis para o log, e o GitHub mascara os segredos.

Falha esperada hoje: a etapa 9 para em `FRILA_SUPABASE_PROD_URL is not set` enquanto o projeto `frila-prod` não existir ([Dependências externas](ExternalSetup.md), item 9). Isso é intencional: Prod sem Supabase não compila em silêncio.

Custo: o repositório é privado e cada minuto macOS consome cerca de dez vezes a cota de um minuto Linux. O orçamento de Actions da organização está em US$ 0 com bloqueio de uso adicional, então esgotar a cota interrompe a CI sem gerar cobrança.
