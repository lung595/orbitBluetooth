import QtQuick
import qs.Common

// Orbit's volume face inside a Dank Island (D263): created in memory as a
// child of the island's own expanded volume sheet, so the island grows to
// hold it on its own spring, with its own glass and shape. The island's
// slider underneath is hidden while Orbit shows, and comes back when this
// face goes (plugin off): nothing of DMS is written (value 12, D259).
// Collapsed, the sheet is invisible and so is this: nothing runs.
Item {
    id: face

    required property var overlay
    // The island's IslandController on that screen
    required property var controller

    anchors.fill: parent

    // The island is showing the volume (not the brightness, which shares
    // the sheet)
    readonly property bool mine: controller.activeActivity === "volume"
    readonly property bool shown: mine && controller.expanded && visible
    // What the sheet holds, volume or brightness. It keeps its value while
    // the island moves on to something else, because the sheet then fades
    // out for a few frames: switching to DMS's slider then would flash it
    // (P133).
    property string _sheetOf: mine ? "volume" : ""
    Connections {
        target: face.controller
        function onActiveActivityChanged() {
            const a = face.controller.activeActivity;
            if (a === "volume" || a === "brightness")
                face._sheetOf = a;
        }
    }
    readonly property bool ours: _sheetOf === "volume"
    visible: ours

    // --- Open and close ----------------------------------------------------------
    // The island grows into its volume sheet, unless the user has opened
    // something else in it on purpose
    function open() {
        const c = controller;
        if (c.inputSuspended || (c.expanded && c.activeActivity !== "volume"))
            return false;
        if (!c.requestSystemActivity("volume"))
            return false;
        c.expanded = true;
        hide.restart();
        return true;
    }
    // A level set from the face itself: it stays, the clock restarts
    function keep() {
        if (shown)
            hide.restart();
    }
    // Shrinks back to whatever the island showed before
    function close() {
        hide.stop();
        if (mine && controller.expanded)
            controller.requestCollapse();
    }

    // As long as DMS's own OSD would stay, longer while the pointer is on it
    Timer {
        id: hide
        interval: 3000
        onTriggered: {
            if (face.controller.pointerInside || screenItem.hovered)
                restart();
            else
                face.close();
        }
    }
    onShownChanged: {
        if (!shown)
            hide.stop();
        overlay.islandShown(face, shown);
    }

    // --- The island's own content underneath ------------------------------------------
    function _hideNative() {
        const native = parent ? parent.item : null;
        if (native)
            native.visible = Qt.binding(() => !face.ours);
    }
    Connections {
        target: face.parent
        function onItemChanged() {
            face._hideNative();
        }
    }
    Component.onCompleted: _hideNative()
    Component.onDestruction: {
        const native = parent ? parent.item : null;
        if (native)
            native.visible = true;
        overlay.islandShown(face, false);
    }

    ScopeScreen {
        id: screenItem
        anchors.fill: parent
        overlay: face.overlay
        live: face.shown
        // The island sheet's own corners (flat against the screen edge)
        readonly property var sheet: face.controller.expandedTargetFor("volume")
        radii: [sheet.topLeftRadius, sheet.topRightRadius, sheet.bottomLeftRadius, sheet.bottomRightRadius]
        onTouched: face.keep()
    }
}
