import json
import os
import tempfile
import unittest

import orbit_uninstall as U

ID = "orbitBluetooth"


def write(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def read(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class Shell:
    """A fake shell configuration with Orbit and a neighbour everywhere."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.plugin = os.path.join(root, "plugins", ID)
        os.makedirs(self.plugin)
        self.manifest = os.path.join(self.plugin, "plugin.json")
        write(self.manifest, {"id": ID})
        self.cache = os.path.join(root, "cache", ID)
        os.makedirs(os.path.join(self.cache, "pictures"))
        self.settings = os.path.join(root, "settings.json")
        self.plugin_settings = os.path.join(root, "plugin_settings.json")
        self.session = os.path.join(root, "session.json")
        write(self.plugin_settings, {ID: {"enabled": True, "pcLevels": {}}, "abyss": {"enabled": True}})
        write(self.settings, {
            "barConfigs": [
                {"id": "default", "leftWidgets": ["clock"], "centerWidgets": [],
                 "rightWidgets": [{"id": "battery"}, {"id": ID, "enabled": True}]},
                {"id": "second", "rightWidgets": [ID + ":compact", "orbitBluetoothFake"]},
            ],
            "controlCenterWidgets": [{"id": "volume"}, {"id": "plugin_" + ID}],
            "desktopWidgetInstances": [
                {"id": "dw_1", "widgetType": ID},
                {"id": "dw_2", "widgetType": "modernClock"},
            ],
            "theme": "dark",
        })
        write(self.session, {"desktopWidgetInstancePositions": {"dw_1": {"x": 1}, "dw_2": {"x": 2}}, "other": 1})

        # dms commands asked for, answered from a made-up keybind listing
        self.calls = []
        self.listing = {"binds": {"Audio": [
            {"key": "XF86AudioRaiseVolume", "action": 'spawn sh -c "case ... dms ipc call orbitBluetooth volume ... esac orbit up increment 5"'},
            {"key": "XF86AudioLowerVolume", "action": "spawn dms ipc call audio decrement 3"},
            {"key": "Mod+V", "action": "spawn dms ipc call orbitBluetooth volume up"},
        ]}}

    def dms(self, args):
        self.calls.append(args)
        return json.dumps(self.listing) if args[:2] == ["keybinds", "show"] else '{"success": true}'

    def run(self):
        return U.sweep(ID, self.manifest, self.cache, self.settings, self.plugin_settings, self.session, grace=0, run=self.dms)


class SweepTest(unittest.TestCase):
    def setUp(self):
        self.shell = Shell()
        self.addCleanup(self.shell.tmp.cleanup)

    def test_nothing_happens_while_the_plugin_is_installed(self):
        before = [read(p) for p in (self.shell.settings, self.shell.plugin_settings, self.shell.session)]
        self.assertFalse(self.shell.run())
        after = [read(p) for p in (self.shell.settings, self.shell.plugin_settings, self.shell.session)]
        self.assertEqual(before, after)
        self.assertTrue(os.path.isdir(self.shell.cache))

    def test_uninstalled_plugin_leaves_nothing(self):
        os.remove(self.shell.manifest)
        self.assertTrue(self.shell.run())
        self.assertFalse(os.path.exists(self.shell.cache))
        self.assertEqual(read(self.shell.plugin_settings), {"abyss": {"enabled": True}})
        s = read(self.shell.settings)
        self.assertEqual(s["barConfigs"][0]["rightWidgets"], [{"id": "battery"}])
        self.assertEqual(s["barConfigs"][0]["leftWidgets"], ["clock"])
        # A look-alike id is not Orbit's
        self.assertEqual(s["barConfigs"][1]["rightWidgets"], ["orbitBluetoothFake"])
        self.assertEqual(s["controlCenterWidgets"], [{"id": "volume"}])
        self.assertEqual(s["desktopWidgetInstances"], [{"id": "dw_2", "widgetType": "modernClock"}])
        self.assertEqual(s["theme"], "dark")
        self.assertEqual(read(self.shell.session), {"desktopWidgetInstancePositions": {"dw_2": {"x": 2}}, "other": 1})

    def test_folder_cloned_back_during_the_grace_period_keeps_everything(self):
        # Same as an update that re-clones: plugin.json exists again when checked
        self.assertFalse(self.shell.run())
        self.assertIn(ID, read(self.shell.plugin_settings))

    def test_untouched_files_are_not_rewritten(self):
        os.remove(self.shell.manifest)
        write(self.shell.session, {"other": 1})
        stamp = os.stat(self.shell.session).st_mtime_ns
        write(self.shell.settings, {"theme": "dark"})
        self.shell.run()
        self.assertEqual(os.stat(self.shell.session).st_mtime_ns, stamp)

    def test_permissions_are_kept(self):
        os.remove(self.shell.manifest)
        os.chmod(self.shell.plugin_settings, 0o600)
        self.shell.run()
        self.assertEqual(os.stat(self.shell.plugin_settings).st_mode & 0o777, 0o600)

    def test_missing_or_broken_files_are_left_alone(self):
        os.remove(self.shell.manifest)
        os.remove(self.shell.session)
        with open(self.shell.settings, "w") as f:
            f.write("{ not json")
        self.assertTrue(self.shell.run())
        with open(self.shell.settings) as f:
            self.assertEqual(f.read(), "{ not json")

    def test_bad_arguments_erase_nothing(self):
        os.remove(self.shell.manifest)
        s = self.shell
        # Cache folder not named after the plugin
        self.assertFalse(U.sweep(ID, s.manifest, os.path.dirname(s.cache), s.settings, s.plugin_settings, s.session, grace=0))
        self.assertFalse(U.sweep("../x", s.manifest, s.cache, s.settings, s.plugin_settings, s.session, grace=0))
        self.assertFalse(U.sweep(ID, "relative/plugin.json", s.cache, s.settings, s.plugin_settings, s.session, grace=0))
        self.assertFalse(U.sweep(ID, s.manifest, s.cache, "settings.json", s.plugin_settings, s.session, grace=0))
        self.assertTrue(os.path.isdir(s.cache))
        self.assertIn(ID, read(s.plugin_settings))


class KeysTest(unittest.TestCase):
    def test_uninstall_gives_the_volume_keys_back(self):
        s = Shell()
        self.addCleanup(s.tmp.cleanup)
        os.remove(s.manifest)
        self.assertTrue(s.run())
        # Only the volume key still bound to Orbit, never another shortcut,
        # set back to DMS's own action with the step it had
        self.assertEqual([c for c in s.calls if c[1] == "set"], [["keybinds", "set", "niri", "XF86AudioRaiseVolume", "spawn dms ipc call audio increment 5", "--allow-when-locked", "--json"]])
        self.assertEqual([c for c in s.calls if c[1] == "reset"], [])

    def test_nothing_reset_while_installed(self):
        s = Shell()
        self.addCleanup(s.tmp.cleanup)
        s.run()
        self.assertEqual(s.calls, [])

    def test_unreadable_listing_resets_nothing(self):
        self.assertEqual(U.give_back_keys(ID, lambda a: None), [])
        self.assertEqual(U.give_back_keys(ID, lambda a: "not json"), [])


class IdTest(unittest.TestCase):
    def test_ids(self):
        self.assertTrue(U.mine(ID, ID))
        self.assertTrue(U.mine(ID, ID + ":compact"))
        self.assertTrue(U.mine(ID, "plugin_" + ID))
        self.assertFalse(U.mine(ID, ID + "Fake"))
        self.assertFalse(U.mine(ID, "battery"))
        self.assertFalse(U.mine(ID, None))


if __name__ == "__main__":
    unittest.main()
