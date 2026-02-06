import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: root
    property var listModel
    property string itemTextRole: "name"
    signal itemSelected(int index)

    standardButtons: Dialog.Ok | Dialog.Cancel
    height: 500

    ListView {
        width: 300
        height: 500
        model: root.listModel
        delegate: ItemDelegate {
            required property int index
            required property var model
            text: {
                if (root.itemTextRole && model[root.itemTextRole] !== undefined)
                    return model[root.itemTextRole]
                if (model.type !== undefined && model.id !== undefined)
                    return model.type + " (" + model.id + ")"
                return "Item " + index
            }
            onClicked: root.itemSelected(index)
        }
    }
}
