#!/usr/bin/env python3
"""Update one app's newest version in source.json (used by CI after each build).

usage: update_source.py BUNDLE_ID VERSION BUILD SIZE DOWNLOAD_URL [NOTES]
"""
import json, sys, datetime, pathlib

bundle_id, version, build, size, url = sys.argv[1:6]
notes = sys.argv[6] if len(sys.argv) > 6 else "Bug fixes and improvements."
path = pathlib.Path(__file__).resolve().parents[2] / "source.json"
source = json.loads(path.read_text())

app = next(a for a in source["apps"] if a["bundleIdentifier"] == bundle_id)
entry = {
    "version": version,
    "buildVersion": build,
    "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "localizedDescription": notes,
    "downloadURL": url,
    "size": int(size),
    "minOSVersion": app["versions"][0].get("minOSVersion", "15.0") if app.get("versions") else "15.0",
}
app["versions"] = [entry]
path.write_text(json.dumps(source, indent=2) + "\n")
print(f"{bundle_id} -> {version} ({build})")
