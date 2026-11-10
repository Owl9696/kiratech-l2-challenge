# Avvio del laboratorio Kiratech L2

## Prerequisiti

Ambiente verificato: Ubuntu su WSL2, architettura amd64.

Strumenti richiesti nel PATH:
- Bash, Git, tar, Python 3.
- Docker con daemon avviato e accessibile all'utente.
- kind.
- kubectl con supporto Kustomize.
- curl per le verifiche HTTP.

È necessaria connettività verso GitHub e i registry delle immagini.
Il setup non installa questi strumenti.

## Repository

Per una nuova copia:

```bash
git clone --branch challenge/platform \
  https://github.com/Owl9696/kiratech-l2-challenge.git
cd kiratech-l2-challenge
```

Usare un clone completo: le immagini negli overlay possono riferirsi
a revisioni precedenti del repository.

## Setup

```bash
./platform/scripts/setup.sh both
```

Sono disponibili anche:

```bash
./platform/scripts/setup.sh dev
./platform/scripts/setup.sh prod
```

Lo script:
1. Controlla i prerequisiti e genera i manifest dev/prod.
2. Legge dagli overlay i tag Git delle immagini frontend.
3. Prepara le immagini dalle revisioni indicate.
4. Crea il cluster kind se assente, oppure riutilizza quello esistente.
5. Carica le immagini frontend nei nodi.
6. Esegue il deploy degli ambienti richiesti.

Cluster: kiratech-l2.
Contesto Kubernetes: kind-kiratech-l2.
Namespace: boutique-dev e boutique-prod.

Il deploy crea il namespace e inizializza il Secret Redis se assente,
esegue la validazione server dei manifest, applica le risorse e attende
il rollout dei Deployment.

Un Secret già presente viene conservato: il setup non ruota le credenziali.
Questa verifica di esistenza non certifica che un Secret creato manualmente
contenga tutte le chiavi e i valori corretti.

## Accesso tramite Ingress

Per installare Traefik e accedere ai due ambienti attraverso gli Ingress,
seguire la [guida Ingress](../ingress/README.md).
Il controller richiede un'installazione separata da setup.sh.

## Accesso diretto al sito tramite port-forward

Aprire una finestra terminale dedicata per ogni port-forward e lasciarla aperta.

Dev:

```bash
kubectl --context kind-kiratech-l2 -n boutique-dev \
  port-forward deployment/frontend 8082:8080
```

Aprire http://localhost:8082 nel browser.

Prod:

```bash
kubectl --context kind-kiratech-l2 -n boutique-prod \
  port-forward deployment/frontend 8081:8080
```

Aprire http://localhost:8081 nel browser.

I port-forward terminano con Ctrl+C o chiudendo il terminale.
Non vengono avviati automaticamente dal setup.

## Verifiche

Da un altro terminale, con il port-forward dev attivo:

```bash
curl --fail --silent --show-error \
  -o /dev/null -w 'Homepage HTTP %{http_code}\n' \
  http://localhost:8082/

curl --fail --silent --show-error \
  http://localhost:8082/metrics
```

Per prod usare la porta 8081.

Nel browser verificare anche aggiunta al carrello, cambio valuta e checkout.
Il pagamento è simulato dall'applicazione dimostrativa.

Stato dei Deployment:

```bash
kubectl --context kind-kiratech-l2 -n boutique-dev get deployments
kubectl --context kind-kiratech-l2 -n boutique-prod get deployments
```

Dev usa una replica frontend; prod ne usa due.
Il loadgenerator è disabilitato in prod con zero repliche.

## Redis e gestione delle credenziali

Le credenziali vengono generate da platform/scripts/init-redis-secret.py
e inserite direttamente in un Secret Kubernetes nel namespace richiesto.
Lo script non le scrive in un file locale e non le stampa.

Il Secret contiene password, configurazione Redis e stringa di connessione
usata da cartservice. I manifest Git contengono i riferimenti al Secret.

Redis richiede autenticazione; le probe usano credenziali tramite ambiente.

Verifica in dev:

```bash
kubectl --context kind-kiratech-l2 -n boutique-dev \
  exec deployment/redis-cart -- \
  sh -c 'unset REDISCLI_AUTH; redis-cli ping'
```

Risposta attesa: NOAUTH Authentication required.

```bash
kubectl --context kind-kiratech-l2 -n boutique-dev \
  exec deployment/redis-cart -- redis-cli ping
```

Risposta attesa: PONG.

Per prod sostituire boutique-dev con boutique-prod.
Non includere i valori dei Secret in Git, screenshot o evidenze.

## Aggiornamenti e troubleshooting

Per riapplicare i manifest con le immagini già caricate nel cluster:

```bash
./platform/scripts/deploy.sh dev
./platform/scripts/deploy.sh prod
```

Per preparare e caricare anche le immagini referenziate dagli overlay,
usare nuovamente setup.sh.

La prova di guasto immagine e ripristino è descritta in
[incident-image-pull.md](incident-image-pull.md).

## Limiti e stato delle verifiche

- Setup verificato sul cluster esistente per entrambi gli ambienti.
- Setup verificato anche su un nuovo cluster kind, riutilizzando
  l'immagine frontend locale e correggendo un limite inotify dell'host.
  Dettagli: [verifica di ricostruzione](rebuild-verification.md).
  Non è stata eseguita una prova su un PC completamente vuoto.
- La CI controlla sintassi shell, rendering, test Go e build frontend;
  esegue setup dev/prod su un cluster kind temporaneo, installa Traefik
  e verifica homepage, health check e metriche attraverso gli Ingress.
  Il percorso completo di acquisto rimane una verifica manuale.
- Dev e prod sono namespace dello stesso cluster locale a singolo nodo.
  Il nome prod identifica l'overlay dimostrativo, non un servizio
  configurato per produzione reale.
- Redis usa emptyDir: la sostituzione del pod può perdere i carrelli.
- Le immagini frontend sono locali a Docker/kind, senza registry dedicato.
- I tag Git identificano la revisione sorgente; non garantiscono build
  identiche byte per byte, anche per la presenza di immagini base non
  tutte fissate tramite digest.
- La metrica frontend_http_requests_total è un contatore per processo:
  esclude health check e richieste a /metrics, riparte al riavvio e non
  aggrega automaticamente le repliche. Il port-forward al Deployment
  consente di osservare una singola replica.
- Non è stato configurato un sistema centralizzato di raccolta metriche.
