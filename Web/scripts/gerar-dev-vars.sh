#!/bin/bash
# Gera Web/.dev.vars (ignorado pelo git) com o endereço e a chave PUBLICÁVEL do Supabase de dev,
# sem imprimir os valores. Fonte: as variáveis FRILA_SUPABASE_DEV_URL e FRILA_SUPABASE_DEV_PUBLISHABLE_KEY
# ou, se faltarem, o iOS/Configurations/Secrets.xcconfig deste clone (o mesmo par que o iOS usa).

set -euo pipefail
umask 077

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCCONFIG="$RAIZ/../iOS/Configurations/Secrets.xcconfig"

do_xcconfig() { sed -n "s|^$1 *= *||p" "$XCCONFIG" 2>/dev/null | head -1 | sed 's|\$()||g; s|[[:space:]]*$||'; }

URL="${FRILA_SUPABASE_DEV_URL:-$(do_xcconfig FRILA_SUPABASE_DEV_URL)}"
CHAVE="${FRILA_SUPABASE_DEV_PUBLISHABLE_KEY:-$(do_xcconfig FRILA_SUPABASE_DEV_PUBLISHABLE_KEY)}"

if [[ -z "$URL" || -z "$CHAVE" ]]; then
  echo "error: faltam FRILA_SUPABASE_DEV_URL e FRILA_SUPABASE_DEV_PUBLISHABLE_KEY (variáveis ou Secrets.xcconfig do iOS)." >&2
  exit 1
fi

printf 'SUPABASE_URL=%s\nSUPABASE_CHAVE_PUBLICAVEL=%s\n' "$URL" "$CHAVE" > "$RAIZ/.dev.vars"
echo "ok: .dev.vars gerado (valores não exibidos)."
