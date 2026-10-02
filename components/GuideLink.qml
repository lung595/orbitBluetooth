import QtQuick
import "Guide.js" as Guide

// The GitHub mark as a link to one section of the guide. Opens the browser
// on click only; nothing is fetched by the plugin itself
Item {
    id: link

    property string anchor: ""
    property color color: "white"
    property color hoverColor: color
    property real size: 15

    width: size + 10
    height: size + 10

    GitHubMark {
        anchors.centerIn: parent
        size: link.size
        color: area.containsMouse ? link.hoverColor : link.color
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.openUrlExternally(Guide.url(link.anchor))
    }
}
