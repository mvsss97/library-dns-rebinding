#!/usr/bin/env bash
# Contrôles statiques : syntaxe Python, zone DNS, syntaxe Ansible, applications Flask.
set -euo pipefail

python3 -m py_compile \
  provisioning/roles/iot-server/files/user_vm/rebind_iot/iot.py \
  provisioning/roles/iot-server/files/user_vm/rebind_iot/__init__.py \
  provisioning/roles/iot-server/files/user_vm/rebind_iot/config.py \
  provisioning/roles/attacker-server/files/attacker_vm/rebind_malware/__init__.py
echo "  [OK]   applications Python : syntaxe valide"

# Rendu du modèle de zone (valeurs par défaut) puis contrôle BIND.
tmp=$(mktemp -d)
sed -e 's/{{ zone_ttl }}/10000/' -e 's/{{ attacker_domain }}/attacker32.com/g' \
    -e 's/{{ attacker_ip }}/10.0.2.8/g' \
    provisioning/roles/attacker-server/templates/attacker.zone.j2 > "$tmp/zone"
named-checkzone attacker32.com "$tmp/zone" > /dev/null
echo "  [OK]   fichier de zone : valide (named-checkzone)"

cd provisioning
ansible-galaxy install -r requirements.yml -p roles > /dev/null
ansible-playbook playbook.yml -i ../ci/inventory.yml --syntax-check > /dev/null
echo "  [OK]   playbook.yml : syntaxe Ansible valide"
cd ..

python3 ci/flask_test.py
