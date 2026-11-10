# Ingress locale con Traefik

Il laboratorio usa Traefik con Ingress standard Kubernetes.
La versione del chart è fissata in chart-version.txt;
la configurazione è contenuta in traefik-values.yaml.

Prerequisiti: Helm (verificato con v3.20.0), kubectl e cluster
creato con gli script della piattaforma.

## Installazione del controller

Eseguire dalla radice del repository:

    helm repo add traefik https://traefik.github.io/charts
    helm repo update traefik

    helm upgrade --install traefik traefik/traefik \
      --version "$(cat platform/ingress/chart-version.txt)" \
      --kube-context kind-kiratech-l2-rebuild \
      --namespace ingress-system \
      --create-namespace \
      --values platform/ingress/traefik-values.yaml \
      --skip-crds \
      --wait --timeout 5m

Per il cluster originale usare il contesto kind-kiratech-l2.
L'installazione del controller è separata da setup.sh.

## Deploy delle regole Ingress

deploy.sh accetta un solo ambiente; eseguire i due comandi:

    KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/deploy.sh dev
    KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/deploy.sh prod

Le regole sono incluse negli overlay e usano ingressClassName: traefik.
Ogni regola inoltra al Service frontend:80 del proprio namespace.

## Accesso locale

Lasciare aperto un terminale con:

    kubectl --context kind-kiratech-l2-rebuild \
      -n ingress-system port-forward service/traefik 8085:80

Da un altro terminale:

    curl --fail --noproxy '*' \
      --resolve boutique-dev.localhost:8085:127.0.0.1 \
      http://boutique-dev.localhost:8085/

    curl --fail --noproxy '*' \
      --resolve boutique-prod.localhost:8085:127.0.0.1 \
      http://boutique-prod.localhost:8085/

Il port-forward raggiunge Traefik; il controller applica la regola
Ingress in base all'host e inoltra al backend dell'ambiente scelto.

## Verifiche e troubleshooting

    kubectl --context kind-kiratech-l2-rebuild \
      -n ingress-system get pods,services
    kubectl --context kind-kiratech-l2-rebuild get ingressclass
    kubectl --context kind-kiratech-l2-rebuild get ingress -A
    kubectl --context kind-kiratech-l2-rebuild \
      -n ingress-system logs deployment/traefik --tail=80

Se la connessione locale viene rifiutata, controllare il port-forward.
Per una risposta 404 controllare host e ingressClassName.
Per errori del backend controllare Service, EndpointSlice e pod.

## Esito verificato e limiti

Il 10 novembre 2026, sul cluster kiratech-l2-rebuild:
- chart 42.3.1, immagine Traefik v3.7.17;
- controller disponibile e Ingress dev/prod creati;
- homepage dev e prod raggiunte attraverso Traefik con HTTP 200.

Accesso locale HTTP senza TLS, tramite Service ClusterIP e port-forward.
Non è un'esposizione pubblica e non richiede un LoadBalancer esterno.
Il campo ADDRESS degli Ingress può rimanere vuoto: la pubblicazione
dell'indirizzo è disabilitata nella configurazione del controller.
Il controller non è ancora stato installato sul cluster originale.
