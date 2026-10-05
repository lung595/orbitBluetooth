import QtQuick
import "../scene/Physics.js" as Physics
import "WiredSign.js" as Sign

// The wired members of the group, one rounded square each (WiredBody), as
// siblings of the Bluetooth bodies so that they sort among the planets by their
// stacking order. They exist only while the group has a wired member
// (OrbitCentre.wired). The scene's hit tests read them next to the bodies.
Repeater {
    id: members

    required property var scene

    model: members.scene.centre.wired
    delegate: WiredBody {
        scene: members.scene
    }

    // Every wired member drawn, as a plain array
    function list() {
        const all = [];
        for (let i = 0; i < members.count; i++) {
            const b = members.itemAt(i);
            if (b)
                all.push(b);
        }
        return all;
    }

    // The wired member drawn under this scene point, if any, on its own shape
    function at(x, y) {
        return list().find(b => Sign.inside(x - b.px, y - b.py, Physics.hitDiameter(b))) ?? null;
    }
}
