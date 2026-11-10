# Utilizzo dell'AI nella challenge

## Strumento e modalità di collaborazione

È stato utilizzato ChatGPT per supportare analisi, scrittura di codice,
configurazioni, comandi operativi e documentazione.

Nel flusso di lavoro descritto, l'assistente non aveva accesso diretto
al terminale Ubuntu del candidato o al cluster locale.

Il candidato ha eseguito i comandi, applicato le modifiche e condiviso
output testuali e screenshot. L'assistente ha interpretato le evidenze
e proposto i passi successivi.

Il contributo dell'AI è stato sostanziale: ha incluso bozze di script,
patch Kubernetes, implementazione della metrica, test e documentazione.
Il codice generato non è stato considerato corretto soltanto perché
prodotto dall'assistente.

## Ambiti di utilizzo e verifiche

| Ambito | Supporto AI | Verifica eseguita |
| --- | --- | --- |
| Kustomize | Base, overlay e patch | Rendering e validazione server durante il deploy |
| Automazione | Script di build, deploy e setup | Controllo sintassi, esecuzione locale e CI |
| Frontend | Contatore HTTP ed endpoint /metrics | Test Go e richieste HTTP |
| Sicurezza | Patch frontend e autenticazione Redis | Ispezione pod, NOAUTH senza credenziali e PONG autenticato |
| Troubleshooting | Interpretazione eventi e proposta di rollback | Rollout, stato pod, homepage e metrica dopo il ripristino |
| Documentazione | Bozze delle guide e descrizione dei limiti | Confronto con gli output raccolti |

La CI verifica sintassi shell, rendering degli overlay, test Go e build
del frontend. Esegue inoltre setup dev/prod su kind temporaneo,
installazione di Traefik e controlli HTTP attraverso gli Ingress.
Questi controlli non sostituiscono la verifica del percorso completo
di acquisto, eseguita manualmente.

## Esempi di richieste

I prompt seguenti sono ricostruzioni sintetiche delle richieste e del
contesto condiviso durante il lavoro, non trascrizioni letterali.

### Metrica applicativa

Richiesta ricostruita:

> Aggiungere al frontend una metrica HTTP verificabile, usando il codice
> esistente e distinguendo il traffico applicativo da health check e scrape.

Risultato:
- endpoint /metrics;
- contatore frontend_http_requests_total;
- esclusione di /_healthz e /metrics;
- test automatici del comportamento del contatore.

Verifica:
- esecuzione dei test Go;
- lettura del contatore prima e dopo una richiesta alla homepage;
- verifica in dev e prod tramite port-forward.

Limite:
il contatore è locale al processo, riparte al riavvio e non aggrega
le repliche. Non è stato installato un sistema centralizzato di raccolta.

### Autenticazione Redis

Richiesta ricostruita:

> Configurare Redis e cartservice con credenziali fuori dal repository,
> mantenendo funzionanti le probe e il percorso di acquisto.

Prima della proposta sono stati esaminati Startup.cs, RedisCartStore.cs,
le variabili ambiente e le probe dei Deployment.

Risultato:
- script di inizializzazione del Secret;
- configurazione Redis autenticata;
- stringa di connessione cartservice tramite secretKeyRef;
- probe Redis autenticate;
- conservazione dei Secret già esistenti.

Verifica:
- NOAUTH con REDISCLI_AUTH rimosso;
- PONG con autenticazione;
- rollout e controlli funzionali del sito.

Limite:
non sono stati implementati rotazione delle credenziali, TLS Redis
o persistenza dei carrelli oltre la vita del pod.

### Build e avvio del laboratorio

Richiesta ricostruita:

> Rendere possibile costruire la revisione frontend indicata dagli
> overlay e preparare dev e prod con un unico comando.

Risultato:
- build da revisione Git esplicita;
- label con revisione sorgente;
- controllo della label prima del riutilizzo dell'immagine;
- setup del cluster e caricamento immagini in kind;
- inizializzazione dei Secret durante il deploy.

Verifica:
- build e test frontend in CI;
- riutilizzo controllato dell'immagine locale;
- esecuzione di setup.sh both sul cluster esistente;
- creazione di un secondo cluster e verifica funzionale dev/prod,
  dopo la risoluzione di un problema inotify dell'host.

Limite:
la prova sul nuovo cluster ha riutilizzato l'immagine frontend locale.
Non equivale a una prova su PC vuoto o a una build senza cache.
Vedere [verifica di ricostruzione](rebuild-verification.md).

## Caso operativo: immagine non disponibile

È stato introdotto deliberatamente in dev il riferimento immagine
kiratech-frontend:missing-drill-001.

Le evidenze condivise con l'assistente mostravano:
- nuovo pod in ErrImagePull e ImagePullBackOff;
- tentativo di pull da docker.io/library;
- messaggi di accesso negato e insufficient_scope;
- vecchio pod ancora pronto durante le osservazioni.

L'assistente ha supportato la lettura degli eventi e la procedura
di rollback alla revisione funzionante identificata prima della prova.

Il candidato ha eseguito il rollback e verificato:
- rollout completato;
- immagine corretta ripristinata;
- frontend pronto;
- homepage HTTP 200;
- endpoint /metrics raggiungibile.

In un incidente reale, un errore di accesso al registry richiederebbe
anche controlli su repository, tag e autorizzazioni.
In questa prova il riferimento non disponibile era stato introdotto
intenzionalmente.

Non è stata misurata continuamente la disponibilità durante la prova.
La presenza di un vecchio pod pronto non dimostra da sola zero downtime.

Dettagli: [incident-image-pull.md](incident-image-pull.md).

## Correzioni e limiti emersi durante il lavoro

### Nomi dei pod non più validi

Alcuni tentativi di describe su pod osservati in precedenza hanno
restituito NotFound dopo un rollout.

Questo risultato non dimostrava un guasto del Deployment.
È stato necessario riferirsi allo stato aggiornato delle risorse.
I nomi dei pod non devono essere trattati come identificatori permanenti.

### Port-forward non attivo

Una verifica HTTP verso localhost:8082 ha restituito connection refused
e HTTP 000. Il port-forward dev non era attivo.

Avviato il port-forward corretto in una finestra dedicata, homepage
e metriche sono risultate raggiungibili senza modifiche applicative.

Il codice HTTP 000 riportato da curl non era una risposta HTTP
dell'applicazione.

### Esito locale e prova da zero

Il successo del setup su un cluster esistente è stato distinto dalla
ricostruzione completa su un ambiente nuovo.

Analogamente, il riutilizzo di un'immagine presente non dimostra
l'esecuzione del percorso di build su immagine assente.

### Stime e conclusioni

Le percentuali di avanzamento fornite durante la collaborazione sono
stime organizzative, non misure automatiche né valutazioni ufficiali.

Il completamento viene verificato attraverso requisiti, file,
esecuzioni e risultati osservabili.

## Gestione delle informazioni

Per documentare il progetto sono sufficienti codice, configurazioni
prive di credenziali, output di stato ed errori pertinenti.

I valori dei Secret non devono essere inseriti nelle evidenze o nei prompt.
Gli script di inizializzazione non stampano le credenziali generate.

Prima della consegna è prevista una revisione dei materiali da pubblicare
per escludere credenziali e informazioni non pertinenti.

## Responsabilità e attività ancora aperte

Il candidato mantiene la responsabilità delle modifiche applicate,
della verifica dei risultati e della spiegazione delle scelte tecniche.

Restano da completare:
- eventuale verifica aggiuntiva su un host completamente nuovo;
- revisione finale dei workflow e dei requisiti della challenge;
- aggiornamento della documentazione in base alle verifiche finali.

L'assistenza AI non sostituisce questi controlli.

## Estensione della CI con deploy automatico

Il 10 novembre 2026 l'assistente ha supportato l'estensione del workflow:
checkout con cronologia completa, installazione di kind e Helm con verifica
checksum, setup dev/prod, installazione Traefik, controlli HTTP e pulizia.

Il candidato ha applicato le modifiche e verificato l'esito su GitHub Actions.
Il run [42829585201](https://github.com/Owl9696/kiratech-l2-challenge/actions/runs/42829585201),
relativo al commit 4ba85d39, si è concluso con successo in 3 minuti e 13 secondi.
Sono riusciti deploy, installazione del controller, verifiche HTTP e pulizia.
Il passo diagnostico è stato saltato perché non si sono verificati errori:
il suo percorso di esecuzione non è quindi stato verificato da questo run.

Un precedente suggerimento AI per Traefik usava service.type, non accettato
dal chart 42.3.1. Il rendering Helm ha bloccato l'installazione.
La lettura dei valori della versione esatta ha permesso di correggere
il campo in service.spec.type; installazione e accesso sono stati poi verificati.

Il valore dell'assistenza è stato accelerare la preparazione del workflow
e la diagnosi. La correttezza è stata verificata attraverso gli strumenti
e gli esiti osservati, senza considerare affidabile il solo suggerimento AI.
