# Backlog produit — personal-gen-ai

Backlog des améliorations et ajouts, dérivé du **rapport d'analyse v2**
(`docs/Personal-Gen-AI_Rapport-Analyse-v2.pdf`, daté du 8 juillet 2026) et croisé
avec l'état réel du dépôt.

**Légende**
- **Priorité** : `Haute` · `Moyenne` · `Basse`
- **État** : `A FAIRE` · `EN COURS` · `FAIT`
- Les 3 chantiers prioritaires de la conclusion du rapport sont notés **P1 / P2 / P3**.

## Backlog

| # | Amélioration / Ajout | Thème | Priorité | État | Commentaire |
|---|----------------------|-------|----------|------|-------------|
| 1 | Restreindre l'ingress des cibles VM à mon IP (`/32`) via une variable `my_ip` | Réseau & sécurité | Haute | A FAIRE | **P1** « Fermer le réseau » : dernier écart *élevé*. SG `0.0.0.0/0` sur `aws`, `exoscale`, `ovhcloud`. Alternative plus complète : accès privé (#5). |
| 2 | Persistance inter-sessions des modèles & conversations (volume détachable / snapshot par cible) | Persistance & données | Haute | FAIT | **P2** : `down` conserve les données sur AWS/Exoscale/OVHcloud via volumes détachables ; limites RunPod/Vast.ai/Lyceum documentées ; `purge` détruit tout explicitement. |
| 3 | Garde-fous budgétaires : arrêt automatique sur inactivité + alertes de coût | FinOps | Haute | A FAIRE | **P3** : une instance oubliée facture en silence, surtout sur AWS. Aucune alerte ni auto-stop aujourd'hui. |
| 4 | Certificat TLS **public** (nom de domaine + Let's Encrypt / ACM) | Sécurité & réseau | Moyenne | A FAIRE | Remplace l'auto-signé (`common/nginx-https.sh`) → supprime l'avertissement navigateur et donne une identité serveur vérifiable. |
| 5 | Accès privé unifié (Tailscale / WireGuard) sur les 6 cibles | Réseau | Moyenne | A FAIRE | Supprime **toute** exposition publique. Alternative structurante à #1 + #4. |
| 6 | Chiffrement au repos (`encrypted = true`) sur volumes racine et disques de données | Sécurité | Moyenne | A FAIRE | Aucun `encrypted` dans le code aujourd'hui ; bonus : un `skip-check` checkov de moins. |
| 7 | Backend d'état Terraform **distant** avec verrouillage (S3+DynamoDB / GCS / TF Cloud) | IaC & état | Moyenne | A FAIRE | 6 `tfstate` locaux sans verrou → pas de collaboration ni de reprise. |
| 8 | IP stable (Elastic IP / IP flottante) sur les cibles VM | Réseau | Moyenne | A FAIRE | Aujourd'hui nouvelle IP publique à chaque `up`. Prérequis d'un vrai DNS (#16). |
| 9 | Confirmer les endpoints API Lyceum (`/vms` vs `/vms/create`, `hardware_profile`, provisioning SSH) | Fournisseurs | Moyenne | A FAIRE | Sort la 6ᵉ cible du statut **best-effort** : `validate`/`tftest` ne couvrent que le HCL, pas les appels REST. |
| 10 | Épingler la version de l'AMI AWS (ou `ignore_changes`) | IaC | Moyenne | A FAIRE | `data.aws_ami … most_recent = true` → risque de remplacement d'instance surprise au `plan`. |
| 11 | Revue avant apply : retirer `-auto-approve` par défaut (mode `plan` + confirmation) | Sécurité & exploitation | Moyenne | A FAIRE | `deploy.sh` applique **et** détruit en `-auto-approve` sans revue. |
| 12 | Banc de mesure du coût réel par cible | FinOps | Moyenne | A FAIRE | Objective le comparatif coût du README (chiffres annoncés vs mesurés). |
| 13 | Ajouter `LICENSE`, description et topics GitHub | Diffusion / open source | Moyenne | A FAIRE | Dépôt public sans licence → réutilisation juridiquement floue. Gain rapide à fort rendement. |
| 14 | Releases taguées (versioning des livraisons) | Diffusion / open source | Basse | A FAIRE | Chantier « État & diffusion » du rapport. |
| 15 | Veille sur les providers communautaires (`runpod`, `vastai`) | Fournisseurs | Basse | A FAIRE | Leur maintenance conditionne ces cibles ; surveillance, pas d'action immédiate. |
| 16 | Nom de domaine / DNS stable | Réseau | Basse | A FAIRE | Dépend de l'IP stable (#8) ; complète le TLS public (#4). |
| 17 | CI + 6 couches de tests (`fmt`, `validate`, `lint`, `unit`, `tftest`, `sec`) | Qualité | — | FAIT | Recommandation du rapport précédent **traitée** (`Makefile`, `.github/workflows/ci.yml`). |
| 18 | Scan sécurité checkov bloquant (baseline justifiée) | Sécurité | — | FAIT | `.checkov.yaml` : 10 checks écartés, chacun documenté. |
| 19 | Pré-téléchargement du modèle Ollama (`ollama_model`) | UX | — | FAIT | Recommandation précédente **traitée** (`common/bootstrap.sh`). |
| 20 | IMDSv2 obligatoire sur l'EC2 (CKV_AWS_79) | Sécurité | — | FAIT | Durcissement métadonnées (`providers/aws/main.tf`). |
| 21 | Secrets hors du code (clés API en env, `tfstate`/`tfvars` ignorés) | Sécurité | — | FAIT | `.gitignore` + garde-fous d'identifiants dans `deploy.sh`. |
| 22 | Accès sans exposition web pour Vast.ai & Lyceum (tunnel SSH) | Réseau | — | FAIT | Rien n'écoute sur Internet pour ces deux cibles. |

## Notes

- **Priorisation du rapport** : la conclusion retient 3 chantiers — **P1** fermer le réseau (#1),
  **P2** persister les modèles (#2), **P3** outiller le coût (#3). Ce sont les 3 items `Haute`.
- Les items #4→#13 correspondent aux « gains rapides » et « chantiers structurants » (slides 13-14) ;
  #14→#16 sont des compléments à plus faible urgence.
- Les lignes **FAIT** (#17→#22) reprennent les points marqués « RÉGLÉ » / « déjà traités » par le rapport,
  vérifiés dans le dépôt.
- Le pari d'origine — **infrastructure éphémère** — reste la ligne directrice : aucune de ces évolutions
  ne vise à transformer le projet en serveur permanent.
