import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Uninstalling leaves nothing behind (value 12, D259).
// DMS deletes the plugin folder but keeps what it stored for the plugin
// (settings, bar, Control Center and desktop widgets). When Orbit is
// unloaded, it checks whether its own plugin.json is gone; disabling,
// reloading or quitting the shell keep the folder, so nothing happens then.
// If it is gone, uninstall/orbit_uninstall.py erases those traces. The
// folder no longer exists at that point, so the script is read when Orbit
// loads and handed over from memory. It runs detached (it must outlive the
// plugin) and waits a little first, since an update may re-clone the folder.
// At rest this costs nothing: no timer, no process, one small string.
Item {
    id: root

    required property string pluginId

    // Captured while the plugin is loaded: DMS forgets its path on unload
    property string manifest: ""
    property string script: ""

    // The opt-in picture cache (XDG cache, as pictures/orbit_pictures.py)
    readonly property string cacheDir: Paths.strip(Paths.xdgCache) + "/" + pluginId
    // The shell's files that keep the plugin's widgets and their positions
    readonly property string settingsPath: Paths.strip(Paths.config) + "/settings.json"
    readonly property string sessionPath: Paths.strip(Paths.state) + "/session.json"

    FileView {
        id: source
        path: Paths.strip(Qt.resolvedUrl("../../uninstall/orbit_uninstall.py"))
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: probe
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        const dir = PluginService.getPluginPath(pluginId);
        if (dir)
            manifest = dir + "/plugin.json";
        script = source.text();
    }

    Component.onDestruction: {
        if (!manifest || !script)
            return;
        probe.path = manifest;
        probe.reload();
        if (probe.text() !== "")
            return;
        // An argument list, never a shell string; the script validates them
        Quickshell.execDetached(["python3", "-E", "-s", "-c", script, pluginId, manifest, cacheDir, settingsPath, SettingsData.pluginSettingsPath, sessionPath]);
    }
}
