import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import FileIO 1.0
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
ApplicationWindow {
    id: rootwindow
    width: 1920
    height: 1080
    minimumWidth: 1920
    visible: true
    title: "Генератор сигналов"
    property bool modbus: false
    property bool mek: false
    property bool mek_101: false
    property bool mek_104: false
    property int nextIoIndex: 1
    property string stateFileName: "app_state.json"
    property bool loadingState: false
    property bool closeapp: false
    property string currentType: "Аналоговые входы"
    property int ethcounter: 0
    property int rscounter: 0
    property int mekcounter:0
    property int mbcounter:0

    property string currentBldePath: ""

    menuBar: MenuBar {
        Menu {
            title: "Файл"

            MenuItem {
                text: "Сохранить"
                onTriggered: {
                    if (rootwindow.currentBldePath !== "") {
                        saveToBlde(rootwindow.currentBldePath)
                    } else {
                        saveFileDialog.open()
                    }
                }
            }

            MenuItem {
                text: "Сохранить как..."
                onTriggered: {saveFileDialog.open(); console.log("trigger")}
            }

            MenuItem {
                text: "Экспорт..."
                onTriggered: {exportDialog.open(); console.log("trigger")}
            }

            MenuItem {
                text: "Выход"
                onTriggered: {confirmExitDialog.open(); console.log("trigger")}
            }
        }
        Menu {
            title: "Объектные модели"

            Menu {
                title: "Добавить"

                MenuItem {
                    text: "MEK"
                    onTriggered: {
                        console.log("Добавить MEK")
                        objectModels.append({
                            id: "MEK_object_model_" + + mekcounter,
                            type: "MEK"
                        });
                        mek = true;
                        if (mek) {
                            initializeMekProperties();
                        } else {
                            mek_101 = false;
                            mek_104 = false;
                            mekLoader.active = false;
                            mekLoader.sourceComponent= null;
                        }
                        mekcounter=mekcounter+1
                    }
                }

                MenuItem {
                    text: "Modbus"
                    onTriggered: {
                        console.log("Добавить Modbus")
                        objectModels.append({
                            id: "Modbus_object_model_" + + mbcounter,
                            type: "Modbus"
                        });
                        modbus = true
                        mbcounter=mbcounter+1
                    }
                }
            }

            MenuItem {
                text: "Удалить"
                onTriggered: {
                    console.log("Удалить модель")
                    removeObjectModelDialog.open()
                }
            }
        }
        Menu {
            title: "Интерфейсы"

            Menu {
                title: "Добавить"

                MenuItem {
                    text: "ETH"
                    onTriggered: {
                        console.log("Добавить MEK")
                        interfaceModel.append({
                            id: "ETH" + + ethcounter,
                            type: "ETH"
                        });
                        ethcounter=ethcounter+1
                        ethConfigDialog.open()

                    }
                }

                MenuItem {
                    text: "RS"
                    onTriggered: {
                        console.log("Добавить Modbus")
                        interfaceModel.append({
                            id: "RS" + + rscounter,
                            type: "RS"
                        });
                        rscounter=rscounter+1
                        rsConfigDialog.open()
                    }
                }
            }

            MenuItem {
                text: "Удалить"
                onTriggered: {
                    console.log("Удалить интерфейс")
                    removeInterfaceDialog.open()
                }
            }
        }
        Menu {
            title: "Протоколы"
            enabled: (objectModels.count > 0 && interfaceModel.count > 0)
            Menu {
                title: "Добавить"

                MenuItem {
                    text: "MEK_101"
                    onTriggered: {
                        mek_101 = true;
                        if (mek_101) tabBar.updateFocus();
                    }
                }

                MenuItem {
                    text: "MEK_104"
                    onTriggered: {
                        mek_104 = true;
                        if (mek_104) tabBar.updateFocus();
                    }
                }
            }

            MenuItem {
                text: "Удалить MEK_101"
                onTriggered: {
                    mek_101 = false;
                    if (mek_101) tabBar.updateFocus();
                }
            }
            MenuItem {
                text: "Удалить MEK_104"
                onTriggered: {
                    mek_104 = false
                    if (mek_104) tabBar.updateFocus();
                }
            }
        }
    }
    Dialog {
        id: removeInterfaceDialog
        title: "Удалить интерфейс"
        standardButtons: Dialog.Ok | Dialog.Cancel
        height: 500
        ListView {
            width: 300
            height: 500
            model: interfaceModel
            delegate: ItemDelegate {
                text: model.type + " (" + model.id + ")"
                onClicked: {
                    interfaceModel.remove(index)
                    if (item.type === "ETH") {
                        ethcounter--
                    } else if (item.type === "rs") {
                        rscounter--
                    }
                    removeInterfaceDialog.close()
                }
            }
        }
    }
    Dialog {
        id: removeObjectModelDialog
        title: "Удалить объектную модель"
        standardButtons: Dialog.Ok | Dialog.Cancel
        height: 500
        ListView {
            width: 300
            height: 500
            model: objectModels
            delegate: ItemDelegate {
                text: model.type + " (" + model.id + ")"
                onClicked: {
                    objectModels.remove(index)
                        if (item.type === "MEK") {
                            mekcounter--
                            mekcounter === 0 ? mek = false : true
                        } else if (item.type === "Modbus") {
                            mbcounter--
                            mbcounter === 0 ? modbus = false : true
                        }
                    removeObjectModelDialog.close()
                    }
                }
            }
        }

    FileDialog {
        id: saveDialog
        title: "Сохранить как..."
        fileMode: FileDialog.SaveFile
        nameFilters: ["BLDE (*.blde)"]
        onAccepted: {
            let path = selectedFile.toString().replace("file://", "")
            if (!path.endsWith(".blde")) path += ".blde"
            rootwindow.currentBldePath = path
            saveToBlde(path)
        }
    }

    FileDialog {
        id: exportDialog
        title: "Экспортировать в Excel"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel (*.xlsx)"]
        onAccepted: {
            let path = selectedFile.toString().replace("file://", "")
            if (!path.endsWith(".xlsx")) path += ".xlsx"
            let tempJson = Qt.resolvedUrl("temp_export.json")
            saveToBlde(tempJson)
            fileHandler.runPythonScript(tempJson, false)
        }
    }

    Platform.FileDialog {
        id: saveFileDialog
        title: "Сохранить как..."
        nameFilters: ["BLDE (*.blde)"]
        defaultSuffix: "blde"
        fileMode: Platform.FileDialog.SaveFile
        onAccepted: {
            const filePath = String(file).replace("file://", "")
            if (fileHandler.saveToFile(filePath, exportToJson())) {
                stateFileName = filePath
            }
            rootwindow.currentBldePath = filePath
        }
    }
    MessageDialog {
        id: confirmExitDialog
        title: "Выход"
        text: "Сохранить перед выходом?"
        buttons: StandardButton.Yes | StandardButton.No | StandardButton.Cancel
        onAccepted: {
            switch (clickedButton) {
                case StandardButton.Yes:
                    if (rootwindow.currentBldePath !== "")
                        saveToBlde(rootwindow.currentBldePath)
                    else
                        saveDialog.open()
                    Qt.quit()
                    break
                case StandardButton.No:
                    Qt.quit()
                    break
                case StandardButton.Cancel:
                    break
            }
        }
    }

    ListModel{
        id:objectModels
    }
    ListModel{
        id:interfaceModel
    }
    ListModel {
        id: dataModel
        dynamicRoles: false
        onCountChanged: {
            updateNextIoIndex();
        }
    }
    property var toModel:[]
    property var triggerModel:[]
    ListModel { id: analogInputsModel }
    ListModel { id: digitalInputsModel }
    ListModel { id: analogOutputsModel }
    ListModel { id: digitalOutputsModel }
    ListModel { id: flagsModel }
    ListModel { id: settingsModel }

    function initializeFilteredModels() {
        analogInputsModel.clear()
        digitalInputsModel.clear()
        analogOutputsModel.clear()
        digitalOutputsModel.clear()
        flagsModel.clear()
        settingsModel.clear()

        for (var i = 0; i < dataModel.count; i++) {
            syncFilteredModels()
        }
    }

    // Function to update filtered models when an item changes
    function syncFilteredModels() {
        // Clear all filtered models
        analogInputsModel.clear()
        digitalInputsModel.clear()
        analogOutputsModel.clear()
        digitalOutputsModel.clear()
        flagsModel.clear()
        settingsModel.clear()

        // Repopulate from main dataModel
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)
            switch(item.paramType) {
                case "Аналоговые входы": analogInputsModel.append({ "originalIndex": i }); break
                case "Дискретные входы": digitalInputsModel.append({ "originalIndex": i }); break
                case "Аналоговый выход": analogOutputsModel.append({ "originalIndex": i }); break
                case "Дискретный выход": digitalOutputsModel.append({ "originalIndex": i }); break
                case "Признаки": flagsModel.append({ "originalIndex": i }); break
                case "Уставка": settingsModel.append({ "originalIndex": i }); break
            }
        }
    }


    function removeFromAllFilteredModels(id) {
        var models = [settingsModel, flagsModel, digitalOutputsModel,
            analogOutputsModel, digitalInputsModel, analogInputsModel]
        for (var m = 0; m < models.length; m++) {
            var model = models[m]
            for (var i = model.count - 1; i >= 0; i--) {
                if (model.get(i).__id === id) {
                    model.remove(i)
                    break
                }
            }
        }
    }


    Connections {
        target: dataModel

        function onRowsInserted(parent, first, last) {
            for (var i = first; i <= last; i++) {
                syncFilteredModels()
            }
        }

        function onRowsRemoved(parent, first, last) {
            // Rebuild all filtered models after removal
            initializeFilteredModels()
        }

        function onDataChanged(topLeft, bottomRight, roles) {
            for (var i = topLeft.row; i <= bottomRight.row; i++) {
                var item = dataModel.get(i)
                console.log("change")
                // If paramType changed, we need to re-categorize
                if (roles.length === 0 || roles.indexOf("paramType") >= 0) {
                    syncFilteredModels()
                }
            }
        }
    }

    function getFilteredModel(type) {
        switch(type) {
            case "Аналоговые входы": return analogInputsModel
            case "Дискретные входы": return digitalInputsModel
            case "Аналоговый выход": return analogOutputsModel
            case "Дискретный выход": return digitalOutputsModel
            case "Признаки": return flagsModel
            case "Уставка": return settingsModel
            default: return analogInputsModel
        }
    }



    Dialog {
        id: startDialog
        title: "Выберите действие"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent

        GridLayout {
            columns: 1
            columnSpacing: 10
            rowSpacing: 10

            Button {
                text: "Создать новую конфигурацию"
                Layout.fillWidth: true
                onClicked: {
                    dataModel.clear()
                    startDialog.close()
                }
            }

            Button {
                text: "Открыть существующую"
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width
                onClicked: {
                    fileDialog.open()
                    startDialog.close()
                }
            }
        }
    }

    Dialog {
        id: rsConfigDialog
        width: 500
        height: 500
        anchors.centerIn: parent
        title: "Настройка RS"
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                anchors.fill: parent

                Label { text: "Четность" }
                ComboBox {
                    id: parityField
                    model: ["None", "Even", "Odd"]
                }
                Label { text: "Скорость" }
                ComboBox {
                    id: baudrateField
                    model: [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
                }
                Label { text: "Длина слова" }
                TextField {
                    id: lenField
                }
                Label { text: "Стоп-бит" }
                ComboBox {
                    id: stopField
                    model: ["1", "1.5", "2"]
                }
                Label { text: "Адрес устройства"  }
                TextField {
                    id: addField
                }
                Button {
                    text: "Сохранить"
                    Layout.alignment: Qt.AlignRight
                    onClicked: {
                        // Добавляем все параметры в dataModel
                        rsConfigDialog.addToModel("RS" + rscounter + " четность", parityField.currentText, "PA_" + "RS" + rscounter + "_PARITY", "unsigned short", "Да", "Нет");
                        rsConfigDialog.addToModel("RS" + rscounter +" скорость", baudrateField.currentText, "PA_" + "RS" + rscounter + "_BAUDRATE", "unsigned short", "Да", "Нет");
                        rsConfigDialog.addToModel("RS" + rscounter +" длина слова", lenField.text, "PA_" + "RS" + rscounter + "_WORD_LEN", "unsigned short", "Да", "Нет");
                        rsConfigDialog.addToModel("RS" + rscounter +" стоп-бит", stopField.currentText, "PA_" + "RS" + rscounter + "_STOP_BITS", "unsigned short", "Да", "Нет");
                        rsConfigDialog.addToModel("RS" + rscounter +" адрес устройства", addField.text, "PA_" + "RS" + rscounter + "_MAC_NIC", "unsigned int", "Да", "Нет");
                        rsConfigDialog.close();
                    }
                }
            }

        }
        function addToModel(name, value, codename, type, saving, logicuse) {
            dataModel.append({
                "paramType": "Уставка",
                "name": name,
                "ioIndex": rootwindow.nextIoIndex.toString(),
                "codeName": codename,
                "def_value": value,
                "type": type,
                "saving": saving,
                "logicuse": logicuse,
                "aperture": "",
                "ktt": "",
                "ad": "",
                "oc": "",
                "tosp": "",
                "tolp": ""
            });
        }
    }

    Dialog {
        id: ethConfigDialog
        width: 500
        height: 1080
        anchors.centerIn: parent
        title: "Настройка ETH"
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            anchors.fill: parent

            Label { text: "IP адрес" }
            TextField {
                id: ipAddressField
                inputMask: "000.000.000.000;_"
                placeholderText: "192.168.0.1"
            }

            Label { text: "Маска подсети" }
            TextField {
                id: subnetMaskField
                inputMask: "000.000.000.000;_"
                placeholderText: "255.255.255.0"
            }

            Label { text: "Шлюз" }
            TextField {
                id: gatewayField
                inputMask: "000.000.000.000;_"
                placeholderText: "192.168.0.254"
            }

            Label { text: "Старшие 3 байта MAC адреса" }
            TextField {
                id: macHighField
                inputMask: "HH:HH:HH;_"
                placeholderText: "00:1A:2B"
            }

            Label { text: "Младшие 3 байта MAC адреса" }
            TextField {
                id: macLowField
                inputMask: "HH:HH:HH;_"
                placeholderText: "3C:4D:5E"
            }

            Label { text: "IP адрес клиента 1" }
            TextField {
                id: clientIp1Field
                inputMask: "000.000.000.000;_"
                placeholderText: "192.168.0.10"
            }

            Label { text: "IP адрес клиента 2" }
            TextField {
                id: clientIp2Field
                inputMask: "000.000.000.000;_"
                placeholderText: "192.168.0.11"
            }

            Label { text: "IP адрес клиента 3" }
            TextField {
                id: clientIp3Field
                inputMask: "000.000.000.000;_"
                placeholderText: "192.168.0.12"
            }

            Label { text: "IP адрес клиента 4" }
            TextField {
                id: clientIp4Field
                inputMask: "000.000.000.000;_"
                placeholderText: "192.168.0.13"
            }
            Label { text: "ETH адрес устройства"}
            TextField {
                id: addrField
            }
            Label { text: "Порт 1" }
            TextField {
                id: port1Field
                validator: IntValidator { bottom: 1; top: 65535 }
            }

            Label { text: "Порт 2" }
            TextField {
                id: port2Field
                validator: IntValidator { bottom: 1; top: 65535 }
            }

            Label { text: "Порт 3" }
            TextField {
                id: port3Field
                validator: IntValidator { bottom: 1; top: 65535 }
            }

            Label { text: "Порт 4" }
            TextField {
                id: port4Field
                validator: IntValidator { bottom: 1; top: 65535 }
            }
            Button {
                text: "Сохранить"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    ethConfigDialog.addToModel("ETH" + ethcounter + " IP адрес", ipAddressField.text, "ETH" + ethcounter + "_IP_ADDR", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Маска подсети", subnetMaskField.text, "ETH" + ethcounter + "_MASK", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Шлюз", gatewayField.text, "ETH" + ethcounter + "_GATEWAY", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Старшие 3 байта MAC", macHighField.text, "ETH" + ethcounter + "_MAC_OUI", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Младшие 3 байта MAC", macLowField.text, "ETH" + ethcounter + "_MAC_NIC", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" IP клиента 1", clientIp1Field.text, "ETH" + ethcounter + "_IP_CLIENT1", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" IP клиента 2", clientIp2Field.text, "ETH" + ethcounter + "_IP_CLIENT2", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" IP клиента 3", clientIp3Field.text, "ETH" + ethcounter + "_IP_CLIENT3", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" IP клиента 4", clientIp4Field.text, "ETH" + ethcounter + "_IP_CLIENT4", "unsigned int", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" адрес устройства", clientIp4Field.text, "ETH" + ethcounter + "_ADDR", "unsigned short", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Порт 1", port1Field.text, "ETH" + ethcounter + "_IP_PORT1", "unsigned short", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Порт 2", port2Field.text, "ETH" + ethcounter + "_IP_PORT2", "unsigned short", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Порт 3", port3Field.text, "ETH" + ethcounter + "_IP_PORT3", "unsigned short", "Да", "Нет");
                    ethConfigDialog.addToModel("ETH" + ethcounter +" Порт 4", port4Field.text, "ETH" + ethcounter + "_IP_PORT4", "unsigned short", "Да", "Нет");

                    ethConfigDialog.close();
                }
            }
        }

        }
        function addToModel(name, value, codename, type, saving, logicuse) {
            dataModel.append({
                "paramType": "Уставка",
                "name": name,
                "ioIndex": rootwindow.nextIoIndex.toString(),
                "codeName": codename,
                "def_value": value,
                "type": type,
                "saving": saving,
                "logicuse": logicuse,
                "aperture": "",
                "ktt": "",
                "ad": "",
                "oc": "",
                "tosp": "",
                "tolp": ""
            });
        }
    }

    FileDialog {
        id: jsonSelectDialog
        title: "Выберите JSON файл"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON файлы (*.json)"]
        property string exportType: ""
        onAccepted: {
            let localPath = selectedFile.toString().startsWith("file:///")
                ? selectedFile.toString().substring(8)
                : selectedFile.toString().replace("file://", "")
            if(exportType === "code"){
                fileHandler.runPythonScript(localPath, true)
            }
            if(exportType === "exel")
                {
                fileHandler.runPythonScript(localPath, false)
            }

        }

        onRejected: {
            console.log("Выбор отменён")
        }
    }

    Platform.FileDialog {
        id: fileDialog
        title: "Выберите файл конфигурации"
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
           const cleanPath = fileHandler.cleanPath(String(file))
            const data = fileHandler.loadFromFile(cleanPath)
            if (data) {
                stateFileName = cleanPath
                console.log("Trying to load:", data)
                if (data) {
                    dataModel.clear()
                    for (var i = 0; i < data.length; i++) {
                        dataModel.append(data[i])
                    }
                    updateNextIoIndex();
                    initializeFilteredModels()
                    updateFiltered()
                    updateTrigger()
                    modbus = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("address");
                    mek = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("ioa_address");
                    mek_101 = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("use_in_spont_101");
                    mek_104 = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("use_in_spont_104");


                        Qt.callLater(() => {
                            for (let i = 0; i < listView.count; ++i) {
                        let item = listView.itemAtIndex(i);
                        if (item && item.nameField) {
                            item.nameField.updateName(item.nameField.text);
                        }
                        if (item && item.codeNameField) {
                            item.codeNameField.updateName(item.codeNameField.text);
                        }

                    }
                    checkForDuplicates();

                });
                }
                loadingState = false
            }
        }
    }



    Dialog {
        id: exitConfirmDialog
        title: "Есть несохранённые изменения"
        standardButtons: Dialog.Yes | Dialog.No | Dialog.Cancel
        modal: true
        Label {
            text: "Сохранить изменения перед выходом?"
        }

        onAccepted: {
            saveFileDialog.open()
            saveFileDialog.onAccepted.connect(function () {
                if (fileHandler.saveToFile(saveFileDialog.file, exportToJson())) {
                    closeapp = true
                    Qt.quit()
                } else {
                    closeWindow(false)
                }
            })
        }

        onRejected: {
            console.log("Save successful, quitting")
            closeapp = true
            Qt.quit()
        }
    }


    onClosing: (close) =>
        {
        if (!closeapp) {
            close.accepted = false
            exitConfirmDialog.open()
        }
    }

    function closeWindow(accepted) {
        if (accepted) {
            rootwindow.close()
        }
        else {
            exitConfirmDialog.open()
        }
    }

    Component.onCompleted: {
        startDialog.open()
    }


    FileHandler {
        id: fileHandler
    }

    function exportToJson() {
        var result = []
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)
            var exportItem = {}
            var props = Object.keys(item)
            for (var j = 0; j < props.length; j++) {
                var prop = props[j]
                if (typeof item[prop] !== "function") {
                    exportItem[prop] = item[prop]
                }
            }
            result.push(exportItem)
        }
            for (var k = 0; k < objectModels.count; k++) {
                var model = objectModels.get(k);
                result.push({
                    interface: true,
                    id: model.id,
                    type: model.type
                })
            }
            for (var n = 0; n < interfaceModel.count; n++) {
                var model = interfaceModel.get(n);
                result.push({
                    interface: true,
                    id: model.id,
                    type: model.type
                })
            }
        return JSON.stringify(result, null, 2)
        }

    function saveToBlde(path) {
        let json = exportToJson()
        fileHandler.saveToFile(path, json)
    }


    Component {
        id: parameterPageComponent1


        ColumnLayout {
            id: pageRoot1
            property string paramType: "Дискретный выход"
            signal addClicked
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                padding: 10
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                leftPadding: 15
                rightPadding: 22
                contentWidth: listView1.width - 30
                contentHeight: listView1.height
                ListView {
                    id: listView1
                    width: parent.width - 30
                    height: parent.height
                    cacheBuffer: 200
                    model: digitalOutputsModel
                    spacing: 0
                    interactive: true
                    clip: true
                    headerPositioning: ListView.OverlayHeader
                    header: Rectangle {
                        z: 2
                        width: listView1.width
                        height: 32
                        color: "#f1f5f9"
                        antialiasing: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#cbd5e1"
                        }

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: "#e2e8f0"
                        }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#f8fafc" }
                            GradientStop { position: 1.0; color: "#e2e8f0" }
                        }

                        layer.enabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0

                            Label {
                                text: "IO"
                                Layout.preferredWidth: 50
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Наименование"
                                Layout.preferredWidth: 350
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Англ.название"
                                Layout.preferredWidth: 350
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Single/Double"
                                Layout.preferredWidth: 80
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Логика"
                                Layout.preferredWidth: 100
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Выход"
                                Layout.preferredWidth: 100
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Короткий импульс"
                                Layout.preferredWidth: 160
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: "Длинный импульс"
                                Layout.preferredWidth: 160
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: ""
                                Layout.preferredWidth: 160
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    delegate: RowLayout {
                        z:1
                        property bool hasDuplicateName: itemData.isNameDuplicate || false
                        property bool hasDuplicateCodeName: itemData.isCodeNameDuplicate || false

                        required property int index
                        property string ioIndex
                        property string paramType
                        property string name
                        property string codeName
                        property string type
                        property string logicuse
                        property string saving
                        property string aperture
                        property string ktt
                        property string def_value
                        property string ad
                        property string oc
                        property string tosp
                        property string tolp

                        property int originalIndex: digitalOutputsModel.get(index).originalIndex

                        width: listView1.width
                        spacing: 0
                        height: implicitHeight

                        property var itemData: dataModel.get(originalIndex)

                        TextField {
                            text: itemData.ioIndex
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 30
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                // Subtle shadow when focused
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -1
                                    color: "transparent"
                                    border.color: parent.parent.activeFocus ? "#3b82f620" : "transparent"
                                    border.width: 2
                                    radius: 5
                                    visible: parent.parent.activeFocus
                                }

                                // Modern transition
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            onTextChanged: dataModel.setProperty(originalIndex, "ioIndex", text)
                        }

                        TextField {
                            text: itemData.name
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 32

                            color: (itemData.isNameDuplicate || false) ? "#dc2626" : "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: (itemData.isNameDuplicate || false) ? "#dc2626" :
                                    (parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0"))
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: {
                                dataModel.setProperty(originalIndex, "name", text)
                                Qt.callLater(rootwindow.checkForDuplicates)
                            }
                        }

                        TextField {
                            id: codeNameField
                            text: itemData.codeName
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 32

                            color: itemData.isCodeNameDuplicate ? "#dc2626" : "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: (itemData.isCodeNameDuplicate || false) ? "#dc2626" :
                                    (parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0"))
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: {
                                Qt.callLater(rootwindow.checkForDuplicates)
                            }

                            onEditingFinished: {
                                if (text === itemData.codeName)
                                    return

                                let newCodeName = text
                                let newOc = "VAL_" + newCodeName

                                // Обновляем текущий элемент
                                dataModel.setProperty(originalIndex, "codeName", newCodeName)
                                updateFiltered()
                                updateTrigger()
                                // Ищем соответствующий уже добавленный innermek-элемент
                                let existingIndex = -1
                                for (let i = 0; i < dataModel.count; ++i) {
                                    let item = dataModel.get(i)
                                    if (item.paramType === "innermek" && item.oc === newOc) {
                                        existingIndex = i
                                        break
                                    }
                                }

                                if (existingIndex >= 0) {
                                    // Уже существует — просто обновим данные
                                    dataModel.setProperty(existingIndex, "oc", newOc)
                                    dataModel.setProperty(existingIndex, "codeName", newOc)
                                    dataModel.setProperty(existingIndex, "name", newOc)
                                } else {
                                    // Создаём только если ещё не было
                                    dataModel.append({
                                        paramType: "innermek",
                                        ioIndex: rootwindow.nextIoIndex.toString(),
                                        name: newOc,
                                        codeName: newOc,
                                        oc: newOc,
                                        type: "bool",
                                        logicuse: "Да",
                                        saving: "Нет",
                                        sod: "",
                                        aperture: "",
                                        ktt: "",
                                        def_value: "",
                                        ad: "",
                                        tosp: "",
                                        tolp: "",
                                        address: "",
                                        blockName: "",
                                        ioa_address: "",
                                        asdu_address: 1,
                                        second_class_num: "",
                                        type_spont: "",
                                        type_back: "",
                                        type_percyc: "",
                                        type_def: "",
                                        oi_c_sc_na_1: false,
                                        oi_c_se_na_1: false,
                                        oi_c_se_nb_1: false,
                                        oi_c_dc_na_1: false,
                                        oi_c_bo_na_1: false,
                                        use_in_spont_101: false,
                                        use_in_back_101: false,
                                        use_in_percyc_101: false,
                                        allow_address_101: false,
                                        survey_group_101: "",
                                        use_in_spont_104: false,
                                        use_in_back_104: false,
                                        use_in_percyc_104: false,
                                        allow_address_104: false,
                                        survey_group_104: ""
                                    })
                                }

                                Qt.callLater(rootwindow.checkForDuplicates)
                            }
                        }
                        Switch {
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            checked: itemData.sod || false
                            onCheckedChanged: {
                                dataModel.setProperty(originalIndex, "sod", checked)

                                let parentCodeName = itemData.codeName
                                let childCodeName = "VAL_" + parentCodeName

                                for (let i = 0; i < dataModel.count; i++) {
                                    let item = dataModel.get(i)
                                    if (item.paramType === "innermek" && item.codeName === childCodeName) {
                                        dataModel.setProperty(i, "type", checked ? "unsigned char" : "bool")
                                        break
                                    }
                                }
                            }
                        }
                        ComboBox {
                            model: ["Да", "Нет"]
                            currentIndex: {
                                if (!itemData) return 0
                                return model.indexOf(itemData.logicuse || "bool")
                            }
                            onCurrentTextChanged: {
                                if (itemData) {
                                    dataModel.setProperty(originalIndex, "logicuse", currentText)
                                }
                            }
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 30
                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                        TextField {
                            text: "VAL_" + codeNameField.text
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 30
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            enabled: false
                        }
                        ComboBox {
                            id: tospComboBox
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            editable: true
                            model: toModel

                            Component.onCompleted: {
                                const idx = toModel.indexOf(itemData.tosp)
                                currentIndex = idx >= 0 ? idx : -1
                            }

                            onActivated: {
                                if (currentIndex >= 0) {
                                    dataModel.setProperty(originalIndex, "tosp", toModel[currentIndex])
                                }
                            }

                            onCurrentTextChanged: {
                                if (!toModel.includes(currentText)) {
                                    dataModel.setProperty(originalIndex, "tosp", currentText)
                                }
                            }
                        }

                        ComboBox {
                            id: tolpComboBox
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30
                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            editable: true
                            model: toModel

                            Component.onCompleted: {
                                const idx = toModel.indexOf(itemData.tolp)
                                currentIndex = idx >= 0 ? idx : -1
                            }

                            onActivated: {
                                if (currentIndex >= 0) {
                                    dataModel.setProperty(originalIndex, "tolp", toModel[currentIndex])
                                }
                            }

                            onCurrentTextChanged: {
                                if (!toModel.includes(currentText)) {
                                    dataModel.setProperty(originalIndex, "tolp", currentText)
                                }
                            }
                        }

                        Button {
                            text: "Удалить"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 32

                            font.pixelSize: 13
                            font.weight: Font.Medium

                            background: Rectangle {
                                color: parent.pressed ? "#b91c1c" : (parent.hovered ? "#dc2626" : "#ef4444")
                                radius: 4
                                antialiasing: true

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#ffffff"
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: dataModel.remove(originalIndex)
                        }
                    }
                }
            }

            Button {
                Layout.alignment: Qt.AlignCenter
                text: "Добавить"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40

                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? "#059669" : (parent.hovered ? "#10b981" : "#22c55e")
                    radius: 6
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: "#ffffff"
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    addClicked()
                    dataModel.append( {
                        "paramType": "Дискретный выход",
                        "ioIndex": rootwindow.nextIoIndex.toString(),
                        "name": "",
                        "codeName": "",
                        "sod": false,
                        "type": "unsigned char",
                        "logicuse": "Да",
                        "saving": "Да",
                        "aperture": "",
                        "ktt": "",
                        "def_value": "",
                        "ad": "",
                        "oc": "",
                        "tosp": "",
                        "tolp": "",
                        "sector": "",
                        "address": "",
                        "blockName": "",
                        "ioa_address": "",
                        "asdu_address": 1,
                        "second_class_num": "",
                        "type_spont": "",
                        "type_back": "",
                        "type_percyc": "",
                        "type_def": "",
                        "oi_c_sc_na_1": false,
                        "oi_c_se_na_1": false,
                        "oi_c_se_nb_1": false,
                        "oi_c_dc_na_1": false,
                        "oi_c_bo_na_1": false,
                        "use_in_spont_101": false,
                        "use_in_back_101": false,
                        "use_in_percyc_101": false,
                        "allow_address_101": false,
                        "survey_group_101": "",
                        "use_in_spont_104": false,
                        "use_in_back_104": false,
                        "use_in_percyc_104": false,
                        "allow_address_104": false,
                        "survey_group_104": "",
                        isNameDuplicate: false,
                        isCodeNameDuplicate: false
                    });
                    updateFiltered()
                    updateTrigger()
                }
            }
        }
    }

    Component {
        id: parameterPageComponent
        ColumnLayout {
            id: pageRoot
            property string paramType: "Аналоговые входы"
            signal addClicked
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
                    model: getFilteredModel(pageRoot.paramType)
                    spacing: 0
                    interactive: true
                    clip: true
                    headerPositioning: ListView.OverlayHeader
                    header: Rectangle {
                        z: 2
                        width: listView.width
                        height: 32
                        color: "#f1f5f9"
                        antialiasing: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#cbd5e1"
                        }

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: "#e2e8f0"
                        }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#f8fafc" }
                            GradientStop { position: 1.0; color: "#e2e8f0" }
                        }

                        layer.enabled: false
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0

                            Label { text: "IO"
                                Layout.preferredWidth: 50
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: "Наименование"
                                Layout.preferredWidth: 350
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: "Англ.название"
                                Layout.preferredWidth: 350
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: "Тип"
                                Layout.preferredWidth: 120
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: "Логика"
                                Layout.preferredWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: "Сохран."
                                visible: rootwindow.currentType === "Признаки" || rootwindow.currentType === "Уставка
                               "
                                Layout.preferredWidth: 140
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: "Триггер"
                                visible: rootwindow.currentType === "Признаки"
                                Layout.preferredWidth: 140
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: "Апертура"
                                visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка
                               "
                                Layout.preferredWidth: 120
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: "КТТ"
                                visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка
                               "
                                Layout.preferredWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: "Знач. по умолч."
                                visible: !(rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы")
                                Layout.preferredWidth: 120
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: "Антидребезг"
                                Layout.preferredWidth: 170
                                visible: rootwindow.currentType === "Дискретные входы"
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: ""
                                Layout.preferredWidth: 120
                            }
                        }
                    }

                    delegate: RowLayout {
                        z: 1
                        property bool hasDuplicateName: itemData.isNameDuplicate || false
                        property bool hasDuplicateCodeName: itemData.isCodeNameDuplicate || false

                        required property int index
                        property string ioIndex
                        property string paramType
                        property string name
                        property string codeName
                        property string type
                        property string logicuse
                        property string saving
                        property string aperture
                        property string ktt
                        property string def_value
                        property string ad
                        property string oc
                        property string sector
                        property string tosp
                        property string tolp

                        property int originalIndex: {
                            switch (pageRoot.paramType) {
                                case "Аналоговые входы":
                                    return analogInputsModel.get(index).originalIndex
                                case "Дискретные входы":
                                    return digitalInputsModel.get(index).originalIndex
                                case "Аналоговый выход":
                                    return analogOutputsModel.get(index).originalIndex
                                case "Дискретный выход":
                                    return digitalOutputsModel.get(index).originalIndex
                                case "Признаки":
                                    return flagsModel.get(index).originalIndex
                                case "Уставка":
                                    return settingsModel.get(index).originalIndex
                                default:
                                    return -1
                            }
                        }

                        width: listView.width
                        spacing: 0
                        height: 34

                        property var itemData: dataModel.get(originalIndex)

                        TextField {
                            text: itemData.ioIndex
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 32

                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: dataModel.setProperty(originalIndex, "ioIndex", text)
                        }

                        TextField {
                            text: itemData.name
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 32

                            color: (itemData.isNameDuplicate || false) ? "#dc2626" : "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: (itemData.isNameDuplicate || false) ? "#dc2626" :
                                    (parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0"))
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: {
                                dataModel.setProperty(originalIndex, "name", text)
                                Qt.callLater(rootwindow.checkForDuplicates)
                            }
                        }

                        TextField {
                            text: itemData.codeName
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 32

                            color: itemData.isCodeNameDuplicate ? "#dc2626" : "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: (itemData.isCodeNameDuplicate || false) ? "#dc2626" :
                                    (parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0"))
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: {
                                dataModel.setProperty(originalIndex, "codeName", text)
                                Qt.callLater(rootwindow.checkForDuplicates)
                            }
                        }

                        ComboBox {
                            editable: true
                            model: ["bool", "float", "unsigned int", "unsigned short", "unsigned char"]
                            currentIndex: model.indexOf(itemData.type || "bool")
                            onCurrentTextChanged: dataModel.setProperty(originalIndex, "type", currentText)
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32

                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }

                        ComboBox {
                            model: ["Да", "Нет"]
                            currentIndex: model.indexOf(itemData.logicuse || "Да")
                            onCurrentTextChanged: dataModel.setProperty(originalIndex, "logicuse", currentText)
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32

                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }

                        ComboBox {
                            visible: rootwindow.currentType === "Признаки" || rootwindow.currentType === "Уставка
                           "
                            model: ["Нет", "Да"]
                            currentIndex: model.indexOf(itemData.saving || "Нет")
                            onCurrentTextChanged: dataModel.setProperty(originalIndex, "saving", currentText)
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 32

                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }

                        ComboBox {
                            visible: rootwindow.currentType === "Признаки"
                            editable: true
                            model: triggerModel
                            currentIndex: triggerModel.indexOf(itemData.sector)
                            onCurrentTextChanged: dataModel.setProperty(originalIndex, "sector", currentText)
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 32

                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }

                        TextField {
                            visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка
                           "
                            text: itemData.aperture
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32

                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: dataModel.setProperty(originalIndex, "aperture", text)
                        }

                        TextField {
                            visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка
                           "
                            text: itemData.ktt
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32

                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: dataModel.setProperty(originalIndex, "ktt", text)
                        }

                        TextField {
                            visible: !(rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы")
                            text: itemData.def_value
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32

                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: dataModel.setProperty(originalIndex, "def_value", text)
                        }

                        TextField {
                            text: itemData.ad
                            Layout.preferredWidth: 170
                            Layout.preferredHeight: 32
                            visible: rootwindow.currentType === "Дискретные входы"

                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            onTextChanged: dataModel.setProperty(originalIndex, "ad", text)
                        }

                        Button {
                            text: "Удалить"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 32

                            font.pixelSize: 13
                            font.weight: Font.Medium

                            background: Rectangle {
                                color: parent.pressed ? "#b91c1c" : (parent.hovered ? "#dc2626" : "#ef4444")
                                radius: 4
                                antialiasing: true

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#ffffff"
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: dataModel.remove(originalIndex)
                        }
                    }
                }
            }

            Button {
                Layout.alignment: Qt.AlignCenter
                text: "Добавить"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40

                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? "#059669" : (parent.hovered ? "#10b981" : "#22c55e")
                    radius: 6
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: "#ffffff"
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    addClicked()
                    dataModel.append( {
                        "paramType": pageRoot.paramType,
                        "ioIndex": rootwindow.nextIoIndex.toString(),
                        "name": "",
                        "codeName": "",
                        "type": "bool",
                        "logicuse": "Да",
                        "saving": "Да",
                        "aperture": "",
                        "ktt": "",
                        "def_value": "",
                        "ad": "",
                        "oc": "",
                        "tosp": "",
                        "tolp": "",
                        "sector": "",
                        "address": "",
                        "blockName": "",
                        "ioa_address": "",
                        "asdu_address": 1,
                        "second_class_num": "",
                        "type_spont": "",
                        "type_back": "",
                        "type_percyc": "",
                        "type_def": "",
                        "oi_c_sc_na_1": false,
                        "oi_c_se_na_1": false,
                        "oi_c_se_nb_1": false,
                        "oi_c_dc_na_1": false,
                        "oi_c_bo_na_1": false,
                        "use_in_spont_101": false,
                        "use_in_back_101": false,
                        "use_in_percyc_101": false,
                        "allow_address_101": false,
                        "survey_group_101": "",
                        "use_in_spont_104": false,
                        "use_in_back_104": false,
                        "use_in_percyc_104": false,
                        "allow_address_104": false,
                        "survey_group_104": "",
                        isNameDuplicate: false,
                        isCodeNameDuplicate: false
                    });
                    Qt.callLater(syncFilteredModels)
                    updateFiltered()
                    updateTrigger()
                }
            }
        }
    }
    Component {
        id: modbusPageComponent
            Item {
                anchors.fill: parent
                property var typeIndexMap: {
                    "Coil": 0,
                    "Discrete input": 0,
                    "Input register": 0,
                    "Holding register": 0
                }
                ColumnLayout {
                    id: grid
                    width: parent.width - 30
                    spacing: 5
                    anchors.fill: parent
                    Layout.preferredHeight: 30
                    RowLayout {
                        spacing: 5
                        Label {
                            text: "IO"
                            Layout.preferredWidth: 50
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Label {
                            text: "Тип"
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter                        }
                        Label {
                            text: "Наименование"
                            Layout.preferredWidth: 200
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter                        }
                        Label {
                            text: "Тип данных"
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter                        }
                        Label {
                            text: "Адрес"
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter                        }
                        Label {
                            text: "Блок"
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter                        }
                        Item {
                            Layout.preferredWidth: 160
                        }
                    }

                    ListView {
                        id: mbList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cacheBuffer: 200
                        spacing: 4
                        model: dataModel
                        ScrollBar.vertical: ScrollBar {
                            id: vbar
                            policy: ScrollBar.AlwaysOn
                        }
                        delegate: Item {
                            width: mbList.width
                            height: 40
                            RowLayout{
                                Text {
                                    text: ioIndex
                                    Layout.preferredWidth: 50
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: paramType
                                    Layout.preferredWidth: 100
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: name
                                    Layout.preferredWidth: 200
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: type
                                    Layout.preferredWidth: 100
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                TextField {
                                    id: mbaddress
                                    text: {
                                        const item = dataModel.get(index);
                                        return item ? (item.address || "") : "";
                                    }

                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30

                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.Normal

                                    leftPadding: 8
                                    rightPadding: 8
                                    topPadding: 6
                                    bottomPadding: 6

                                    selectByMouse: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    // Only allow numbers
                                    validator: IntValidator { bottom: 1; top: 65535 }

                                    background: Rectangle {
                                        color: enabled ? "#ffffff" : "#f8fafc"
                                        border.color: parent.activeFocus ? "#3b82f6" :
                                            (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                        border.width: 1
                                        radius: 4
                                        antialiasing: true

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    onTextChanged: {
                                        if (text !== "") {
                                            dataModel.setProperty(index, "address", text);
                                        }
                                    }

                                    // Clear address when text is manually cleared
                                    onEditingFinished: {
                                        if (text === "") {
                                            dataModel.setProperty(index, "address", "");
                                        }
                                    }
                                }

                                // Block Type ComboBox
                                ComboBox {
                                    id: combo
                                    model: ["Coil", "Discrete input", "Input register", "Holding register"]

                                    currentIndex: {
                                        const item = dataModel.get(index);
                                        const blockName = item ? item.blockName : "";
                                        return model.indexOf(blockName || "Coil");
                                    }

                                    Layout.preferredWidth: 150
                                    Layout.preferredHeight: 30

                                    onActivated: { // Use activated instead of currentIndexChanged
                                        if (currentIndex >= 0) {
                                            const newBlockType = model[currentIndex];
                                            const oldBlockType = dataModel.get(index).blockName;

                                            // Update the block type
                                            dataModel.setProperty(index, "blockName", newBlockType);

                                            // If block type changed, clear the address and assign new one

                                                dataModel.setProperty(index, "address", "");
                                                assignAddressByType(newBlockType);
                                            }
                                        }
                                    }

                                Button {
                                    text: "Удалить"
                                    Layout.preferredWidth: 160
                                    Layout.preferredHeight: 32

                                    font.pixelSize: 13
                                    font.weight: Font.Medium

                                    background: Rectangle {
                                        color: parent.pressed ? "#b91c1c" : (parent.hovered ? "#dc2626" : "#ef4444")
                                        radius: 4
                                        antialiasing: true

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: "#ffffff"
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked: dataModel.remove(originalIndex)
                                }
                            }
                        }
                    }
                }
            }

        }

    Component {
        id: mekPageComponent
        Item {
            anchors.fill: parent
            Component.onCompleted: assignIOA()
            ColumnLayout {
                spacing: 8
                width: parent.width - 30
                anchors.fill: parent

                RowLayout {
                    spacing: 8

                    Label {
                        text: "IO"
                        Layout.preferredWidth: 50
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Тип"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Наименование"
                        Layout.preferredWidth: 200
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "Адрес ОИ"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Тип данных"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Адрес АСДУ"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Номер буфера"
                        Layout.preferredWidth: 130
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Тип при спорадике"
                        Layout.preferredWidth: 130
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Тип при фоновом"
                        Layout.preferredWidth: 130
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Тип при пер/цик"
                        Layout.preferredWidth: 130
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: "Тип при общем"
                        Layout.preferredWidth: 130
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label { text: ""
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                ListView {
                    id: mekList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cacheBuffer: 200
                    spacing: 4
                    model: dataModel
                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        policy: ScrollBar.AlwaysOn
                    }
                    delegate: Item {
                        width: mekList.width
                        height: 40

                        RowLayout{
                        Text {
                            text: ioIndex
                                Layout.preferredWidth: 50
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                            }

                            Text { text: paramType
                                Layout.preferredWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                text: name
                                Layout.preferredWidth: 200
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text { text: type
                                Layout.preferredWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            TextField {
                                text: ioa_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                visible: rootwindow.currentType === "Дискретные входы"

                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onTextChanged: dataModel.setProperty(index, "ioa_address", text)
                            }

                            TextField {
                                text: asdu_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                visible: rootwindow.currentType === "Дискретные входы"

                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onTextChanged: dataModel.setProperty(index, "asdu_address", text)
                            }

                            ComboBox {
                                model: ["NOT_USE", "SECOND_CLASS_1", "SECOND_CLASS_2", "SECOND_CLASS_3", "SECOND_CLASS_4",
                                    "SECOND_CLASS_5", "SECOND_CLASS_6", "SECOND_CLASS_7", "SECOND_CLASS_8"]
                                currentIndex: model.indexOf(second_class_num || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onCurrentIndexChanged: dataModel.setProperty(index, "second_class_num", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1", "M_BO_NA_1",
                                    "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1", "M_ME_TB_1", "M_ME_NC_1",
                                    "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1", "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"]
                                currentIndex: model.indexOf(type_spont || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_spont", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_DP_NA_1", "M_BO_NA_1", "M_ME_NA_1",
                                    "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"]
                                currentIndex: model.indexOf(type_back || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_back", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_ME_NA_1", "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"]
                                currentIndex: model.indexOf(type_percyc || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_percyc", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1", "M_BO_NA_1",
                                    "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1", "M_ME_TB_1", "M_ME_NC_1",
                                    "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1", "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"]
                                currentIndex: model.indexOf(type_def || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? "#ffffff" : "#f8fafc"
                                    border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_def", model[currentIndex])
                            }
                            Button {
                                text: "Удалить"
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 32

                                font.pixelSize: 13
                                font.weight: Font.Medium

                                background: Rectangle {
                                    color: parent.pressed ? "#b91c1c" : (parent.hovered ? "#dc2626" : "#ef4444")
                                    radius: 4
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "#ffffff"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: dataModel.remove(originalIndex)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mek101PageComponent
        Item {
            anchors.fill: parent
            ColumnLayout {
                id: mek_101_grid
                width: parent.width - 30
                spacing: 8
                anchors.fill: parent

                RowLayout {
                    spacing: 8

                    Label {
                        text: "IO"
                        Layout.preferredWidth: 50
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Тип"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Наименование"
                        Layout.preferredWidth: 200
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "Адрес ОИ"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Адрес АСДУ"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Исп. в спорадике"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Исп. в цикл/период"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Исп. в фон. сканир"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Разреш. адрес"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Группа опроса"
                        Layout.preferredWidth: 150
                        color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: ""
                        Layout.preferredWidth: 160
                    }
                }
                ListView {
                    id: mek101List
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cacheBuffer: 200
                    spacing: 4
                    model: dataModel
                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        policy: ScrollBar.AlwaysOn
                    }
                    delegate: Item {
                        width: mek101List.width
                        height: 40

                        RowLayout{
                        Text {
                            text: ioIndex
                            Layout.preferredWidth: 50
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: paramType
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: name
                            Layout.preferredWidth: 200
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                ToolTip.visible: containsMouse
                                ToolTip.text: name
                            }
                        }
                        Text {
                            text: ioa_address
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: asdu_address
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Switch {
                            checked: model.use_in_spont_101 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "use_in_spont_101", checked)
                        }
                        Switch {
                            checked: model.use_in_back_101 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "use_in_back_101", checked)
                        }
                        Switch {
                            checked: model.use_in_percyc_101 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "use_in_percyc_101", checked)
                        }
                        Switch {
                            checked: model.allow_address_101 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "allow_address_101", checked)
                        }
                        ComboBox {
                            id: surveyGroupCombo
                            model: ["GENERAL_SURVEY", "GROUP_1", "GROUP_2", "GROUP_3", "GROUP_4",
                                "GROUP_5", "GROUP_6", "GROUP_7", "GROUP_8"]
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 30
                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            property string _currentValue: survey_group_101 || ""
                            property bool _initialized: false

                            Component.onCompleted: {
                                if (_currentValue) {
                                    var idx = model.indexOf(_currentValue);
                                    currentIndex = idx >= 0 ? idx : 0;
                                } else {
                                    currentIndex = 0;
                                }
                                _initialized = true;
                            }

                            on_CurrentValueChanged: {
                                if (_initialized && _currentValue) {
                                    var idx = model.indexOf(_currentValue);
                                    currentIndex = idx >= 0 ? idx : 0;
                                }
                            }

                            onCurrentIndexChanged: {
                                if (_initialized && !loadingState && currentIndex >= 0) {
                                    dataModel.setProperty(index, "survey_group_101", model[currentIndex]);
                                }
                            }
                        }
                        Button {
                            text: "Удалить"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 32

                            font.pixelSize: 13
                            font.weight: Font.Medium

                            background: Rectangle {
                                color: parent.pressed ? "#b91c1c" : (parent.hovered ? "#dc2626" : "#ef4444")
                                radius: 4
                                antialiasing: true

                                Behavior on color {
                                    ColorAnimation { duration: 150
                                    }
                                }
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#ffffff"
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: dataModel.remove(originalIndex)
                        }

                    }
                }
            }
        }
    }
    }

    Component {
        id: mek104PageComponent
        Item {
            anchors.fill: parent
            ColumnLayout {
                id: mek_104_grid
                width: parent.width - 30
                spacing: 8
                anchors.fill: parent
                RowLayout {
                    spacing: 8
                    Label {
                        text: "IO"
                        Layout.preferredWidth: 50
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Тип"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Наименование"
                        Layout.preferredWidth: 200
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Адрес ОИ"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Адрес АСДУ"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Исп. в спорадике"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Исп. в цикл/период"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Исп. в фон. сканир"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Разреш. адрес"
                        Layout.preferredWidth: 100
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "Группа опроса"
                        Layout.preferredWidth: 150
                        color: "#1e293b"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: ""
                        Layout.preferredWidth: 160
                    }
                }

                ListView {
                    id: mek104List
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cacheBuffer: 200
                    spacing: 4
                    model: dataModel
                    ScrollBar.vertical: ScrollBar {
                        id: vbar
                        policy: ScrollBar.AlwaysOn
                    }
                    delegate: Item {
                        width: mek104List.width
                        height: 40

                        RowLayout{
                        Text {
                            text: ioIndex
                            Layout.preferredWidth: 50
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: paramType
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: name
                            Layout.preferredWidth: 200
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                ToolTip.visible: containsMouse
                                ToolTip.text: name
                            }
                        }
                        Text {
                            text: ioa_address
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: asdu_address
                            Layout.preferredWidth: 100
                            color: "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                        Switch {
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            checked: model.use_in_spont_104 || false
                            onCheckedChanged: dataModel.setProperty(index, "use_in_spont_104", checked)
                        }
                        Switch {
                            checked: model.use_in_back_104 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "use_in_back_104", checked)
                        }
                        Switch {
                            checked: model.use_in_percyc_104 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "use_in_percyc_104", checked)
                        }
                        Switch {
                            checked: model.allow_address_104 || false
                            implicitWidth: 44
                            implicitHeight: 24

                            indicator: Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 24
                                radius: 12

                                color: parent.checked ? "#3b82f6" : "#f8fafc"
                                border.color: parent.checked ? "#3b82f6" :
                                    (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.parent.checked ? parent.width - width - 3 : 3

                                    color: "#ffffff"
                                    border.color: parent.parent.checked ? "#ffffff" : "#94a3b8"
                                    border.width: 1

                                    Behavior on x {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                            onCheckedChanged: dataModel.setProperty(index, "allow_address_104", checked)
                        }
                        ComboBox {
                            id: surveyGroupCombo104
                            model: ["GENERAL_SURVEY", "GROUP_1", "GROUP_2", "GROUP_3", "GROUP_4",
                                "GROUP_5", "GROUP_6", "GROUP_7", "GROUP_8"]
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 30
                            font.pixelSize: 13

                            background: Rectangle {
                                color: enabled ? "#ffffff" : "#f8fafc"
                                border.color: parent.activeFocus ? "#3b82f6" : (parent.hovered ? "#94a3b8" : "#e2e8f0")
                                border.width: 1
                                radius: 4
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            property string _currentValue: survey_group_104 || ""
                            property bool _initialized: false

                            Component.onCompleted: {
                                if (_currentValue) {
                                    var idx = model.indexOf(_currentValue);
                                    currentIndex = idx >= 0 ? idx : 0;
                                } else {
                                    currentIndex = 0;
                                }
                                _initialized = true;
                            }

                            on_CurrentValueChanged: {
                                if (_initialized && _currentValue) {
                                    var idx = model.indexOf(_currentValue);
                                    currentIndex = idx >= 0 ? idx : 0;
                                }
                            }

                            onCurrentIndexChanged: {
                                if (_initialized && !loadingState && currentIndex >= 0) {
                                    dataModel.setProperty(index, "survey_group_104", model[currentIndex]);
                                }
                            }
                        }

                            Button {
                                text: "Удалить"
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 32

                                font.pixelSize: 13
                                font.weight: Font.Medium

                                background: Rectangle {
                                    color: parent.pressed ? "#b91c1c" : (parent.hovered ? "#dc2626" : "#ef4444")
                                    radius: 4
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "#ffffff"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: dataModel.remove(originalIndex)
                            }

                    }
                }
            }
        }
    }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        anchors.bottomMargin: 70
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: 0
            property int tabWidth: 180
            TabButton { text: "Аналоговые входы"}
            TabButton { text: "Дискретные входы" }
            TabButton { text: "Аналоговый выход"}
            TabButton { text: "Дискретный выход" }
            TabButton { text: "Признаки" }
            TabButton { text: "Уставка" }

            TabButton {
                visible: modbus
                text: "Modbus"
                width: visible ? tabBar.tabWidth : 0
            }
            TabButton {
                visible: mek
                text: "MEK"
                width: visible ? tabBar.tabWidth : 0
            }
            TabButton {
                visible: mek && mek_101
                text: "MEK_101"
                width: visible ? tabBar.tabWidth : 0
            }
            TabButton {
                visible: mek && mek_104
                text: "MEK_104"
                width: visible ? tabBar.tabWidth : 0
            }

            function activateTab(tabName) {
                for (var i = 0; i < count; i++) {
                    if (itemAt(i).text === tabName && itemAt(i).visible) {
                        currentIndex = i;
                        return true;
                    }
                }
                return false;
            }

            function updateFocus() {
                if (mek && mek_104 && activateTab("MEK_104")) return;
                if (mek && mek_101 && activateTab("MEK_101")) return;
                if (mek && activateTab("MEK")) return;
                if (modbus && activateTab("Modbus")) return;

                currentIndex = 0;
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    swipeView.currentIndex = currentIndex;
                    switch(swipeView.currentIndex) {
                        case 0:
                            rootwindow.currentType = "Аналоговые входы";
                            break;
                        case 1:
                            rootwindow.currentType = "Дискретные входы";
                            break;
                        case 2:
                            rootwindow.currentType = "Аналоговый выход";
                            break;
                        case 3:
                            rootwindow.currentType = "Дискретный выход";
                            break;
                        case 4:
                            rootwindow.currentType = "Признаки";
                            break;
                        case 5:
                            rootwindow.currentType = "Уставка";
                            break;
                        default:
                            rootwindow.currentType = "";
                    }
                    console.log(rootwindow.currentType);
                }
            }

        }

        StackLayout {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex
            anchors.margins: 10

            Loader {
                id: loader1
                active: tabBar.currentIndex === 0
                sourceComponent: parameterPageComponent
                asynchronous: true
                onLoaded: {
                    item.paramType = "Аналоговые входы"
                    item.listView = listView
                        item.addClicked.connect(() => {
                        rootwindow.currentType = "Аналоговые входы"
                    })
                }
            }

            Loader {
                id: loader2
                active: tabBar.currentIndex === 1
                sourceComponent: parameterPageComponent
                asynchronous: true
                onLoaded: {
                    item.paramType = "Дискретные входы"
                    item.listView = listView
                        item.addClicked.connect(() => {
                        rootwindow.currentType = "Дискретные входы"

                    })
                }
            }

            Loader {
                id: loader3
                active: tabBar.currentIndex === 2
                sourceComponent: parameterPageComponent
                asynchronous: true
                onLoaded: {
                    item.paramType = "Аналоговый выход"
                    item.listView = listView
                        item.addClicked.connect(() => {
                        rootwindow.currentType = "Аналоговый выход"

                    })
                }
            }

            Loader {
                id: loader4
                active: tabBar.currentIndex === 3
                sourceComponent: parameterPageComponent1
                asynchronous: true
                onLoaded: {
                    item.paramType = "Дискретный выход"
                    item.listView = listView1
                        item.addClicked.connect(() => {
                        rootwindow.currentType = "Дискретный выход"

                    })
                }
            }
            Loader {
                id: loader5
                active: tabBar.currentIndex === 4
                sourceComponent: parameterPageComponent
                asynchronous: true
                onLoaded: {
                    item.paramType = "Признаки"
                    item.listView = listView
                        item.addClicked.connect(() => {
                        rootwindow.currentType = "Признаки"

                    })
                }
            }
            Loader {
                id: loader6
                active: tabBar.currentIndex === 5
                sourceComponent: parameterPageComponent
                asynchronous: true
                onLoaded: {
                    item.paramType = "Уставка"
                    item.listView = listView
                        item.addClicked.connect(() => {
                        rootwindow.currentType = "Уставка"

                    })
                }
            }
            Loader {
                id: mekLoader
                active: tabBar.currentIndex === 6 && modbus
                sourceComponent: modbusPageComponent
                asynchronous: true
            }
            Loader {
                active: tabBar.currentIndex === 7 && mek
                sourceComponent: mekPageComponent
                asynchronous: true

            }
            Loader {
                active: tabBar.currentIndex === 8
                sourceComponent: mek101PageComponent
                asynchronous: true
            }
            Loader {
                active: tabBar.currentIndex === 9
                sourceComponent: mek104PageComponent
                asynchronous: true
            }

         }
     }

    Rectangle {
        id: controlPanel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 70
        color: "#d0ffffff"
        Behavior on color { ColorAnimation { duration: 200 } }


        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#e0e0e0"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 15

            Button {
                text: modbus ? "Удалить Modbus" : "Добавить ModBus"
                onClicked: {
                    modbus = !modbus;
                    if (modbus) tabBar.updateFocus();
                }
            }

            Button {
                text: mek ? "Удалить MEK" : "Добавить MEK"
                onClicked: {
                    mek = !mek;
                    if (mek) {
                        initializeMekProperties();
                        tabBar.updateFocus();
                    } else {
                        mek_101 = false;
                        mek_104 = false;
                        mekLoader.active = false;
                        mekLoader.sourceComponent= null;
                    }
                }
            }

            Button {
                enabled: mek
                visible: mek
                text: mek_101 ? "Удалить MEK_101" : "Добавить MEK_101"
                onClicked: {
                    mek_101 = !mek_101;
                    if (mek_101) tabBar.updateFocus();
                }
            }

            Button {
                enabled: mek
                visible: mek
                text: mek_104 ? "Удалить MEK_104" : "Добавить MEK_104"
                onClicked: {
                    mek_104 = !mek_104;
                    if (mek_104) tabBar.updateFocus();
                }
            }


            Button {
                text: "Debug Full Model"
                onClicked: {
                    if (dataModel.count === 0) {
                        console.log("Model is empty!")
                        return
                    }
                    console.log("----- FULL MODEL DUMP -----");
                    for (var i = 0; i < dataModel.count; i++) {
                        var item = dataModel.get(i);
                        console.log(`\nItem ${i}: ${item.paramType} "${item.name}"`);
                        var props = Object.keys(item);
                        for (var j = 0; j < props.length; j++) {
                            var propName = props[j];
                            if (!/^[A-Z]/.test(propName)) {
                                console.log(`  ${propName}:`, item[propName]);
                            }
                        }
                    }
                    console.log("----- END DUMP -----");
                }
            }

            Button {
                text: "Настроить ETH"
                onClicked: {
                    ethcounter = ethcounter + 1
                    ethConfigDialog.open()
                }
            }
            Button {
                text: "Настроить RS"
                onClicked: {
                    rscounter = rscounter + 1
                    rsConfigDialog.open()
                }
            }
            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "Export to JSON"
                onClicked: {
                    saveFileDialog.open()
                }
            }
            Button {
                text: "Generate code"
                onClicked: {
                    jsonSelectDialog.exportType = "code"
                    onClicked: jsonSelectDialog.open()
                }
            }
            Button {
                text: "Generate exel"
                onClicked: {
                    jsonSelectDialog.exportType = "exel"
                    onClicked: jsonSelectDialog.open()
                }
            }
            Button {
                text: "MEK indexing"
                onClicked: {
                    assignIOA
                }
            }
        }
    }


    Material.theme: Material.Light
    Material.accent: Material.Purple



    function cleanProperties(val) {
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)

            if (val == 0) {
                item.oi_c_sc_na_1 = undefined
                item.oi_c_dc_na_1 = undefined
                item.oi_c_bo_na_1 = undefined
                item.oi_c_se_na_1 = undefined
                item.oi_c_se_nb_1 = undefined
            }

            if (val == 0 || val == 1) {
                item.use_in_spont_101 = undefined
                item.use_in_back_101 = undefined
                item.use_in_percyc_101 = undefined
                item.allow_address_101 = undefined
                item.survey_group_101 = undefined
            }

            if (val == 0 || val == 2) {
                item.use_in_spont_104 = undefined
                item.use_in_back_104 = undefined
                item.use_in_percyc_104 = undefined
                item.allow_address_104 = undefined
                item.survey_group_104 = undefined
            }

            if (val == 4) {
                item.address = undefined
                item.block = undefined
            }
            dataModel.set(i, item)
        }
        console.log("Cleaned property" + val)
    }

    function initializeMekProperties() {
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)
            if (item.paramType == "Выходные сигналы") {
                dataModel.setProperty(i, "oi_c_sc_na_1", true)
            }
            else if (item.paramType === "Уставка") {
                if (item.type === "bool") {
                    dataModel.setProperty(i, "oi_c_sc_na_1", true)
                }
                else if (item.type === "unsigned short" || item.type === "unsigned int") {
                    dataModel.setProperty(i, "oi_c_se_na_1", true)
                }
                else if (item.type === "float") {
                    dataModel.setProperty(i, "oi_c_se_nb_1", true)
                }
            }
        }
    }

    function checkDuplicateIndex(index) {
        for (var i = 0; i < dataModel.count; i++) {
            if (dataModel.get(i).ioIndex === index) {
                return true;
            }
        }
        return false;
    }

    function checkDuplicateName(check, selfIndex) {
        for (var i = 0; i < dataModel.count; i++) {
            if (i !== selfIndex && dataModel.get(i).name === check) {
                return true;
            }
        }
        return false;
    }

    function checkDuplicateCodeName(check, selfIndex) {
        for (var i = 0; i < dataModel.count; i++) {
            if (i !== selfIndex && dataModel.get(i).codeName === check) {
                return true;
            }
        }
        return false;
    }

    function saveState() {
        if (loadingState) {
            console.warn("Skipping save - still loading state");
            return;
        }

        try {
            var data = exportToJson();
            if (fileHandler.saveToFile(stateFileName, data)) {
                console.log("Application state saved successfully");
            } else {
                console.error("Failed to save application state");
            }
        } catch (error) {
            console.error("Error saving state:", error);
        }
    }

    function prepareDataForSave() {
        var result = []
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)

            if (item.paramType === "MEK Parameters") {
                item = Object.assign({
                    mek: true,
                    mek_101: item.mek_101 || false,
                    mek_104: item.mek_104 || false,
                    use_in_spont_104: item.use_in_spont_104 || false
                }, item)
            }
            else if (item.paramType === "Modbus Parameters") {
                item = Object.assign({
                    modbus: true,
                    modbusAddress: item.modbusAddress || '',
                    modbusType: item.modbusType || 'holding'
                }, item)
            }

            result.push(item)
        }
        return result
    }

    function isAnalogInput(item) {
        return item.paramType === "Аналоговые входы" && item.type !== "bool"
    }

    function isDiscreteInput(item) {
        return item.paramType === "Дискретные входы" && item.type === "bool"
    }

    function assignAddressByType(type) {
        // Get all existing addresses for this block type
        const existingAddresses = new Set();

        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);
            if (item.blockName === type && item.address) {
                const addr = parseInt(item.address);
                if (!isNaN(addr) && addr > 0) {
                    existingAddresses.add(addr);
                }
            }
        }

        // Function to get address increment based on block type and data type
        function getAddressIncrement(blockType, dataType) {
            // Modbus addressing increments
            switch (blockType) {
                case "Coil":
                case "Discrete input":
                    return 1; // Single bit
                case "Input register":
                case "Holding register":
                    // Depends on data type
                    switch (dataType) {
                        case "bool":
                        case "unsigned char":
                        case "unsigned short":
                            return 1; // 1 register
                        case "float":
                        case "unsigned int":
                            return 2; // 2 registers
                        default:
                             return 1;
                    }
                default:
                    return 1;
            }
        }

        // Find next available address
        function findNextAvailableAddress(startAddr, increment) {
            let addr = startAddr;
            while (true) {
                let isAvailable = true;
                // Check if this address range is available
                for (let i = 0; i < increment; i++) {
                    if (existingAddresses.has(addr + i)) {
                        isAvailable = false;
                        break;
                    }
                }
                if (isAvailable) {
                    return addr;
                }
                addr++;
            }
        }

        // // If specific item index provided, assign only to that item
        // if (itemIndex >= 0) {
        //     const item = dataModel.get(itemIndex);
        //     if (item && item.blockName === type && !item.address) {
        //         const increment = getAddressIncrement(type, item.type || item.dataType);
        //         const newAddress = findNextAvailableAddress(1, increment);
        //         dataModel.setProperty(itemIndex, "address", newAddress.toString());
        //     }
        //     return;
        // }

        // Otherwise, assign to all items of this type that don't have addresses
        const itemsNeedingAddress = [];
        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);
            if (item.blockName === type && (!item.address || item.address === "")) {
                itemsNeedingAddress.push({
                    index: i,
                    dataType: item.type || item.dataType || "INT16"
                });
            }
        }

        // Assign addresses to items that need them
        for (const { index, dataType } of itemsNeedingAddress) {
            const increment = getAddressIncrement(type, dataType);
            const newAddress = findNextAvailableAddress(1, increment);

            // Mark this address range as used
            for (let i = 0; i < increment; i++) {
                existingAddresses.add(newAddress + i);
            }

            dataModel.setProperty(index, "address", newAddress.toString());
        }
    }

    function assignIOA() {
        for (var i = 0; i < dataModel.count; i++) {
            dataModel.setProperty(i, "ioa_address", i + 1);
        }
    }


    function updateNextIoIndex() {
        var maxIndex = 0;
        for (var i = 0; i < dataModel.count; i++) {
            var ioIndex = parseInt(dataModel.get(i).ioIndex);
            if (!isNaN(ioIndex) && ioIndex > maxIndex) {
                maxIndex = ioIndex;
            }
        }
        nextIoIndex = maxIndex + 1;
    }

    function checkForDuplicates() {
        // Count occurrences of each name and codeName
        const nameCount = new Map();
        const codeNameCount = new Map();

        // First pass: count occurrences
        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);

            // Count names (case-insensitive comparison)
            const name = item.name ? item.name.toLowerCase().trim() : "";
            if (name) {
                nameCount.set(name, (nameCount.get(name) || 0) + 1);
            }

            // Count code names (case-insensitive comparison)
            const codeName = item.codeName ? item.codeName.toLowerCase().trim() : "";
            if (codeName) {
                codeNameCount.set(codeName, (codeNameCount.get(codeName) || 0) + 1);
            }
        }

        // Second pass: update duplicate flags
        let hasNameDuplicates = false;
        let hasCodeNameDuplicates = false;

        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);

            // Check for name duplicates
            const name = item.name ? item.name.toLowerCase().trim() : "";
            const isNameDuplicate = name && nameCount.get(name) > 1;

            // Check for code name duplicates
            const codeName = item.codeName ? item.codeName.toLowerCase().trim() : "";
            const isCodeNameDuplicate = codeName && codeNameCount.get(codeName) > 1;

            // Update the model - these properties must exist when items are added
            dataModel.setProperty(i, "isNameDuplicate", isNameDuplicate);
            dataModel.setProperty(i, "isCodeNameDuplicate", isCodeNameDuplicate);

            if (isNameDuplicate) hasNameDuplicates = true;
            if (isCodeNameDuplicate) hasCodeNameDuplicates = true;
        }

        return { hasNameDuplicates, hasCodeNameDuplicates };
    }

    function initializeExistingItems() {
        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);
            if (!item.hasOwnProperty('isNameDuplicate')) {
                dataModel.setProperty(i, "isNameDuplicate", false);
            }
            if (!item.hasOwnProperty('isCodeNameDuplicate')) {
                dataModel.setProperty(i, "isCodeNameDuplicate", false);
            }
        }
    }


    function getFilteredUstavkaList() {
        var filtered = [];
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i);
            if (item.paramType === "Уставка" && item.type === "unsigned short") {
                filtered.push(item.tosp);
            }
        }
        return filtered;
    }
    function updateFiltered() {
        toModel.splice(0, toModel.length)
        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i)
            if (item.paramType === "Уставка" &&
                item.type === "unsigned short" &&
                item.codeName !== "") {
                toModel.push(item.codeName)
            }
        }
    }
    function updateTrigger() {
        triggerModel.splice(0, triggerModel.length)

        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i)

            if (
                item.codeName !== "" &&
                (
                    item.paramType !== "Признаки" ||
                    (item.paramType === "Признаки" && item.type === "bool")
                )
            ) {
                triggerModel.push(item.codeName)
            }
        }
    }

}




// TODO: Добавить диалог выбора куда сохранить, откуда открыть, заменить сигналы на инфо объекты+
// только у аналогово входа апертура, ктт=коэффициент трансформации+Уставка
//длительность только у выхода
//у входов не может быть знач по умолчанию
// антидребезг только у входа дискретного
// назначение убрать
// удалять из мека/модбаса только
// автоиндексация в модбасе
// автосохранялку
// в дискретных выходах выбор кор и дл импульса из уставок, выход = VAL_+англ название тип всегда uchar. колонка single/double point. если single то выход bool, если double, то uchar
// рядом с колонкой сохранения номер сектора(?)
//переименовить по умолчанию и АД=антибрежез
//аналоговый выход пока не нужен
//если double то 2 IO
//номер сектора=триггер, выбор из списка всех других сигналов,  импульс ushort, в Уставках нет триггера
//добавляя 101


//claude: дубликаты, другие вкладки(хедер, дизайн), индексация модбаса