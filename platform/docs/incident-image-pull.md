# Prova di troubleshooting: immagine frontend non disponibile

Data: 2026-11-06
Ambiente: boutique-dev
Contesto: kind-kiratech-l2

## Stato iniziale
- Deployment frontend: 1 replica pronta su 1.
- Immagine: kiratech-frontend:git-b13f4246ae3d.
- Revisione del Deployment prima della prova: 6.

## Guasto introdotto
Impostata temporaneamente sul Deployment l'immagine:
kiratech-frontend:missing-drill-001

La modifica è stata applicata al cluster, senza modificare gli overlay Git.

## Sintomi ed evidenze
- Nuovo pod: 0/1, ErrImagePull e successivamente ImagePullBackOff.
- Vecchio pod: rimasto 1/1 Running durante le osservazioni.
- Il runtime ha tentato il download da:
  docker.io/library/kiratech-frontend:missing-drill-001
- Gli eventi riportavano pull access denied e insufficient_scope.

## Diagnosi
La prova ha introdotto deliberatamente un riferimento immagine non disponibile.
In un incidente reale, il messaggio di accesso negato richiederebbe di
verificare anche nome del repository, tag e autorizzazioni del registry.

## Ripristino eseguito
kubectl --context kind-kiratech-l2 -n boutique-dev \
  rollout undo deployment/frontend --to-revision=6

kubectl --context kind-kiratech-l2 -n boutique-dev \
  rollout status deployment/frontend --timeout=300s

La revisione 6 è specifica di questa esecuzione: per ripetere la prova
occorre prima identificare la revisione corretta con rollout history.

## Verifica finale
- Immagine corretta ripristinata.
- Frontend: 1/1 Running, zero riavvii.
- Homepage: HTTP 200.
- Endpoint /metrics raggiungibile; contatore osservato: 2065.

Non è stato misurato continuamente il traffico durante la prova:
la presenza del vecchio pod pronto non dimostra da sola assenza di downtime.

## Problema distinto durante la verifica
Un primo curl verso localhost:8082 è fallito con connection refused
e HTTP 000 perché il port-forward dev non era attivo.
Riavviato il port-forward in una finestra dedicata, le verifiche HTTP
sono riuscite. Non è stato necessario modificare l'applicazione.

## Prevenzione
Verificare la disponibilità dell'immagine prima del deploy, usare tag
tracciabili e controllare sempre rollout, eventi e risposta HTTP.
