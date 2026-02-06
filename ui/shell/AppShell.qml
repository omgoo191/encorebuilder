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
        title: "Файл"

        MenuItem { text: "Сохранить"; onTriggered: saveRequested() }
        MenuItem { text: "Сохранить как..."; onTriggered: saveAsRequested() }

        Menu {
            title: "Экспорт..."
            MenuItem { text: "Excel"; onTriggered: exportExcelRequested() }
            MenuItem { text: "Код"; onTriggered: exportCodeRequested() }
        }

        MenuItem { text: "Импорт"; onTriggered: importRequested() }
        MenuItem { text: "Выход"; onTriggered: exitRequested() }
    }

    Menu {
        title: "Объектные модели"
        MenuItem { text: "Создать MEK модель"; onTriggered: createMekModelRequested() }
        MenuItem { text: "Создать MODBUS модель"; onTriggered: createModbusModelRequested() }
        MenuSeparator {}
        MenuItem { text: "Управление моделями"; onTriggered: objectModelManagerRequested() }
    }

    Menu {
        title: "Интерфейсы"
        MenuItem { text: "Ethernet"; onTriggered: ethernetConfigRequested() }
        MenuItem { text: "RS"; onTriggered: rsConfigRequested() }
        MenuItem { text: "Управление интерфейсами"; onTriggered: interfaceManagerRequested() }
    }

    Menu {
        title: "Протоколы"
        MenuItem { text: "Создать протокол"; onTriggered: createProtocolRequested() }
        MenuItem { text: "Управление протоколами"; onTriggered: protocolManagerRequested() }
    }

    Menu {
        title: "Дополнительно"
        MenuItem { text: "Добавить ТУ"; onTriggered: addTuRequested() }
        MenuItem { text: "Добавить ТC"; onTriggered: addTsRequested() }
        MenuItem { text: "Добавить ТИ"; onTriggered: addTiRequested() }
    }
}
