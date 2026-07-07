# personal-gen-ai

Déployez votre **Open WebUI + Ollama** personnel, **au choix** sur :

- **AWS EC2** (VM GPU dédiée, Deep Learning AMI + Nginx HTTPS) — `providers/aws/`
- **RunPod** (marketplace GPU bon marché, 100 % Terraform) — `providers/runpod/`
- **Exoscale** (IaaS européen, souveraineté des données) — `providers/exoscale/`
- **Vast.ai** (marketplace GPU le moins cher, accès par tunnel SSH) — `providers/vastai/`
- **OVHcloud** (IaaS européen basé OpenStack) — `providers/ovhcloud/`

Chaque cible vit dans `providers/<cible>/` (une stack Terraform autonome). La logique métier commune est dans `common/`, les tests dans `tests/`.

Les cinq cibles sont pilotées par un dispatcher unique : `./deploy.sh <cible> <action>`.

## Comparatif des cibles

| | AWS EC2 (`aws`) | RunPod (`runpod`) | Exoscale (`exoscale`) | Vast.ai (`vastai`) | OVHcloud (`ovhcloud`) |
|---|---|---|---|---|---|
| Modèle | VM GPU dédiée | Marketplace GPU (Community Cloud) | VM GPU dédiée (IaaS UE) | Marketplace GPU | VM GPU dédiée (IaaS UE, OpenStack) |
| Localisation | Régions AWS | Mondiale | Zones UE (Suisse/DE/AT/BG) | Mondiale | Régions OVH (UE/AM/AP) |
| Coût GPU | Élevé (quotas à demander) | Bas | Moyen (A40 -30 % depuis 06/2026) | Le plus bas | Moyen (L4/L40S/A100/H100) |
| IaC | Terraform (`hashicorp/aws`) | Terraform (`decentralized-infrastructure/runpod`) | Terraform (`exoscale/exoscale`) | Terraform (`realnedsanders/vastai`) | Terraform (`terraform-provider-openstack/openstack`) |
| Réseau | VPC + subnet + security group | Fourni par RunPod | Security group | Fourni par Vast.ai | Security group (Neutron) |
| Accès web | Nginx HTTPS auto-signé | Proxy natif RunPod (TLS + auth) | Nginx HTTPS auto-signé | **Tunnel SSH** (pas d'IP publique exposée) | Nginx HTTPS auto-signé |
| Docker / GPU | AMI avec drivers pré-installés | L'image **est** le pod | Drivers NVIDIA installés au boot | L'image **est** l'instance | Drivers NVIDIA installés au boot |
| Persistance modèles | Volume Docker `ollama` | Volume monté sur `/root/.ollama` | Volume Docker `ollama` | Disque de l'instance | Volume Docker `ollama` |

La logique commune est factorisée dans [`common/`](common/) :
- [`common/bootstrap.sh`](common/bootstrap.sh) — lancement d'Open WebUI + pré-téléchargement du modèle Ollama (auto-adaptatif hôte/conteneur), réutilisé par **toutes** les cibles ;
- [`common/nginx-https.sh`](common/nginx-https.sh) — reverse-proxy HTTPS auto-signé, réutilisé par les cibles « vraie VM » (AWS, Exoscale, OVHcloud).

## Prérequis

- **terraform >= 1.5.7**
- Cible **aws** : `aws-cli` installé et configuré (credentials)
- Cible **runpod** : une clé API RunPod (`RUNPOD_API_KEY`)
- Cible **exoscale** : une clé API Exoscale (`EXOSCALE_API_KEY` / `EXOSCALE_API_SECRET`) **et un quota GPU validé** (validation manuelle du compte requise sur le portail Exoscale)
- Cible **vastai** : une clé API Vast.ai (`VASTAI_API_KEY`) et une paire de clés SSH locale
- Cible **ovhcloud** : les identifiants OpenStack sourcés (`source openrc.sh` — fichier « OpenStack RC » depuis l'espace client OVH) et une paire de clés SSH locale

## Utilisation

```bash
# Déployer
./deploy.sh aws up
./deploy.sh runpod up
./deploy.sh exoscale up
./deploy.sh vastai up
./deploy.sh ovhcloud up

# Voir l'URL (ou la commande de tunnel) et les autres sorties
./deploy.sh <cible> status

# Détruire
./deploy.sh <cible> down
```

Chaque commande affiche notamment `https_url`, l'adresse à ouvrir dans le navigateur.

### Cible AWS

1. Éditez [`providers/aws/terraform.tfvars`](providers/aws/terraform.tfvars) : région, type d'instance, taille de volume, nom de votre clé SSH, et éventuellement `ollama_model`.
2. `./deploy.sh aws up`
3. Ouvrez l'URL `https://<ec2_public_ip>` (certificat auto-signé : acceptez l'avertissement).

### Cible RunPod

1. Exportez votre clé API : `export RUNPOD_API_KEY=...`
2. `cp providers/runpod/terraform.tfvars.example providers/runpod/terraform.tfvars` puis ajustez (type de GPU, disque, `ollama_model`…).
3. `./deploy.sh runpod up`
4. Ouvrez l'URL `https://<pod_id>-8080.proxy.runpod.net` renvoyée par `status`.

> Sur RunPod, si `ollama_model` n'est pas pré-téléchargé, tirez le modèle depuis l'UI Open WebUI (persisté sur `/root/.ollama`).

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

> Le provider Vast.ai n'expose pas d'IP/port HTTP public : l'accès à Open WebUI passe par le **tunnel SSH** (`ssh -L 3000:localhost:8080 …`). Les modèles sont pré-téléchargés via `ollama_model` ou tirés depuis l'UI.

### Cible OVHcloud

1. Téléchargez le fichier **OpenStack RC** (application credentials) depuis l'espace client OVH, puis sourcez-le : `source openrc.sh`.
2. `cp providers/ovhcloud/terraform.tfvars.example providers/ovhcloud/terraform.tfvars` puis ajustez (`region`, `flavor_name`, `ssh_public_key_path`, `ollama_model`…).
3. `./deploy.sh ovhcloud up`
4. Ouvrez l'URL `https://<public_ip>` (certificat auto-signé).

> OVH Public Cloud est basé sur OpenStack. Comme pour Exoscale, l'image Ubuntu n'embarque pas les drivers NVIDIA : ils sont installés au premier boot via `user_data`. Les flavors A100/H100/L4/L40S sont en région **GRA11** (V100 en GRA7/9/BHS5).

## Structure

```
personal-gen-ai/
├── providers/              # Une stack Terraform autonome par fournisseur GPU
│   ├── aws/                #   AWS (VPC, EC2 GPU, Nginx HTTPS)
│   ├── runpod/             #   RunPod (runpod_pod)
│   ├── exoscale/           #   Exoscale (compute_instance GPU + SG)
│   ├── vastai/             #   Vast.ai (vastai_instance + tunnel SSH)
│   └── ovhcloud/           #   OVHcloud (openstack_compute_instance_v2 + SG)
├── common/                 # Logique métier partagée entre les stacks
│   ├── bootstrap.sh        #   Lancement Open WebUI + Ollama
│   └── nginx-https.sh      #   Reverse-proxy HTTPS auto-signé
├── tests/                  # Tests unitaires shell (bats) + mocks + fixtures
├── deploy.sh               # Dispatcher ./deploy.sh <aws|runpod|exoscale|vastai|ovhcloud> <up|down|status>
├── Makefile                # Cibles de test (make test)
└── README.md
```

## Tests

Le projet est testé **sans provisioning réel** (aucun coût GPU, aucune clé API), via 4 couches lancées par `make test` et en CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) :

| Cible make | Couche | Outil |
|---|---|---|
| `fmt` | formatage | `terraform fmt -check` |
| `validate` | schéma des 4 stacks | `terraform validate` |
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
- Sur Exoscale, si `nvidia-smi` échoue au premier démarrage, un `reboot` de l'instance charge le module noyau NVIDIA.
- Ne committez jamais un `terraform.tfstate` ni une clé API : c'est couvert par le [`.gitignore`](.gitignore).
