# SEED DNS Rebinding Attack — scénario CyberRangeCZ

Reproduction du SEED Lab **« DNS Rebinding Attack »** comme scénario CyberRangeCZ :
contourner la **politique de même origine** du navigateur par **DNS rebinding** pour
piloter un thermostat IoT derrière un pare-feu. Trois VM entièrement provisionnées ;
un **flag unique par étudiant**.

## Architecture

```
[ user ] 10.0.2.6 ─┐
[ dns  ] 10.0.2.7 ─┼─ lab-net 10.0.2.0/24 ─ 10.0.2.1 [ router ] ─ WAN (apt au provisioning)
[ attacker ] 10.0.2.8 ─┘
```

On garde le plan d'adressage exact de l'énoncé SEED (`10.0.2.6/7/8`), pour que toutes
les commandes du PDF fonctionnent telles quelles.

| VM | IP | Image | Rôle | Démarré par le provisioning |
|-|-|-|-|-|
| `user` | 10.0.2.6 | `seed` | victime : thermostat IoT + Firefox | serveur IoT (port 8080), résolveur → 10.0.2.7, cache DNS Firefox court |
| `dns` | 10.0.2.7 | `debian-12-x86_64` | DNS local | BIND9 : transfère `attacker32.com` → 10.0.2.8 |
| `attacker` | 10.0.2.8 | `debian-12-x86_64` | attaquant | serveur web (port 8080) + BIND9 autoritaire pour `attacker32.com` |

Tout tourne dès l'allocation : l'étudiant ne fait que la partie **navigateur** (tâches 6-8
de l'énoncé). Les tâches 1-5 (installer Flask, configurer BIND9, `/etc/hosts`, résolveur)
sont déjà faites par Ansible.

## Comptes

| Compte | Qui l'utilise | Droits |
|-|-|-|
| `ubuntu` / `debian` (`mgmt_user`) | la plateforme (Ansible, clé SSH) | sudo |
| `seed` / `dees` | l'étudiant, sur les 3 VM (console *Open GUI* ou SSH) | **sudo** (le TP demande d'éditer `/etc/bind`, de redémarrer des services) |

Contrairement au TP PRNG, l'étudiant **a besoin de sudo** : il modifie la zone DNS et
redémarre BIND9 / le serveur web. Il n'y a pas de secret à cacher ici (le mot de passe du
thermostat est public par conception, c'est une protection anti-CSRF, pas un flag).

## Le flag

Le serveur IoT expose `/flag`. Il ne le révèle **que** lorsqu'une requête de réglage de
température (≥ 88 °C) lui parvient **avec le nom d'hôte `www.attacker32.com`** — la signature
du DNS rebinding. Régler le curseur sur la page de l'IoT (même origine) ne le débloque pas.
Après l'attaque, l'étudiant ouvre `http://www.attacker32.com:8080/flag` (ce nom pointe alors
vers l'IoT) et soumet la valeur. Le flag est unique par sandbox (`variables.yml`).

## Déployer sur CyberRangeCZ

Même procédure que le TP PRNG (voir le guide du dépôt `library-seed-prng`, section 4) :

1. **Sandboxes > Images** : vérifier que `seed` et `debian-12-x86_64` existent.
2. **Sandboxes > Definition** : *Create*, URL Git de ce dépôt, révision `main`.
3. **Sandboxes > Pool** : *Create* (taille 1 pour tester), puis *Allocate*.
4. **Trainings > Definition** : *Upload* de `training.json`.
5. **Trainings > Instance** : *Create*, assigner le pool, noter le jeton.
6. **Trainings > Run** : jouer le TP (jeton d'accès `start`).

## Vérifier une sandbox déployée

Sur `user` (connexion `seed` / `dees`) :

```bash
dig +short www.attacker32.com        # -> 10.0.2.8 (via le DNS local 10.0.2.7)
curl -s http://www.seedIoT32.com:8080/temperature   # -> {"temperature": 20}
```

Sur `attacker` :

```bash
systemctl is-active attacker-web named     # -> active / active
sudo named-checkzone attacker32.com /etc/bind/attacker32.com.zone
```

Déroulé complet de l'attaque : voir les tâches 4 et 5 de `training.json`.

## Arborescence

```
library-dns-rebinding/
├── topology.yml                 3 VM + routeur, réseau 10.0.2.0/24
├── variables.yml                flag_dns (1 par sandbox)
├── training.json                7 niveaux (intro, accès, tâches, fin)
└── provisioning/
    ├── requirements.yml         user-access, sandbox-logging
    ├── playbook.yml
    └── roles/
        ├── common/              python3, dig
        ├── iot-server/          thermostat + /etc/hosts + résolveur + Firefox   (VM user)
        ├── local-dns/           BIND9 transfert attacker32.com                   (VM dns)
        └── attacker-server/     serveur web + BIND9 autoritaire                  (VM attacker)
```

Les fichiers SEED d'origine sont sous `roles/iot-server/files/user_vm/` et
`roles/attacker-server/files/attacker_vm/` (voir `ATTRIBUTION.txt`).
