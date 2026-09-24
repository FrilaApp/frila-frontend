#!/bin/bash

set -euo pipefail

case "${FRILA_ENVIRONMENT:-}" in
  local)
    exit 0
    ;;
  frila-dev)
    FIREBASE_ENVIRONMENT="Dev"
    ;;
  frila-prod)
    FIREBASE_ENVIRONMENT="Prod"
    ;;
  *)
    echo "warning: unknown FRILA_ENVIRONMENT; Firebase configuration was not copied" >&2
    exit 0
    ;;
esac

SOURCE_PLIST="${SRCROOT}/Resources/Firebase/${FIREBASE_ENVIRONMENT}/GoogleService-Info.plist"
DESTINATION_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

if [[ ! -f "$SOURCE_PLIST" ]]; then
  if [[ "${CI:-false}" == "true" ]]; then
    echo "error: missing Firebase configuration for ${FRILA_ENVIRONMENT}; run Scripts/inject-firebase-config.sh first" >&2
    exit 1
  fi

  echo "warning: missing Firebase configuration for ${FRILA_ENVIRONMENT}; push messaging stays disabled in this local build" >&2
  exit 0
fi

mkdir -p "$DESTINATION_DIR"
cp "$SOURCE_PLIST" "$DESTINATION_DIR/GoogleService-Info.plist"
