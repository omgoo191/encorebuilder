import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: root
    property var tableModel
    property Component rowDelegate
    property Component headerComponent
    property alias listView: listView

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        padding: 10
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
        leftPadding: 15
        rightPadding: 22
        contentWidth: listView.width - 30
        contentHeight: listView.height

        ListView {
            id: listView
            width: parent.width - 30
            height: parent.height
            cacheBuffer: 200
            model: root.tableModel
            spacing: 0
            interactive: true
            clip: true
            headerPositioning: ListView.OverlayHeader
            header: Loader { sourceComponent: root.headerComponent }
            delegate: Loader { sourceComponent: root.rowDelegate }
        }
    }
}
