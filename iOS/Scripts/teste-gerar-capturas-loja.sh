#!/usr/bin/env bash
# teste-gerar-capturas-loja.sh
# Autoteste do script gerar-capturas-loja.sh (Cartão 33 - uwBBwwoV).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/gerar-capturas-loja.sh"
TMPDIR_TESTE="$(mktemp -d "${TMPDIR:-/tmp}/frila-teste-capturas-loja.XXXXXX")"

trap 'rm -rf "$TMPDIR_TESTE"' EXIT

[[ -x "$SCRIPT" ]] || {
  echo "FALHA: gerar-capturas-loja.sh não encontrado ou não executável: $SCRIPT" >&2
  exit 1
}

# 1. Opção --ajuda funciona
if ! "$SCRIPT" --ajuda >/dev/null 2>&1; then
  echo "FALHA: --ajuda deveria retornar código 0" >&2
  exit 1
fi

# 2. Pasta vazia em --validar-apenas deve falhar
if "$SCRIPT" --destino "$TMPDIR_TESTE" --validar-apenas >/dev/null 2>&1; then
  echo "FALHA: validar pasta vazia deveria retornar erro" >&2
  exit 1
fi

# 3. Cria imagem de teste com dimensão inválida (ex: 400x400)
python3 -c "
import Quartz, CoreFoundation
cs = Quartz.CGColorSpaceCreateDeviceRGB()
ctx = Quartz.CGBitmapContextCreate(None, 400, 400, 8, 400 * 4, cs, Quartz.kCGImageAlphaPremultipliedLast)
Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0)
Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(0, 0, 400, 400))
img = Quartz.CGBitmapContextCreateImage(ctx)
url = CoreFoundation.CFURLCreateFromFileSystemRepresentation(None, b'$TMPDIR_TESTE/dimensao_errada.png', len(b'$TMPDIR_TESTE/dimensao_errada.png'), False)
dest = Quartz.CGImageDestinationCreateWithURL(url, 'public.png', 1, None)
Quartz.CGImageDestinationAddImage(dest, img, None)
Quartz.CGImageDestinationFinalize(dest)
" 2>/dev/null || {
  # Fallback caso python Quartz não esteja no path atual
  sips -s format png -z 400 400 /tmp/test_17promax.png --out "$TMPDIR_TESTE/dimensao_errada.png" >/dev/null 2>&1 || true
}

if [[ -f "$TMPDIR_TESTE/dimensao_errada.png" ]]; then
  if "$SCRIPT" --destino "$TMPDIR_TESTE" --validar-apenas >/dev/null 2>&1; then
    echo "FALHA: imagem com dimensões 400x400 deveria ter sido reprovada pelo sips" >&2
    exit 1
  fi
  rm -f "$TMPDIR_TESTE/dimensao_errada.png"
fi

# 4. Testa validação de imagem com dimensões corretas (1320x2868)
if [[ -f "/tmp/01_feed_vagas.png" ]]; then
  cp "/tmp/01_feed_vagas.png" "$TMPDIR_TESTE/01_valida.png"
  if ! "$SCRIPT" --destino "$TMPDIR_TESTE" --validar-apenas >/dev/null 2>&1; then
    echo "FALHA: imagem válida de demonstração deveria ter sido aprovada" >&2
    exit 1
  fi
fi

echo "OK: autoteste de gerar-capturas-loja.sh passou"
