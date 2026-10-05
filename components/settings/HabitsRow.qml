import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../common"
import "../together/Habits.js" as Habits

// What the ghost group learns (D299): the switch, and the button that forgets
// it. Each has its own link to the guide. The memory is only hashes of the
// outputs listened to together, kept in Orbit's own settings and never sent
// anywhere; switching learning off erases it at once (HabitLog), and the
// button does the same on demand. It shows how many groups are remembered, so
// the user sees what is there without anything readable being kept.
Column {
    id: row

    required property PluginSettings settings

    // The saved switch (default on) and the groups remembered
    property bool learning: true
    property int remembered: 0

    function load() {
        if (!settings.pluginService)
            return;
        learning = settings.loadValue("learnHabits", true) !== false;
        remembered = Habits.count(settings.loadValue("togetherHabits", ({})));
    }

    width: parent ? parent.width : 0
    spacing: Theme.spacingS

    // The service is handed over after the page is built: read on the next turn
    Component.onCompleted: Qt.callLater(load)
    Connections {
        target: row.settings.pluginService
        enabled: row.settings.pluginService !== null

        function onPluginDataChanged(pluginId) {
            if (pluginId === row.settings.pluginId)
                row.load();
        }
    }

    Item {
        width: parent.width
        height: toggle.height

        Column {
            width: parent.width - toggle.width - links.width - Theme.spacingM * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: "Learn my groups"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "The suggested group is the one you listen to most. Orbit remembers each group as short hashes, at most 8, on this computer only: no name, no address, never sent anywhere. Off: nothing is kept and a pair is suggested"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
        GuideLink {
            id: links
            anchor: "learn-my-groups"
            anchors.right: toggle.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            size: 14
            color: Theme.surfaceVariantText
            hoverColor: Theme.surfaceText
        }
        DankToggle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: row.learning
            onToggled: isChecked => {
                row.learning = isChecked;
                row.settings.saveValue("learnHabits", isChecked);
            }
        }
    }

    // Only once there is something to forget
    Item {
        width: parent.width
        height: forget.height
        visible: row.remembered > 0

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: row.remembered === 1 ? "1 group remembered" : row.remembered + " groups remembered"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            ActionButton {
                id: forget
                text: "Forget what Orbit learned"
                onClicked: {
                    row.settings.saveValue("togetherHabits", Habits.forget());
                    row.remembered = 0;
                }
            }
            GuideLink {
                anchor: "forget-what-orbit-learned"
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                color: Theme.surfaceVariantText
                hoverColor: Theme.surfaceText
            }
        }
    }
}
