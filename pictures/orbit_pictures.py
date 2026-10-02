#!/usr/bin/env python3
"""Orbit pictures helper: finds a picture of a device model online.

Started by OrbitBluetoothDaemon.qml only when the user turned on
"Real device pictures" (off by default), never by itself:

    python3 orbit_pictures.py find <device model name>
    python3 orbit_pictures.py clear

This is the only part of Orbit that uses the network. What it contacts,
in this order, stopping at the first match:
1. Wikimedia Commons, real photos of phones, TVs, headphones...
   - https://commons.wikimedia.org/w/api.php   (the model name, nothing else)
   - https://upload.wikimedia.org/...           (the picture of the best match)
2. Sketchfab, previews of 3D models, for what Commons does not have
   - https://api.sketchfab.com/v3/search        (the model name, nothing else)
   - https://media.sketchfab.com/...            (the preview of the best match)
Never sent: the Bluetooth address, the machine name, any other device.

Only free licenses are used (Creative Commons, public domain), and the
author is credited in the detail card. A result counts as a match only when
its title contains the device's model name, so a wrong picture is rarer
than a missing one.

Everything found is cached in ~/.cache/orbitBluetooth/pictures (one image
and one small credit file per model, also for "nothing found"), so each
model is looked up once. "clear" empties that folder.

stdout: one JSON line {"name": ..., "image": path or null, "credit": {...}}.

Inspired by: the public API documentation of Wikimedia Commons
(https://www.mediawiki.org/wiki/API:Main_page) and Sketchfab
(https://sketchfab.com/developers). Thanks to the photographers and 3D
artists whose free work makes this possible.
"""

import json
import os
import re
import shutil
import sys
import time
import urllib.parse
import urllib.request

COMMONS_API = "https://commons.wikimedia.org/w/api.php"
SKETCHFAB_API = "https://api.sketchfab.com/v3/search"
# Searched in this order; the first license with a match wins
LICENSES = (("cc0", "CC0"), ("by", "CC BY"), ("by-sa", "CC BY-SA"))
IMAGE_HOSTS = ("media.sketchfab.com", "upload.wikimedia.org")
MAX_BYTES = 4 * 1024 * 1024
TIMEOUT = 10
# A model nobody published a picture of is looked up again after a week
NONE_TTL = 7 * 24 * 3600
WANTED_WIDTH = 400


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "orbitBluetooth", "pictures")


def compact(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def clean_name(name):
    """'Galaxy Buds2 Pro (A1B2)' -> 'Galaxy Buds2 Pro'."""
    return re.sub(r"\s*[\(\[][^\)\]]*[\)\]]\s*", " ", name).strip()


def slug(name):
    return compact(clean_name(name))[:80]


def needles(name):
    """What a model title must contain, from strict to the vendor-less form."""
    full = compact(clean_name(name))
    found = [full] if len(full) >= 4 else []
    short = re.sub(r"^(wh|wf)", "", full)
    if short != full and len(short) >= 6:
        found.append(short)
    return found


def matches(title, name):
    flat = compact(title)
    return any(n in flat for n in needles(name))


def pick_image(model):
    """Smallest preview that is still sharp enough, https on Sketchfab only."""
    images = (model.get("thumbnails") or {}).get("images") or []
    good = []
    for img in images:
        url = img.get("url") or ""
        parts = urllib.parse.urlsplit(url)
        if parts.scheme != "https" or (parts.hostname or "") not in IMAGE_HOSTS:
            continue
        good.append((img.get("width") or 0, url))
    if not good:
        return None
    big = sorted(w for w in good if w[0] >= WANTED_WIDTH)
    return (big[0] if big else max(good))[1]


def pick_sketchfab(results, name, license_label):
    """The first result whose title matches and that has a usable preview."""
    for model in results:
        if not matches(model.get("name") or "", name):
            continue
        url = pick_image(model)
        if not url:
            continue
        user = model.get("user") or {}
        return url, {
            "title": model.get("name") or "",
            "author": user.get("displayName") or user.get("username") or "",
            "license": license_label,
            "url": model.get("viewerUrl") or "",
            "source": "Sketchfab",
        }
    return None


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "orbitBluetooth/1.9 (open source, MIT; https://github.com/lung595/orbitBluetooth)"})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        data = response.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise OSError("image too large")
    return data


def strip_tags(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]*>", "", html or "")).strip()


def free_license(label):
    """CC BY, CC BY-SA, CC0 and public domain; never NC (non-commercial) or ND (no derivatives)."""
    if not re.match(r"(CC[ -]|Public domain|PD)", label or "", re.I):
        return False
    return not re.search(r"[ -](NC|ND)\b", label.upper())


def pick_commons(pages, name):
    """Best photo among Commons search results (same order as the search)."""
    for page in sorted(pages, key=lambda p: p.get("index", 0)):
        title = re.sub(r"^File:", "", page.get("title") or "")
        if not matches(title, name):
            continue
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata") or {}
        label = (meta.get("LicenseShortName") or {}).get("value") or ""
        if not free_license(label):
            continue
        url = pick_image({"thumbnails": {"images": [{"url": info.get("thumburl") or "", "width": info.get("thumbwidth") or 0}]}})
        if not url:
            continue
        return url, {
            "title": os.path.splitext(title)[0],
            "author": strip_tags((meta.get("Artist") or {}).get("value")),
            "license": label,
            "url": info.get("descriptionurl") or "",
            "source": "Wikimedia Commons",
        }
    return None


def search_commons(name):
    query = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6, "gsrlimit": 12,
        "gsrsearch": clean_name(name) + " filetype:bitmap", "prop": "imageinfo",
        "iiprop": "url|extmetadata", "iiurlwidth": WANTED_WIDTH,
    })
    pages = ((json.loads(get(COMMONS_API + "?" + query)).get("query") or {}).get("pages") or {}).values()
    return pick_commons(list(pages), name)


def search_sketchfab(name):
    for license_slug, label in LICENSES:
        query = urllib.parse.urlencode({"type": "models", "q": clean_name(name), "license": license_slug, "count": 24})
        results = json.loads(get(SKETCHFAB_API + "?" + query)).get("results") or []
        found = pick_sketchfab(results, name, label)
        if found:
            return found
    return None


def search(name):
    return search_commons(name) or search_sketchfab(name)


def find(name, folder=None):
    folder = folder or cache_dir()
    key = slug(name)
    if not key:
        return {"name": name, "image": None, "credit": None}
    image_path = os.path.join(folder, key + ".jpg")
    meta_path = os.path.join(folder, key + ".json")
    if os.path.exists(meta_path):
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
        if os.path.exists(image_path):
            return {"name": name, "image": image_path, "credit": meta}
        if time.time() - os.path.getmtime(meta_path) < NONE_TTL:
            return {"name": name, "image": None, "credit": None}
    found = None
    try:
        found = search(name)
        if found:
            data = get(found[0])
    except (OSError, ValueError):
        # Offline or rate limited: not remembered, so it is tried again later
        return {"name": name, "image": None, "credit": None}
    os.makedirs(folder, mode=0o700, exist_ok=True)
    # Made by an older version with the default (world-readable) mode
    os.chmod(folder, 0o700)
    if not found:
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump({}, f)
        os.chmod(meta_path, 0o600)
        return {"name": name, "image": None, "credit": None}
    with open(image_path, "wb") as f:
        f.write(data)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(found[1], f)
    # Private whatever the umask: the cache tells which devices were looked up
    os.chmod(image_path, 0o600)
    os.chmod(meta_path, 0o600)
    return {"name": name, "image": image_path, "credit": found[1]}


def main(argv):
    # The cache tells which devices were looked up: only this user may read it
    os.umask(0o077)
    if len(argv) == 2 and argv[1] == "clear":
        shutil.rmtree(cache_dir(), ignore_errors=True)
        return 0
    if len(argv) == 3 and argv[1] == "find":
        sys.stdout.write(json.dumps(find(argv[2]), separators=(",", ":")) + "\n")
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
