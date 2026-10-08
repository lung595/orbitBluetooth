import QtQuick
import "DeviceCatalog.js" as Catalog
import "../card/Charge.js" as Charge
import "../common/Pictures.js" as Pictures
import "../card/Endurance.js" as Endurance

// What a body knows about its device, as the base type of DeviceBody: the
// name, kind and picture, the connection, the battery and its forecast, noise
// control and the signal. All of it is read from the scene's services by
// address. Rule: nothing here reads a part of the body (its face, label,
// pointer...) nor its motion; that stays in DeviceBody.
// tests/structure.test.js checks it.
Item {
    id: body

    required property var scene
    required property string address
    required property bool leaving

    readonly property var device: scene.deviceMap[address] ?? null
    readonly property string name: Catalog.deviceName(device) || address
    // Recognition only (see Catalog.modelName): never changes on rename
    readonly property string model: Catalog.modelName(device) || address
    readonly property string kind: Catalog.resolve(device, scene.prefs.glyphOverrides)
    // Real picture of the model (opt-in); the query is empty for anything
    // that must not be looked up, see Pictures.js
    readonly property string pictureQuery: scene.prefs.realPictures ? Pictures.queryFor(Catalog.modelName(device), paired || connected) : ""
    readonly property var picture: pictureQuery ? scene.pictureFor(pictureQuery) : null
    onPictureQueryChanged: scene.requestPicture(pictureQuery)
    Component.onCompleted: scene.requestPicture(pictureQuery)
    readonly property bool connected: device?.connected ?? false
    readonly property bool paired: (device?.paired || device?.bonded) ?? false
    // The headset's own battery report (noise-control helper), trusted while
    // its session is live or for ten minutes after: UPower often has no
    // charging state for headphones, and waiting for the level to rise is slow
    readonly property var ancInfo: scene.ancFor(address)
    readonly property bool ancFresh: !!ancInfo && (ancInfo.live || scene.now - (ancInfo.at || 0) < 600000)
    // The headset itself or an earbud charging (a charging case alone does
    // not make the earbuds "charging")
    readonly property bool headsetCharging: {
        const parts = ancFresh ? ancInfo.state?.battery : null;
        return !!parts && ["single", "left", "right"].some(k => parts[k]?.charging);
    }
    // Level from the headset's report when BlueZ has none (e.g. some earbuds):
    // the headphones, or the lower earbud
    readonly property int ancLevel: {
        const parts = ancFresh ? ancInfo.state?.battery : null;
        if (!parts)
            return -1;
        if (parts.single)
            return parts.single.level;
        const buds = [parts.left, parts.right].filter(p => p);
        return buds.length ? Math.min(...buds.map(p => p.level)) : -1;
    }
    readonly property var power: {
        const p = scene.powerFor(address);
        return headsetCharging ? Object.assign({}, p || {}, {
            "state": 1      // UPower's "charging"
        }) : p;
    }
    readonly property int battery: device?.batteryAvailable ? Math.round(device.battery * 100) : connected ? (power?.percentage ?? ancLevel) : -1
    // Rated life depends only on the model and mode: looked up once, not on every clock tick
    readonly property real ratedHours: Endurance.ratedHours(model, kind, ancMode)
    readonly property var charge: connected && battery >= 0 ? Charge.analyze(scene.batteryLogFor(address), battery, power, scene.now, ratedHours) : null
    // Time until empty, when discharging and known ("≈" unless the system says it)
    readonly property real minutesLeft: charge && !charging ? charge.minutesLeft : 0
    readonly property bool charging: charge?.state === "charging"
    // Noise control, when the headset speaks a known vendor protocol
    readonly property bool ancCapable: scene.ancCapable(body)
    onAncCapableChanged: Qt.callLater(scene.ancSyncViews)
    readonly property string ancMode: ancCapable ? (scene.ancFor(address)?.state?.mode ?? "") : ""
    readonly property real rawSignal: (device?.signalStrength ?? 0) > 0 ? device.signalStrength / 100 : 0
    // Only remembered devices can be out of range; discovered ones are nearby
    readonly property bool dormant: !connected && paired && rawSignal <= 0
}
