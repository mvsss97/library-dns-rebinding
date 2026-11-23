#!/usr/bin/env bash
# Démarre les trois VM du TP (conteneurs systemd) sur le réseau 10.0.2.0/24, avec les
# adresses exactes de l'énoncé SEED, et crée le compte étudiant seed / dees.
set -euo pipefail
IMAGE="$1"

docker network create --subnet=10.0.2.0/24 labnet > /dev/null

box() {   # box <nom> <ip>
  docker run -d --name "$1" --hostname "$1" --network labnet --ip "$2" \
    --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw "$IMAGE" > /dev/null
}
box user 10.0.2.6
box dns 10.0.2.7
box attacker 10.0.2.8

for name in user dns attacker; do
  state=""
  for _ in $(seq 1 60); do
    state=$(docker exec "$name" systemctl is-system-running 2> /dev/null || true)
    if [ "$state" = running ] || [ "$state" = degraded ]; then break; fi
    sleep 2
  done
  echo "$name : systemd ${state:-inconnu}"
  docker exec "$name" bash -c '
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq openssh-server sudo python3 curl > /dev/null
    id ubuntu > /dev/null 2>&1 || useradd -m -s /bin/bash ubuntu
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-cloud-init-users
    chmod 440 /etc/sudoers.d/90-cloud-init-users
    id seed > /dev/null 2>&1 || useradd -m -s /bin/bash seed
    echo "seed:dees" | chpasswd
    echo "seed ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/seed
    chmod 440 /etc/sudoers.d/seed'
done

docker exec user bash -c '. /etc/os-release; echo "Cible : $PRETTY_NAME, $(python3 -V 2>&1)"'
