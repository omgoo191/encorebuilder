import QtQuick 2.15
import QtQuick.Controls 2.15

MenuBar {
    signal saveRequested()
    signal saveAsRequested()
    signal exportExcelRequested()
    signal exportCodeRequested()
    signal importRequested()
    signal exitRequested()
    signal createMekModelRequested()
    signal createModbusModelRequested()
    signal objectModelManagerRequested()
    signal ethernetConfigRequested()
    signal rsConfigRequested()
    signal interfaceManagerRequested()
    signal createProtocolRequested()
    signal protocolManagerRequested()
    signal addTuRequested()
    signal addTsRequested()
    signal addTiRequested()

    Menu {
        title: qsTr("Файл")

        MenuItem { text: qsTr("Сохранить"); onTriggered: saveRequested() }
        MenuItem { text: qsTr("Сохранить как..."); onTriggered: saveAsRequested() }

        Menu {
            title: qsTr("Экспорт...")
            MenuItem { text: qsTr("Excel"); onTriggered: exportExcelRequested() }
            MenuItem { text: qsTr("Код"); onTriggered: exportCodeRequested() }
        }

        MenuItem { text: qsTr("Импорт"); onTriggered: importRequested() }
        MenuItem { text: qsTr("Выход"); onTriggered: exitRequested() }
    }

    Menu {
        title: qsTr("Объектные модели")
        MenuItem { text: qsTr("Создать MEK модель"); onTriggered: createMekModelRequested() }
        MenuItem { text: qsTr("Создать MODBUS модель"); onTriggered: createModbusModelRequested() }
        MenuSeparator {}
        MenuItem { text: qsTr("Управление моделями"); onTriggered: objectModelManagerRequested() }
    }

    Menu {
        title: qsTr("Интерфейсы")
        MenuItem { text: qsTr("Ethernet"); onTriggered: ethernetConfigRequested() }
        MenuItem { text: qsTr("RS"); onTriggered: rsConfigRequested() }
        MenuItem { text: qsTr("Управление интерфейсами"); onTriggered: interfaceManagerRequested() }
    }

    Menu {
        title: qsTr("Протоколы")
        MenuItem { text: qsTr("Создать протокол"); onTriggered: createProtocolRequested() }
        MenuItem { text: qsTr("Управление протоколами"); onTriggered: protocolManagerRequested() }
    }

    Menu {
        title: qsTr("Дополнительно")
        MenuItem { text: qsTr("Добавить ТУ"); onTriggered: addTuRequested() }
        MenuItem { text: qsTr("Добавить ТC"); onTriggered: addTsRequested() }
        MenuItem { text: qsTr("Добавить ТИ"); onTriggered: addTiRequested() }
    }
}
