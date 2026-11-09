#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Uso: $0 [commit]" >&2
  exit 1
fi

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

for tool in git docker tar; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERRORE: $tool non è installato." >&2
    exit 1
  }
done

if [[ $# -eq 0 && -n "$(git status --porcelain -- src/frontend)" ]]; then
  echo "ERRORE: salva le modifiche del frontend in Git prima della build." >&2
  exit 1
fi

REVISION="$(git rev-parse --verify "${1:-HEAD}^{commit}")"
IMAGE="kiratech-frontend:git-${REVISION:0:12}"

docker info >/dev/null

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  EXISTING_REVISION="$(docker image inspect "$IMAGE" \
    --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}')"

  if [[ "$EXISTING_REVISION" != "$REVISION" ]]; then
    echo "ERRORE: immagine esistente con etichetta revision non coerente." >&2
    exit 1
  fi
  echo "Riutilizzo immagine locale: $IMAGE"
else
  BUILD_DIR="$(mktemp -d)"
  trap 'rm -rf "$BUILD_DIR"' EXIT

  git archive "$REVISION" src/frontend | tar -x -C "$BUILD_DIR"

  docker build \
    --label "org.opencontainers.image.revision=$REVISION" \
    --tag "$IMAGE" \
    --file "$BUILD_DIR/src/frontend/Dockerfile" \
    "$BUILD_DIR/src/frontend"
fi

docker image inspect "$IMAGE" \
  --format 'IMAGE_ID={{.Id}} OS={{.Os}} ARCH={{.Architecture}}'

echo "OK: immagine disponibile: $IMAGE"
