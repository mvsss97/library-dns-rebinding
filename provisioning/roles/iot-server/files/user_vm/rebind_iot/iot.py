# Serveur IoT (thermostat) du SEED Lab « DNS Rebinding Attack ».
#
# Basé sur le code original de SEED Labs (Wenliang Du) — voir ATTRIBUTION.txt.
# Un seul ajout pour CyberRangeCZ : la route /flag. Elle ne révèle le flag de la
# sandbox que lorsqu'une requête de réglage de température atteint CE serveur en
# portant le nom d'hôte de l'ATTAQUANT (www.attacker32.com) : c'est la signature
# même du DNS rebinding. Déplacer le curseur du thermostat sur sa propre page
# (même origine, Host: www.seedIoT32.com) ne débloque jamais le flag.

import os
from flask import (
    Blueprint, render_template, request, current_app as app, json
)


bp = Blueprint('iot', __name__)


def _attacker_domain():
    return os.environ.get('SEED_ATTACKER_DOMAIN', 'attacker32.com').lower()


def _attack_min():
    try:
        return int(os.environ.get('SEED_ATTACK_MIN', '88'))
    except (TypeError, ValueError):
        return 88


@bp.route('/password', methods=('GET',))
def password():
    data = {
        'password': app.password
    }
    return app.response_class(
        response=json.dumps(data),
        mimetype='application/json; charset=utf-8'
    )


@bp.route('/', methods=('GET',))
def index():
    return render_template('index.html')


@bp.route('/change', methods=('GET',))
def change():
    return render_template('change.html')


@bp.route('/temperature', methods=('GET',))
def get_temperature():
    data = {
        'temperature': app.temperature
    }

    response = app.response_class(
        response=json.dumps(data),
        mimetype='application/json; charset=utf-8'
    )
    return response


@bp.route('/temperature', methods=('POST',))
def set_temperature():
    l_password = request.args.get('password', None)
    if l_password != app.password:
        return app.response_class(
            response='wrong password',
            status=401
        )
    temperature = request.args.get('value', None)
    if not temperature:
        return app.response_class(
            response='not value',
            status=400,
            mimetype='text/plain'
        )
    temperature = int(temperature)
    if app.config['LOWEST'] <= temperature <= app.config['HIGHEST']:
        app.temperature = temperature

        # Détecteur de DNS rebinding : une requête qui règle la température mais qui
        # arrive avec le nom d'hôte de l'attaquant prouve que le navigateur a bien
        # été « rebindé » de la page de l'attaquant vers ce serveur IoT.
        host = (request.host or '').split(':')[0].lower()
        attacker = _attacker_domain()
        if temperature >= _attack_min() and (host == attacker or host.endswith('.' + attacker)):
            app.attack_unlocked = True

        data = {'temperature': temperature}
        return app.response_class(
            response=json.dumps(data),
            mimetype='application/json; charset=utf-8'
        )
    else:
        return app.response_class(
            response='temperature out of bound',
            status=400,
            mimetype='text/plain'
        )


@bp.route('/flag', methods=('GET',))
def flag():
    if getattr(app, 'attack_unlocked', False):
        data = {'flag': os.environ.get('SEED_DNS_FLAG', '')}
        return app.response_class(
            response=json.dumps(data),
            mimetype='application/json; charset=utf-8'
        )
    return app.response_class(
        response="Flag verrouille : reglez le thermostat a >= %d C via l'attaque DNS "
                 "rebinding (page de l'attaquant), puis rechargez cette page." % _attack_min(),
        status=403,
        mimetype='text/plain; charset=utf-8'
    )
