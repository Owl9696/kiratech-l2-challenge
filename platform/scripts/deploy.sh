#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 dev|prod" >&2
  exit 1
fi

case "$1" in
  dev|prod) ENVIRONMENT="$1" ;;
  *)
    echo "ERRORE: scegli dev oppure prod." >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CONTEXT="kind-kiratech-l2"
NAMESPACE="boutique-$ENVIRONMENT"
OVERLAY="platform/overlays/$ENVIRONMENT"

./platform/scripts/validate.sh

echo "Verifica accesso al cluster: $CONTEXT"
kubectl --context "$CONTEXT" get nodes

# Il namespace deve esistere prima della validazione server delle risorse.
kubectl --context "$CONTEXT" apply -f "$OVERLAY/namespace.yaml"

# Crea il Secret solo se assente, preservando le credenziali esistenti.
python3 platform/scripts/init-redis-secret.py "$ENVIRONMENT"

echo "Validazione server: $ENVIRONMENT"
kubectl --context "$CONTEXT" apply --dry-run=server -k "$OVERLAY"

echo "Applicazione ambiente: $ENVIRONMENT"
kubectl --context "$CONTEXT" apply -k "$OVERLAY"

echo "Attesa completamento dei Deployment..."
kubectl --context "$CONTEXT" -n "$NAMESPACE" \
  rollout status deployment -l "environment=$ENVIRONMENT" --timeout=300s

kubectl --context "$CONTEXT" -n "$NAMESPACE" get deployments
kubectl --context "$CONTEXT" -n "$NAMESPACE" get pods

echo "OK: deploy $ENVIRONMENT completato."
