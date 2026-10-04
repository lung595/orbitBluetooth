import QtQuick

Item {
    property bool active: false
    default property Component component
    property var item: null
    onActiveChanged: {
        if (active && !item)
            item = component.createObject(this);
        else if (!active && item) {
            item.destroy();
            item = null;
        }
    }
}
