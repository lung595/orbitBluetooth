import QtQuick
import qs.Common
import qs.Modules.Plugins
import "components/settings"
import "diagnostics/Log.js" as Log

// Plugin settings: a search field on top, the categories on the left as
// bodies on a plotted orbit, one category at a time on the right. Typing
// turns the page into the answer (only the matching settings, editable in
// place); Esc gives the page back. Every option works out of the box; each
// setting has a label and one short help line (both read from the search
// index), and options that cost battery carry a pill with their level (BatteryPill).
PluginSettings {
    id: root

    // One memory write each way: which surfaces are alive shows in a report
    Component.onCompleted: Log.event("ORB-I020", {
        "surface": "settings"
    })
    Component.onDestruction: Log.event("ORB-I021", {
        "surface": "settings"
    })
    pluginId: "orbitBluetooth"

    // Below this width the rail keeps its icons only
    readonly property int narrowWidth: 400

    FocusScope {
        id: page
        width: parent ? parent.width : 0
        implicitHeight: column.implicitHeight

        SettingsView {
            id: view
            compact: page.width < root.narrowWidth
        }

        // Ctrl+F reaches the field from anywhere in the window; "/" only
        // arrives here when no text field has taken it, so a slash typed into
        // a field still works
        Shortcut {
            sequence: "Ctrl+F"
            enabled: page.visible
            onActivated: search.focusField()
        }
        Keys.onPressed: event => {
            if (event.text === "/" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                search.focusField();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape && view.filtering) {
                view.query = "";
                event.accepted = true;
            }
        }
        // A click on the page gives it the keys ("/", Esc); the controls keep their own clicks
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
            onTapped: page.forceActiveFocus()
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.spacingS

            SearchField {
                id: search
                width: parent.width
                view: view
                onReleased: page.forceActiveFocus()
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                CategoryRail {
                    id: rail
                    // Above the content, so a narrow rail's tooltips overlap it
                    z: 1
                    view: view
                }

                Item {
                    width: parent.width - rail.width - Theme.spacingM
                    height: Math.max(pages.implicitHeight, none.implicitHeight)

                    NoResults {
                        id: none
                        width: parent.width
                        visible: view.filtering && !view.hasResults
                        query: view.query
                    }

                    // Every page is built once; only the open one (or those with a match) shows
                    Column {
                        id: pages
                        width: parent.width

                        OrbitPage {
                            view: view
                            settings: root
                        }
                        ScanningPage {
                            view: view
                        }
                        HeadphonesPage {
                            view: view
                            settings: root
                        }
                        VolumePage {
                            view: view
                        }
                        PopupPage {
                            view: view
                        }
                        AudioPage {
                            view: view
                        }
                        SoundsPage {
                            view: view
                            settings: root
                        }
                        DesktopPage {
                            view: view
                            pluginId: root.pluginId
                        }
                        LookPage {
                            view: view
                        }
                        ResetPage {
                            view: view
                            settings: root
                        }
                    }
                }
            }
        }
    }
}
