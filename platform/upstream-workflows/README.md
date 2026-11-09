# Workflow upstream archiviati

Questi workflow provengono dal progetto GoogleCloudPlatform/microservices-demo.
Sono conservati come riferimento, con le relative intestazioni di licenza.

Sono stati spostati fuori da .github/workflows perché includono operazioni
destinate all'infrastruttura cloud upstream, non utilizzata dalla challenge:

- ci-main.yaml: test upstream e deploy su GKE.
- deploy-pr.yaml: deploy delle pull request su GKE.
- cleanup.yaml: eliminazione dei namespace delle PR chiuse.
- make-release.yaml: build e pubblicazione delle release.

In questa posizione non vengono riconosciuti come workflow GitHub Actions.
La modifica diventa effettiva sui branch che contengono questo commit;
non modifica automaticamente gli altri branch o eventuali run già avviate.

La pipeline della challenge è .github/workflows/kiratech-ci.yaml.
Verifica sintassi shell, rendering Kustomize, test Go e build del frontend.
Non sostituisce tutti i test degli altri microservizi presenti nei workflow
upstream.

Gli altri workflow rimasti in .github/workflows non sono modificati
da questo intervento.

Un eventuale ripristino dei workflow archiviati richiede prima la revisione
di trigger, permessi, credenziali, destinazioni cloud e operazioni eseguite.
