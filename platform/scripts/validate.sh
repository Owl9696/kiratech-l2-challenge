#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

command -v kubectl >/dev/null 2>&1 || {
  echo "ERRORE: kubectl non è installato." >&2
  exit 1
}

OUTPUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUTPUT_DIR"' EXIT

for environment in dev prod; do
  echo "Validazione overlay: $environment"

  kubectl kustomize "platform/overlays/$environment" \
    > "$OUTPUT_DIR/$environment.yaml"

  if [[ ! -s "$OUTPUT_DIR/$environment.yaml" ]]; then
    echo "ERRORE: manifest vuoto per $environment." >&2
    exit 1
  fi

  echo "OK: manifest $environment generato."
done

echo "Validazione Kustomize completata per dev e prod."
