import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: startupDialog
    title: "Выберите действие"
    modal: true
    standardButtons: Dialog.NoButton
    anchors.centerIn: parent
    width: 400
    height: 200

    signal createNewRequested()
    signal openExistingRequested()

    background: Rectangle {
        color: "#ffffff"
        radius: 8
        antialiasing: true
        border.color: "#e2e8f0"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.color: "#00000010"
            border.width: 2
            radius: 10
            z: -1
        }
    }

    header: Rectangle {
        width: parent.width
        height: 50
        color: "#f8fafc"
        radius: 8
        antialiasing: true

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#e2e8f0"
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f8fafc" }
            GradientStop { position: 1.0; color: "#f1f5f9" }
        }

        Label {
            anchors.centerIn: parent
            text: startupDialog.title
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: "#1e293b"
        }
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: 20
        columns: 1
        columnSpacing: 10
        rowSpacing: 15

        Button {
            text: "Создать новую конфигурацию"
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            font.pixelSize: 14
            font.weight: Font.Medium
            background: Rectangle {
                color: parent.pressed ? "#059669" : (parent.hovered ? "#10b981" : "#22c55e")
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                startupDialog.createNewRequested()
                startupDialog.close()
            }
        }

        Button {
            text: "Открыть существующую"
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            font.pixelSize: 14
            font.weight: Font.Medium
            background: Rectangle {
                color: parent.pressed ? "#1d4ed8" : (parent.hovered ? "#2563eb" : "#3b82f6")
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                startupDialog.openExistingRequested()
                startupDialog.close()
            }
        }
    }
}
