#!/usr/bin/env python3
import json
import os
import re
import secrets
import subprocess
import sys

if len(sys.argv) != 2 or sys.argv[1] not in ("dev", "prod"):
    sys.exit("Uso: python3 platform/scripts/init-redis-secret.py dev|prod")

cluster = os.environ.get("KIND_CLUSTER_NAME") or "kiratech-l2"
if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", cluster):
    sys.exit("ERRORE: nome cluster non valido.")

namespace = "boutique-" + sys.argv[1]
command = [
    "kubectl", "--context", f"kind-{cluster}",
    "-n", namespace,
]

existing = subprocess.run(
    command + [
        "get", "secret", "redis-auth",
        "--ignore-not-found", "-o", "name",
    ],
    check=True,
    capture_output=True,
    text=True,
)

if existing.stdout.strip():
    print(f"Secret redis-auth già presente in {namespace}: nessuna modifica.")
    sys.exit(0)

password = secrets.token_hex(32)
document = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "redis-auth", "namespace": namespace},
    "type": "Opaque",
    "stringData": {
        "password": password,
        "connection-string": (
            f"redis-cart:6379,password={password},abortConnect=false"
        ),
        "redis.conf": (
            "bind 0.0.0.0\n"
            "protected-mode yes\n"
            "port 6379\n"
            "dir /data\n"
            "save \"\"\n"
            "appendonly no\n"
            f"requirepass {password}\n"
        ),
    },
}

result = subprocess.run(
    command + ["create", "-f", "-"],
    input=json.dumps(document),
    capture_output=True,
    text=True,
)
if result.returncode:
    sys.exit(
        "Creazione non riuscita. Dettagli soppressi per evitare "
        "di mostrare credenziali; controllare accesso e stato del cluster."
    )

print(f"OK: Secret redis-auth creato in {namespace}, credenziale non mostrata.")
