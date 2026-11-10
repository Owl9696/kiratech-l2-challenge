# Aggiornamento applicativo e rollback dichiarativo

Prova eseguita il 10 novembre 2026 sul namespace boutique-dev
del cluster kiratech-l2-rebuild.

## Revisioni

- Release v1: kiratech-frontend:git-b13f4246ae3d.
- Release v2: kiratech-frontend:git-197a0f9c572c.
- Commit di aggiornamento dell'overlay dev: 70e535cd.

La modifica applicativa consiste nel footer visibile:
da Release v1 a Release v2.

## Procedura verificata

1. Modifica del footer e commit dei sorgenti.
2. Aggiornamento del tag frontend nell'overlay dev.
3. Esecuzione di setup.sh dev con KIND_CLUSTER_NAME=kiratech-l2-rebuild.
4. Build dell'immagine dalla revisione Git, caricamento nel nodo e rollout.
5. Verifica della homepage tramite Traefik: Release v2 presente.
6. Ripristino del tag git-b13f4246ae3d nell'overlay dev.
7. Nuova esecuzione del setup dev e completamento del rollout.
8. Verifica della homepage tramite Traefik: Release v1 presente.

Il rollback ripristina il riferimento dichiarativo all'immagine precedente.
I sorgenti v2 restano nella cronologia Git; non vengono cancellati.

## Stato finale e limiti

Il Deployment frontend dev risulta disponibile con una replica v1.
Prod non è stato modificato durante questa prova.

Durante entrambi i rollout un pod uscente è comparso temporaneamente
in stato Error. La causa della terminazione non è stata determinata
con le evidenze finora raccolte. Il primo pod non era più presente
al momento del controllo successivo.

Il successo del rollout e della richiesta HTTP conferma il risultato
finale, ma non dimostra assenza di interruzioni durante la transizione.
