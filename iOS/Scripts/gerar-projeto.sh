#!/bin/bash
# Gera o Frila.xcodeproj a partir do project.yml via XcodeGen
# e restaura o Package.resolved versionado para o projeto gerado.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen não está instalado ou não está no PATH. Instale com 'brew install xcodegen'." >&2
  exit 1
fi

if [[ ! -f "$RAIZ/Package.resolved" ]]; then
  echo "error: arquivo de dependências fixadas não encontrado em $RAIZ/Package.resolved." >&2
  exit 1
fi

echo "Gerando Frila.xcodeproj com xcodegen..."
(cd "$RAIZ" && xcodegen generate)

DEST="$RAIZ/Frila.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$DEST"
cp "$RAIZ/Package.resolved" "$DEST/Package.resolved"
echo "Package.resolved restaurado em $DEST/Package.resolved."
