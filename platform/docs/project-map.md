# Mappa del progetto — Kiratech L2 Challenge

Il laboratorio distribuisce Online Boutique su Kubernetes locale con kind.
Il frontend è personalizzato; gli altri servizi usano immagini upstream.
Dev e prod sono ambienti dimostrativi separati tramite namespace.

## 1. Dal repository al deploy

```mermaid
flowchart TD
    R["Repository GitHub"] --> SRC["Sorgenti frontend e Dockerfile"]
    R --> K["Base Kustomize e overlay dev/prod"]
    SRC --> B["Build da revisione Git"]
    B --> IMG["Immagine frontend con tag Git e label revisione"]
    IMG --> SETUP["setup.sh: prepara kind e carica le immagini"]
    K --> SETUP
    SETUP --> DEP["deploy.sh"]
    DEP --> SEC["Crea il Secret Redis se assente"]
    SEC --> APPLY["Validazione server, apply e attesa rollout"]
    APPLY --> DEV["Namespace boutique-dev"]
    APPLY --> PROD["Namespace boutique-prod"]
```

- `validate.sh` verifica il rendering degli overlay.
- `build-frontend.sh` costruisce la revisione richiesta o riutilizza
  un'immagine locale dopo il controllo della label di revisione.
- `setup.sh` crea o riutilizza il cluster e prepara gli ambienti richiesti.
- `deploy.sh` applica i manifest e attende i Deployment.
- Traefik richiede un'installazione Helm separata dal setup locale.
- Il tag Git permette di risalire ai sorgenti; non garantisce build
  identiche byte per byte.

## 2. Accesso e separazione degli ambienti

```mermaid
flowchart TD
    U["Browser o curl"] --> PF["Port-forward locale sulla porta 8085"]
    PF --> T["Traefik nel namespace ingress-system"]

    subgraph DEV["Namespace boutique-dev"]
        ID["Ingress boutique-dev.localhost"] --> SD["Service frontend:80"]
        SD --> FD["Frontend: 1 replica, porta 8080"]
        FD --> MD["Microservizi dev"]
        CD["Cart Service dev"] --> RD["Redis dev"]
        MD --> CD
        LD["Loadgenerator attivo"] --> FD
    end

    subgraph PROD["Namespace boutique-prod"]
        IP["Ingress boutique-prod.localhost"] --> SP["Service frontend:80"]
        SP --> FP["Frontend: 2 repliche, porta 8080"]
        FP --> MP["Microservizi prod"]
        CP["Cart Service prod"] --> RP["Redis prod"]
        MP --> CP
    end

    T --> ID
    T --> IP
```

Il diagramma rappresenta i collegamenti logici: Traefik può raggiungere
direttamente gli endpoint dei pod associati al Service.

Il frontend riceve HTTP e comunica con i servizi applicativi tramite gRPC.
Catalogo, valuta, raccomandazioni, pubblicità, carrello e checkout sono
distribuiti fra i microservizi. Il checkout coordina anche pagamento,
spedizione ed email. Pagamenti e spedizioni sono simulati.

Ogni ambiente possiede i propri servizi e Redis.
Il loadgenerator è disattivato in prod.

Il controller Traefik è stato installato nel cluster di ricostruzione
`kiratech-l2-rebuild`. Il cluster originale `kiratech-l2` è indipendente:
non esiste failover automatico fra i due.

## 3. Pipeline GitHub Actions

```mermaid
flowchart TD
    PUSH["Push o pull request previsti dal workflow"] --> CHECK["Sintassi shell e rendering Kustomize"]
    CHECK --> BUILD["Test Go e build frontend del commit corrente"]
    BUILD --> TOOLS["Preparazione kind, Helm e limiti inotify"]
    TOOLS --> SETUP["setup.sh both sul runner GitHub"]
    SETUP --> CL["Cluster temporaneo con dev e prod"]
    CL --> HELM["Installazione Traefik"]
    HELM --> HTTP["Verifiche HTTP tramite Ingress"]
    HTTP --> OK["Homepage, health e metriche"]
    HTTP --> FAIL["Diagnostica in caso di errore"]
    OK --> CLEAN["Cleanup del cluster temporaneo"]
    FAIL --> CLEAN
```

Il setup distribuisce le revisioni frontend indicate negli overlay:
possono differire dal commit corrente sottoposto ai test iniziali.

Le verifiche controllano HTTP 200 su `/`, `/_healthz` e `/metrics`
nei due ambienti e la presenza di `frontend_http_requests_total`.
Il percorso completo di acquisto è stato verificato manualmente.

La CI usa un cluster temporaneo sul runner: non aggiorna il laboratorio
locale e non mantiene un ambiente pubblico dopo l'esecuzione.
Il workflow prevede il cleanup anche in caso di errore.

## 4. Configurazione, sicurezza e osservabilità

| Area | Implementazione | Limite |
| --- | --- | --- |
| Configurazione | Overlay dev/prod e ConfigMap del loadgenerator | Separazione logica sullo stesso nodo |
| Credenziali | Secret Redis generati fuori dal repository e conservati se già presenti | Rotazione non implementata |
| Frontend | Utente non-root, filesystem root in sola lettura, capability rimosse, seccomp e token SA non montato | Non costituisce un audit completo di sicurezza |
| Risorse | Requests e limits nei manifest | Nessun autoscaling configurato |
| Probe | Readiness e liveness | La salute del frontend non dimostra il funzionamento dell'intero checkout |
| Log | Log JSON del frontend con informazioni sulle richieste | Nessuna raccolta centralizzata |
| Metriche | Contatore frontend_http_requests_total esposto su /metrics | Per processo, si azzera al riavvio e non aggrega le repliche |
| Redis | Autenticazione e volume emptyDir | Nessuna persistenza, replica o strategia di backup |

## 5. Aggiornamento e troubleshooting

```mermaid
flowchart TD
    V1["Dev: Release v1"] --> TAG["Overlay aggiornato alla revisione v2"]
    TAG --> SETUP["Build, caricamento immagine e deploy"]
    SETUP --> V2["Release v2 verificata tramite HTTP"]
    V2 --> BACK["Overlay ripristinato alla revisione v1"]
    BACK --> RESTORE["Deploy e verifica del footer Release v1"]
```

La prova v1 → v2 → v1 è documentata in
[aggiornamento e rollback](update-rollback.md).
Non è stata misurata continuamente la disponibilità durante il rollout.

Sono inoltre documentati:

- [Errore di pull dell'immagine e rollback](incident-image-pull.md).
- [Ricostruzione e problema dei limiti inotify](rebuild-verification.md).

## 6. Krateo e utilizzo AI

Krateo è stato valutato come possibile evoluzione della gestione della
piattaforma, tramite una proposta basata su chart Helm e Composition.
Non è stato installato né verificato con una prova pratica.

- [Valutazione tecnica Krateo](krateo-assessment.md).
- [Utilizzo AI, verifiche e correzioni](ai-usage.md).

L'AI ha supportato codice, configurazioni, documentazione e analisi.
Le evidenze delle esecuzioni e i controlli effettuati sono descritti
nei resoconti; le proposte non eseguite sono distinte dai risultati osservati.

## 7. Confini del laboratorio

- Ogni cluster kind ha un solo nodo.
- Dev e prod condividono il dominio di guasto del nodo.
- Due repliche frontend prod non proteggono dal guasto del nodo.
- I due cluster locali non formano una soluzione ad alta disponibilità.
- L'accesso tramite Traefik è locale, HTTP senza TLS, con port-forward.
- Le immagini frontend vengono caricate in kind senza un registry dedicato.
- Il nome prod identifica un overlay dimostrativo.

## Documentazione operativa

- [Avvio rapido](quickstart.md).
- [Architettura](architecture.md).
- [Installazione e accesso tramite Traefik](../ingress/README.md).
- [Sequenza della demo](demo.md).
