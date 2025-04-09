import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import FileIO 1.0
ApplicationWindow {
    id: rootwindow
    width: 1800
    height: 800
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
    // Dialog {
    //     id: ethConfigDialog
    //     title: "Настройки ETH"
    //     modal: true
    //     width: 600
    //     height: 700
    //
    //     // Локальная модель для хранения настроек ETH-интерфейсов.
    //     // В каждом объекте хранятся значения, введённые пользователем.
    //     property var ethInterfaces: [
    //         {
    //             name: "ETH1",
    //             ipAddress: "192.168.0.100",
    //             subnetMask: "255.255.255.0",
    //             gateway: "192.168.0.1",
    //             macFirst3: "00:11:22",
    //             macLast3: "33:44:55",
    //             clientIP1: "192.168.0.101",
    //             clientIP2: "",
    //             clientIP3: "",
    //             clientIP4: "",
    //             deviceAddress: "Device1",
    //             ethPort1: 2404,  // значение для порта
    //             ethPort2: 0,
    //             ethPort3: 0,
    //             ethPort4: 0,
    //             expanded: true
    //         }
    //     ]
    //
    //
    //     ColumnLayout {
    //         anchors.fill: parent
    //         spacing: 10
    //
    //         ScrollView {
    //             Layout.fillWidth: true
    //             Layout.fillHeight: true
    //
    //             ColumnLayout {
    //                 id: ethListLayout
    //                 spacing: 10
    //
    //                 // Вывод списка ETH-интерфейсов
    //                 Repeater {
    //                     id: ethRepeater
    //                     model: ethInterfaces
    //                     delegate: Rectangle {
    //                         width: parent.width
    //                         color: "#f5f5f5"
    //                         border.color: "#cccccc"
    //                         radius: 4
    //                         Layout.margins: 5
    //
    //                         ColumnLayout {
    //                             anchors.fill: parent
    //                             spacing: 5
    //
    //                             RowLayout {
    //                                 spacing: 10
    //                                 Label {
    //                                     text: modelData.name
    //                                     font.bold: true
    //                                 }
    //                                 Button {
    //                                     text: modelData.expanded ? "Скрыть" : "Показать"
    //                                     onClicked: modelData.expanded = !modelData.expanded
    //                                 }
    //                                 Button {
    //                                     text: "Удалить"
    //                                     onClicked: {
    //                                         ethInterfaces.splice(index, 1)
    //                                     }
    //                                 }
    //                             }
    //
    //                             // Настройки для ETH-интерфейса (видимы, если expanded == true)
    //                             ColumnLayout {
    //                                 visible: modelData.expanded
    //                                 spacing: 5
    //
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "IP адрес:"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.ipAddress
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.ipAddress = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "Маска подсети:"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.subnetMask
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.subnetMask = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "Шлюз:"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.gateway
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.gateway = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "MAC (старшие 3 байта):"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.macFirst3
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.macFirst3 = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "MAC (младшие 3 байта):"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.macLast3
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.macLast3 = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "IP клиента 1:"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.clientIP1
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.clientIP1 = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "Адрес устройства:"; Layout.preferredWidth: 150 }
    //                                     TextField {
    //                                         text: modelData.deviceAddress
    //                                         Layout.fillWidth: true
    //                                         onTextChanged: modelData.deviceAddress = text
    //                                     }
    //                                 }
    //                                 RowLayout {
    //                                     spacing: 10
    //                                     Label { text: "ETH Порт 1:"; Layout.preferredWidth: 150 }
    //                                     SpinBox {
    //                                         from: 0; to: 65535
    //                                         value: modelData.ethPort1
    //                                         onValueChanged: modelData.ethPort1 = value
    //                                     }
    //                                 }
    //                             }
    //                         }
    //                     }
    //                 }
    //             }
    //         }
    //
    //         // Кнопки для добавления нового ETH-интерфейса и сохранения настроек
    //         RowLayout {
    //             Layout.fillWidth: true
    //             spacing: 20
    //
    //             Button {
    //                 text: "Добавить ETH"
    //                 onClicked: {
    //                     var newInterface = {
    //                         name: "ETH" + (ethConfigDialog.ethInterfaces.length + 1),
    //                         ipAddress: "",
    //                         subnetMask: "",
    //                         gateway: "",
    //                         macFirst3: "",
    //                         macLast3: "",
    //                         clientIP1: "",
    //                         clientIP2: "",
    //                         clientIP3: "",
    //                         clientIP4: "",
    //                         deviceAddress: "",
    //                         ethPort1: 2404,
    //                         ethPort2: 0,
    //                         ethPort3: 0,
    //                         ethPort4: 0,
    //                         expanded: true
    //                     };
    //                     ethConfigDialog.ethInterfaces.push(newInterface);
    //                 }
    //             }
    //
    //             Button {
    //                 text: "Сохранить настройки ETH"
    //                 onClicked: {
    //                     // Для каждого ETH-интерфейса создаем новый сигнал с ТАКОЙ ЖЕ структурой,
    //                     // как у любого сигнала. Если поле не заполнено, оно будет пустым.
    //                     for (var i = 0; i < ethConfigDialog.ethInterfaces.length; i++) {
    //                         var eth = ethConfigDialog.ethInterfaces[i];
    //
    //                         var newSignal = {
    //                             "source": eth.name,               // источник (можно использовать имя интерфейса)
    //                             "paramType": "ETH",               // тип параметра (можно менять по необходимости)
    //                             "ioIndex": "",                    // индекс ввода/вывода (оставляем пустым)
    //                             "name": "Порт eth" + (i + 1),       // жёстко заданное имя
    //                             "codeName": "ETH PORT" + (i + 1),   // жёстко заданное кодовое имя
    //                             "type": "unsigned_short",         // тип данных
    //                             "logicuse": "",                   // логическое назначение
    //                             "saving": "true",                 // признак сохранения (строкой или булевым значением)
    //                             "aperture": "",                   // aperture
    //                             "ktt": "",                        // ktt
    //                             "def_value": eth.ethPort1,        // дефолтное значение из настроек ETH Порт 1
    //                             "ad": "",                         // ad
    //                             "oc": "",                         // oc
    //                             "tosp": "",                       // tosp (короткий импульс)
    //                             "tolp": "",                       // tolp (длинный импульс)
    //                             "address": "",                    // адрес (пусто)
    //                             "blockName": "",                  // имя блока (пусто)
    //                             "ioa_address": "",                // адрес ioa (пусто)
    //                             "asdu_address": "",               // адрес asdu (пусто)
    //                             "second_class_num": "",           // номер второго класса (пусто)
    //                             "type_spont": "",                 // тип spont
    //                             "type_back": "",                  // тип back
    //                             "type_percyc": "",                // тип percyc
    //                             "type_def": "",                   // тип def
    //                             oi_c_sc_na_1: false,              // логическое поле
    //                             oi_c_se_na_1: false,              // для уставок с числовым типом (false, если не применимо)
    //                             oi_c_se_nb_1: false,              // для уставок с float (false, если не применимо)
    //                             oi_c_dc_na_1: false,
    //                             oi_c_bo_na_1: false,
    //                             "use_in_spont_101": false,
    //                             "use_in_back_101": false,
    //                             "use_in_percyc_101": false,
    //                             "allow_address_101": false,
    //                             "survey_group_101": "",
    //                             "use_in_spont_104": false,
    //                             "use_in_back_104": false,
    //                             "use_in_percyc_104": false,
    //                             "allow_address_104": false,
    //                             "survey_group_104": ""
    //                         };
    //
    //                         dataModel.append(newSignal);
    //                     }
    //                     console.log("Новые ETH сигналы добавлены в dataModel. Всего элементов:", dataModel.count);
    //                 }
    //             }
    //         }
    //     }
    // }


    // Стартовый диалог
    Dialog {
        id: startDialog
        title: "Выберите действие"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent

        ColumnLayout {
            spacing: 10
            Button {
                text: "Создать новую конфигурацию"
                onClicked: {
                    dataModel.clear()
                    startDialog.close()
                }
            }
            Button {
                text: "Открыть существующую"
                onClicked: {
                    fileDialog.open()
                    startDialog.close()
                }
            }
        }
    }

    // Диалог открытия файла
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

                                // Restore tab states
                                modbus = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("address");
                                mek = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("ioa_address");
                                mek_101 = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("use_in_spont_101");
                                mek_104 = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("use_in_spont_104");
                }
                loadingState = false
            }
        }
    }

    // Диалог сохранения файла
    Platform.FileDialog {
        id: saveFileDialog
        nameFilters: ["JSON files (*.json)"]
        defaultSuffix: "json" // Автоматически добавит .json если не указано
        fileMode: Platform.FileDialog.SaveFile
        onAccepted: {
            const filePath = String(file).replace("file://", "")
            if (fileHandler.saveToFile(filePath, exportToJson())) {
                stateFileName = filePath
            }
        }
    }

    //Диалог подтверждения выхода
    Dialog {
        id: exitConfirmDialog
        title: "Есть несохранённые изменения"
        standardButtons: Dialog.Yes | Dialog.No | Dialog.Cancel
        modal: true
        Label {
            text: "Сохранить изменения перед выходом?"
        }

        onAccepted: {
            // Сохраняем файл, если нужно
            saveFileDialog.open()
            saveFileDialog.onAccepted.connect(function () {
                if (fileHandler.saveToFile(saveFileDialog.file, exportToJson())) {
                    // Если сохранение прошло успешно, разрешаем закрыть окно
                    closeapp = true
                    Qt.quit()
                } else {
                    // Если не сохранилось, не закрываем окно
                    closeWindow(false)
                }
            })
        }

        onRejected: {
            // Не сохранять - просто закрываем окно
            console.log("Save successful, quitting")
            closeapp = true
            Qt.quit()
        }

        onDiscarded: {
            // Отмена - ничего не делаем, диалог закроется сам
            closeWindow(false)
        }
    }


    // Обработка закрытия окна
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

    // Обновляем Component.onCompleted
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
            // Create a new object with all properties from the model item
            var exportItem = {};
            // Get all properties (including dynamic ones)
            var props = Object.keys(item);
            for (var j = 0; j < props.length; j++) {
                var propName = props[j];
                // Skip internal Qt properties and methods
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



    ListModel {
        id: dataModel
    }

    Dialog {
        id: entryDialog
        title: "Новый сигнал"
        width: 600
        height: 600
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        topPadding: 15
        bottomPadding: 15
        property bool hasDuplicateIndex: false
        property bool hasDuplicateName: false
        property bool hasDuplicateCodeName: false
        property string currentType: "Входные сигналы"
        property int ioIndexValue: 0
        onAboutToShow: {
            ioIndex.text = ioIndexValue
            scrollView.contentItem.contentY = 0
        }

        ScrollView {
            id: scrollView
            anchors.fill: parent
            clip: true
            contentWidth: parent.width
            contentHeight: contentLayout.implicitHeight

            GridLayout {
                id: contentLayout
                width: parent.width
                columns: 2
                columnSpacing: 20
                rowSpacing: 15
                anchors.margins: 10

                Label {
                    text: "Источник:"
                }
                TextField {
                    id: source
                    Layout.fillWidth: true
                }

                Label {
                    text: "Io index:"
                }
                TextField {
                    id: ioIndex
                    Layout.fillWidth: true
                    text: rootwindow.ioIndex
                    onTextChanged: {
                        entryDialog.hasDuplicateIndex = checkDuplicateIndex(ioIndex.text)
                        Material.foreground = entryDialog.hasDuplicateIndex ? Material.Orange : Material.LightGrey
                    }
                    ToolTip {
                        visible: entryDialog.hasDuplicateIndex&& ioIndex.hovered
                        text: "Этот индекс уже используется"
                        delay: 500
                    }
                }

                Label {
                    text: "Наименование:"
                }
                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    onTextChanged: {
                        entryDialog.hasDuplicateName = checkDuplicateName(nameField.text)
                        Material.foreground = entryDialog.hasDuplicateName ? Material.Red : Material.LightGrey

                    }
                    ToolTip {
                        visible: entryDialog.hasDuplicateName && nameField.hovered
                        text: "Это наименование уже используется"
                        delay: 500
                    }

                }

                Label {
                    text: "Наименование на английском:"
                }
                TextField {
                    id: codeNameField
                    Layout.fillWidth: true
                    onTextChanged: {
                        entryDialog.hasDuplicateCodeName = checkDuplicateCodeName(codeNameField.text)
                        Material.foreground = entryDialog.hasDuplicateCodeName ? Material.Red : Material.LightGrey

                    }
                    ToolTip {
                        visible: entryDialog.hasDuplicateCodeName && codeNameField.hovered
                        text: "Это наименование на английском уже используется"
                        delay: 500
                    }

                }

                Label {
                    text: "Тип данных:"
                }
                ComboBox {
                    id: typeCombo
                    model: ["bool", "float", "unsigned int", "unsigned short", "unsigned char"]
                    Layout.fillWidth: true

                }

                Label {
                    text: "Исп. в логике:"
                }
                ComboBox {
                    id: logicusageCombo
                    model: ["Да", "Нет"]
                    Layout.fillWidth: true
                }
                Label {
                    text: "Сохранение:"
                }
                ComboBox {
                    id: savingCombo
                    model: ["Да", "Нет"]
                    Layout.fillWidth: true
                }

                Label {
                    text: "Уст. апертуры:"
                    enabled: isAnalogInput() || enrtyDialog.currentType === "Уставки"
                    opacity: enabled ? 1.0 : 0.5
                }
                TextField {
                    id: apertureField
                    Layout.fillWidth: true
                    enabled: isAnalogInput() || enrtyDialog.currentType === "Уставки"
                    placeholderText: enabled ? "" : "Только для аналоговых входов"
                }

                Label {
                    text: "Коэффициент трансформации:"
                    enabled: isAnalogInput() || enrtyDialog.currentType === "Уставки"
                    opacity: enabled ? 1.0 : 0.5
                }
                TextField {
                    id: kttField
                    Layout.fillWidth: true
                    enabled: isAnalogInput() || enrtyDialog.currentType === "Уставки"
                    placeholderText: enabled ? "" : "Только для аналоговых входов"
                }

                Label {
                    text: "Значение по умолчанию:"
                    enabled: entryDialog.currentType !== "Входные сигналы"
                    opacity: enabled ? 1.0 : 0.5
                }
                TextField {
                    id: defaultField
                    Layout.fillWidth: true
                    enabled: entryDialog.currentType !== "Входные сигналы"
                    placeholderText: enabled ? "" : "Не для входных сигналов"
                }

                Label {
                    text: "Антидребезг:"
                    enabled: isDiscreteInput()
                    opacity: enabled ? 1.0 : 0.5
                }
                TextField {
                    id: adField
                    Layout.fillWidth: true
                    enabled: isDiscreteInput()
                    placeholderText: enabled ? "" : "Только для дискретных входов"
                }

                Label {
                    text: "Состояние выхода:"
                }
                TextField {
                    id: ocField
                    Layout.fillWidth: true
                }

                Label {
                    text: "Длительность кор. импульса:"
                    enabled: entryDialog.currentType === "Выходные сигналы"
                    opacity: enabled ? 1.0 : 0.5

                }
                TextField {
                    id: shortPulseField
                    Layout.fillWidth: true
                    enabled: entryDialog.currentType === "Выходные сигналы"
                    placeholderText: enabled ? "" : "Только для выходных сигналов"
                }

                Label {
                    text: "Длительность длинного импульса:"
                    enabled: entryDialog.currentType === "Выходные сигналы"
                    opacity: enabled ? 1.0 : 0.5
                }
                TextField {
                    id: longPulseField
                    Layout.fillWidth: true
                    enabled: entryDialog.currentType === "Выходные сигналы"
                    placeholderText: enabled ? "" : "Только для выходных сигналов"
                }
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 5
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                onPressed: mouse.accepted = true
                onPositionChanged: {
                    let dx = mouse.x
                    if (entryDialog.width - dx > entryDialog.minimumWidth) {
                        entryDialog.x += dx
                        entryDialog.width -= dx
                    }
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 5
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                onPositionChanged: {
                    let dx = mouse.x
                    if (entryDialog.width + dx > entryDialog.minimumWidth)
                        entryDialog.width += dx
                }
            }
        }

        Rectangle {
            id: edgeResizeAreaTop
            height: 5
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                drag.target: entryDialog
                drag.axis: Drag.YAxis
                onPositionChanged: entryDialog.height -= mouse.y
            }
        }

        Rectangle {
            id: edgeResizeAreaBottom
            height: 5
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                drag.target: entryDialog
                drag.axis: Drag.YAxis
                onPositionChanged: entryDialog.height += mouse.y
            }
        }

        onAccepted: {
            var isOutputSignal = currentType === "Выходные сигналы";
            var isSettingBool = currentType === "Уставка" && typeCombo.currentText === "bool";
            if (entryDialog.hasDuplicateName || entryDialog.hasDuplicateCodeName) {
                duplicateWarning.open();
                return;
            }
            rootwindow.nextIoIndex++
            var newSignal = {
                "source": source.text,
                "paramType": currentType,
                "ioIndex": ioIndex.text,
                "name": nameField.text,
                "codeName": codeNameField.text,
                "type": typeCombo.currentText,
                "logicuse": logicusageCombo.currentText,
                "saving": savingCombo.currentText,
                "aperture": apertureField.text,
                "ktt": kttField.text,
                "def_value": defaultField.text,
                "ad": adField.text,
                "oc": ocField.text,
                "tosp": shortPulseField.text,
                "tolp": longPulseField.text,
                "address": "",
                "blockName": "",
                "ioa_address": "",
                "asdu_address": "",
                "second_class_num": "",

                "type_spont": "",
                "type_back": "",
                "type_percyc": "",
                "type_def": "",
                oi_c_sc_na_1: isOutputSignal || isSettingBool,
                oi_c_se_na_1: currentType === "Уставка" &&
                    (typeCombo.currentText === "unsigned short" ||
                        typeCombo.currentText === "unsigned int"),
                oi_c_se_nb_1: currentType === "Уставка" &&
                    typeCombo.currentText === "float",
                oi_c_dc_na_1: false,
                oi_c_bo_na_1: false,
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
            };
            dataModel.append(newSignal);
            source.text = ""
            ioIndex.text = ""
            nameField.text = ""
            codeNameField.text = ""
            typeCombo.currentIndex = 0
            adField.text = ""
            ocField.text = ""
            shortPulseField.text = ""
            longPulseField.text = ""
            logicusageCombo.currentIndex = 0
            savingCombo.currentIndex = 0
            apertureField.text = ""
            kttField.text = ""
            defaultField.text = ""
        }
    }

    Dialog {
        id: duplicateWarning
        title: "Ошибка дублирования"
        width: 400
        standardButtons: Dialog.Ok

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            text: {
                var parts = []
                if (checkDuplicateName(nameField.text)) parts.push("• Наименование: '" + nameField.text + "'")
                if (checkDuplicateCodeName(codeNameField.text)) parts.push("• Английское наименование: '" + codeNameField.text + "'")
                return parts.length > 0
                    ? "Обнаружены дубликаты:\n" +"С индексом "+ ioIndex.text +"\n" + parts.join("\n") + "\n\nПожалуйста, измените значения."
                    : ""
            }
        }
    }


    Component {
        id: parameterPageComponent

        ColumnLayout {
            id: pageRoot
            property string paramType: "Входной сигнал"
            signal addClicked

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                padding: 10
                leftPadding: 15
                rightPadding: 10

                ListView {
                    id: listView
                    width: parent.width - 25
                    height: contentHeight
                    model: dataModel
                    spacing: 5
                    interactive: false
                    clip: true
                    headerPositioning: ListView.OverlayHeader
                    header: RowLayout {
                        width: listView.width
                        spacing: 10
                        Item {
                            Layout.preferredWidth: 12 // Ширина scrollbar
                            visible: false
                        }
                        Label {
                            text: "IO"
                            Layout.preferredWidth: 50
                        }
                        Label {
                            text: "Наименование"
                            Layout.preferredWidth: 200
                        }
                        Label {
                            text: "Англ.название"
                            Layout.preferredWidth: 200
                        }
                        Label {
                            text: "Тип"
                            Layout.preferredWidth: 200
                        }
                        Label {
                            text: "Логика"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: "Сохран."
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: "Апертура"
                            Layout.preferredWidth: 100
                        }
                        Label {
                            text: "КТТ"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: "Умолч."
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: "АД"
                            Layout.preferredWidth: 60
                        }
                        Label {
                            text: "Выход"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: "Кор.имп"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: "Дл.имп"
                            Layout.preferredWidth: 80
                        }
                        Label {
                            text: ""   // пустой заголовок для колонки с кнопкой удаления
                            Layout.preferredWidth: 160
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    delegate: RowLayout {
                        required property int index
                        required property string ioIndex
                        required property string paramType
                        required property string name
                        required property string codeName
                        required property string type
                        required property string logicuse
                        required property string saving
                        required property string aperture
                        required property string ktt
                        required property string def_value
                        required property string ad
                        required property string oc
                        required property string tosp
                        required property string tolp

                        width: listView.width
                        spacing: 10
                        height: visible ? implicitHeight : 0
                        visible: paramType === pageRoot.paramType
                        Item {
                            Layout.preferredWidth: 12
                            visible: false
                        }
                        TextField {
                            text: dataModel.get(index).ioIndex
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter

                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "ioIndex", text)
                        }
                        TextField {
                            text: dataModel.get(index).name
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "name", text)
                            ToolTip.visible: hovered && !activeFocus
                            ToolTip.text: text
                        }
                        TextField {
                            text: dataModel.get(index).codeName
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "codeName", text)
                            ToolTip.visible: hovered && !activeFocus
                            ToolTip.text: text
                        }
                        ComboBox {
                            model: ["bool", "float", "unsigned int", "unsigned short", "unsigned char"]
                            currentIndex: model.indexOf(dataModel.get(index).type || "bool")
                            onCurrentIndexChanged: {
                                dataModel.setProperty(index, "type", model[currentIndex]);
                            }
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 30
                        }
                        ComboBox {
                            model: ["Да", "Нет"]
                            currentIndex: model.indexOf(dataModel.get(index).logicuse || "Да")
                            onCurrentIndexChanged: {
                                dataModel.setProperty(index, "logicuse", model[currentIndex]);
                            }
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                        }
                        ComboBox {
                            model: ["Да", "Нет"]
                            currentIndex: model.indexOf(dataModel.get(index).saving|| "Да")
                            onCurrentIndexChanged: {
                                dataModel.setProperty(index, "saving", model[currentIndex]);
                            }
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                        }
                        TextField {
                            text: dataModel.get(index).aperture
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "aperture", text)
                        }
                        TextField {
                            text: dataModel.get(index).ktt
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "ktt", text)
                        }
                        TextField {
                            text: dataModel.get(index).def_value
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "def_value", text)
                        }
                        TextField {
                            text: dataModel.get(index).ad
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "ad", text)
                        }
                        TextField {
                            text: dataModel.get(index).oc
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "oc", text)
                        }
                        TextField {
                            text: dataModel.get(index).tosp
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "tosp", text)
                        }
                        TextField {
                            text: dataModel.get(index).tolp
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 30
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                            color: "black" // Цвет текста
                            onTextChanged: dataModel.setProperty(index, "tolp", text)
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

            Button {
                Layout.alignment: Qt.AlignCenter
                text: "Добавить новый " + paramType
                onClicked: {
                    entryDialog.ioIndexValue = rootwindow.nextIoIndex
                    addClicked()
                }
                Material.background: Material.Purple
                Material.foreground: "white"
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
            property int tabWidth: 225
            // Основные статические вкладки
            TabButton { text: "Входные сигналы"}
            TabButton { text: "Выходные сигналы" }
            TabButton { text: "Признаки" }
            TabButton { text: "Уставки" }

            // Динамические вкладки
            TabButton {
                visible: modbus
                text: "Modbus"

                // Костыль для правильного отображения
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

                // Фолбэк на первую вкладку если ничего не активно
                currentIndex = 0;
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    swipeView.currentIndex = currentIndex;
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex
            anchors.margins: 10
            // Input Signals
            Loader {
                sourceComponent: parameterPageComponent
                onLoaded: {
                    item.paramType = "Входные сигналы"
                        item.addClicked.connect(() => {
                        entryDialog.currentType = "Входные сигналы"
                        entryDialog.open()
                    })
                }
            }

            // Output Signals
            Loader {
                sourceComponent: parameterPageComponent
                onLoaded: {
                    item.paramType = "Выходные сигналы"
                        item.addClicked.connect(() => {
                        entryDialog.currentType = "Выходные сигналы"
                        entryDialog.open()
                    })
                }
            }

            Loader {
                sourceComponent: parameterPageComponent
                onLoaded: {
                    item.paramType = "Признаки"
                        item.addClicked.connect(() => {
                        entryDialog.currentType = "Признаки"
                        entryDialog.open()
                    })
                }
            }

            // Settings
            Loader {
                sourceComponent: parameterPageComponent
                onLoaded: {
                    item.paramType = "Уставка"
                        item.addClicked.connect(() => {
                        entryDialog.currentType = "Уставка"
                        entryDialog.open()
                    })
                }
            }

            // ModBus Settings
            ScrollView {
                clip: true
                contentWidth: grid.implicitWidth
                contentHeight: grid.implicitHeight
                leftPadding: 15
                rightPadding: 15
                visible: modbus
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

                    // Header Row
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
                        } // Spacer for delete button
                    }

                    // Data Rows
                    Repeater {
                        model: dataModel
                        delegate: RowLayout {
                            spacing: 5
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
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    ToolTip {
                                        visible: mouseArea.containsMouse
                                        text: name
                                    }
                                }
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

                                // Скрываем текущий текст, если ничего не выбрано
                                displayText: currentIndex === -1 ? "" : model[currentIndex]

                                currentIndex: {
                                    if (!blockName) return -1; // ничего не выбрано
                                    var idx = model.indexOf(blockName);
                                    return idx >= 0 ? idx : -1;
                                }

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

            // MEK settings
            ScrollView {
                clip: true
                contentWidth: gridmek.implicitWidth
                contentHeight: gridmek.implicitHeight
                leftPadding: 15
                rightPadding: 15
                visible: mek

                ColumnLayout {
                    id: gridmek
                    width: parent.width - 30
                    spacing: 8
                    anchors.fill: parent

                    // Шапка таблицы: 12 колонок
                    GridLayout {
                        id: headerGrid
                        columns: 12
                        columnSpacing: 5
                        rowSpacing: 5
                        width: parent.width

                        Label {
                            text: "IO"
                            Layout.preferredWidth: 50
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Наименование"
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип данных"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Адрес ОИ"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Адрес АСДУ"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Номер буфера"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип при спорадике"
                            Layout.preferredWidth: 130
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип при фоновом"
                            Layout.preferredWidth: 130
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип при пер/цик"
                            Layout.preferredWidth: 130
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип при общем"
                            Layout.preferredWidth: 130
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: ""   // пустой заголовок для колонки с кнопкой удаления
                            Layout.preferredWidth: 160
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Строки данных: для каждой строки – 12 колонок
                    Repeater {
                        model: dataModel
                        delegate: GridLayout {
                            columns: 12
                            columnSpacing: 5
                            rowSpacing: 5
                            width: parent.width

                            // Колонка 1: IO
                            Text {
                                text: ioIndex
                                Layout.preferredWidth: 50
                                Layout.alignment: Qt.AlignHCenter
                            }
                            // Колонка 2: Тип
                            Text {
                                text: paramType
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter
                            }
                            // Колонка 3: Наименование
                            Text {
                                text: name
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignHCenter
                                elide: Text.ElideRight
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    ToolTip.visible: containsMouse
                                    ToolTip.text: name
                                }
                            }
                            // Колонка 4: Тип данных
                            Text {
                                text: type
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter
                            }
                            // Колонка 5: Адрес ОИ
                            TextField {
                                text: ioa_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                                horizontalAlignment: Text.AlignHCenter
                                onTextChanged: dataModel.setProperty(index, "ioa_address", text)
                            }
                            // Колонка 6: Адрес АСДУ
                            TextField {
                                text: asdu_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                                horizontalAlignment: Text.AlignHCenter
                                onTextChanged: dataModel.setProperty(index, "asdu_address", text)
                            }
                            // Колонка 7: Номер буфера (ComboBox для выбора, например)
                            ComboBox {
                                model: ["NOT_USE", "SECOND_CLASS_1", "SECOND_CLASS_2", "SECOND_CLASS_3", "SECOND_CLASS_4", "SECOND_CLASS_5", "SECOND_CLASS_6", "SECOND_CLASS_7", "SECOND_CLASS_8"]
                                currentIndex: {
                                    if (!second_class_num) return 0;
                                    var idx = model.indexOf(second_class_num);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
                                        dataModel.setProperty(index, "second_class_num", model[currentIndex]);
                                    }
                                }
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                            }
                            // Колонка 8: Тип при спорадике
                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1", "M_BO_NA_1", "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1", "M_ME_TB_1", "M_ME_NC_1", "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1", "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"]
                                currentIndex: {
                                    if (!type_spont) return 0;
                                    var idx = model.indexOf(type_spont);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
                                        dataModel.setProperty(index, "type_spont", model[currentIndex]);
                                    }
                                }
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                            }
                            // Колонка 9: Тип при фоновом
                            ComboBox {
                                model: ["NOT_USE", "M_SP_NA_1", "M_DP_NA_1", "M_BO_NA_1", "M_ME_NA_1", "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"]
                                currentIndex: {
                                    if (!type_back) return 0;
                                    var idx = model.indexOf(type_back);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
                                        dataModel.setProperty(index, "type_back", model[currentIndex]);
                                    }
                                }
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                            }
                            // Колонка 10: Тип при пер/цик
                            ComboBox {
                                id: typepercyc
                                model: ["NOT_USE", "M_ME_NA_1", "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"]
                                currentIndex: {
                                    if (!type_percyc) return 0;
                                    var idx = model.indexOf(type_percyc);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
                                        dataModel.setProperty(index, "type_percyc", model[currentIndex]);
                                    }
                                }
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                            }
                            // Колонка 11: Тип при общем
                            ComboBox {
                                id:typedef
                                model: ["NOT_USE", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1", "M_BO_NA_1", "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1", "M_ME_TB_1", "M_ME_NC_1", "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1", "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"]
                                currentIndex: {
                                    if (!type_def) return 0;
                                    var idx = model.indexOf(type_def);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
                                        dataModel.setProperty(index, "type_def", model[currentIndex]);
                                    }
                                }
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 30
                            }
                            // Колонка 12: Кнопка удаления
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

            ScrollView {
                clip: true
                contentWidth: mek_101_grid.implicitWidth
                contentHeight: mek_101_grid.implicitHeight
                leftPadding: 15
                rightPadding: 15
                visible: mek_101 && mek

                ColumnLayout {
                    id: mek_101_grid
                    width: parent.width - 30
                    spacing: 8
                    anchors.fill: parent

                    // Шапка таблицы (11 колонок; последний заголовок пустой)
                    GridLayout {
                        id: headerGrid_101
                        columns: 11
                        columnSpacing: 5
                        rowSpacing: 5

                        Label {
                            text: "IO"
                            Layout.preferredWidth: 50
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Наименование"
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignHCenter
                            elide: Text.ElideRight
                        }
                        Label {
                            text: "Адрес ОИ"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Адрес АСДУ"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Исп. в спорадике"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Исп. в цикл/период"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Исп. в фон. сканир"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Разреш. адрес"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Группа опроса"
                            Layout.preferredWidth: 150
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: ""
                            Layout.preferredWidth: 160
                        }
                    }

                    // Строки данных (каждая строка – 11 колонок)
                    Repeater {
                        model: dataModel
                        delegate: GridLayout {
                            columns: 11
                            columnSpacing: 5
                            rowSpacing: 5

                            Text {
                                text: ioIndex
                                Layout.preferredWidth: 50
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: paramType
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: name
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignHCenter
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
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: asdu_address
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter
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
                                model: ["GENERAL_SURVEY", "GROUP_1", "GROUP_2", "GROUP_3", "GROUP_4", "GROUP_5", "GROUP_6", "GROUP_7", "GROUP_8"]
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 30

                                currentIndex: {
                                    if (!survey_group_101) return 0;
                                    var idx = model.indexOf(survey_group_101);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
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

            ScrollView {
                clip: true
                contentWidth: mek_104_grid.implicitWidth
                contentHeight: mek_104_grid.implicitHeight
                leftPadding: 15
                rightPadding: 15
                visible: mek_104 && mek

                ColumnLayout {
                    id: mek_104_grid
                    width: parent.width - 30
                    spacing: 8
                    anchors.fill: parent

                    GridLayout {
                        id: headerGrid_104
                        columns: 11
                        columnSpacing: 5
                        rowSpacing: 5

                        Label {
                            text: "IO"
                            Layout.preferredWidth: 50
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Тип"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Наименование"
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Адрес ОИ"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Адрес АСДУ"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Исп. в спорадике"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Исп. в цикл/период"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Исп. в фон. сканир"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Разреш. адрес"
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Группа опроса"
                            Layout.preferredWidth: 150
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: ""
                            Layout.preferredWidth: 160
                        }
                    }

                    // Строки данных (каждая строка – 11 колонок)
                    Repeater {
                        model: dataModel
                        delegate: GridLayout {
                            columns: 11
                            columnSpacing: 5
                            rowSpacing: 5

                            Text {
                                text: ioIndex
                                Layout.preferredWidth: 50
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: paramType
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: name
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignHCenter
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
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: asdu_address
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter
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
                                model: ["GENERAL_SURVEY", "GROUP_1", "GROUP_2", "GROUP_3", "GROUP_4", "GROUP_5", "GROUP_6", "GROUP_7", "GROUP_8"]
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 30
                                currentIndex: {
                                    if (!survey_group_104) return 0;
                                    var idx = model.indexOf(survey_group_104);
                                    return idx >= 0 ? idx : 0;
                                }

                                onCurrentIndexChanged: {
                                    if (!loadingState && currentIndex >= 0) {
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

    // Панель с кнопками внизу окна
    Rectangle {
        id: controlPanel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 70
        color: "#d0ffffff"  // Полупрозрачный белый
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
                    ethConfigDialog.open()
                }
            }


            // Растягивающийся элемент для выравнивания кнопок слева
            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "Export to JSON"
                onClicked: saveFileDialog.open()
            }
            Button {
                text: "Generate code"
                onClicked: {
                    fileHandler.runPythonScript()
                }
            }
        }
    }


    Material.theme: Material.Light
    Material.accent: Material.Purple



    function cleanProperties(val) {
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)

            // Remove all MEK-related properties
            if (val == 0) {
                item.oi_c_sc_na_1 = undefined
                item.oi_c_dc_na_1 = undefined
                item.oi_c_bo_na_1 = undefined
                item.oi_c_se_na_1 = undefined
                item.oi_c_se_nb_1 = undefined
            }

            // Clear MEK 101 properties
            if (val == 0 || val == 1) {
                item.use_in_spont_101 = undefined
                item.use_in_back_101 = undefined
                item.use_in_percyc_101 = undefined
                item.allow_address_101 = undefined
                item.survey_group_101 = undefined
            }

            // Clear MEK 104 properties
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
            dataModel.set(i, item) // Update the item in model
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

    function checkDuplicateName(check) {
        for (var i = 0; i < dataModel.count; i++) {
            if (dataModel.get(i).name === check) {
                return true;
            }
        }
        return false;
    }

    function checkDuplicateCodeName(check) {
        for (var i = 0; i < dataModel.count; i++) {
            if (dataModel.get(i).codeName === check) {
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

    //
    // function loadState() {
    //     loadingState = true;
    //     try {
    //         var savedData = fileHandler.loadFromFile(stateFileName);
    //         if (savedData && savedData.length > 0) {
    //             dataModel.clear();
    //             for (var i = 0; i < savedData.length; i++) {
    //                 dataModel.append(savedData[i]);
    //             }
    //             console.log("Loaded previous state with", savedData.length, "items");
    //
    //             // Restore tab states
    //             // modbus = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("address");
    //             // mek = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("ioa_address");
    //             // mek_101 = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("use_in_spont_101");
    //             // mek_104 = dataModel.count > 0 && dataModel.get(0).hasOwnProperty("use_in_spont_104");
    //         }
    //     } catch (error) {
    //         console.error("Error loading state:", error);
    //     } finally {
    //         loadingState = false;
    //         console.log("Loading state set to false");
    //     }
    // }

    function prepareDataForSave() {
        var result = []
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)

            // Ensure all MEK and Modbus fields exist
            if (item.paramType === "MEK Parameters") {
                item = Object.assign({
                    mek: true,
                    mek_101: item.mek_101 || false,
                    mek_104: item.mek_104 || false,
                    use_in_spont_104: item.use_in_spont_104 || false
                    // Add other MEK defaults
                }, item)
            }
            else if (item.paramType === "Modbus Parameters") {
                item = Object.assign({
                    modbus: true,
                    modbusAddress: item.modbusAddress || '',
                    modbusType: item.modbusType || 'holding'
                    // Add other Modbus defaults
                }, item)
            }

            result.push(item)
        }
        return result
    }

    function isAnalogInput() {
        return entryDialog.currentType === "Входные сигналы" &&
            typeCombo.currentText !== "bool"
    }
    function isDiscreteInput() {
        return entryDialog.currentType === "Входные сигналы" &&
            typeCombo.currentText === "bool"
    }

    function assignIndexByType(type) {
        let count = 1;
        for (let i = 0; i < dataModel.count; i++) {
            let item = dataModel.get(i);
            if (item.blockName === type) {
                if (!item.address || item.address === "") {
                    dataModel.setProperty(i, "address", count);
                    count++;
                } else {
                    count = Math.max(count, parseInt(item.address) + 1);
                }
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