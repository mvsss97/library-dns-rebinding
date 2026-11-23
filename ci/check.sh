#!/usr/bin/env bash
# Vérifie l'environnement provisionné : services démarrés, configuration déployée,
# chaîne DNS, serveurs HTTP, et propagation d'une mise à jour de zone.
set -uo pipefail
FAIL=0
R() { docker exec "$1" bash -c "$2"; }
ok()  { echo "  [OK]   $1"; }
ko()  { echo "  [FAIL] $1"; FAIL=1; }
want() { if R "$1" "$2" | grep -qE "$3"; then ok "$4"; else ko "$4 (attendu : $3)"; fi; }

echo "Services"
want user     "systemctl is-active iot"            "^active"  "user : serveur du thermostat actif"
want attacker "systemctl is-active attacker-web"   "^active"  "attacker : serveur web actif"
want dns      "systemctl is-active named bind9 2>/dev/null | head -1" "^active" "dns : BIND actif"
want attacker "systemctl is-active named bind9 2>/dev/null | head -1" "^active" "attacker : BIND actif"

echo
echo "Configuration déployée"
want user     "cat /etc/seed-iot.env"              "SEED_DNS_FLAG=CiTestFlag123456" "user : flag de la sandbox câblé dans le service"
want user     "grep -m1 nameserver /etc/resolv.conf" "10.0.2.7" "user : résolveur = DNS local (10.0.2.7)"
want user     "getent hosts www.seedIoT32.com"      "10.0.2.6" "user : nom du thermostat dans /etc/hosts"

echo
echo "Chaîne DNS"
want attacker "dig +short @127.0.0.1 www.attacker32.com" "^10\.0\.2\.8$" "attacker : zone autoritaire répond 10.0.2.8"
want user     "dig +short www.attacker32.com"        "^10\.0\.2\.8$" "user : résolution via le DNS local (transfert) = 10.0.2.8"

echo
echo "Serveurs HTTP"
want user     "curl -s http://www.seedIoT32.com:8080/temperature" '"temperature": 20' "user : thermostat répond (20)"
want user     "curl -s -o /dev/null -w '%{http_code}' http://10.0.2.8:8080/" "200" "user : serveur web de l'énoncé joignable"
want user     "curl -s -o /dev/null -w '%{http_code}' http://www.seedIoT32.com:8080/flag" "403" "user : endpoint /flag présent et verrouillé au départ"

echo
echo "Propagation d'une mise à jour de zone (mécanisme du TP)"
R attacker "sed -i '/^www/s/10.0.2.8/10.0.2.6/' /etc/bind/attacker32.com.zone && rndc reload attacker32.com" > /dev/null 2>&1
R dns "rndc flush" > /dev/null 2>&1
R user "resolvectl flush-caches" > /dev/null 2>&1 || true
sleep 2
want user "dig +short www.attacker32.com" "^10\.0\.2\.6$" "user : après reload de la zone, le nom pointe vers la nouvelle IP (10.0.2.6)"

echo
if [ "$FAIL" -eq 0 ]; then echo "Tous les contrôles d'intégration sont au vert."; else echo "Des contrôles ont échoué."; fi
exit $FAIL
