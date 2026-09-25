import QtQuick
import QtMultimedia

// Short UI sounds. The multimedia backend is only instantiated when sounds
// are enabled, so a silent setup pays nothing for it.
Item {
    id: root

    property bool enabled: false
    property real volume: 0.6

    visible: false

    function play(name) {
        if (loader.item)
            loader.item.play(name);
    }

    Loader {
        id: loader
        active: root.enabled
        sourceComponent: Item {
            function play(name) {
                const fx = {
                    "connect": connectFx,
                    "disconnect": disconnectFx,
                    "snap": snapFx,
                    "error": errorFx
                }[name];
                if (fx)
                    fx.play();
            }

            SoundEffect {
                id: connectFx
                source: Qt.resolvedUrl("../sounds/connect.wav")
                volume: root.volume
            }
            SoundEffect {
                id: disconnectFx
                source: Qt.resolvedUrl("../sounds/disconnect.wav")
                volume: root.volume
            }
            SoundEffect {
                id: snapFx
                source: Qt.resolvedUrl("../sounds/snap.wav")
                volume: root.volume * 0.8
            }
            SoundEffect {
                id: errorFx
                source: Qt.resolvedUrl("../sounds/error.wav")
                volume: root.volume
            }
        }
    }
}
