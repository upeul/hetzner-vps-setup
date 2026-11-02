#!/usr/bin/env python3
"""EU catalogue/pricing helper, not a location availability or stock check."""
import json
import os
import urllib.request

CEILING = float(os.environ.get("CEILING", "90"))
TOKEN = os.environ.get("HCLOUD_TOKEN", "")

url = "https://api.hetzner.cloud/v1/server_types"
headers = {}
if TOKEN:
    headers["Authorization"] = f"Bearer {TOKEN}"

data = {"server_types": []}
page = 1
while page is not None:
    req = urllib.request.Request(f"{url}?per_page=50&page={page}", headers=headers)
    with urllib.request.urlopen(req) as resp:
        result = json.load(resp)
    data["server_types"].extend(result["server_types"])
    page = result["meta"]["pagination"]["next_page"]

rows = []
for t in data.get("server_types", []):
    eu = None
    for p in t.get("prices", []):
        if p.get("location") in ("nbg1", "fsn1", "hel1"):
            eu = float(p["price_monthly"]["net"])
            break
    if eu is None:
        continue
    rows.append(
        (
            eu or 999.0,
            t["name"],
            t["cores"],
            t["memory"],
            t["disk"],
            t.get("architecture", "?"),
            t.get("cpu_type", "?"),
        )
    )

rows.sort()
print("Catalogue only: first EU location price, net EUR/month; no stock/availability guarantee.")
print(f"{'name':8} {'vCPU':>4} {'RAM':>5} {'disk':>5} {'EUR/mo':>7} arch/cpu")
for eu, name, cores, mem, disk, arch, cpu in rows:
    if eu <= CEILING:
        print(f"{name:8} {cores:4} {mem:5} {disk:5} {eu:7.2f} {arch}/{cpu}")
