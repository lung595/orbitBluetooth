#!/usr/bin/env python3
"""Orbit uninstall sweep: erases what the shell keeps for Orbit once it is
uninstalled, so that removing the plugin leaves nothing (value 12, D259).

DMS deletes the plugin folder but keeps everything it stored for it: the
entry in plugin_settings.json, the widgets in every bar, the Control Center
tile, the desktop widgets and their positions. So when Orbit is unloaded and
its plugin.json is gone, components/UninstallSweep.qml starts this script.
The plugin folder no longer exists by then, so the script is passed from
memory with "python3 -c" and depends on nothing in it:

    python3 -c <this file> <plugin id> <plugin.json> <cache dir>
            <settings.json> <plugin_settings.json> <session.json>

It waits a few seconds and checks again, because an update may delete the
folder and clone it back: nothing is erased if plugin.json came back.
The shell watches these three files and reloads them when they change, so
editing them here is the same as a user editing them by hand. Each file is
written atomically and only if something of Orbit's was found in it.
Nothing is printed and nothing is sent anywhere.
"""
import json
import os
import re
import shutil
import sys
import tempfile
import time

# Long enough for an update to clone the folder back
GRACE_SECONDS = 4

SIDES = ("leftWidgets", "centerWidgets", "rightWidgets")


def mine(plugin_id, value):
    """True for this plugin's widget ids: "<id>", "<id>:<variant>" and the
    Control Center's "plugin_<id>"."""
    text = str(value)
    for prefix in (plugin_id, "plugin_" + plugin_id):
        if text == prefix or text.startswith(prefix + ":"):
            return True
    return False


def widget_id(widget):
    return widget.get("id") if isinstance(widget, dict) else widget


def drop_plugin_settings(plugin_id, data):
    if not isinstance(data, dict) or plugin_id not in data:
        return False
    del data[plugin_id]
    return True


def drop_widgets(plugin_id, data):
    """Removes the plugin from the bars, the Control Center and the desktop.
    Returns (changed, ids of the removed desktop widgets)."""
    if not isinstance(data, dict):
        return False, []
    changed = False
    for bar in data.get("barConfigs") or []:
        if not isinstance(bar, dict):
            continue
        for side in SIDES:
            items = bar.get(side)
            if not isinstance(items, list):
                continue
            kept = [w for w in items if not mine(plugin_id, widget_id(w))]
            if len(kept) != len(items):
                bar[side] = kept
                changed = True
    tiles = data.get("controlCenterWidgets")
    if isinstance(tiles, list):
        kept = [w for w in tiles if not mine(plugin_id, widget_id(w))]
        if len(kept) != len(tiles):
            data["controlCenterWidgets"] = kept
            changed = True
    removed = []
    desktop = data.get("desktopWidgetInstances")
    if isinstance(desktop, list):
        kept = []
        for inst in desktop:
            if isinstance(inst, dict) and mine(plugin_id, inst.get("widgetType")):
                removed.append(inst.get("id"))
            else:
                kept.append(inst)
        if removed:
            data["desktopWidgetInstances"] = kept
            changed = True
    return changed, removed


def drop_positions(instance_ids, data):
    positions = data.get("desktopWidgetInstancePositions") if isinstance(data, dict) else None
    if not isinstance(positions, dict):
        return False
    found = [i for i in instance_ids if i in positions]
    for i in found:
        del positions[i]
    return bool(found)


def edit(path, change):
    """Loads a JSON file, applies change(data) -> bool and, when it returns
    True, writes it back atomically with the same permissions. A missing or
    unreadable file is left alone."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    result = change(data)
    if not (result[0] if isinstance(result, tuple) else result):
        return result
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".orbit-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            # Same layout as the shell's JSON.stringify(data, null, 2)
            json.dump(data, f, indent=2, ensure_ascii=False)
        shutil.copymode(path, tmp)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
    return result


def valid(plugin_id, manifest, cache, files):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", plugin_id):
        return False
    if os.path.basename(manifest) != "plugin.json":
        return False
    # Only ever deletes a folder named after the plugin
    if os.path.basename(cache.rstrip("/")) != plugin_id:
        return False
    return all(os.path.isabs(p) for p in [manifest, cache] + files)


def sweep(plugin_id, manifest, cache, settings, plugin_settings, session, grace=GRACE_SECONDS):
    """Returns True when the plugin was found uninstalled and swept."""
    if not valid(plugin_id, manifest, cache, [settings, plugin_settings, session]):
        return False
    time.sleep(grace)
    if os.path.exists(manifest):
        return False
    shutil.rmtree(cache, ignore_errors=True)
    edit(plugin_settings, lambda d: drop_plugin_settings(plugin_id, d))
    result = edit(settings, lambda d: drop_widgets(plugin_id, d))
    removed = result[1] if isinstance(result, tuple) else []
    if removed:
        edit(session, lambda d: drop_positions(removed, d))
    return True


if __name__ == "__main__":
    if len(sys.argv) == 7:
        sweep(*sys.argv[1:7])
