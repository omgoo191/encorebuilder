import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    property var columns: []
    color: "#f1f5f9"
    height: 32

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#cbd5e1" }
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#e2e8f0" }

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#f8fafc" }
        GradientStop { position: 1.0; color: "#e2e8f0" }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        Repeater {
            model: root.columns
            delegate: Item {
                Layout.preferredWidth: modelData.width
                Layout.fillWidth: !!modelData.stretch
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: modelData.title || ""
                    color: "#1e293b"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
