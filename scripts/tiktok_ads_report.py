#!/usr/bin/env python3
"""Rapport de performance TikTok Ads en ligne de commande.

Aucune dépendance externe : stdlib uniquement.
Les identifiants (App ID, App Secret, access token) sont stockés dans le
keychain macOS, jamais dans un fichier du dépôt.

Usage :
    ./scripts/tiktok_ads_report.py auth               # première fois : autorise le compte
    ./scripts/tiktok_ads_report.py accounts           # liste les comptes publicitaires
    ./scripts/tiktok_ads_report.py report             # 30 derniers jours, par campagne
    ./scripts/tiktok_ads_report.py report --days 7
    ./scripts/tiktok_ads_report.py report --daily     # ventilation par jour (max 30 j)
    ./scripts/tiktok_ads_report.py report --level ad
"""

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, timedelta
from getpass import getpass

API = "https://business-api.tiktok.com/open_api/v1.3"
KEYCHAIN_SERVICE = "goldn-tiktok-ads"

# Niveaux de rapport : data_level et dimension d'agrégation associée.
LEVELS = {
    "campaign": ("AUCTION_CAMPAIGN", "campaign_id", "campaign_name"),
    "adgroup": ("AUCTION_ADGROUP", "adgroup_id", "adgroup_name"),
    "ad": ("AUCTION_AD", "ad_id", "ad_name"),
    "account": ("AUCTION_ADVERTISER", "advertiser_id", None),
}

METRICS = [
    "spend",
    "impressions",
    "clicks",
    "ctr",
    "cpc",
    "cpm",
    "conversion",
    "cost_per_conversion",
]


# --- keychain ---------------------------------------------------------------

def kc_get(account):
    """Lit une valeur du keychain, ou None si absente."""
    r = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE,
         "-a", account, "-w"],
        capture_output=True, text=True,
    )
    return r.stdout.strip() or None if r.returncode == 0 else None


def kc_set(account, value):
    # Note : la valeur transite par argv, donc visible dans `ps` le temps de
    # l'appel. Acceptable sur une machine personnelle mono-utilisateur.
    subprocess.run(
        ["security", "add-generic-password", "-U", "-s", KEYCHAIN_SERVICE,
         "-a", account, "-w", value],
        check=True, capture_output=True,
    )


# --- appels API -------------------------------------------------------------

def api_get(path, params, token):
    qs = urllib.parse.urlencode(
        {k: (json.dumps(v) if isinstance(v, (list, dict)) else v)
         for k, v in params.items() if v is not None}
    )
    req = urllib.request.Request(
        f"{API}{path}?{qs}", headers={"Access-Token": token})
    return _send(req)


def api_post(path, body, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Access-Token"] = token
    req = urllib.request.Request(
        f"{API}{path}", data=json.dumps(body).encode(),
        headers=headers, method="POST")
    return _send(req)


def _send(req):
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            payload = json.load(r)
    except urllib.error.HTTPError as e:
        # TikTok renvoie ses erreurs métier en 200 ; un vrai HTTP != 200 est
        # une erreur de transport qu'on veut voir telle quelle.
        sys.exit(f"Erreur HTTP {e.code} : {e.read().decode()[:400]}")
    except urllib.error.URLError as e:
        sys.exit(f"Réseau injoignable : {e.reason}")

    if payload.get("code") != 0:
        sys.exit(f"Erreur API {payload.get('code')} : {payload.get('message')}\n"
                 f"request_id : {payload.get('request_id')}")
    return payload.get("data", {})


# --- authentification -------------------------------------------------------

def cmd_auth(_args):
    print("=== Autorisation TikTok Ads ===\n")
    print("1. Ouvre https://business-api.tiktok.com/portal/apps")
    print("2. Clique sur ton app, puis copie son URL d'autorisation")
    print("   (libellée « Advertiser authorization URL » ou similaire)\n")

    auth_url = input("Colle l'URL d'autorisation ici : ").strip()
    if not auth_url.startswith("http"):
        sys.exit("URL invalide.")

    app_id = kc_get("app_id")
    if not app_id:
        app_id = input("\nApp ID : ").strip()
    secret = getpass("App Secret (masqué à la saisie) : ").strip()
    if not (app_id and secret):
        sys.exit("App ID et App Secret sont requis.")

    print("\n3. Ouvre cette URL dans ton navigateur et autorise ton compte "
          "publicitaire :\n")
    print(f"   {auth_url}\n")
    print("4. Tu seras redirigé vers une page dont l'URL contient "
          "« auth_code=... »")
    print("   (la page peut afficher une erreur, c'est normal — seule l'URL "
          "compte)\n")

    redirected = input("Colle l'URL complète de redirection : ").strip()
    qs = urllib.parse.parse_qs(urllib.parse.urlparse(redirected).query)
    auth_code = (qs.get("auth_code") or qs.get("code") or [None])[0]
    if not auth_code:
        sys.exit("Aucun auth_code trouvé dans cette URL.")

    print("\nÉchange du code contre un access token…")
    data = api_post("/oauth2/access_token/", {
        "app_id": app_id,
        "secret": secret,
        "auth_code": auth_code,
        "grant_type": "auth_code",
    })

    token = data.get("access_token")
    if not token:
        sys.exit(f"Pas d'access_token dans la réponse : {data}")

    kc_set("app_id", app_id)
    kc_set("secret", secret)
    kc_set("access_token", token)

    print("\n✓ Token obtenu et enregistré dans le keychain.")

    ids = [str(i) for i in (data.get("advertiser_ids") or [])]
    print(f"  Comptes publicitaires autorisés : {len(ids)}")

    # Ne jamais retenir un compte au hasard : plusieurs comptes autorisés
    # peuvent être vides, ce qui donne un rapport vide trompeur.
    chosen = _pick_default_account(ids, token)
    if chosen:
        kc_set("advertiser_id", chosen)
        print(f"  Compte par défaut : {chosen}")

    print("\nTu peux maintenant lancer :  ./scripts/tiktok_ads_report.py report")


def _pick_default_account(ids, token):
    """Choisit comme compte par défaut le seul qui contienne des campagnes."""
    if not ids:
        return None
    if len(ids) == 1:
        return ids[0]

    with_campaigns = [i for i in ids if count_campaigns(i, token)]
    if len(with_campaigns) == 1:
        print(f"  ({len(ids)} comptes autorisés, un seul contient des "
              f"campagnes)")
        return with_campaigns[0]

    print("\n  Plusieurs comptes autorisés :")
    for i in ids:
        n = count_campaigns(i, token)
        print(f"    {i}  —  {n if n is not None else '?'} campagne(s)")
    print("  Choisis-en un avec :  ./scripts/tiktok_ads_report.py use <id>")
    return with_campaigns[0] if with_campaigns else None


def count_campaigns(advertiser_id, token):
    """Nombre de campagnes d'un compte, ou None si l'appel échoue."""
    try:
        qs = urllib.parse.urlencode(
            {"advertiser_id": advertiser_id, "page_size": 1})
        req = urllib.request.Request(
            f"{API}/campaign/get/?{qs}", headers={"Access-Token": token})
        with urllib.request.urlopen(req, timeout=30) as r:
            payload = json.load(r)
        if payload.get("code") != 0:
            return None
        return payload.get("data", {}).get("page_info", {}).get("total_number")
    except Exception:
        return None


def cmd_use(args):
    token = require_token()
    n = count_campaigns(args.advertiser_id, token)
    if n is None:
        sys.exit(f"Compte {args.advertiser_id} inaccessible avec ce token. "
                 f"Vérifie l'ID avec « accounts ».")
    kc_set("advertiser_id", args.advertiser_id)
    print(f"✓ Compte par défaut : {args.advertiser_id} ({n} campagne(s))")


def require_token():
    token = kc_get("access_token")
    if not token:
        sys.exit("Pas encore autorisé. Lance d'abord : "
                 "./scripts/tiktok_ads_report.py auth")
    return token


def resolve_advertiser(explicit):
    if explicit:
        return explicit
    stored = kc_get("advertiser_id")
    if stored:
        return stored
    sys.exit("Aucun compte publicitaire connu. Lance « accounts » puis "
             "passe --advertiser-id.")


# --- commandes --------------------------------------------------------------

def cmd_accounts(_args):
    token = require_token()
    app_id, secret = kc_get("app_id"), kc_get("secret")
    if not (app_id and secret):
        sys.exit("App ID / Secret absents du keychain. Relance « auth ».")

    data = api_get("/oauth2/advertiser/get/",
                   {"app_id": app_id, "secret": secret}, token)
    rows = data.get("list", [])
    if not rows:
        print("Aucun compte publicitaire autorisé sur cette app.")
        return

    current = kc_get("advertiser_id")
    print(f"{len(rows)} compte(s) publicitaire(s) :\n")
    for r in rows:
        adv = str(r.get("advertiser_id"))
        n = count_campaigns(adv, token)
        mark = " ← par défaut" if adv == current else ""
        print(f"  {adv}  {str(r.get('advertiser_name', '')):20}  "
              f"{n if n is not None else '?'} campagne(s){mark}")
    print("\nChanger de compte :  ./scripts/tiktok_ads_report.py use <id>")


def cmd_report(args):
    token = require_token()
    advertiser_id = resolve_advertiser(args.advertiser_id)

    data_level, id_dim, name_metric = LEVELS[args.level]

    # La doc impose : dimensions contenant stat_time_day => 30 jours maximum,
    # sinon 365 jours maximum.
    max_days = 30 if args.daily else 365
    if args.days > max_days:
        sys.exit(f"--days {args.days} dépasse la limite de l'API "
                 f"({max_days} jours dans ce mode).")

    end = date.today()
    start = end - timedelta(days=args.days - 1)

    dimensions = [id_dim]
    if args.daily:
        dimensions.append("stat_time_day")

    metrics = list(METRICS)
    if name_metric:
        metrics.insert(0, name_metric)

    data = api_get("/report/integrated/get/", {
        "advertiser_id": advertiser_id,
        "report_type": "BASIC",
        "service_type": "AUCTION",
        "data_level": data_level,
        "dimensions": dimensions,
        "metrics": metrics,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "order_field": "spend",
        "order_type": "DESC",
        "page": 1,
        "page_size": 1000,
    }, token)

    rows = data.get("list", [])
    if not rows:
        print(f"Aucune donnée entre {start} et {end} pour le compte "
              f"{advertiser_id}.")
        n = count_campaigns(advertiser_id, token)
        if n == 0:
            print("\nCe compte ne contient aucune campagne — c'est "
                  "probablement le mauvais compte.")
            print("Lance « accounts » pour voir lequel contient tes "
                  "campagnes, puis « use <id> ».")
        else:
            print(f"\nCe compte contient {n} campagne(s), mais aucune "
                  f"dépense sur cette période.")
            print("Essaie une plage plus large :  report --days 365")
        return

    print(f"\nTikTok Ads — niveau {args.level} — du {start} au {end}")
    print(f"Compte {advertiser_id}\n")
    _print_table(rows, id_dim, name_metric, args.daily)


def _print_table(rows, id_dim, name_metric, daily):
    header = ["Jour"] if daily else []
    header += ["Nom" if name_metric else "ID", "Dépense", "Impr.", "Clics",
               "CTR %", "CPC", "CPM", "Conv.", "Coût/conv."]

    table = []
    totals = {"spend": 0.0, "impressions": 0, "clicks": 0, "conversion": 0.0}
    for r in rows:
        d, m = r.get("dimensions", {}), r.get("metrics", {})
        line = []
        if daily:
            line.append(str(d.get("stat_time_day", ""))[:10])
        label = m.get(name_metric) if name_metric else d.get(id_dim)
        line.append(str(label or d.get(id_dim, ""))[:32])
        line += [_num(m.get("spend"), 2), _num(m.get("impressions"), 0),
                 _num(m.get("clicks"), 0), _num(m.get("ctr"), 2),
                 _num(m.get("cpc"), 2), _num(m.get("cpm"), 2),
                 _num(m.get("conversion"), 0),
                 _num(m.get("cost_per_conversion"), 2)]
        table.append(line)

        totals["spend"] += _f(m.get("spend"))
        totals["impressions"] += int(_f(m.get("impressions")))
        totals["clicks"] += int(_f(m.get("clicks")))
        totals["conversion"] += _f(m.get("conversion"))

    widths = [max(len(str(c)) for c in col) for col in zip(header, *table)]
    fmt = "  ".join(f"{{:{'<' if i == (1 if daily else 0) else '>'}{w}}}"
                    for i, w in enumerate(widths))
    print(fmt.format(*header))
    print("  ".join("-" * w for w in widths))
    for line in table:
        print(fmt.format(*line))

    ctr = (totals["clicks"] / totals["impressions"] * 100
           if totals["impressions"] else 0)
    cpa = (totals["spend"] / totals["conversion"]
           if totals["conversion"] else 0)
    print(f"\nTOTAL  dépense {totals['spend']:.2f}   "
          f"impressions {totals['impressions']:,}   "
          f"clics {totals['clicks']:,}   CTR {ctr:.2f} %   "
          f"conversions {totals['conversion']:.0f}   "
          f"coût/conv. {cpa:.2f}")


def _f(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _num(v, decimals):
    return f"{_f(v):,.{decimals}f}"


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("auth", help="autoriser un compte publicitaire").set_defaults(
        func=cmd_auth)
    sub.add_parser("accounts", help="lister les comptes publicitaires").set_defaults(
        func=cmd_accounts)

    u = sub.add_parser("use", help="choisir le compte publicitaire par défaut")
    u.add_argument("advertiser_id")
    u.set_defaults(func=cmd_use)

    r = sub.add_parser("report", help="afficher les performances")
    r.add_argument("--days", type=int, default=30,
                   help="nombre de jours à couvrir (défaut : 30)")
    r.add_argument("--daily", action="store_true",
                   help="ventiler par jour (30 jours maximum)")
    r.add_argument("--level", choices=list(LEVELS), default="campaign",
                   help="niveau d'agrégation (défaut : campaign)")
    r.add_argument("--advertiser-id",
                   help="compte publicitaire à interroger")
    r.set_defaults(func=cmd_report)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
