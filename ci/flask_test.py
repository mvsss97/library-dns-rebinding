#!/usr/bin/env python3
"""Vérifie que les deux applications Flask du scénario répondent correctement, et que
l'endpoint de correction /flag ne délivre le flag que dans la bonne condition.
Utilise le client de test Flask (aucun réseau)."""
import json
import os
import sys

FLAG = "CiTestFlag123456"
os.environ.update(SEED_DNS_FLAG=FLAG, SEED_ATTACKER_DOMAIN="attacker32.com", SEED_ATTACK_MIN="88")

IOT_SRC = "provisioning/roles/iot-server/files/user_vm"
ATK_SRC = "provisioning/roles/attacker-server/files/attacker_vm"
sys.path.insert(0, IOT_SRC)
sys.path.insert(0, ATK_SRC)
from rebind_iot import create_app as iot_create      # noqa: E402
from rebind_malware import create_app as atk_create  # noqa: E402

FAIL = 0


def check(cond, label):
    global FAIL
    print(("  [OK]   " if cond else "  [FAIL] ") + label)
    FAIL = FAIL or (0 if cond else 1)


def client():
    return iot_create().test_client()


def pwd(c):
    return json.loads(c.get("/password").data)["password"]


def set_temp(c, value, host):
    return c.post("/temperature?value=%d&password=%s" % (value, pwd(c)), headers={"Host": host})


print("Serveur du thermostat")
c = client()
check(json.loads(c.get("/temperature").data)["temperature"] == 20, "température de départ = 20")
check(c.get("/").status_code == 200 and c.get("/change").status_code == 200, "pages servies")
check(c.post("/temperature?value=99&password=faux").status_code == 401, "mot de passe incorrect refusé")

print("\nEndpoint de correction /flag")
# régler la température depuis la même origine ne délivre pas le flag
c = client()
check(set_temp(c, 99, "www.seedIoT32.com:8080").status_code == 200, "réglage accepté")
check(c.get("/flag").status_code == 403, "flag non délivré (même origine)")
# condition de réussite du TP : la valeur attendue par la plateforme est délivrée
c = client()
set_temp(c, 99, "www.attacker32.com:8080")
fr = c.get("/flag")
check(fr.status_code == 200 and json.loads(fr.data).get("flag") == FLAG, "flag de la sandbox délivré dans la bonne condition")
# température trop basse : non délivré
c = client()
set_temp(c, 50, "www.attacker32.com:8080")
check(c.get("/flag").status_code == 403, "flag non délivré si la température reste basse")

print("\nServeur web de l'énoncé")
a = atk_create().test_client()
check(a.get("/").status_code == 200 and a.get("/change").status_code == 200, "pages servies")

sys.exit(FAIL)
