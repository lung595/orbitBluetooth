import QtQuick
import qs.Common
import qs.Widgets
import "../common"
import "../common/Guide.js" as Guide

// The "Copy report" button and what it says: collects the anonymous report
// when pressed (nothing runs before), copies it with wl-copy --sensitive and
// tells where to paste it. The report never leaves the machine by itself.
Row {
    id: row
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    readonly property var note: Guide.reportNote(service.busy ? "collecting" : copier.result, copier.inHistory)

    // Orbit's own saved settings, read when the report is built
    Prefs {
        id: prefs
    }

    ReportService {
        id: service
        prefs: prefs
        surfaces: ({
                "settings": true
            })
        onBuilt: text => copier.copy(text)
    }

    ReportCopy {
        id: copier
    }

    StyledText {
        width: parent.width - button.width - link.width - parent.spacing * 2
        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: copier.result === "none" ? Theme.error : Theme.surfaceVariantText
        text: row.note.title + ". " + row.note.hint
    }

    ActionButton {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        text: "Copy report"
        onClicked: service.request("button")
    }

    GuideLink {
        id: link
        anchors.verticalCenter: parent.verticalCenter
        anchor: row.note.anchor
        size: 14
        color: Theme.surfaceVariantText
        hoverColor: Theme.surfaceText
    }
}
