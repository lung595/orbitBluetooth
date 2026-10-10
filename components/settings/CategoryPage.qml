import QtQuick
import qs.Common
import qs.Widgets

// One category of the settings: its title, then its settings as children.
// A page shows only while its category is open, or, during a search, only if
// it has a match; inside it a setting shows if it matches (see shown()).
Item {
    id: page

    required property var view
    required property string category
    // The settings and rows of the category go in the column, under the title
    default property alias content: column.data

    readonly property var info: view.info(category)
    readonly property bool reduceMotion: SettingsData.reduceMotion

    // Whether the setting `key` shows: always while browsing (the page itself
    // is shown or hidden), only the matches while a search filters
    function shown(key) {
        return !view.filtering || view.hits[key] === true;
    }

    function label(key) {
        return view.label(key);
    }

    function help(key) {
        return view.help(key);
    }

    // The setting called `key` among the children, looking everywhere below
    function _find(item, key) {
        for (const child of item.children) {
            if (child.settingKey === key)
                return child;
            const inside = _find(child, key);
            if (inside)
                return inside;
        }
        return null;
    }

    // Frames the setting `key` for a moment: full, held, then one fade. With
    // Reduce motion it stays lit until the next click on the page.
    function light(key) {
        const target = _find(column, key);
        if (!target)
            return;
        // The frame lives inside the setting, so it follows the layout settling
        frame.parent = target;
        fade.stop();
        frame.opacity = 1;
        if (!reduceMotion)
            fade.start();
    }

    visible: view.filtering ? (view.counts[category] || 0) > 0 : view.current === category
    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight

    // Brief fade in when the page appears (100 ms for a filter, 150 ms for a category)
    onVisibleChanged: {
        if (!visible || reduceMotion)
            return;
        enter.duration = view.filtering ? 100 : 150;
        enter.restart();
    }
    NumberAnimation {
        id: enter
        target: column
        property: "opacity"
        from: 0
        to: 1
        easing.type: Easing.OutCubic
    }

    Connections {
        target: page.view
        function onLitCountChanged() {
            // After the page is shown and laid out
            if (page.view.current === page.category)
                Qt.callLater(page.light, page.view.litKey);
        }
    }

    TapHandler {
        // Only matters to a lit frame that Reduce motion keeps; passive: the settings still get their clicks
        enabled: frame.opacity > 0 && page.reduceMotion
        gesturePolicy: TapHandler.ReleaseWithinBounds
        grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        onTapped: frame.opacity = 0
    }

    Rectangle {
        id: frame
        // Over the setting's background, under its controls
        z: -1
        anchors.fill: parent
        anchors.margins: -Theme.spacingXS
        opacity: 0
        visible: opacity > 0
        radius: Theme.cornerRadius / 2
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
        border.width: 1
        border.color: Theme.primary
    }
    SequentialAnimation {
        id: fade
        PauseAnimation {
            duration: 300
        }
        NumberAnimation {
            target: frame
            property: "opacity"
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.spacingM

        Row {
            spacing: Theme.spacingS
            height: 28
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: page.info.icon
                size: 20
                color: Theme.primary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: page.info.name
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !page.view.compact
                text: "· " + page.info.help
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
