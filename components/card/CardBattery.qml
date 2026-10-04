import QtQuick
import "Charge.js" as Charge
import "CardStatus.js" as CardStatus

// The battery card as the detail card shows it: the focused device's level,
// time, history and charge figures. The wording lives in CardStatus.js.
BatteryCard {
    id: battery
    required property var card

    readonly property var c: card.body?.charge ?? null
    readonly property real since: card.scene.sinceFor(card.body?.address)

    framed: false
    gaugeRatio: card.ancShown ? 0.035 : 0.1
    timeText: card.timeText
    showMeter: !card.trioShown
    animate: card.scene.awake && card.scene.motion
    time: card.scene.fxTime

    level: card.body?.connected ? card.body.battery : -1
    charging: card.body?.charging ?? false
    history: {
        const log = card.scene.batteryLogFor(card.body?.address);
        return log.length && level >= 0 ? log.concat([[card.scene.now, level]]) : [];
    }
    footnote: card.body?.connected && level >= 0 && !card.ancShown ? Charge.footnote(c, charging) : ""
    statusIcon: CardStatus.statusIcon(card.body, c)
    statusText: CardStatus.statusText(card.body, c, since, card.scene.now)
    detailText: CardStatus.detailText(card.body, c, level)
    stats: card.ancShown ? [] : card.statItems
}
