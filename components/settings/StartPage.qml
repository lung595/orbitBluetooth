import QtQuick
import qs.Common
import qs.Widgets

// Getting started: where Orbit shows up. Most people who install it expect it
// to replace DMS's Bluetooth and never add a widget, so the settings open
// here while the widget is placed nowhere (SettingsView, Placement.js). It
// only explains: three places, each with a small moving drawing and the
// steps in DMS's own words; a place that already has Orbit says so. It reads
// DMS's layout and never writes it.
CategoryPage {
    id: page
    category: "start"

    readonly property var placed: view.placed

    StyledText {
        width: parent.width
        visible: page.shown("gettingStarted")
        text: "Orbit does not replace DMS's Bluetooth by itself: it shows up where you add its widget. Pick one place, or several."
        wrapMode: Text.WordWrap
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
    }

    // Not a setting, so no settingKey: the index lists it as a keyless row
    // ("gettingStarted", like "report") so that "add widget" finds this page
    Column {
        width: parent.width
        visible: page.shown("gettingStarted")
        spacing: Theme.spacingS

        Way {
            kind: "cc"
            icon: "tune"
            title: "In the Control Center"
            steps: "Open the Control Center, press Edit (the pencil), then Add widget and pick Orbit Bluetooth. Its tile opens the orbit."
            here: page.placed.cc
            where: "your Control Center"
            live: page.visible
        }
        Way {
            kind: "bar"
            icon: "toolbar"
            title: "In the bar"
            steps: "DMS Settings → Bar widgets → Add, then pick Orbit Bluetooth. A click on it opens the orbit."
            here: page.placed.bar
            where: "a bar"
            live: page.visible
        }
        Way {
            kind: "desktop"
            icon: "desktop_windows"
            title: "On the desktop"
            steps: "DMS Settings → Desktop widgets → Add, then pick Orbit Bluetooth, and drag it where you like."
            here: page.placed.desktop
            where: "your desktop"
            live: page.visible
        }
    }

    Row {
        width: parent.width
        visible: page.shown("gettingStarted")
        spacing: Theme.spacingS
        DankIcon {
            id: btIcon
            name: "bluetooth"
            size: 16
            color: Theme.surfaceVariantText
        }
        StyledText {
            width: parent.width - btIcon.width - Theme.spacingS
            text: "DMS's own Bluetooth widget stays as it is: both live side by side, and you may remove DMS's if you like."
            wrapMode: Text.WordWrap
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // One place: the drawing on the left, the steps beside it (under it when
    // the page is narrow)
    component Way: Rectangle {
        id: way
        required property string kind
        required property string icon
        required property string title
        required property string steps
        required property bool here
        // Ends "Orbit is already in …"
        required property string where
        // The drawing moves only while the page shows: a hidden page runs nothing
        required property bool live

        readonly property bool stacked: width < sketch.width + Theme.spacingM * 3 + 180

        width: parent.width
        height: flow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: here ? 1 : 0
        border.color: Theme.withAlpha(Theme.primary, 0.5)

        Accessible.role: Accessible.StaticText
        Accessible.name: title + ". " + steps + (here ? " Orbit is already in " + where + "." : "")

        Flow {
            id: flow
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingM

            WidgetSketch {
                id: sketch
                kind: way.kind
                running: way.live
            }

            Column {
                width: way.stacked ? flow.width : flow.width - sketch.width - flow.spacing
                spacing: Theme.spacingXS

                Row {
                    spacing: Theme.spacingS
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: way.icon
                        size: 18
                        color: Theme.primary
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: way.title
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }
                }
                StyledText {
                    width: parent.width
                    text: way.steps
                    wrapMode: Text.WordWrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
                Row {
                    visible: way.here
                    spacing: Theme.spacingXS
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check_circle"
                        size: 14
                        color: Theme.primary
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Orbit is already in " + way.where
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
