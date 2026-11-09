# Verifica di ricostruzione e troubleshooting della rete

Data: 9 novembre 2026.

## Ambito della prova

È stato creato un secondo cluster kind, kiratech-l2-rebuild,
mantenendo disponibile il laboratorio originale kiratech-l2.

Gli script setup.sh, deploy.sh e init-redis-secret.py utilizzano
KIND_CLUSTER_NAME per selezionare il cluster.
Il valore predefinito rimane kiratech-l2.

Comando utilizzato:

```bash
KIND_CLUSTER_NAME=kiratech-l2-rebuild ./platform/scripts/setup.sh both
```

Il cluster era inizialmente assente.
L'immagine frontend kiratech-frontend:git-b13f4246ae3d era già disponibile
nel Docker dell'host ed è stata riutilizzata e caricata nel nuovo nodo.

La prova dimostra la creazione di un nuovo cluster e delle risorse
applicative, con ripristino dopo un problema dell'host.
Non è una prova su un PC vuoto né una build senza cache.

## Problema osservato

Il primo setup si è fermato durante il rollout dev.
Il loadgenerator era bloccato nell'init container frontend-check.

Evidenze raccolte:
- wget verso frontend:80: bad address;
- nslookup frontend: timeout;
- Service frontend ed EndpointSlice presenti;
- richiesta diretta all'IP del pod frontend: HTTP 200;
- richiesta all'IP del Service frontend: timeout;
- kube-proxy in CrashLoopBackOff;
- entrambe le repliche CoreDNS non pronte;
- log kube-proxy: failed complete: too many open files.

L'init container mostrava anche un difetto di gestione dell'errore:
il codice HTTP vuoto veniva confrontato numericamente senza virgolette,
producendo unknown operand. Questo messaggio non era la causa
del guasto della rete.

## Diagnosi e intervento

Il confronto fra IP del pod e IP del Service ha indirizzato la diagnosi
verso il percorso dei Service e kube-proxy.

La documentazione kind segnala l'esaurimento delle risorse inotify
come possibile causa di too many open files.

Valori iniziali sull'host Ubuntu/WSL:
- fs.inotify.max_user_watches = 524288;
- fs.inotify.max_user_instances = 128.

Il limite delle istanze è stato aumentato temporaneamente a 512.
Il limite dei watch è rimasto invariato.

Dopo l'intervento:
1. È stato riavviato il DaemonSet kube-proxy nel cluster di prova.
2. Il rollout di kube-proxy è riuscito.
3. CoreDNS riportava ancora il superamento della progress deadline.
4. È stato richiesto il riavvio del Deployment CoreDNS.
5. Il setup è stato rieseguito e ha completato dev e prod.

Il recupero dopo l'aumento del limite è coerente con l'esaurimento
delle istanze inotify. Non è stata misurata direttamente l'occupazione
delle istanze al momento del guasto.

La modifica sysctl è stata applicata a runtime nell'host WSL,
non resa persistente in un file di configurazione.
Dopo un riavvio occorre ricontrollare i valori, soprattutto quando
si eseguono più cluster contemporaneamente.

## Risultati finali

- Cluster kiratech-l2-rebuild: nodo Ready.
- Dev: tutti i Deployment disponibili, frontend 1/1, loadgenerator 1/1.
- Prod: tutti i Deployment attivi disponibili, frontend 2/2.
- Loadgenerator prod: intenzionalmente a zero repliche.
- Secret Redis creati nei namespace del nuovo cluster.
- Alla seconda esecuzione il Secret dev esistente è stato conservato.
- Setup terminato con: OK: setup completato per dev prod.

Sono stati aperti port-forward sul contesto kind-kiratech-l2-rebuild:
- dev: localhost:8083;
- prod: localhost:8084.

Verifiche HTTP:
- dev: homepage HTTP 200, frontend_http_requests_total pari a 844;
- prod: homepage HTTP 200, frontend_http_requests_total pari a 26.

I contatori rappresentano valori osservati su singoli processi,
non soglie di accettazione o totali aggregati dell'ambiente.

Il candidato ha inoltre eseguito e confermato in entrambi gli ambienti
le prove manuali di carrello, cambio valuta e checkout.

## Miglioramenti individuati

- Controllare la disponibilità di kube-proxy e CoreDNS prima del deploy
  applicativo, oltre alla condizione Ready del nodo.
- Rendere più robusto frontend-check: timeout delle richieste,
  gestione del codice HTTP assente e messaggi diagnostici leggibili.
- Documentare i requisiti inotify per l'esecuzione contemporanea
  di più cluster kind.

Questi miglioramenti sono distinti dalle verifiche già completate.

## Fonte

kind, Known Issues, sezione Pod errors due to "too many open files":
https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files
