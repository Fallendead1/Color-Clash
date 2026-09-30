"""SEC-10: scan everything a client can read in the PRODUCTION build for credentials, unsafe dynamic code and
unexpected network surface.

Client-readable = scripts under ReplicatedStorage, ReplicatedFirst, StarterPlayer, StarterGui, StarterPack and
Workspace. Server scripts (ServerScriptService, ServerStorage) are scanned for credentials only.

Usage (repo root):  python tools/scan_client_surface.py build/production.rbxlx
Exit code 1 when anything is found. Standard library only.
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET

CLIENT_ROOTS = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "StarterPack", "Workspace"}

# Credentials / secrets anywhere (client or server).
SECRET_PATTERNS = [
    (r"(?i)api[_-]?key\s*[=:]", "api key assignment"),
    (r"(?i)\bsecret\s*[=:]\s*[\"']", "secret literal"),
    (r"(?i)password\s*[=:]\s*[\"']", "password literal"),
    (r"(?i)\btoken\s*[=:]\s*[\"'][A-Za-z0-9_\-\.]{12,}", "token literal"),
    (r"(?i)discord(app)?\.com/api/webhooks", "webhook url"),
    (r"(?i)bearer\s+[A-Za-z0-9_\-\.]{12,}", "bearer credential"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key"),
    (r"(?i)\.ROBLOSECURITY", "roblox cookie"),
]

# Unsafe dynamic code or surface in client-readable scripts.
CLIENT_PATTERNS = [
    (r"\bloadstring\s*\(", "loadstring"),
    (r"\b[gs]etfenv\s*\(", "getfenv/setfenv"),
    (r"\brequire\s*\(\s*\d+\s*\)", "require by asset id"),
    (r"Instance\.new\(\s*[\"']RemoteFunction[\"']", "RemoteFunction created"),
    (r"(?i)GiveUltimate|SetWinner|TeleportAnywhere", "debug command name"),
]


def scripts(root: ET.Element):
    """Yields (path, class, source) for every script item, with its ancestor path."""

    def walk(item: ET.Element, path: list[str]):
        cls = item.get("class", "")
        props = item.find("Properties")
        name = ""
        source = None
        if props is not None:
            for p in props:
                if p.get("name") == "Name":
                    name = p.text or ""
                elif p.get("name") == "Source":
                    source = p.text or ""
        here = path + [name or cls]
        if source is not None and cls in ("Script", "LocalScript", "ModuleScript"):
            yield "/".join(here), cls, source
        for child in item.findall("Item"):
            yield from walk(child, here)

    for top in root.findall("Item"):
        yield from walk(top, [])


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "build/production.rbxlx"
    root = ET.parse(path).getroot()
    findings = []
    count = 0
    client_count = 0
    for spath, cls, source in scripts(root):
        count += 1
        service = spath.split("/", 1)[0]
        is_client = service in CLIENT_ROOTS
        if is_client:
            client_count += 1
        patterns = SECRET_PATTERNS + (CLIENT_PATTERNS if is_client else [])
        for pattern, label in patterns:
            for m in re.finditer(pattern, source):
                line = source.count("\n", 0, m.start()) + 1
                findings.append(f"{spath}:{line}: {label}")
    print(f"scanned {count} scripts ({client_count} client-readable) in {path}")
    for f in findings:
        print("FOUND", f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
