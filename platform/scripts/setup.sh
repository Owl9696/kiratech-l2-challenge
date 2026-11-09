#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Uso: $0 [dev|prod|both]" >&2
  exit 1
fi

case "${1:-both}" in
  dev) ENVIRONMENTS=(dev) ;;
  prod) ENVIRONMENTS=(prod) ;;
  both) ENVIRONMENTS=(dev prod) ;;
  *)
    echo "Uso: $0 [dev|prod|both]" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

export KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kiratech-l2}"
if [[ ! "$KIND_CLUSTER_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERRORE: nome cluster non valido." >&2
  exit 1
fi
CLUSTER="$KIND_CLUSTER_NAME"
CONTEXT="kind-$CLUSTER"
NODE_IMAGE="kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0"

for tool in git docker kind kubectl python3 tar; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERRORE: $tool non è installato." >&2
    exit 1
  }
done

docker info >/dev/null
./platform/scripts/validate.sh

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Legge il riferimento effettivo dai manifest generati.
for environment in "${ENVIRONMENTS[@]}"; do
  kubectl kustomize "platform/overlays/$environment" \
    > "$WORK_DIR/$environment.yaml"

  python3 - "$WORK_DIR/$environment.yaml" <<'PY' >> "$WORK_DIR/images.txt"
import re
import sys
from pathlib import Path

manifest = Path(sys.argv[1]).read_text()
images = set()

for line in manifest.splitlines():
    match = re.fullmatch(r"\s*image:\s*(.*?)\s*", line)
    if match:
        value = match.group(1).strip("'\"")
        if value.startswith("kiratech-frontend:"):
            images.add(value)

if len(images) != 1:
    sys.exit("ERRORE: attesa una sola immagine kiratech-frontend nell'overlay.")

image = images.pop()
if not re.fullmatch(r"kiratech-frontend:git-[0-9a-f]{12}", image):
    sys.exit("ERRORE: il frontend deve usare un tag git con 12 caratteri esadecimali.")

print(image)
PY
done

# Prepara ogni immagine una sola volta e verifica la revisione Git.
mapfile -t IMAGES < <(python3 - "$WORK_DIR/images.txt" <<'PY'
import sys
from pathlib import Path

for image in sorted(set(Path(sys.argv[1]).read_text().splitlines())):
    print(image)
PY
)

for image in "${IMAGES[@]}"; do
  revision="${image#kiratech-frontend:git-}"
  echo "Preparazione immagine: $image"
  ./platform/scripts/build-frontend.sh "$revision"
done

CLUSTERS="$(kind get clusters)"
CLUSTER_EXISTS=false

while IFS= read -r existing; do
  if [[ "$existing" == "$CLUSTER" ]]; then
    CLUSTER_EXISTS=true
  fi
done <<< "$CLUSTERS"

if [[ "$CLUSTER_EXISTS" == true ]]; then
  echo "Riutilizzo cluster: $CLUSTER"
else
  echo "Creazione cluster: $CLUSTER"
  kind create cluster \
    --name "$CLUSTER" \
    --image "$NODE_IMAGE" \
    --wait 5m
fi

kubectl --context "$CONTEXT" get nodes
kubectl --context "$CONTEXT" wait \
  --for=condition=Ready nodes --all --timeout=300s

for image in "${IMAGES[@]}"; do
  kind load docker-image "$image" --name "$CLUSTER"
done

for environment in "${ENVIRONMENTS[@]}"; do
  ./platform/scripts/deploy.sh "$environment"
done

echo "OK: setup completato per ${ENVIRONMENTS[*]}."
