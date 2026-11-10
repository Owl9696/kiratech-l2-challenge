# Demo tecnica della challenge

## Obiettivo e ambiente

Mostrare architettura, installazione, funzionamento, osservabilità,
sicurezza, aggiornamento e troubleshooting di Online Boutique.

Ambiente della demo: cluster kiratech-l2-rebuild.
Namespace: boutique-dev e boutique-prod.
Gli ambienti condividono un singolo nodo: prod è una simulazione.

Le prove dei singoli componenti sono documentate.
Questa sequenza completa deve essere provata prima della presentazione.

## 1. Repository e architettura

Per un nuovo clone:

    git clone --branch challenge/platform https://github.com/Owl9696/kiratech-l2-challenge.git
    cd kiratech-l2-challenge

Se il repository è già presente, usare la copia esistente.

Mostrare:
- platform/README.md: indice e motivazione della scelta.
- platform/docs/architecture.md: componenti e flussi.
- platform/base e platform/overlays: configurazione comune e ambienti.
- platform/scripts: build, validazione, setup e deploy.
- .github/workflows/kiratech-ci.yaml: automazione.

Spiegare che il browser usa HTTP verso il frontend; i servizi applicativi
comunicano principalmente tramite gRPC; cartservice usa Redis.
Pagamento e spedizione sono simulati.

## 2. Build e installazione

Verificare i prerequisiti descritti nel quickstart.
Costruire esplicitamente la versione attualmente distribuita:

    ./platform/scripts/build-frontend.sh b13f4246ae3d

Se l'immagine esiste già con la label attesa, lo script la riutilizza:
non presentare questo risultato come una build senza cache.

Preparare entrambi gli ambienti:

    KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/setup.sh both

Il setup crea il cluster se assente, carica le immagini e applica
gli overlay. Conserva i Secret Redis già presenti.

Installare Traefik seguendo ../ingress/README.md.
Questo passaggio è separato dal setup applicativo.

Mostrare anche un run CI riuscito: la pipeline crea un cluster temporaneo
sul runner GitHub, esegue deploy dev/prod, installa Traefik, verifica
homepage, health check e metriche e infine elimina il cluster.

I test Go riguardano il sorgente corrente; il deploy usa le revisioni
indicate negli overlay. La CI non esegue l'intero percorso di acquisto.

## 3. Stato delle risorse

    kubectl --context kind-kiratech-l2-rebuild get nodes
    kubectl --context kind-kiratech-l2-rebuild -n boutique-dev get deployments,pods,services,ingresses,configmaps
    kubectl --context kind-kiratech-l2-rebuild -n boutique-prod get deployments,pods,services,ingresses,configmaps

Risultati attesi:
- frontend dev: una replica disponibile;
- frontend prod: due repliche disponibili;
- loadgenerator dev: una replica; prod: zero;
- Ingress con classe traefik e host distinti;
- ConfigMap loadgenerator-config con suffisso generato.

Il loadgenerator legge USERS e RATE dalla ConfigMap.
Il suffisso generato da Kustomize cambia quando cambia il contenuto.

## 4. Accesso e percorso applicativo

In un terminale dedicato, mantenere attivo:

    kubectl --context kind-kiratech-l2-rebuild -n ingress-system port-forward service/traefik 8085:80

Da un secondo terminale:

    curl --fail --noproxy '*' --resolve boutique-dev.localhost:8085:127.0.0.1 http://boutique-dev.localhost:8085/
    curl --fail --noproxy '*' --resolve boutique-prod.localhost:8085:127.0.0.1 http://boutique-prod.localhost:8085/

Le richieste attraversano Traefik e le regole Ingress.
Nel browser provare:
- http://boutique-dev.localhost:8085/
- http://boutique-prod.localhost:8085/

Se il browser non risolve questi nomi, usare il percorso di accesso
diretto descritto nel quickstart per la dimostrazione grafica,
mantenendo separata la verifica Ingress tramite curl.

Per ciascun ambiente:
1. Aprire il catalogo e un prodotto.
2. Impostare EUR.
3. Aggiungere un prodotto al carrello.
4. Eseguire il checkout con dati fittizi del negozio dimostrativo.
5. Mostrare la conferma dell'ordine.

## 5. Osservabilità

    kubectl --context kind-kiratech-l2-rebuild -n boutique-dev logs deployment/frontend --tail=30

Mostrare nei log JSON metodo, percorso, stato HTTP e durata.

    curl --fail --noproxy '*' --resolve boutique-dev.localhost:8085:127.0.0.1 http://boutique-dev.localhost:8085/_healthz
    curl --fail --noproxy '*' --resolve boutique-dev.localhost:8085:127.0.0.1 http://boutique-dev.localhost:8085/metrics

Mostrare le probe configurate:

    kubectl --context kind-kiratech-l2-rebuild -n boutique-dev get deployment frontend -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}{"\n"}{.spec.template.spec.containers[0].readinessProbe}{"\n"}'

La metrica frontend_http_requests_total conta richieste completate
dal singolo processo, escludendo health check e metriche.
Si azzera al riavvio e non aggrega le repliche.
Non è presente una raccolta centralizzata Prometheus/Grafana.

## 6. Sicurezza

Mostrare i manifest frontend-security.yaml, redis-auth.yaml
e cartservice-redis-auth.yaml, senza stampare i valori dei Secret.

    kubectl --context kind-kiratech-l2-rebuild -n boutique-dev get secret redis-auth
    kubectl --context kind-kiratech-l2-rebuild -n boutique-dev get serviceaccount frontend

Spiegare:
- frontend non-root, privilegi ridotti e token del service account non montato;
- credenziali Redis generate fuori dal repository;
- Secret preservati durante i deploy successivi;
- nessuna rotazione automatica delle credenziali.

Le prove NOAUTH senza credenziali e PONG autenticato sono state eseguite
nel laboratorio originale. Non mostrare password durante la demo.

## 7. Aggiornamento e rollback

Seguire il resoconto update-rollback.md:
- v1: kiratech-frontend:git-b13f4246ae3d;
- v2: kiratech-frontend:git-197a0f9c572c.

Per ripetere la prova, modificare solo il newTag dell'immagine frontend
nell'overlay dev, impostando git-197a0f9c572c, quindi eseguire:

    KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/setup.sh dev

Verificare il rollout e il footer:

    kubectl --context kind-kiratech-l2-rebuild -n boutique-dev rollout status deployment/frontend --timeout=300s
    curl --fail --silent --show-error --noproxy '*' --resolve boutique-dev.localhost:8085:127.0.0.1 http://boutique-dev.localhost:8085/ | grep -F 'Release v2'

Ripristinare newTag: git-b13f4246ae3d nello stesso overlay e ripetere:

    KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/setup.sh dev

Verificare che la homepage mostri Release v1 e controllare git diff.
Non lasciare modifiche involontarie dopo la dimostrazione.

Questo è un rollback dichiarativo del riferimento all'immagine.
La prova non dimostra zero downtime.
Il resoconto descrive anche i pod uscenti osservati in stato Error,
la cui causa di terminazione non è stata determinata.

## 8. Failure scenario e troubleshooting

Usare incident-image-pull.md per la procedura del guasto controllato
e il rollback già verificati. Limitare la prova all'ambiente dev
e adattare esplicitamente il contesto al cluster scelto.

Mostrare il metodo diagnostico:
1. Stato del rollout e dei pod.
2. Eventi e motivo dell'errore.
3. Immagine richiesta e disponibilità nel nodo o registry.
4. Ripristino della versione funzionante.
5. Verifica applicativa dopo il recupero.

Come secondo caso, presentare rebuild-verification.md:
- DNS e Service non raggiungibili;
- IP diretto del pod frontend raggiungibile;
- kube-proxy in CrashLoopBackOff con "too many open files";
- modifica dei limiti inotify e successivo ripristino.

Distinguere sempre sintomi, ipotesi ed evidenze.

## 9. Krateo e utilizzo AI

Presentare krateo-assessment.md:
- proposta di servizio self-service;
- percorso Helm e CompositionDefinition;
- parametri esposti, prerequisiti, benefici e limiti;
- integrazione progettata, non installata.

Presentare ai-usage.md con un caso concreto:
- input: errore di schema del chart Traefik;
- proposta iniziale AI non valida: service.type;
- verifica con helm template e valori del chart fissato;
- correzione: service.spec.type;
- installazione e richieste HTTP riuscite.

Il candidato mantiene la responsabilità delle scelte e delle verifiche.

## 10. Limiti da dichiarare

- Cluster a singolo nodo e ambienti nello stesso dominio di guasto.
- Redis su emptyDir: nessuna garanzia di persistenza dei carrelli.
- Accesso locale HTTP senza TLS.
- Nessuna raccolta centralizzata di log e metriche.
- Nessuna garanzia di build identiche byte per byte.
- Test HTTP automatizzati distinti dal percorso di acquisto manuale.
- Krateo valutato, non implementato.

Prima del colloquio provare la sequenza completa e verificare la CI
del commit che sarà effettivamente consegnato.
