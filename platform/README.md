# Kiratech L2 Challenge

Laboratorio Kubernetes locale basato su Online Boutique.
Autore: Francesco De Gese.

## Scelta dell'applicazione

Il progetto originale è [Google Cloud Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo).
È un negozio dimostrativo con catalogo, carrello e checkout:
pagamenti e spedizioni sono simulati.

La scelta permette di esercitare deploy, comunicazioni HTTP/gRPC,
dipendenze tra servizi, gestione di Redis e troubleshooting.
La disponibilità di codice, Dockerfile e manifest upstream consente
di concentrarsi sull'esercizio della piattaforma e su modifiche mirate.

La challenge utilizza i servizi applicativi e Redis del progetto.
Il loadgenerator è attivo in dev e disattivato in prod.
Il frontend è personalizzato e costruito localmente; gli altri servizi
utilizzano le immagini upstream indicate nei manifest.
Le integrazioni cloud opzionali non fanno parte del laboratorio.

## Documentazione

- [Avvio rapido](docs/quickstart.md): prerequisiti, setup e accesso.
- [Architettura](docs/architecture.md): componenti, scelte e limiti.
- [Incidente immagine](docs/incident-image-pull.md): guasto e rollback.
- [Ricostruzione](docs/rebuild-verification.md): nuovo cluster e problema inotify.
- [Valutazione Krateo](docs/krateo-assessment.md): proposta non implementata.
- [Utilizzo AI](docs/ai-usage.md): contributi, verifiche e limiti.
- [Workflow archiviati](upstream-workflows/README.md): motivazione dell'archiviazione.

## Avvio

Dalla radice del repository, dopo aver installato i prerequisiti:

    ./platform/scripts/setup.sh both

Per utilizzare un cluster con nome diverso:

    KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/setup.sh both

Il setup prepara le immagini indicate negli overlay, crea il cluster
se assente, carica le immagini e avvia dev e prod.
I Secret Redis già presenti vengono conservati.

## Struttura

- base/: manifest comuni e sicurezza frontend.
- overlays/dev/ e overlays/prod/: configurazioni dei due ambienti.
- scripts/: validazione, build, Secret, deploy e setup.
- docs/: documentazione e resoconti.

Frontend: [src/frontend](../src/frontend).
Pipeline: [Kiratech CI](../.github/workflows/kiratech-ci.yaml).

## Verifiche completate

- Test Go e build frontend in CI.
- Rendering Kustomize e validazione server durante il deploy.
- Deploy dev/prod e verifiche manuali di carrello, valuta e checkout.
- Log JSON, probe ed endpoint /metrics.
- Autenticazione Redis verificata nel laboratorio originale.
- Guasto immagine controllato e rollback.
- Ricostruzione su un secondo cluster con risoluzione del problema
  inotify e verifiche funzionali in entrambi gli ambienti.

La ricostruzione ha riutilizzato l'immagine frontend locale:
non è una prova su PC vuoto né una build senza cache.

## Limiti principali

- Cluster a singolo nodo; dev e prod condividono il dominio di guasto.
- Redis usa emptyDir e può perdere i carrelli alla sostituzione del pod.
- Immagini frontend caricate localmente in kind.
- Metriche per processo, senza raccolta centralizzata.
- Krateo valutato, non installato.
- La CI non esegue deploy o test end-to-end dell'intero negozio.

Consultare i documenti collegati per procedure e risultati dettagliati.
