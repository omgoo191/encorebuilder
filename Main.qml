import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import FileIO 1.0
import QtQuick.Dialogs
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

    Platform.FileDialog {
        id: saveFileDialog
        nameFilters: ["JSON files (*.json)"]
        defaultSuffix: "json"
        fileMode: Platform.FileDialog.SaveFile
        onAccepted: {
            const filePath = String(file).replace("file://", "")
            if (fileHandler.saveToFile(filePath, exportToJson())) {
                stateFileName = filePath
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
        var result = [];
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i);
            var exportItem = {};
            var props = Object.keys(item);
            for (var j = 0; j < props.length; j++) {
                var propName = props[j];
                if (propName !== "objectName" && propName !== "hasOwnProperty" &&
                    propName !== "toString" && propName !== "destroyed" &&
                    propName !== "destroy" && typeof item[propName] !== "function") {
                    exportItem[propName] = item[propName];
                }
            }
            result.push(exportItem);
        }
        return JSON.stringify(result, null, 2);
    }


    ListModel{
        id:testModel
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
                        z:2
                        width: listView1.width
                        height: 25
                        color: "#f0f0f0"
                        RowLayout {
                            spacing: 0
                            width: listView1.width
                            Label { text: "IO";
                                Layout.preferredWidth: 50}
                            Label { text: "Наименование";
                                Layout.preferredWidth: 350}
                            Label { text: "Англ.название"
                                Layout.preferredWidth: 350}
                            Label { text: "Single/Double"
                                Layout.preferredWidth: 80
                                }
                            Label { text: "Логика"
                                Layout.preferredWidth: 100}
                            Label { text: "Выход"
                                Layout.preferredWidth: 100
                            }
                            Label { text: "Короткий импульс"
                                Layout.preferredWidth: 160
                            }
                            Label { text: "Длинный импульс"
                                Layout.preferredWidth: 160
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
                        property bool hasDuplicateName: false
                        property bool hasDuplicateCodeName: false

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
                            onTextChanged: dataModel.setProperty(originalIndex, "ioIndex", text)
                        }

                        TextField {
                            id: nameField
                            text: itemData.name
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 30
                            color: itemData.isNameDuplicate ? "red" : "black"

                            ToolTip.visible: hovered
                            ToolTip.text: itemData.isNameDuplicate ?
                                "Это наименование уже используется" :
                                text

                            onTextChanged: if (text !== itemData.name) {
                                dataModel.setProperty(originalIndex, "name", text)
                                Qt.callLater(rootwindow.checkForDuplicates)
                            }
                        }

                        TextField {
                            id: codeNameField
                            text: itemData.codeName
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 30

                            color: itemData.isCodeNameDuplicate ? "red" : "black"

                            ToolTip.visible: hovered
                            ToolTip.text: itemData.isCodeNameDuplicate ?
                                "Это наименование на английском уже используется" :
                                text

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
                            checked: itemData.sod || false
                            Layout.preferredWidth: 80
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
                        }
                        TextField {
                            text: "VAL_" + codeNameField.text
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 30
                            enabled: false
                        }
                        ComboBox {
                            id: tospComboBox
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 30

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
                            onClicked: dataModel.remove(originalIndex)
                            Material.background: Material.Red
                        }
                    }
                }
            }

            Button {
                Layout.alignment: Qt.AlignCenter
                text: "+"

                Material.background: Material.Green
                Material.foreground: "white"
                onClicked: {
                    addClicked()
                    dataModel.append( {
                        "paramType": "Дискретный выход",
                        "ioIndex": rootwindow.nextIoIndex.toString(),
                        "name": "",
                        "codeName": "",
                        "sod": "",
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
                        "survey_group_104": ""
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
                    height: 25
                    color: "#f0f0f0"
                    RowLayout {
                        width: listView.width
                        anchors.fill: parent
                        spacing: 8

                        Label { text: "IO"
                            Layout.preferredWidth: 50
                        }
                        Label { text: "Наименование"
                            Layout.preferredWidth: 350
                        }
                        Label { text: "Англ.название"
                            Layout.preferredWidth: 350
                        }
                        Label { text: "Тип"
                            Layout.preferredWidth: 120
                        }
                        Label { text: "Логика"
                            Layout.preferredWidth: 100
                        }
                        Label {
                            text: "Сохран."
                            visible: rootwindow.currentType === "Признаки" || rootwindow.currentType === "Уставка"
                            Layout.preferredWidth: 140
                        }
                        Label {
                            text: "Триггер"
                            visible: rootwindow.currentType === "Признаки"
                            Layout.preferredWidth: 140
                        }
                        Label {
                            text: "Апертура"
                            visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка"
                            Layout.preferredWidth: 120
                        }
                        Label {
                            text: "КТТ"
                            visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка"
                            Layout.preferredWidth: 100
                        }
                        Label {
                            text: "Знач. по умолч."
                            visible: !(rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы")
                            Layout.preferredWidth: 120
                        }
                        Label { text: "Антидребезг"
                            Layout.preferredWidth: 170
                            visible: rootwindow.currentType === "Дискретные входы"
                        }
                        Label {
                            text: ""
                            Layout.preferredWidth: 120
                        }
                    }
                }

                delegate: RowLayout {
                    z: 1
                    property bool hasDuplicateName: false
                    property bool hasDuplicateCodeName: false

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
                    height: implicitHeight

                    property var itemData: dataModel.get(originalIndex)

                    TextField {
                        text: itemData.ioIndex
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 30
                        onTextChanged: dataModel.setProperty(originalIndex, "ioIndex", text)
                    }
                    TextField {
                        text: itemData.name
                        Layout.preferredWidth: 350
                        Layout.preferredHeight: 30
                        color: itemData.isNameDuplicate ? "red" : "black"
                        onTextChanged: {
                            dataModel.setProperty(originalIndex, "name", text)
                            Qt.callLater(rootwindow.checkForDuplicates)
                        }
                    }

                    TextField {
                        text: itemData.codeName
                        Layout.preferredWidth: 350
                        Layout.preferredHeight: 30
                        color: itemData.isCodeNameDuplicate ? "red" : "black"
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
                        Layout.preferredHeight: 30
                    }

                    ComboBox {
                        model: ["Да", "Нет"]
                        currentIndex: model.indexOf(itemData.logicuse || "Да")
                        onCurrentTextChanged: dataModel.setProperty(originalIndex, "logicuse", currentText)
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 30
                    }

                    ComboBox {
                        visible: rootwindow.currentType === "Признаки" || rootwindow.currentType === "Уставка"
                        model: ["Нет", "Да"]
                        currentIndex: model.indexOf(itemData.saving || "Нет")
                        onCurrentTextChanged: dataModel.setProperty(originalIndex, "saving", currentText)
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 30
                    }

                    ComboBox {
                        visible: rootwindow.currentType === "Признаки"
                        editable: true
                        model: triggerModel
                        currentIndex: triggerModel.indexOf(itemData.sector)
                        onCurrentTextChanged: dataModel.setProperty(originalIndex, "sector", currentText)
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 30
                    }

                    TextField {
                        visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка"
                        text: itemData.aperture
                        onTextChanged: dataModel.setProperty(originalIndex, "aperture", text)
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 30
                    }

                    TextField {
                        visible: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка"
                        text: itemData.ktt
                        onTextChanged: dataModel.setProperty(originalIndex, "ktt", text)
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 30
                    }
                    TextField {
                        visible: !(rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы")
                        text: itemData.def_value
                        onTextChanged: dataModel.setProperty(originalIndex, "def_value", text)
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 30
                    }
                    TextField {
                        text: itemData.ad
                        Layout.preferredWidth: 170
                        Layout.preferredHeight: 30
                        onTextChanged: dataModel.setProperty(originalIndex, "ad", text)
                        visible: rootwindow.currentType === "Дискретные входы"
                    }
                    Button {
                        text: "Удалить"
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 50
                        onClicked: dataModel.remove(originalIndex)
                        Material.background: Material.Red
                    }

                }
            }
            }

            Button {
                Layout.alignment: Qt.AlignCenter
                text: "+"

                Material.background: Material.Green
                Material.foreground: "white"
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
                        "survey_group_104": ""
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
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            text: "Тип"
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            text: "Наименование"
                            Layout.preferredWidth: 200
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            text: "Тип данных"
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            text: "Адрес"
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            text: "Блок"
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
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
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: paramType
                                    Layout.preferredWidth: 100
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: name
                                    Layout.preferredWidth: 200
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: type
                                    Layout.preferredWidth: 100
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                TextField {
                                    id: mbaddress
                                    text: dataModel.get(index).address
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    horizontalAlignment: Text.AlignHCenter
                                    onTextChanged: dataModel.setProperty(index,
                                        "address",
                                        text)
                                }
                                ComboBox {
                                    id: combo
                                    model: ["Coil", "Discrete input", "Input register", "Holding register"]

                                    currentIndex: model.indexOf(blockName || "Coil")
                                    onCurrentIndexChanged: {
                                        if (!loadingState && currentIndex >= 0) {
                                            dataModel.setProperty(index, "blockName", model[currentIndex])
                                            assignIndexByType(model[currentIndex])
                                        }
                                    }

                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                }
                                Button {
                                    text: "Удалить"
                                    Layout.preferredWidth: 160
                                    onClicked: dataModel.remove(index)
                                    Material.background: Material.Red
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
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Тип"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Наименование"
                        Layout.preferredWidth: 200
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "Адрес ОИ"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label { text: "Тип данных"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignLeft
                    }
                    Label { text: "Адрес АСДУ"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignLeft
                    }
                    Label { text: "Номер буфера"
                        Layout.preferredWidth: 130
                        horizontalAlignment: Text.AlignLeft
                    }
                    Label { text: "Тип при спорадике"
                        Layout.preferredWidth: 130
                        horizontalAlignment: Text.AlignLeft
                    }
                    Label { text: "Тип при фоновом"
                        Layout.preferredWidth: 130
                        horizontalAlignment:Text.AlignLeft
                    }
                    Label { text: "Тип при пер/цик"
                        Layout.preferredWidth: 130
                    }
                    Label { text: "Тип при общем"
                        Layout.preferredWidth: 130
                        horizontalAlignment: Text.AlignLeft
                    }
                    Label { text: ""
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignLeft
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
                            horizontalAlignment: Text.AlignHCenter
                            }

                            Text { text: paramType
                                ;
                                Layout.preferredWidth: 100
                                ;
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: name
                                Layout.preferredWidth: 200
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                ToolTip.visible: containsMouse
                                ToolTip.text: name
                                MouseArea { anchors.fill: parent
                                    ;
                                    hoverEnabled: true
                                }
                            }

                            Text { text: type
                                ;
                                Layout.preferredWidth: 100
                                ;
                                horizontalAlignment: Text.AlignHCenter
                            }

                            TextField {
                                text: ioa_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                                onTextChanged: dataModel.setProperty(index, "ioa_address", text)
                            }

                            TextField {
                                text: asdu_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                                onTextChanged: dataModel.setProperty(index, "asdu_address", text)
                            }

                            ComboBox {
                                model: ["NOT_USE", "SECOND_CLASS_1", "SECOND_CLASS_2", "SECOND_CLASS_3", "SECOND_CLASS_4",
                                    "SECOND_CLASS_5", "SECOND_CLASS_6", "SECOND_CLASS_7", "SECOND_CLASS_8"]
                                currentIndex: model.indexOf(second_class_num || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                onCurrentIndexChanged: dataModel.setProperty(index, "second_class_num", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1", "M_BO_NA_1",
                                    "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1", "M_ME_TB_1", "M_ME_NC_1",
                                    "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1", "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"]
                                currentIndex: model.indexOf(type_spont || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_spont", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_DP_NA_1", "M_BO_NA_1", "M_ME_NA_1",
                                    "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"]
                                currentIndex: model.indexOf(type_back || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_back", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_ME_NA_1", "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"]
                                currentIndex: model.indexOf(type_percyc || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_percyc", model[currentIndex])
                            }

                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1", "M_BO_NA_1",
                                    "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1", "M_ME_TB_1", "M_ME_NC_1",
                                    "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1", "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"]
                                currentIndex: model.indexOf(type_def || "NOT_USE")
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                                onCurrentIndexChanged: dataModel.setProperty(index, "type_def", model[currentIndex])
                            }

                            Button {
                                text: "Удалить"
                                Layout.preferredWidth: 160
                                onClicked: dataModel.remove(index)
                                Material.background: Material.Red
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
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Тип"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Наименование"
                        Layout.preferredWidth: 200
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Label {
                        text: "Адрес ОИ"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Адрес АСДУ"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Исп. в спорадике"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Исп. в цикл/период"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Исп. в фон. сканир"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Разреш. адрес"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Группа опроса"
                        Layout.preferredWidth: 150
                        horizontalAlignment: Text.AlignHCenter
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
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: paramType
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: name
                            Layout.preferredWidth: 200
                            horizontalAlignment: Text.AlignHCenter
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
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: asdu_address
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Switch {
                            checked: model.use_in_spont_101 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "use_in_spont_101", checked)
                        }
                        Switch {
                            checked: model.use_in_back_101 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "use_in_back_101", checked)
                        }
                        Switch {
                            checked: model.use_in_percyc_101 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "use_in_percyc_101", checked)
                        }
                        Switch {
                            checked: model.allow_address_101 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "allow_address_101", checked)
                        }
                        ComboBox {
                            id: surveyGroupCombo
                            model: ["GENERAL_SURVEY", "GROUP_1", "GROUP_2", "GROUP_3", "GROUP_4",
                                "GROUP_5", "GROUP_6", "GROUP_7", "GROUP_8"]
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 30

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
                            onClicked: dataModel.remove(index)
                            Material.background: Material.Red
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
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Тип"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Наименование"
                        Layout.preferredWidth: 200
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Адрес ОИ"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Адрес АСДУ"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Исп. в спорадике"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Исп. в цикл/период"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Исп. в фон. сканир"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Разреш. адрес"
                        Layout.preferredWidth: 100
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        text: "Группа опроса"
                        Layout.preferredWidth: 150
                        horizontalAlignment: Text.AlignHCenter
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
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: paramType
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: name
                            Layout.preferredWidth: 200
                            horizontalAlignment: Text.AlignHCenter
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
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: asdu_address
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Switch {
                            checked: model.use_in_spont_104 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "use_in_spont_104", checked)
                        }
                        Switch {
                            checked: model.use_in_back_104 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "use_in_back_104", checked)
                        }
                        Switch {
                            checked: model.use_in_percyc_104 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "use_in_percyc_104", checked)
                        }
                        Switch {
                            checked: model.allow_address_104 || false
                            Layout.preferredWidth: 100
                            onCheckedChanged: dataModel.setProperty(index, "allow_address_104", checked)
                        }
                        ComboBox {
                            id: surveyGroupCombo104
                            model: ["GENERAL_SURVEY", "GROUP_1", "GROUP_2", "GROUP_3", "GROUP_4",
                                "GROUP_5", "GROUP_6", "GROUP_7", "GROUP_8"]
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 30

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
                            onClicked: dataModel.remove(index)
                            Material.background: Material.Red
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
            TabButton { text: "Уставки" }

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

    function assignIndexByType(type) {
        // 1. Cache existing addresses (ONE-TIME SCAN)
        const existingAddresses = [];
        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);
            if (item.blockName === type && item.address) {
                const addr = parseInt(item.address);
                if (!isNaN(addr)) existingAddresses.push(addr);
            }
        }
            existingAddresses.sort((a, b) => a - b);

        // 2. Find all items needing addresses (ONE-TIME SCAN)
        const itemsNeedingAddress = [];
        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);
            if (item.blockName === type && !item.address) {
                itemsNeedingAddress.push({ index: i, dataType: item.type });
            }
        }

        // 3. Assign addresses in bulk (NO RESCANNING)
        let nextAddr = 1;
        for (const { index, dataType } of itemsNeedingAddress) {
            // Skip used addresses
            while (existingAddresses.includes(nextAddr)) {
                nextAddr += getAddressIncrement(type, dataType);
            }
            // Assign
            dataModel.setProperty(index, "address", nextAddr.toString());
            existingAddresses.push(nextAddr); // Mark as used
            nextAddr += getAddressIncrement(type, dataType);
        }
    }


    // Helper function to determine address increment based on type
    function getAddressIncrement(blockType, dataType) {
        console.log("test2")
        if (blockType === "Input register" || blockType === "Holding register") {
            // 16-bit types (1 register)
            if (dataType === "unsigned short" || dataType === "short" || dataType === "bool") {
                return 1;
            }
            // 32-bit types (2 registers)
            if (dataType === "float" || dataType === "unsigned int" || dataType === "int") {
                return 2;
            }
        }
        // For Coils and Discrete Inputs (always 1 bit)
        return 1;
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
        const names = new Set();
        const codeNames = new Set();
        let hasNameDuplicates = false;
        let hasCodeNameDuplicates = false;

        for (let i = 0; i < dataModel.count; i++) {
            const item = dataModel.get(i);

            // Check name duplicates
            if (names.has(item.name)) {
                hasNameDuplicates = true;
                // Mark all items with this name as duplicates
                for (let j = 0; j < dataModel.count; j++) {
                    if (dataModel.get(j).name === item.name) {
                        dataModel.setProperty(j, "isNameDuplicate", true);
                    }
                }
            } else {
                names.add(item.name);
                dataModel.setProperty(i, "isNameDuplicate", false);
            }

            // Check code name duplicates
            if (codeNames.has(item.codeName)) {
                hasCodeNameDuplicates = true;
                // Mark all items with this code name as duplicates
                for (let j = 0; j < dataModel.count; j++) {
                    if (dataModel.get(j).codeName === item.codeName) {
                        dataModel.setProperty(j, "isCodeNameDuplicate", true);
                    }
                }
            } else {
                codeNames.add(item.codeName);
                dataModel.setProperty(i, "isCodeNameDuplicate", false);
            }
        }

        return { hasNameDuplicates, hasCodeNameDuplicates };
    }
    function getFilteredUstavkaList() {
        var filtered = [];
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i);
            if (item.paramType === "Уставка" && item.type === "unsigned short") {
                filtered.push(item.tosp); // or whatever property you want to display
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
// только у аналогово входа апертура, ктт=коэффициент трансформации+уставки
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
//номер сектора=триггер, выбор из списка всех других сигналов,  импульс ushort, в уставках нет триггера
//добавляя 101