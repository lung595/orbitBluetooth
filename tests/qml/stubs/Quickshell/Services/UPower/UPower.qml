pragma Singleton
import QtQuick
QtObject { property bool onBattery: true; property var displayDevice: ({ isLaptopBattery: true, percentage: 0.8 }) }
