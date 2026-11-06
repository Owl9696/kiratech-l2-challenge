#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

for tool in git docker; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERRORE: $tool non è installato." >&2
    exit 1
  }
done

# Evita di attribuire a un commit modifiche del frontend non salvate.
if [[ -n "$(git status --porcelain -- src/frontend)" ]]; then
  echo "ERRORE: salva in Git le modifiche del frontend prima della build." >&2
  exit 1
fi

REVISION="$(git rev-parse HEAD)"
IMAGE="kiratech-frontend:git-${REVISION:0:12}"

docker info >/dev/null

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Immagine già presente: $IMAGE"
  echo "Riutilizzo la build locale esistente."
else
  docker build \
    --label "org.opencontainers.image.revision=$REVISION" \
    --tag "$IMAGE" \
    --file src/frontend/Dockerfile \
    src/frontend
fi

docker image inspect "$IMAGE" \
  --format 'IMAGE_ID={{.Id}} OS={{.Os}} ARCH={{.Architecture}}'

echo "OK: immagine disponibile: $IMAGE"
