"""Configure Supabase Auth to send emails through Gmail SMTP (Google App Password).

Supabase Auth (not the Flutter app) sends verification and password-reset
emails. This script updates the Supabase project's auth config via the
Management API so that it:
  * requires email confirmation on signup ("Confirm email" ON),
  * sends all auth emails through Gmail SMTP using the App Password,
  * allows the app's deep-link redirect URLs.

The Gmail account can be different from the account you log in to Supabase with.

Usage (from the project root):
    py tool/configure_supabase_email.py

Needs a Supabase personal access token (https://supabase.com/dashboard/account/tokens),
taken from the SUPABASE_ACCESS_TOKEN env var or prompted for.
Reads SUPABASE_URL from .env and SMTP_* from .env.smtp.
"""

import getpass
import json
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REDIRECT_URLS = ["parklagbee://login", "parklagbee://reset-password"]
API = "https://api.supabase.com/v1/projects/{ref}/config/auth"


def load_env(path):
    env = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip("'\"")
    return env


def request(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "User-Agent": "parklagbee-config-script",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} failed: HTTP {e.code}: {e.read().decode(errors='replace')}")


def main():
    app_env = load_env(os.path.join(ROOT, ".env"))
    smtp_env = load_env(os.path.join(ROOT, ".env.smtp"))

    m = re.match(r"https://([a-z0-9]+)\.supabase\.co", app_env.get("SUPABASE_URL", ""))
    if not m:
        sys.exit("Could not read project ref from SUPABASE_URL in .env")
    ref = m.group(1)

    email = smtp_env.get("SMTP_EMAIL", "")
    password = smtp_env.get("SMTP_PASSWORD", "").replace(" ", "")
    if not email or len(password) != 16:
        sys.exit("SMTP_EMAIL / SMTP_PASSWORD (16-char app password) missing in .env.smtp")

    token = os.environ.get("SUPABASE_ACCESS_TOKEN") or getpass.getpass(
        "Supabase personal access token (input hidden): ").strip()
    if not token:
        sys.exit("No access token provided.")

    url = API.format(ref=ref)
    current = request("GET", url, token)
    allow = [u for u in (current.get("uri_allow_list") or "").split(",") if u.strip()]
    for u in REDIRECT_URLS:
        if u not in allow:
            allow.append(u)

    update = {
        "external_email_enabled": True,
        "mailer_autoconfirm": False,  # "Confirm email" ON -> verification emails are sent
        "smtp_host": smtp_env.get("SMTP_HOST", "smtp.gmail.com"),
        "smtp_port": smtp_env.get("SMTP_PORT", "465"),
        "smtp_user": email,
        "smtp_pass": password,
        "smtp_admin_email": email,  # Gmail requires From == the authenticated account
        "smtp_sender_name": smtp_env.get("SMTP_SENDER_NAME", "ParkLagbee Support"),
        "uri_allow_list": ",".join(allow),
    }
    # Supabase caps custom-SMTP sends at 30/hour by default; leave higher values alone.
    if (current.get("rate_limit_email_sent") or 0) < 30:
        update["rate_limit_email_sent"] = 30

    print(f"Updating auth config for project {ref}:")
    for k, v in update.items():
        print(f"  {k} = {'****' if k == 'smtp_pass' else v}")
    request("PATCH", url, token, update)

    after = request("GET", url, token)
    ok = (after.get("smtp_host") == update["smtp_host"]
          and after.get("smtp_user") == email
          and after.get("mailer_autoconfirm") is False)
    print("Done. Custom SMTP active." if ok else "PATCH sent but config did not read back as expected:")
    if not ok:
        print({k: after.get(k) for k in ("smtp_host", "smtp_user", "mailer_autoconfirm")})


if __name__ == "__main__":
    main()
