# personal-gen-ai

Déployez votre **Open WebUI + Ollama** personnel, **au choix** sur :

- **AWS EC2** (VM GPU dédiée, Deep Learning AMI + Nginx HTTPS) — `providers/aws/`
- **RunPod** (marketplace GPU bon marché, 100 % Terraform) — `providers/runpod/`
- **Exoscale** (IaaS européen, souveraineté des données) — `providers/exoscale/`
- **Vast.ai** (marketplace GPU le moins cher, accès par tunnel SSH) — `providers/vastai/`
- **OVHcloud** (IaaS européen basé OpenStack) — `providers/ovhcloud/`
- **Lyceum** (GPU cloud européen, piloté via API REST) — `providers/lyceum/`

Chaque cible vit dans `providers/<cible>/` (une stack Terraform autonome). La logique métier commune est dans `common/`, les tests dans `tests/`.

Les six cibles sont pilotées par un dispatcher unique : `./deploy.sh <cible> <action>`.

## Comparatif des cibles

| | AWS EC2 (`aws`) | RunPod (`runpod`) | Exoscale (`exoscale`) | Vast.ai (`vastai`) | OVHcloud (`ovhcloud`) | Lyceum (`lyceum`) |
|---|---|---|---|---|---|---|
| Modèle | VM GPU dédiée | Marketplace GPU (Community Cloud) | VM GPU dédiée (IaaS UE) | Marketplace GPU | VM GPU dédiée (IaaS UE, OpenStack) | VM GPU (cloud UE, Berlin) |
| Localisation | Régions AWS | Mondiale | Zones UE (Suisse/DE/AT/BG) | Mondiale | Régions OVH (UE/AM/AP) | UE |
| Coût GPU | Élevé (quotas à demander) | Bas | Moyen (A40 -30 % depuis 06/2026) | Le plus bas | Moyen (L4/L40S/A100/H100) | Moyen (H100 dès 2 $/h) |
| IaC | Terraform (`hashicorp/aws`) | Terraform (`decentralized-infrastructure/runpod`) | Terraform (`exoscale/exoscale`) | Terraform (`realnedsanders/vastai`) | Terraform (`terraform-provider-openstack/openstack`) | **API REST** via `Mastercard/restapi` (pas de provider natif) |
| Réseau | VPC + subnet + security group | Fourni par RunPod | Security group | Fourni par Vast.ai | Security group (Neutron) | Fourni par Lyceum |
| Accès web | Nginx HTTPS auto-signé | Proxy natif RunPod (TLS + auth) | Nginx HTTPS auto-signé | **Tunnel SSH** (pas d'IP publique exposée) | Nginx HTTPS auto-signé | **Tunnel SSH** |
| Docker / GPU | AMI avec drivers pré-installés | L'image **est** le pod | Drivers NVIDIA installés au boot | L'image **est** l'instance | Drivers NVIDIA installés au boot | VM root SSH (provisioning post-boot par SSH) |
| Persistance données | Volumes EBS détachables | Volume RunPod `/workspace` | Volumes Block Storage détachables | Disque de l'instance | Volumes Cinder détachables | Disque de la VM |

La logique commune est factorisée dans [`common/`](common/) :
- [`common/bootstrap.sh`](common/bootstrap.sh) — lancement d'Open WebUI + pré-téléchargement du modèle Ollama (auto-adaptatif hôte/conteneur), réutilisé par **toutes** les cibles ; gère aussi le moteur **vLLM** (API OpenAI-compatible) via `ENGINE=vllm` (exposé sur la cible Vast.ai, cf. sa section) ;
- [`common/nginx-https.sh`](common/nginx-https.sh) — reverse-proxy HTTPS auto-signé, réutilisé par les cibles « vraie VM » (AWS, Exoscale, OVHcloud).

## Prérequis

- **terraform** : `>= 1.5.7` pour déployer une cible ; **`>= 1.7` pour la suite complète `make test`** (sinon la couche `tftest`, qui utilise `mock_provider`, est ignorée)
- Cible **aws** : `aws-cli` installé et configuré (credentials)
- Cible **runpod** : une clé API RunPod (`RUNPOD_API_KEY`)
- Cible **exoscale** : une clé API Exoscale (`EXOSCALE_API_KEY` / `EXOSCALE_API_SECRET`) **et un quota GPU validé** (validation manuelle du compte requise sur le portail Exoscale)
- Cible **vastai** : une clé API Vast.ai (`VASTAI_API_KEY`) et une paire de clés SSH locale
- Cible **ovhcloud** : les identifiants OpenStack sourcés (`source openrc.sh` — fichier « OpenStack RC » depuis l'espace client OVH) et une paire de clés SSH locale
- Cible **lyceum** : une clé API Lyceum (`LYCEUM_API_KEY`, format `lk_...`) et une paire de clés SSH locale

## Utilisation

```bash
# Déployer
./deploy.sh aws up
./deploy.sh runpod up
./deploy.sh exoscale up
./deploy.sh vastai up
./deploy.sh ovhcloud up
./deploy.sh lyceum up

# Voir l'URL (ou la commande de tunnel) et les autres sorties
./deploy.sh <cible> status

# Arrêter/détruire le compute coûteux en conservant les données quand la cible le permet
./deploy.sh <cible> down

# Détruire toute la stack, données incluses
./deploy.sh <cible> purge
```

Chaque commande affiche notamment `https_url`, l'adresse à ouvrir dans le navigateur.

### Persistance et cycle de vie

`down` est conçu pour supprimer le coût GPU sans effacer les données quand le provider expose des volumes détachables. `purge` reprend le comportement destructeur total de Terraform et supprime aussi les volumes ou disques gérés par la stack.

| Cible | Garantie après `down` |
|---|---|
| AWS | Modèles Ollama et conversations Open WebUI conservés sur volumes EBS séparés. |
| Exoscale | Modèles et conversations conservés sur volumes Block Storage séparés. |
| OVHcloud | Modèles et conversations conservés sur volumes Cinder séparés. |
| RunPod | Données configurées sous `/workspace`; conservation dépend du cycle de vie du volume RunPod exposé par le provider. |
| Vast.ai | Pas de volume détachable dans cette stack Terraform ; `down` détruit l'instance et ses données. |
| Lyceum | Pas de volume détachable dans cette stack Terraform ; `down` détruit la VM et ses données. |

### Cible AWS

1. Éditez [`providers/aws/terraform.tfvars`](providers/aws/terraform.tfvars) : région, type d'instance, taille de volume, nom de votre clé SSH, et éventuellement `ollama_model`.
2. `./deploy.sh aws up`
3. Ouvrez l'URL `https://<ec2_public_ip>` (certificat auto-signé : acceptez l'avertissement).

### Cible RunPod

1. Exportez votre clé API : `export RUNPOD_API_KEY=...`
2. `cp providers/runpod/terraform.tfvars.example providers/runpod/terraform.tfvars` puis ajustez (type de GPU, disque, `ollama_model`…).
3. `./deploy.sh runpod up`
4. Ouvrez l'URL `https://<pod_id>-8080.proxy.runpod.net` renvoyée par `status`.

> Sur RunPod, si `ollama_model` n'est pas pré-téléchargé, tirez le modèle depuis l'UI Open WebUI. Les modèles et données Open WebUI sont configurés sous `/workspace`, le volume persistant exposé au pod.

### Cible Exoscale

1. Assurez-vous d'avoir un **quota GPU validé** sur votre compte Exoscale (demande manuelle sur le portail).
2. Exportez vos identifiants : `export EXOSCALE_API_KEY=...  EXOSCALE_API_SECRET=...`
3. `cp providers/exoscale/terraform.tfvars.example providers/exoscale/terraform.tfvars` puis renseignez au minimum `ssh_key_name` (nom d'une clé SSH déjà présente dans le compte). Ajustez `zone` / `instance_type` selon la disponibilité GPU.
4. `./deploy.sh exoscale up`
5. Ouvrez l'URL `https://<public_ip>` (certificat auto-signé).

> Contrairement à AWS, le template Ubuntu Exoscale n'embarque pas les drivers NVIDIA : ils sont installés au premier boot via `user_data`. Le provisioning initial est donc un peu plus long.

### Cible Vast.ai

1. Générez une clé SSH si besoin (`ssh-keygen -t ed25519`) — sa clé publique sert au tunnel.
2. Exportez votre clé API : `export VASTAI_API_KEY=...`
3. `cp providers/vastai/terraform.tfvars.example providers/vastai/terraform.tfvars` puis ajustez (`gpu_name`, `max_price`, `ssh_public_key_path`, `ollama_model`…).
4. `./deploy.sh vastai up`
5. `./deploy.sh vastai status` affiche `ssh_tunnel` : collez cette commande dans un terminal, puis ouvrez `http://localhost:3000`.

#### Choix du moteur : Open WebUI ou vLLM

Sur Vast.ai, un **3ᵉ argument** de `deploy.sh` choisit le moteur servi (défaut : `openwebui`) :

```bash
./deploy.sh vastai up            # Open WebUI + Ollama (UI navigateur) — comme ci-dessus
./deploy.sh vastai up vllm       # serveur vLLM : API OpenAI-compatible (pas d'UI)
```

En mode **vllm**, l'instance déploie l'image `vllm/vllm-openai` et expose une API **OpenAI-compatible** (`/v1/chat/completions`, `/v1/models`…) sur le port **8000** — ce n'est **pas** une interface navigateur. Le modèle servi est un id **HuggingFace** (`vllm_model`, défaut `Qwen/Qwen2.5-1.5B-Instruct`, téléchargé au démarrage) ; pour un modèle gated, fournissez un token via `export TF_VAR_hf_token=hf_...`.

Passez le **même moteur** à `status`/`down` pour obtenir des sorties cohérentes :

```bash
./deploy.sh vastai up vllm
./deploy.sh vastai status vllm    # affiche ssh_tunnel (…-L 8000:localhost:8000…) et curl_example
# ouvrez le tunnel affiché, puis :
curl http://localhost:8000/v1/models
curl http://localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-1.5B-Instruct","messages":[{"role":"user","content":"Bonjour"}]}'
./deploy.sh vastai down vllm
```

Depuis un client OpenAI, utilisez `base_url = "http://localhost:8000/v1"` (clé API quelconque, non vérifiée par défaut).

> **Format du nom de GPU** : `gpu_name` doit reprendre exactement le libellé de l'API Vast.ai, **avec des espaces** (`"RTX 4090"`, `"RTX 3090"`, `"H100 SXM"`…), et non des underscores (`RTX_4090`). Un underscore ne matche aucune offre : la recherche renvoie une liste vide et le déploiement échoue à la sélection de l'offre.

> Le provider Vast.ai n'expose pas d'IP/port HTTP public : l'accès (Open WebUI sur 8080, ou vLLM sur 8000) passe par le **tunnel SSH**. Cette stack ne dispose pas de volume détachable Vast.ai ; `down` détruit donc l'instance et ses données.

### Cible OVHcloud

1. Téléchargez le fichier **OpenStack RC** (application credentials) depuis l'espace client OVH, puis sourcez-le : `source openrc.sh`.
2. `cp providers/ovhcloud/terraform.tfvars.example providers/ovhcloud/terraform.tfvars` puis ajustez (`region`, `flavor_name`, `ssh_public_key_path`, `ollama_model`…).
3. `./deploy.sh ovhcloud up`
4. Ouvrez l'URL `https://<public_ip>` (certificat auto-signé).

> OVH Public Cloud est basé sur OpenStack. Comme pour Exoscale, l'image Ubuntu n'embarque pas les drivers NVIDIA : ils sont installés au premier boot via `user_data`. Les flavors A100/H100/L4/L40S sont en région **GRA11** (V100 en GRA7/9/BHS5).

### Cible Lyceum

1. Générez une clé SSH si besoin (`ssh-keygen -t ed25519`).
2. Exportez votre clé API : `export LYCEUM_API_KEY=lk_...`
3. `cp providers/lyceum/terraform.tfvars.example providers/lyceum/terraform.tfvars` puis renseignez `hardware_profile` (profil GPU, cf. `GET /vms/availability`) et ajustez les specs.
4. `./deploy.sh lyceum up` → crée la VM.
5. **Provisionnez Open WebUI par SSH** (l'API ne gère pas de `user_data`) : la sortie `provision_hint` donne la commande. Puis `./deploy.sh lyceum status` affiche `ssh_tunnel` → ouvrez `http://localhost:3000`.

> ⚠️ **Cible best-effort.** Lyceum n'a **pas de provider Terraform natif** : on pilote son [API REST](https://docs.lyceum.technology/) via le provider générique [`Mastercard/restapi`](https://registry.terraform.io/providers/Mastercard/restapi/latest). Le `terraform validate`/`test` ne valide que le HCL, **pas** la justesse des appels API. À **confirmer avant un `apply` réel** : le chemin exact du create (`/vms` vs `/vms/create`), la valeur `hardware_profile` GPU, et le fait que l'API create n'accepte pas de `user_data` (d'où le provisioning par SSH).
> Cette stack ne dispose pas de volume détachable Lyceum ; `down` détruit donc la VM et ses données.

## Structure

```
personal-gen-ai/
├── providers/              # Une stack Terraform autonome par fournisseur GPU
│   ├── aws/                #   AWS (VPC, EC2 GPU, Nginx HTTPS)
│   ├── runpod/             #   RunPod (runpod_pod)
│   ├── exoscale/           #   Exoscale (compute_instance GPU + SG)
│   ├── vastai/             #   Vast.ai (vastai_instance + tunnel SSH)
│   ├── ovhcloud/           #   OVHcloud (openstack_compute_instance_v2 + SG)
│   └── lyceum/             #   Lyceum (API REST via provider restapi + tunnel SSH)
├── common/                 # Logique métier partagée entre les stacks
│   ├── bootstrap.sh        #   Lancement Open WebUI + Ollama
│   └── nginx-https.sh      #   Reverse-proxy HTTPS auto-signé
├── tests/                  # Tests unitaires shell (bats) + mocks + fixtures
├── deploy.sh               # Dispatcher ./deploy.sh <aws|runpod|exoscale|vastai|ovhcloud|lyceum> <up|down|status>
├── Makefile                # Cibles de test (make test)
└── README.md
```

## Tests

Le projet est testé **sans provisioning réel** (aucun coût GPU, aucune clé API), via 6 couches lancées par `make test` et en CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) :

| Cible make | Couche | Outil |
|---|---|---|
| `fmt` | formatage | `terraform fmt -check` |
| `validate` | schéma des 6 stacks | `terraform validate` |
| `lint` | scripts shell | `shellcheck` + `bash -n` |
| `unit` | dispatcher & bootstrap | `bats` |
| `tftest` | câblage des stacks (image, ports, outputs) | `terraform test` + `mock_provider` |
| `sec` | mauvaises configs IaC | `checkov` |

Prérequis locaux : `terraform` (**≥ 1.7 pour `tftest`** ; sinon la cible est ignorée), `shellcheck`, `bats`, `checkov`.

```bash
make test          # tout
make fmt validate  # rapide, sans outils tiers
make unit          # tests bats
```

## Notes

- Les providers RunPod ([`decentralized-infrastructure/runpod`](https://registry.terraform.io/providers/decentralized-infrastructure/runpod/latest)) et Vast.ai ([`realnedsanders/vastai`](https://registry.terraform.io/providers/realnedsanders/vastai/latest)) sont communautaires. En cas d'erreur au `terraform plan`, vérifiez la doc du registry.
- **Lyceum** n'a pas de provider Terraform : la cible pilote l'API REST via `Mastercard/restapi` et est **best-effort** (voir l'avertissement de la section Lyceum). Les appels API ne sont pas couverts par `validate`/`test`.
- Sur Exoscale, si `nvidia-smi` échoue au premier démarrage, un `reboot` de l'instance charge le module noyau NVIDIA.
- Ne committez jamais un `terraform.tfstate` ni une clé API : c'est couvert par le [`.gitignore`](.gitignore).
