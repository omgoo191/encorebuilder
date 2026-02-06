import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Accessibility 1.0
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import FileIO 1.0
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import "ui/shell"
import "ui/dialogs"
import "ui/components"
ApplicationWindow {
    id: rootwindow
    width: 1920
    height: 1080
    visible: true
    title: qsTr("Генератор сигналов")
    Accessible.name: title
    Accessible.description: qsTr("Главное окно генератора сигналов")
    //region global properties
    property bool modbus: false
    property bool mek: false
    property bool mek_101: false
    property bool mek_104: false
    property int nextIoIndex: 1
    property string stateFileName: "app_state.json"
    property bool loadingState: false
    property bool closeapp: false
    property string currentType: "Аналоговые входы"
    property string currentProtocol: "Общее"
    property int ethcounter: 0
    property int rscounter: 0
    property int mekcounter:0
    property int mbcounter:0
    property string currentObjectModelId: ""
    property string currentProtocolId: ""
    property string currentBldePath: ""
    property int workflowStep: 0
    property bool hasUnsavedChanges: false
    property int selectedSignalCount: 0
    property string currentModelName: {
        if (!currentObjectModelId)
            return objectModelsConfig.count > 0 ? (objectModelsConfig.get(0).name || objectModelsConfig.get(0).id || "Не выбрана") : "Не выбрана"
        for (var i = 0; i < objectModelsConfig.count; ++i) {
            var model = objectModelsConfig.get(i)
            if (model.id === currentObjectModelId)
                return model.name || model.id
        }
        return "Не выбрана"
    }

    function updateHeaderIndicators() {
        var currentModel = getFilteredModel(currentType, false)
        selectedSignalCount = currentModel ? currentModel.count : 0
    }

    function markDirty() {
        if (!loadingState) hasUnsavedChanges = true
        updateHeaderIndicators()
    }

    function setTypeCombo(choices, fieldName, item) {
        if (!item || !choices || choices.length === 0) {
            cb.currentIndex = -1
            return
        }
        // если значение уже есть в itemData — используем его

        // умные дефолты только для команд уставок
        if (item.paramType === "Уставка" && item.link_kind !== "val_setpoint") {

            const typ = item.type
            let fallback = "DEFAULT"

            if (fieldName === "type_spont" || fieldName === "type_def") {
                if (typ === "bool")           fallback = "M_SP_TB_1"
                else if (typ === "float")     fallback = "M_ME_TF_1"
                else if (typ === "unsigned int")   fallback = "M_BO_TB_1"
                else if (typ === "unsigned char")  fallback = "M_ME_TD_1"
                else if (typ === "unsigned short") fallback = "M_ME_TD_1"
            }
            else if (fieldName === "type_back") {
                fallback = "NOT_USE"
            }
            else if (fieldName === "type_percyc") {
                if (typ === "bool")           fallback = "NOT_USE"
                else if (typ === "float")     fallback = "M_ME_NC_1"
                else if (typ === "unsigned int")   fallback = "NOT_USE"
                else if (typ === "unsigned char")  fallback = "M_ME_NA_1"
                else if (typ === "unsigned short") fallback = "M_ME_NA_1"
            }

            const fbIdx = choices.indexOf(fallback)
            if (fbIdx >= 0) return fbIdx
        }

        // иначе дефолт

        return defIdx >= 0 ? defIdx : 0
    }


    // === Индексация по codeName и универсальный доступ к полю ===
    property var __code2index: ({})
    property var __refKeys: ["self", "ktt", "aperture", "upper", "lower"]

    // === Индекс по codeName и универсальный доступ ===
    property var __code2row: ({})
    function __rebuildIndex() {
        const m = {}
        for (let i = 0; i < dataModel.count; ++i) {
            const it = dataModel.get(i)
            if (it && it.codeName) m[it.codeName] = i
        }
        __code2row = m
    }
    Component.onCompleted: {
        startDialog.open()
        __rebuildIndex()
        updateHeaderIndicators()
    }
    Connections {
        target: dataModel
        function onCountChanged() { __rebuildIndex() }
        function onDataChanged()  { __rebuildIndex() } // если у твоей модели есть сигнал
    }

    // вернуть массив codeName для колонки (ровно 5 элементов)
    function __codesForRow(itemData) {
        if (!itemData) return [""];

        const t = rootwindow.currentType;

        if (t === "Аналоговые входы") {
            return [
                itemData.codeName,
                itemData.ktt,
                itemData.aperture,
                itemData.upper,
                itemData.lower
            ].map(c => c || "");
        }

        if (t === "Уставка") {
            // Если уставка включена — показываем и сам элемент, и setpoint
            const arr = [itemData.codeName];
            if (itemData.val_setpoint_enabled && itemData.setpoint)
                arr.push(itemData.setpoint);
            return arr.map(c => c || "");
        }

        // По умолчанию — только текущий элемент
        return [itemData.codeName || ""];
    }

    // чтение поля по codeName
    function __getByRole(codeName, roleName) {
        if (!codeName) return ""
        const idx = __code2row[codeName]
        if (idx === undefined) return ""
        const row = dataModel.get(idx)
        return row && roleName in row ? (row[roleName] ?? "") : ""
    }

    // запись поля по codeName
    function __setByRole(codeName, roleName, value) {
        if (!codeName) return false
        const idx = __code2row[codeName]
        return (idx !== undefined) ? dataModel.setProperty(idx, roleName, value) : false
    }


//endregion
    menuBar: MenuBar {
        Menu {
            title: qsTr("Файл")

            MenuItem {
                id: saveMenuItem
                text: qsTr("Сохранить")
                Accessible.name: text
                Accessible.description: qsTr("Сохранить текущую конфигурацию")
                onTriggered: {
                    if (rootwindow.currentBldePath !== "") {
                        saveToBlde(rootwindow.currentBldePath)
                    } else {
                        saveFileDialog.open()
                    }
                }
            }

            MenuItem {
                id: saveAsMenuItem
                text: qsTr("Сохранить как...")
                Accessible.name: text
                Accessible.description: qsTr("Открыть диалог сохранения в новый файл")
                onTriggered: {saveFileDialog.open(); console.log("trigger")}
            }

            Menu {
                title: qsTr("Экспорт...")
                MenuItem{
                    id: exportExcelMenuItem
                    text: qsTr("Excel")
                    Accessible.name: text
                    Accessible.description: qsTr("Экспортировать данные в файл Excel")
                    onTriggered: {
                        exportExcelDialog.open()
                        console.log("trigger")
                    }
                }
                    MenuItem{
                        id: exportCodeMenuItem
                        text: qsTr("Код")
                        Accessible.name: text
                        Accessible.description: qsTr("Экспортировать исходный код")
                        onTriggered:{
                            exportCodeDialog.open()
                        }
                    }
                }

            MenuItem{
                id: importMenuItem
                text: qsTr("Импорт")
                Accessible.name: text
                Accessible.description: qsTr("Импортировать конфигурацию из файла")
                onTriggered: fileDialog.open()
            }

            MenuItem {
                id: exitMenuItem
                text: qsTr("Выход")
                Accessible.name: text
                Accessible.description: qsTr("Закрыть приложение")
                onTriggered: {confirmExitDialog.open(); console.log("trigger")}
            }
        }
        Menu {
            title: qsTr("Объектные модели")
            MenuItem {
                text: qsTr("Создать MEK модель")
                onTriggered: {
                    objectModelTypeCombo.currentIndex = 0 // MEK
                    createObjectModelDialog.open()
                }
            }
            MenuItem {
                text: qsTr("Создать MODBUS модель")
                onTriggered: {
                    objectModelTypeCombo.currentIndex = 1 // MODBUS
                    createObjectModelDialog.open()
                }
            }
            MenuSeparator {}
            MenuItem {
                text: qsTr("Управление моделями")
                onTriggered: objectModelsManagerDialog.open()
            }
        }

        Menu {
            title: qsTr("Интерфейсы")
            MenuItem {
                text: qsTr("Ethernet")
                onTriggered: ethConfigDialog.open()
            }
            MenuItem{
                text: qsTr("RS")
                onTriggered: rsConfigDialog.open()
            }
            MenuItem {
                text: qsTr("Управление интерфейсами")
                onTriggered: interfaceManagerDialog.open()
            }
        }

        Menu {
            title: qsTr("Протоколы")
            MenuItem {
                text: qsTr("Создать протокол")
                onTriggered: createProtocolDialog.open()
            }
            MenuItem {
                text: qsTr("Управление протоколами")
                onTriggered: protocolManagerDialog.open()
            }
        }

        Menu{
            title: qsTr("Дополнительно")
            MenuItem{
                text: qsTr("Добавить ТУ")
                onTriggered: pickTelecommandHeader.open()
            }
            MenuItem{
                text: qsTr("Добавить ТC")
                onTriggered: pickTelesignalHeader.open()
            }
            MenuItem{
                text: qsTr("Добавить ТИ")
                onTriggered: pickTelemeasureHeader.open()
            }
        }
        onObjectModelManagerRequested: objectModelsManagerDialog.open()
        onEthernetConfigRequested: ethConfigDialog.open()
        onRsConfigRequested: rsConfigDialog.open()
        onInterfaceManagerRequested: interfaceManagerDialog.open()
        onCreateProtocolRequested: createProtocolDialog.open()
        onProtocolManagerRequested: protocolManagerDialog.open()
        onAddTuRequested: pickTelecommandHeader.open()
        onAddTsRequested: pickTelesignalHeader.open()
        onAddTiRequested: pickTelemeasureHeader.open()
    }
    // ===== Настройки единственного чекбокса Setpoint =====
    property var val_sp: { "flag": "val_setpoint_enabled",
        "buf":  "val_setpoint_def_value",
        "prefix": "VAL" }
    function isSetpointCommand(itemData) {
        return itemData && itemData.paramType === "Уставка" &&
            itemData.link_kind === "val_setpoint";
    }
    // Имя уставки: VAL_SETPOINT_<codeName>_<ioIndex>
    function makeValSetpointCode(srcItem) {
        var prefix = val_sp.prefix;
        var code   = (srcItem && srcItem.codeName ? String(srcItem.codeName) : "");
        var io     = (srcItem && srcItem.ioIndex  ? String(srcItem.ioIndex)  : "");
        return prefix + "_" + code;
    }

    // Найти уставку, связанную с исходной строкой (возвращает индекс в dataModel или -1)
    function findValSetpointIndex(srcOriginalIndex) {
        for (var i = 0; i < dataModel.count; ++i) {
            var it = dataModel.get(i);
            if (!it) continue;
            if (it.paramType === "Уставка" &&
                it.link_source_index === srcOriginalIndex &&
                it.link_kind === "val_setpoint") {
                return i;
            }
        }
        return -1;
    }

    // Создать связанную уставку (если ещё нет). Вернёт её индекс.
    function createValSetpoint(srcOriginalIndex) {
        var src  = dataModel.get(srcOriginalIndex);
        var code = makeValSetpointCode(src);
        var name = code;
        var bufv = (src && src[val_sp.buf]) ? src[val_sp.buf] : "";
        dataModel.setProperty(srcOriginalIndex, "setpoint", code)
        dataModel.append({
            paramType: "Уставка",
            codeName:  code,
            name:      name,
            def_value: bufv,

            // базовые поля
            ioIndex: (typeof rootwindow !== "undefined" && rootwindow.nextIoIndex) ? String(src.ioIndex) : "",
            type: "float",
            logicuse: "Да",
            saving: "Да",
            sod: false,
            asdu_address: 1,
            // связь (важно для удаления/синхронизации)
            link_source_index: srcOriginalIndex,
            link_source_code:  (src && src.codeName) ? src.codeName : "",
            link_source_io:    (src && src.ioIndex)  ? src.ioIndex  : "",
            link_kind:         "val_setpoint"
        });

        if (typeof rootwindow !== "undefined" && rootwindow.incrementIoIndex)
            rootwindow.incrementIoIndex();

        return dataModel.count - 1;
    }

    // Удалить связанную уставку (если есть)
    function removeValSetpoint(srcOriginalIndex) {
        var idx = findValSetpointIndex(srcOriginalIndex);
        if (idx >= 0) dataModel.remove(idx);
    }

    // (Опционально) вызвать один раз после импорта всех строк, если не сериализуешь автосозданные уставки
    function restoreValSetpointsAfterImport() {
        for (var i = 0; i < dataModel.count; ++i) {
            var src = dataModel.get(i);
            if (!src) continue;
            if (!!src[val_sp.flag]) {
                if (findValSetpointIndex(i) < 0) createValSetpoint(i);
                syncValSetpointDefValue(i);
            } else {
                removeValSetpoint(i);
            }
        }
    }
    // === МЕТА для 4 чекбоксов ===
    // kind — внутр. ключ; flag — имя булевого флага в исходной строке;
    // buf  — имя буфера исходной строки (для импорта/экспорта);
    // prefix — кусок имени уставки.
    property var meas_meta: [
        { kind: "aperture", label: "Апертура",    flag: "meas_aperture_enabled",    buf: "meas_aperture_def_value",    prefix: "MEAS_AP" },
        { kind: "ktt",      label: "КТТ",         flag: "meas_ktt_enabled",         buf: "meas_ktt_def_value",         prefix: "MEAS_KTT" },
        { kind: "upper",    label: "Верх. предел",flag: "meas_upper_enabled",       buf: "meas_upper_def_value",       prefix: "MEAS_UP" },
        { kind: "lower",    label: "Нижн. предел",flag: "meas_lower_enabled",       buf: "meas_lower_def_value",       prefix: "MEAS_LOW" },
    ]

    function makeMeasPrefix(kind, srcItem) {
        // по умолчанию из меты
        const m = meas_meta.find(x => x.kind === kind)
        return m ? m.prefix : "MEAS"
    }

    // Итоговый код уставки: MEAS_<PREFIX>_<codeName>_<IO_INDEX>
    function makeMeasCode(kind, srcItem) {
        const prefix = makeMeasPrefix(kind, srcItem)
        const code   = (srcItem.codeName || "").toString().trim()
        const io     = (srcItem.ioIndex  || "").toString().trim()
        return prefix + "_" + code
    }

    // Поиск уставки, связанной с исходной строкой и kind
    function findLinkedMeasIndexFor(kind, srcOriginalIndex) {
        for (let i = 0; i < dataModel.count; ++i) {
            const it = dataModel.get(i)
            if (it && it.paramType === "Уставка"    &&
                it.link_source_index === srcOriginalIndex &&
                it.link_kind === kind)
                return i
        }
        return -1
    }




    // Создать уставку; вернуть индекс
    function createLinkedMeasFor(kind, srcOriginalIndex) {
        const src  = dataModel.get(srcOriginalIndex)
        const code = makeMeasCode(kind, src)
        const name = code
        const meta = meas_meta.find(x => x.kind === kind)
        const bufv = src[meta.buf] || ""
        dataModel.setProperty(srcOriginalIndex, kind, code)
        dataModel.append({
            paramType: "Уставка",
            codeName:  code,
            name:      "Уставка " + code,
            def_value: bufv,

            // базовые поля — подставь, что нужно твоему генератору
            ioIndex: (typeof rootwindow !== "undefined" && rootwindow.nextIoIndex) ? rootwindow.nextIoIndex.toString() : "",
            type: "float", logicuse: "Да", saving: "Да", sod: false,
            asdu_address: 1,
            // связь
            link_source_index: srcOriginalIndex,
            link_source_code:  src.codeName || "",
            link_source_io:    src.ioIndex  || "",
            link_kind:         kind
        })

        if (typeof rootwindow !== "undefined" && rootwindow.incrementIoIndex)
            rootwindow.incrementIoIndex()

        return dataModel.count - 1
    }

    // Удалить уставку, если есть
    function removeLinkedMeasFor(kind, srcOriginalIndex) {
        dataModel.setProperty(srcOriginalIndex, kind, "")
        const idx = findLinkedMeasIndexFor(kind, srcOriginalIndex)
        if (idx >= 0) dataModel.remove(idx)
    }

    // Протянуть def_value из буфера строки-источника в связанную уставку
    function syncMeasDefValue(kind, srcOriginalIndex) {
        const src  = dataModel.get(srcOriginalIndex)
        const meta = meas_meta.find(x => x.kind === kind)
        const idx  = findLinkedMeasIndexFor(kind, srcOriginalIndex)
        if (idx >= 0) dataModel.setProperty(idx, "def_value", src[meta.buf] || "")
    }

    // Восстановление после импорта (когда dataModel уже наполнен)
    function restoreAutoMeasurementsAfterImport() {
        for (let i = 0; i < dataModel.count; ++i) {
            const src = dataModel.get(i)
            if (!src) continue
            for (const m of meas_meta) {
                if (src[m.flag]) {
                    if (findLinkedMeasIndexFor(m.kind, i) < 0)
                        createLinkedMeasFor(m.kind, i)
                    syncMeasDefValue(m.kind, i)
                } else {
                    removeLinkedMeasFor(m.kind, i)
                }
            }
        }
    }



    // ===== МОДЕЛИ =====
    ListModel { id: telecommandModel }       // TelecommandIndexes
    ListModel { id: telesignalModel }        // TelesignalizationIndexes
    ListModel { id: telemeasureModel }       // Telemeasurement/TelemeasurmentIndexes

    // ===== УНИВЕРСАЛЬНЫЙ ПАРСЕР КЛАССА С ИНДЕКСАМИ =====
    // Ищет класс вида class <ClassName> { ... static constexpr TYPE NAME = N; ... };
    function parseIndexesFromHeader(headerText, className) {
        // тело класса
        const clsRe = new RegExp("class\\s+" + className + "[\\s\\S]*?\\{([\\s\\S]*?)\\};", "m");
        const cls = clsRe.exec(headerText);
        if (!cls) return [];
        const body = cls[1];

        // строки со статическими индексами
        const re = /static\s+constexpr\s+TYPE\s+([A-Za-z_]\w*)\s*=\s*(\d+)\s*;/g;
        let m, items = [];
        while ((m = re.exec(body)) !== null) {
            items.push({ text: m[1], value: Number(m[2]) });
        }
            items.sort((a,b) => a.value - b.value);
        return items;
    }

    // Попытаться распарсить по нескольким возможным именам класса (на случай разного нейминга)
    function parseAnyOf(headerText, classNamesArray) {
        for (let i = 0; i < classNamesArray.length; ++i) {
            const items = parseIndexesFromHeader(headerText, classNamesArray[i]);
            if (items.length > 0) return items;
        }
        return [];
    }

    // ===== ЗАПОЛНЕНИЕ МОДЕЛЕЙ =====
    function fillModel(model, items) {
        model.clear();
        for (let i = 0; i < items.length; ++i) model.append(items[i]);  // {text, value}
    }

    // ===== ЧТЕНИЕ ТЕКСТА ПО URL (подходит и для file://) =====
    function readTextUrl(url, onOk, onErr) {
        try {
            const xhr = new XMLHttpRequest();
            xhr.open("GET", url); // сюда подаём именно URL
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 0 || (xhr.status >= 200 && xhr.status < 300)) {
                        onOk(xhr.responseText);
                    } else {
                            onErr && onErr("HTTP status " + xhr.status);
                    }
                }
            }
            xhr.send();
        } catch (e) {
                onErr && onErr(e);
        }
    }
    // Диалог выбора .h файла
    // ===== DIALOG: Telecommands =====
    FileDialog {
        id: pickTelecommandHeader
        title: qsTr("Выберите заголовок с TelecommandIndexes")
        nameFilters: ["C/C++ headers (*.h)", "All files (*)"]
        onAccepted: {
            const url = (typeof selectedFile !== "undefined" && selectedFile) ? selectedFile
                : (typeof fileUrl !== "undefined" ? fileUrl : null);
            if (!url) { console.warn("Не удалось получить URL выбранного файла"); return; }

            readTextUrl(url.toString(), function(text) {
                // поддержка разных именований
                const items = parseAnyOf(text, ["TelecommandIndexes"]);
                fillModel(telecommandModel, items);
                if (items.length === 0) console.warn("В файле нет TelecommandIndexes");
            }, function(err){ console.error("Ошибка чтения файла:", err);});
        }
    }

    // ===== DIALOG: Telesignalizations =====
    FileDialog {
        id: pickTelesignalHeader
        title: qsTr("Выберите заголовок с TelesignalizationIndexes")
        nameFilters: ["C/C++ headers (*.h)", "All files (*)"]
        onAccepted: {
            const url = (typeof selectedFile !== "undefined" && selectedFile) ? selectedFile
                : (typeof fileUrl !== "undefined" ? fileUrl : null);
            if (!url) { console.warn("Не удалось получить URL выбранного файла"); return; }

            readTextUrl(url.toString(), function(text) {
                const items = parseAnyOf(text, ["TelesignalizationIndexes"]);
                fillModel(telesignalModel, items);
                if (items.length === 0) console.warn("В файле нет TelesignalizationIndexes");
            }, function(err){ console.error("Ошибка чтения файла:", err);});
        }
    }

    // ===== DIALOG: Telemeasurements =====
    FileDialog {
        id: pickTelemeasureHeader
        title: qsTr("Выберите заголовок с TelemeasurementIndexes")
        nameFilters: ["C/C++ headers (*.h)", "All files (*)"]
        onAccepted: {
            const url = (typeof selectedFile !== "undefined" && selectedFile) ? selectedFile
                : (typeof fileUrl !== "undefined" ? fileUrl : null);
            if (!url) { console.warn("Не удалось получить URL выбранного файла"); return; }

            readTextUrl(url.toString(), function(text) {
                // иногда в проекте опечатка: TelemeasurmentIndexes — учитываем оба
                const items = parseAnyOf(text, ["TelemeasurementIndexes", "TelemeasurmentIndexes"]);
                fillModel(telemeasureModel, items);
                if (items.length === 0) console.warn("В файле нет Telemeasurement/TelemeasurmentIndexes");
            }, function(err){ console.error("Ошибка чтения файла:", err);});
        }
    }


    ManagerListDialog {
        id: removeInterfaceDialog
        title: qsTr("Удалить интерфейс")
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

    ManagerListDialog {
        id: removeObjectModelDialog
        title: qsTr("Удалить объектную модель")
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
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Сохранить как...")
        fileMode: FileDialog.SaveFile
        nameFilters: ["BLDE (*.blde)"]
        onAccepted: {
            let path = selectedFile.toString().replace("file://", "")
            if (!path.endsWith(".blde")) path += ".blde"
            rootwindow.currentBldePath = path
            saveToBlde(path)
        }
    }

    Platform.FileDialog {
        id: exportExcelDialog
        title: qsTr("Экспортировать в Excel")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel (*.xlsx)"]
        onAccepted: {
            let path = String(file).replace("file://", "")

            // Remove leading slash if followed by drive letter (Windows)
            if (path.match(/^\/[A-Za-z]:/)) {
                path = path.substring(1)
            }

            // Use forward slashes for consistency (works on both Windows and Unix)
            path = path.replace(/\\/g, "/")

            let exportDir = path.substring(0, path.lastIndexOf("/"))
            let tempJson = exportDir + "/temp_export.json"

            console.log("Final path:", path)
            console.log("Temp file:", tempJson)

            saveToBlde(tempJson)
            fileHandler.runPythonScript(tempJson, false)
        }
    }

    FileDialog {
        id: exportCodeDialog
        title: qsTr("Экспортировать в Excel")
        fileMode: FileDialog.SaveFile
        onAccepted: {
            let path = String(file).replace("file://", "")

            // Remove leading slash if followed by drive letter (Windows)
            if (path.match(/^\/[A-Za-z]:/)) {
                path = path.substring(1)
            }

            // Use forward slashes for consistency (works on both Windows and Unix)
            path = path.replace(/\\/g, "/")

            let exportDir = path.substring(0, path.lastIndexOf("/"))
            let tempJson = exportDir + "/temp_export.json"

            console.log("Final path:", path)
            console.log("Temp file:", tempJson)

            saveToBlde(tempJson)
            fileHandler.runPythonScript(tempJson, true)
        }
    }

    Platform.FileDialog {
        id: saveFileDialog
        title: qsTr("Сохранить как...")
        nameFilters: ["BLDE (*.blde)"]
        defaultSuffix: "blde"
        fileMode: Platform.FileDialog.SaveFile
        onAccepted: {
            const filePath = String(file).replace("file://", "")
            if (fileHandler.saveToFile(filePath, exportToJson())) {
                stateFileName = filePath
            }
            rootwindow.currentBldePath = filePath
            hasUnsavedChanges = false
            updateHeaderIndicators()
        }
    }
    MessageDialog {
        id: confirmExitDialog
        title: qsTr("Выход")
        text: qsTr("Сохранить перед выходом?")
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

    ListModel {
        id: objectModelsConfig
        // Структура: {id, name, type, signalIds: [], protocolIds: []}
    }

    ListModel {
        id: interfaceModelsConfig
        // Структура: {id, name, type, settings: {}}
    }

    ListModel {
        id: protocolModelsConfig
        // Структура: {id, name, type, objectModelId, interfaceId, signalMappings: []}
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
    ListModel { id: meksettingsModel }

    function initializeFilteredModels() {
        analogInputsModel.clear()
        digitalInputsModel.clear()
        analogOutputsModel.clear()
        digitalOutputsModel.clear()
        flagsModel.clear()
        settingsModel.clear()
        meksettingsModel.clear()
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
        meksettingsModel.clear()

        // Repopulate from main dataModel
        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i)
            switch(item.paramType) {
                case "Аналоговые входы": analogInputsModel.append({ "originalIndex": i }); break
                case "Дискретные входы": digitalInputsModel.append({ "originalIndex": i }); break
                case "Аналоговый выход": analogOutputsModel.append({ "originalIndex": i }); break
                case "Дискретный выход": digitalOutputsModel.append({ "originalIndex": i }); break
                case "Признаки": flagsModel.append({ "originalIndex": i }); break
                case "Уставка": settingsModel.append({ "originalIndex": i })
                    var hide = (item.link_kind === "val_setpoint")
                    if(!hide)
                        meksettingsModel.append({originalIndex: i})
                    break
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
                    markDirty()
            }
        }

        function onRowsRemoved(parent, first, last) {
            // Rebuild all filtered models after removal
            initializeFilteredModels()
            markDirty()
        }

        function onDataChanged(topLeft, bottomRight, roles) {
            for (var i = topLeft.row; i <= bottomRight.row; i++) {
                var item = dataModel.get(i)
                console.log("change")
                markDirty()
                // If paramType changed, we need to re-categorize
                if (roles.length === 0 || roles.indexOf("paramType") >= 0) {
                    syncFilteredModels()
                }
            }
        }
    }

    function getFilteredModel(type, ismek) {
        switch(type) {
            case "Аналоговые входы": return analogInputsModel
            case "Дискретные входы": return digitalInputsModel
            case "Аналоговый выход": return analogOutputsModel
            case "Дискретный выход": return digitalOutputsModel
            case "Признаки": return flagsModel
            case "Уставка": return ismek ? meksettingsModel : settingsModel
            default: return analogInputsModel
        }
    }



    StartupDialog {
        id: startDialog
        title: qsTr("Выберите действие")
        Accessible.name: title
        Accessible.description: qsTr("Диалог выбора создания новой или открытия существующей конфигурации")
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: parent
        width: 400
        height: 200

        background: Rectangle {
            color: "#ffffff"
            radius: 8
            antialiasing: true
            border.color: "#e2e8f0"
            border.width: 1

            // Subtle shadow effect
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
                text: startDialog.title
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
                id: startCreateButton
                text: qsTr("Создать новую конфигурацию")
                focus: true
                KeyNavigation.tab: startOpenButton
                Accessible.name: text
                Accessible.description: qsTr("Создать пустую конфигурацию")
                Layout.fillWidth: true
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
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    dataModel.clear()
                    startDialog.close()
                }
            }

            Button {
                id: startOpenButton
                text: qsTr("Открыть существующую")
                KeyNavigation.tab: startCreateButton
                KeyNavigation.backtab: startCreateButton
                Accessible.name: text
                Accessible.description: qsTr("Открыть конфигурацию из файла")
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? "#1d4ed8" : (parent.hovered ? "#2563eb" : "#3b82f6")
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
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

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
        height: 600
        anchors.centerIn: parent
        title: qsTr("Настройка RS")
        modal: true
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: appTheme.surface
            radius: 8
            antialiasing: true
            border.color: appTheme.border
            border.width: 1

            // Subtle shadow effect
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
            color: appTheme.surfaceVariant
            radius: 8
            antialiasing: true
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: appTheme.border
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                GradientStop { position: 1.0; color: Qt.lighter(appTheme.surfaceVariant, 1.06) }
            }

            Label {
                anchors.centerIn: parent
                text: rsConfigDialog.title
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: appTheme.textPrimary
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            GridLayout {
                columns: 2
                columnSpacing: 15
                rowSpacing: 15
                Layout.fillWidth: true

                Label {
                    text: qsTr("Четность")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: parityField
                    model: ["None", "Even", "Odd"]
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 120
                    font.pixelSize: 13

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }

                Label {
                    text: qsTr("Скорость")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: baudrateField
                    model: [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 120
                    font.pixelSize: 13

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }

                Label {
                    text: qsTr("Длина слова")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                TextField {
                    id: lenField
                    Layout.preferredHeight: 32
                    color: appTheme.textPrimary
                    font.pixelSize: 13
                    font.weight: Font.Normal

                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 6
                    bottomPadding: 6

                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        // Subtle shadow when focused
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            color: "transparent"
                            border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                            border.width: 2
                            radius: 5
                            visible: parent.parent.activeFocus
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
                Label {
                    text: qsTr("Стоп-бит")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: stopField
                    model: ["1", "2"]
                    Layout.preferredHeight: 32
                    font.pixelSize: 13
                    Layout.preferredWidth: 120
                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }

                Label {
                    text: qsTr("Адрес устройства")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                TextField {
                    id: addField
                    Layout.preferredHeight: 32
                    color: appTheme.textPrimary
                    font.pixelSize: 13
                    font.weight: Font.Normal

                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 6
                    bottomPadding: 6

                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        // Subtle shadow when focused
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            color: "transparent"
                            border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                            border.width: 2
                            radius: 5
                            visible: parent.parent.activeFocus
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Button {
                text: qsTr("Сохранить")
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? Qt.darker(appTheme.success, 1.3) : (parent.hovered ? Qt.darker(appTheme.success, 1.1) : appTheme.success)
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
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    createInterface("RS", {
                        parity: parityField.currentValue,
                        baudrate: baudrateField.currentText,
                        wordLen: lenField.text,
                        stopBits: stopField.currentValue,
                        addr: addField.text
                    });
                    rsConfigDialog.close();
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
        height: 800
        anchors.centerIn: parent
        title: qsTr("Настройка ETH")
        modal: true
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: appTheme.surface
            radius: 8
            antialiasing: true
            border.color: appTheme.border
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
            color: appTheme.surfaceVariant
            radius: 8
            antialiasing: true

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: appTheme.border
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                GradientStop { position: 1.0; color: Qt.lighter(appTheme.surfaceVariant, 1.06) }
            }

            Label {
                anchors.centerIn: parent
                text: ethConfigDialog.title
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: appTheme.textPrimary
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 15
                    rowSpacing: 15

                    Label {
                        text: qsTr("IP адрес")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: ipAddressField
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("192.168.0.1")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("Маска подсети")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: subnetMaskField
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("255.255.255.0")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("Шлюз")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: gatewayField
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("192.168.0.254")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("Старшие 3 байта MAC адреса")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: macHighField
                        inputMask: "HH:HH:HH;_"
                        placeholderText: qsTr("00:1A:2B")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }Label {
                        text: qsTr("Младшие 3 байта MAC адреса")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: macLowField
                        inputMask: "HH:HH:HH;_"
                        placeholderText: qsTr("3C:4D:5E")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("IP адрес клиента 1")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: clientIp1Field
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("192.168.0.10")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("IP адрес клиента 2")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: clientIp2Field
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("192.168.0.11")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("IP адрес клиента 3")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: clientIp3Field
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("192.168.0.12")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("IP адрес клиента 4")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: clientIp4Field
                        inputMask: "000.000.000.000;_"
                        placeholderText: qsTr("192.168.0.13")
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("ETH адрес устройства")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: addrField
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("Порт 1")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: port1Field
                        validator: IntValidator { bottom: 1; top: 65535 }
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Label {
                        text: qsTr("Порт 2")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: port2Field
                        validator: IntValidator { bottom: 1; top: 65535 }
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                    Label {
                        text: qsTr("Порт 3")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: port3Field
                        validator: IntValidator { bottom: 1; top: 65535 }
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                    Label {
                        text: qsTr("Порт 4")
                        color: "#374151"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    TextField {
                        id: port4Field
                        validator: IntValidator { bottom: 1; top: 65535 }
                        Layout.preferredHeight: 32
                        color: appTheme.textPrimary
                        font.pixelSize: 13

                        leftPadding: 8
                        rightPadding: 8
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                            border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                            border.width: 1
                            radius: 4
                            antialiasing: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                color: "transparent"
                                border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                                border.width: 2
                                radius: 5
                                visible: parent.parent.activeFocus
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
            Button {
                text: qsTr("Сохранить")
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? Qt.darker(appTheme.success, 1.3) : (parent.hovered ? Qt.darker(appTheme.success, 1.1) : appTheme.success)
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
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    createInterface("ETH", {
                        ip: ipAddressField.text,
                        mask: subnetMaskField.text,
                        gate: gatewayField.text,
                        high: macHighField.text,
                        low: macLowField.text,
                        ipc1: clientIp1Field.text,
                        ipc2: clientIp2Field.text,
                        ipc3: clientIp3Field.text,
                        ipc4: clientIp4Field.text,
                        addr: addrField.text,
                        port1: port1Field.text,
                        port2: port2Field.text,
                        port3: port3Field.text,
                        port4: port4Field.text
                    });
                    ethConfigDialog.close();
                }
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
        title: qsTr("Выберите JSON файл")
        fileMode: FileDialog.OpenFile
        // nameFilters: ["JSON файлы (*.json)", "(*.blde)"]
        property string exportType: ""
        onAccepted: {
            let localPath = selectedFile.toString().startsWith("file:///")
                ? selectedFile.toString().substring(8)
                : selectedFile.toString().replace("file://", "")
            console.log(localPath)
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

    Dialog {
        id: mekConfigDialog
        width: 500
        height: 600
        anchors.centerIn: parent
        title: qsTr("Настройка RS")
        modal: true
        standardButtons: Dialog.NoButton
        property string protocolName: ""
        property string protocolType: ""
        property string objectModel: ""
        property string interfacet: ""
        background: Rectangle {
            color: appTheme.surface
            radius: 8
            antialiasing: true
            border.color: appTheme.border
            border.width: 1

            // Subtle shadow effect
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
            color: appTheme.surfaceVariant
            radius: 8
            antialiasing: true
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: appTheme.border
            }

            gradient: Gradient {
                GradientStop { position: 0.0
                    ;
                    color: appTheme.surfaceVariant
                }
                GradientStop { position: 1.0
                    ;
                    color: Qt.lighter(appTheme.surfaceVariant, 1.06)
                }
            }

            Label {
                anchors.centerIn: parent
                text: rsConfigDialog.title
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: appTheme.textPrimary
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            GridLayout {
                columns: 2
                columnSpacing: 15
                rowSpacing: 15
                Layout.fillWidth: true

                Label {
                    text: qsTr("АСДУ адрес")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                TextField {
                    id: asduField
                    Layout.preferredHeight: 32
                    color: appTheme.textPrimary
                    font.pixelSize: 13
                    font.weight: Font.Normal

                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 6
                    bottomPadding: 6

                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        // Subtle shadow when focused
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            color: "transparent"
                            border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                            border.width: 2
                            radius: 5
                            visible: parent.parent.activeFocus
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: 150
                            }
                        }
                    }
                }

                Label {
                    text: qsTr("Длина адресного поля")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: linkaddresField
                    model: [1, 2]
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 120
                    font.pixelSize: 13

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150
                            }
                        }
                    }
                }

                Label {
                    text: qsTr("Длина АСДУ")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: asdulenField
                    model: [1, 2]
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 120
                    font.pixelSize: 13

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150
                            }
                        }
                    }
                }
                Label {
                    text: qsTr("Длина причина передачи")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: reasonlenField
                    model: ["1", "2"]
                    Layout.preferredHeight: 32
                    font.pixelSize: 13
                    Layout.preferredWidth: 120
                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150
                            }
                        }
                    }
                }

                Label {
                    text: qsTr("Длина IOA")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: ioalenField
                    model: [1, 2, 3]
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 120
                    font.pixelSize: 13

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150
                            }
                        }
                    }
                }
                Label {
                    text: qsTr("Синхронизация")
                    color: "#374151"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                ComboBox {
                    id: syncField
                    model: ["true", "false"]
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 120
                    font.pixelSize: 13

                    background: Rectangle {
                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                        border.width: 1
                        radius: 4
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation { duration: 150
                            }
                        }
                    }
                }
            }
            Label {
                text: qsTr("Телеконтроль")
                color: "#374151"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            ComboBox {
                id: telecontrolField
                model: ["true", "false"]
                Layout.preferredHeight: 32
                Layout.preferredWidth: 120
                font.pixelSize: 13

                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation { duration: 150
                        }
                    }
                }
            }
            Label {
                text: qsTr("Период перцик")
                color: "#374151"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            TextField {
                id: percycField
                Layout.preferredHeight: 32
                color: appTheme.textPrimary
                font.pixelSize: 13
                font.weight: Font.Normal

                leftPadding: 8
                rightPadding: 8
                topPadding: 6
                bottomPadding: 6

                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter

                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    // Subtle shadow when focused
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        color: "transparent"
                        border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                        border.width: 2
                        radius: 5
                        visible: parent.parent.activeFocus
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150
                        }
                    }
                }
            }
            Label {
                text: qsTr("Период фонового")
                color: "#374151"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            TextField {
                id: backField
                Layout.preferredHeight: 32
                color: appTheme.textPrimary
                font.pixelSize: 13
                font.weight: Font.Normal

                leftPadding: 8
                rightPadding: 8
                topPadding: 6
                bottomPadding: 6

                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter

                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    // Subtle shadow when focused
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        color: "transparent"
                        border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                        border.width: 2
                        radius: 5
                        visible: parent.parent.activeFocus
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150
                        }
                    }
                }
            }
            Item {
                Layout.fillHeight: true
            }

            Button {
                text: qsTr("Сохранить")
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? Qt.darker(appTheme.success, 1.3) : (parent.hovered ? Qt.darker(appTheme.success, 1.1) : appTheme.success)
                    radius: 6
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
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    createProtocol(
                        mekConfigDialog.protocolName,
                        mekConfigDialog.protocolType,
                        mekConfigDialog.objectModel,
                        mekConfigDialog.interfacet,
                        {
                            asdu: asduField.text,
                            link_address_len: linkaddresField.currentValue,
                            asdu_len: asdulenField.currentValue,
                            reason_len: reasonlenField.currentValue,
                            ioa_len: ioalenField.currentValue,
                            sync: syncField.currentValue,
                            telecontrol: telecontrolField.currentValue,
                            percyc_period: percycField.text,
                            back_period: backField.text
                        }
                    )
                    mekConfigDialog.close();
                    createProtocolDialog.close()
                }
            }
        }
    }
    Platform.FileDialog {
        id: fileDialog
        title: qsTr("Выберите файл конфигурации")
        // nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            const cleanPath = fileHandler.cleanPath(String(file));
            const data = fileHandler.loadFromFile(cleanPath);

            if (!data) {
                console.warn("Файл не загружен или пустой");
                return;
            }

            stateFileName = cleanPath;



                dataModel.clear();
                objectModelsConfig.clear();
                interfaceModelsConfig.clear();
                protocolModelsConfig.clear();
                telemeasureModel.clear();
                telesignalModel.clear();
                telecommandModel.clear();
                for (let i = 0; i < data.signals.length; i++) {
                    dataModel.append(data.signals[i]);
                }
                importObjectModels(data.objectModels)
                for (let i = 0; i < (data.interfaces || []).length; i++) {
                    interfaceModelsConfig.append(data.interfaces[i]);
                }
                for (let i = 0; i < (data.protocols || []).length; i++) {
                    protocolModelsConfig.append(data.protocols[i]);
                }
                for (let i = 0; i < (data.TcIndexes || []).length; i++) {
                    telecommandModel.append(data.TcIndexes[i]);
                }
                for (let i = 0; i < (data.TsIndexes || []).length; i++) {
                    telesignalModel.append(data.TsIndexes[i]);
                }
                for (let i = 0; i < (TmIndexes.protocols || []).length; i++) {
                    telemeasureModel.append(TmIndexes.protocols[i]);
                }
            updateNextIoIndex();
            initializeFilteredModels();
            updateFiltered();
            updateTrigger();
            updateTabs();


                Qt.callLater(() => {
                for (let i = 0; i < listView.count; ++i) {
            let item = listView.itemAtIndex(i);
            if (item?.nameField) item.nameField.updateName(item.nameField.text);
            if (item?.codeNameField) item.codeNameField.updateName(item.codeNameField.text);
        }
            checkForDuplicates();
        });

        loadingState = false;
        hasUnsavedChanges = false;
        updateHeaderIndicators();
    }
    }
    Dialog {
        id: createObjectModelDialog
        title: qsTr("Создать объектную модель")
        Accessible.name: title
        Accessible.description: qsTr("Диалог создания объектной модели")
        height: 200
        background: Rectangle {
            color: appTheme.surface
            radius: 8
            antialiasing: true
            border.color: appTheme.border
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
            color: appTheme.surfaceVariant
            radius: 8
            antialiasing: true

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: appTheme.border
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                GradientStop { position: 1.0; color: Qt.lighter(appTheme.surfaceVariant, 1.06) }
            }

            Label {
                anchors.centerIn: parent
                text: createObjectModelDialog.title
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: appTheme.textPrimary
            }
        }
        Column {
            TextField {
                id: objectModelNameField
                placeholderText: qsTr("Имя объектной модели")
                focus: createObjectModelDialog.visible
                KeyNavigation.tab: objectModelTypeCombo
                Accessible.name: qsTr("Имя объектной модели")
                Accessible.description: qsTr("Введите имя новой объектной модели")
                Layout.preferredHeight: 32
                color: appTheme.textPrimary
                font.pixelSize: 13

                leftPadding: 8
                rightPadding: 8
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter

                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        color: "transparent"
                        border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                        border.width: 2
                        radius: 5
                        visible: parent.parent.activeFocus
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            ComboBox {
                id: objectModelTypeCombo
                model: ["MEK", "MODBUS"]
                KeyNavigation.tab: createObjectModelConfirmButton
                KeyNavigation.backtab: objectModelNameField
                Accessible.name: qsTr("Тип объектной модели")
                Accessible.description: qsTr("Выберите тип создаваемой объектной модели")
                height: 32
                font.pixelSize: 13
                width: 120
                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            Row {
                Button {
                    id: createObjectModelConfirmButton
                    text: qsTr("Создать")
                    KeyNavigation.tab: createObjectModelCancelButton
                    KeyNavigation.backtab: objectModelTypeCombo
                    Accessible.name: text
                    Accessible.description: qsTr("Подтвердить создание объектной модели")
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    font.pixelSize: 14
                    font.weight: Font.Medium

                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(appTheme.success, 1.3) : (parent.hovered ? Qt.darker(appTheme.success, 1.1) : appTheme.success)
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        createObjectModel(objectModelNameField.text, objectModelTypeCombo.currentText)
                        initializeMekProperties();
                        createObjectModelDialog.close()
                    }
                }
                Button {
                    id: createObjectModelCancelButton
                    text: qsTr("Отмена")
                    KeyNavigation.tab: objectModelNameField
                    KeyNavigation.backtab: createObjectModelConfirmButton
                    Accessible.name: text
                    Accessible.description: qsTr("Закрыть диалог без создания модели")
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    font.pixelSize: 14
                    font.weight: Font.Medium

                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(appTheme.danger, 1.2) : (parent.hovered ? appTheme.danger : Qt.lighter(appTheme.danger, 1.2))
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: createObjectModelDialog.close()
                }
            }
        }
    }
    Dialog {
        id: createInterfaceDialog
        title: qsTr("Создать интерфейс")
        Accessible.name: title
        Accessible.description: qsTr("Диалог создания интерфейса")

        Column {
            TextField {
                id: interfaceNameField
                placeholderText: qsTr("Имя интерфейса")
                focus: createInterfaceDialog.visible
                KeyNavigation.tab: interfaceTypeCombo
                Accessible.name: qsTr("Имя интерфейса")
                Accessible.description: qsTr("Введите имя интерфейса")
            }

            ComboBox {
                id: interfaceTypeCombo
                model: ["ETH", "RS485", "RS232"]
                KeyNavigation.tab: createInterfaceConfirmButton
                KeyNavigation.backtab: interfaceNameField
                Accessible.name: qsTr("Тип интерфейса")
                Accessible.description: qsTr("Выберите тип интерфейса")
            }

            // Здесь будут поля для настройки интерфейса
            // IP, порт для ETH; скорость, четность для RS и т.д.

            Row {
                Button {
                    id: createInterfaceConfirmButton
                    text: qsTr("Создать")
                    KeyNavigation.tab: createInterfaceCancelButton
                    KeyNavigation.backtab: interfaceTypeCombo
                    Accessible.name: text
                    Accessible.description: qsTr("Подтвердить создание интерфейса")
                    onClicked: {
                        createInterface(interfaceNameField.text, interfaceTypeCombo.currentText)
                        createInterfaceDialog.close()
                    }
                }
                Button {
                    id: createInterfaceCancelButton
                    text: qsTr("Отмена")
                    KeyNavigation.tab: interfaceNameField
                    KeyNavigation.backtab: createInterfaceConfirmButton
                    Accessible.name: text
                    Accessible.description: qsTr("Закрыть диалог без создания интерфейса")
                    onClicked: createInterfaceDialog.close()
                }
            }
        }
    }
    Dialog {
        id: createProtocolDialog
        title: qsTr("Создать протокол")
        Accessible.name: title
        Accessible.description: qsTr("Диалог создания протокола")

        Column {
            TextField {
                id: protocolNameField
                placeholderText: qsTr("Имя протокола")
                focus: createProtocolDialog.visible
                KeyNavigation.tab: protocolTypeCombo
                Accessible.name: qsTr("Имя протокола")
                Accessible.description: qsTr("Введите имя протокола")
                Layout.preferredHeight: 32
                color: appTheme.textPrimary
                font.pixelSize: 13
                font.weight: Font.Normal

                leftPadding: 8
                rightPadding: 8
                topPadding: 6
                bottomPadding: 6

                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter

                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    // Subtle shadow when focused
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -1
                        color: "transparent"
                        border.color: parent.parent.activeFocus ? Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.13) : "transparent"
                        border.width: 2
                        radius: 5
                        visible: parent.parent.activeFocus
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            ComboBox {
                id: protocolTypeCombo
                model: ["MEK_101", "MEK_104"]
                KeyNavigation.tab: objectModelCombo
                KeyNavigation.backtab: protocolNameField
                Accessible.name: qsTr("Тип протокола")
                Accessible.description: qsTr("Выберите тип протокола")
                height: 32
                font.pixelSize: 13
                width: 120
                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            ComboBox {
                id: objectModelCombo
                KeyNavigation.tab: interfaceCombo
                KeyNavigation.backtab: protocolTypeCombo
                Accessible.name: qsTr("Объектная модель")
                Accessible.description: qsTr("Выберите объектную модель для протокола")
                textRole: "name"
                model: objectModelsConfig
                height: 32
                font.pixelSize: 13
                width: 120
                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            ComboBox {
                id: interfaceCombo
                KeyNavigation.tab: createProtocolConfirmButton
                KeyNavigation.backtab: objectModelCombo
                Accessible.name: qsTr("Интерфейс")
                Accessible.description: qsTr("Выберите интерфейс для протокола")
                textRole: "name"
                model: interfaceModelsConfig
                height: 32
                font.pixelSize: 13
                width: 120
                background: Rectangle {
                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                    border.width: 1
                    radius: 4
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            Row {
                Button {
                    id: createProtocolConfirmButton
                    text: qsTr("Создать")
                    KeyNavigation.tab: createProtocolCancelButton
                    KeyNavigation.backtab: interfaceCombo
                    Accessible.name: text
                    Accessible.description: qsTr("Открыть настройки и создать протокол")
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    font.pixelSize: 14
                    font.weight: Font.Medium

                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(appTheme.success, 1.3) : (parent.hovered ? Qt.darker(appTheme.success, 1.1) : appTheme.success)
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        mekConfigDialog.protocolName = protocolNameField.text
                        mekConfigDialog.protocolType = protocolTypeCombo.currentText
                        mekConfigDialog.objectModel = objectModelCombo.currentValue.id
                        mekConfigDialog.interfacet = interfaceCombo.currentValue.id
                        mekConfigDialog.open()
                        // createProtocolDialog.close()
                    }
                }
                Button {
                    id: createProtocolCancelButton
                    text: qsTr("Отмена")
                    KeyNavigation.tab: protocolNameField
                    KeyNavigation.backtab: createProtocolConfirmButton
                    Accessible.name: text
                    Accessible.description: qsTr("Закрыть диалог без создания протокола")
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    font.pixelSize: 14
                    font.weight: Font.Medium

                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(appTheme.danger, 1.2) : (parent.hovered ? appTheme.danger : Qt.lighter(appTheme.danger, 1.2))
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: createProtocolDialog.close()
                }
            }
        }
    }

    Dialog {
        id: exitConfirmDialog
        title: qsTr("Есть несохранённые изменения")
        standardButtons: Dialog.Yes | Dialog.No | Dialog.Cancel
        modal: true
        Label {
            text: qsTr("Сохранить изменения перед выходом?")
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



    FileHandler {
        id: fileHandler
    }

    function exportToJson() {
        var result = {
            signals: [],
            objectModels: [],
            interfaces: [],
            protocols: [],
            TcIndexes:[],
            TsIndexes:[],
            TmIndexes:[]
        };

        for (var i = 0; i < dataModel.count; i++) {
            var item = dataModel.get(i);
            var exportItem = {};
            var props = Object.keys(item);
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                if (typeof item[prop] !== "function") {
                    exportItem[prop] = item[prop];
                }
            }
            exportItem.index = i;
            result.signals.push(exportItem);
        }

        for (var k = 0; k < objectModelsConfig.count; k++) {
            result.objectModels.push(objectModelsConfig.get(k));
        }

        for (var l = 0; l < interfaceModelsConfig.count; l++) {
            result.interfaces.push(interfaceModelsConfig.get(l));
        }

        for (var m = 0; m < protocolModelsConfig.count; m++) {
            result.protocols.push(protocolModelsConfig.get(m));
        }
        for(var t = 0; t<telecommandModel.count; t++){
            result.TcIndexes.push(telecommandModel.get(t));
        }
        for(var s = 0; s<telesignalModel.count; s++){
            result.TsIndexes.push(telesignalModel.get(s));
        }
        for(var z = 0; z<telemeasureModel.count; z++){
            result.TmIndexes.push(telemeasureModel.get(z));
        }


        return JSON.stringify(result, null, 2);
    }

    function saveToBlde(path) {
        let json = exportToJson()
        fileHandler.saveToFile(path, json)
        hasUnsavedChanges = false
        updateHeaderIndicators()
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
                    header: TableHeaderRow {
                        z: 2
                        width: listView1.width
                        columns: [
                            { title: "IO", width: 50 },
                            { title: "Наименование", width: 350 },
                            { title: "Англ.название", width: 350 },
                            { title: "Индекс ТУ", width: 150 },
                            { title: "S/D", width: 44 },
                            { title: "Логика", width: 100 },
                            { title: "Сохранение", width: 100 },
                            { title: "Триггер", width: 140 }
                        ]
                    }

                    delegate: Rectangle {
                        width: Math.max(listView.width, 1600)
                        id: rowItem
                        height: Math.max(180, nameField.height + 20)
                        color: index % 2 === 0 ? "#ffffff" : "#f8fafc"
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
                        property var itemData: dataModel.get(originalIndex)
                        RowLayout {
                            z: 1
                            anchors.fill: parent
                            spacing: 0

                            Label {
                                text: qsTr("IO")
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 50
                                Layout.maximumWidth: 50
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Наименование")
                                Layout.preferredWidth: 350
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Англ.название")
                                Layout.preferredWidth: 350
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label{
                                text: qsTr("Индекс ТУ")
                                Layout.preferredWidth: 150
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("S/D")
                                Layout.preferredWidth: 44
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Логика")
                                Layout.preferredWidth: 100
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Сохранение")
                                Layout.preferredWidth: 100
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Триггер")
                                Layout.preferredWidth: 140
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Выход")
                                Layout.preferredWidth: 140
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Короткий импульс")
                                Layout.preferredWidth: 160
                                color: "#374151"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                text: qsTr("Длинный импульс")
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
                        property string sector

                        property int originalIndex: digitalOutputsModel.get(index).originalIndex

                        width: listView1.width
                        spacing: 0
                        height: Math.max(180, nameField.height + 20)

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
                            id: nameField
                            text: itemData.name
                            Layout.preferredWidth: 350
                            Layout.minimumHeight: 32
                            Layout.preferredHeight: Math.max(32, contentHeight + topPadding + bottomPadding)

                            color: (itemData.isNameDuplicate || false) ? "#dc2626" : "#1e293b"
                            font.pixelSize: 13
                            font.weight: Font.Normal

                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 6
                            bottomPadding: 6

                            selectByMouse: true
                            verticalAlignment: TextInput.AlignTop
                            wrapMode: TextInput.WordWrap  // Перенос по словам

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

                        ComboBox {
                            id: telecommandIndexBox
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 30
                            model: telecommandModel
                            textRole: "text"  // показываем имя константы из .h
                            currentIndex: {
                                if (!itemData) return 0
                                return model.indexOf(itemData.TYindex || "bool")
                            }
                            onCurrentTextChanged: {
                                if (itemData) {
                                    dataModel.setProperty(originalIndex, "TYindex", currentText)
                                }
                            }
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
                            // удобный аксессор для получения числового enum-значения
                            function currentValue() {
                                if (currentIndex < 0 || currentIndex >= count) return -1;
                                return model.get(currentIndex).value; // size_t из .h
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
                        ComboBox {
                            model: ["Нет", "Да"]
                            currentIndex: model.indexOf(itemData.saving || "Нет")
                            onCurrentTextChanged: dataModel.setProperty(originalIndex, "saving", currentText)
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
                        ComboBox {
                            editable: true
                            model: triggerModel
                            currentIndex: itemData ? triggerModel.indexOf(itemData.sector) : -1
                            onCurrentTextChanged: {
                                if (itemData && dataModel) {
                                    dataModel.setProperty(originalIndex, "sector", currentText)
                                }
                            }
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 32

                            font.pixelSize: 13

                            // Add the search functionality
                            property string searchText: ""

                            onEditTextChanged: {
                                searchText = editText.toLowerCase()

                                // Find first matching item
                                for (let i = 0; i < model.length; i++) {
                                    if (model[i].toString().toLowerCase().startsWith(searchText)) {
                                        highlightedIndex = i
                                        break
                                    }
                                }
                            }

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
                            text: qsTr("VAL_") + codeNameField.text
                            Layout.preferredWidth: 140
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
                            text: qsTr("Удалить")
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
                text: qsTr("Добавить")
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
                        "TYindex": "",
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
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                leftPadding: 15
                rightPadding: 22
                contentWidth: Math.max(listView.width, 1600) // Минимальная ширина для всех колонок
                contentHeight: listView.height
                ListView {
                    id: listView
                    width: parent.width - 30
                    height: parent.height
                    cacheBuffer: 200
                    model: getFilteredModel(pageRoot.paramType, false)
                    spacing: 0
                    interactive: true
                    clip: true
                    headerPositioning: ListView.OverlayHeader
                    header: Rectangle {
                        z: 2
                        width: Math.max(listView.width, 1600)
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

                            Label { text: qsTr("IO")
                                Layout.preferredWidth: 50
                                Layout.minimumWidth: 50
                                Layout.maximumWidth: 50
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: qsTr("Наименование")
                                Layout.preferredWidth: 350
                                Layout.minimumWidth: 300
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: qsTr("Англ.название")
                                Layout.preferredWidth: 250
                                Layout.minimumWidth: 200
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Item{
                                Layout.preferredWidth: 120
                                Layout.minimumWidth: 120
                                Layout.preferredHeight: 32
                                Label{
                                    anchors.fill:parent
                                    text: qsTr("Индекс")
                                    color: "#374151"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы"
                                }
                            }
                            Label { text: qsTr("Тип")
                                Layout.preferredWidth: 100
                                Layout.minimumWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label { text: qsTr("Логика")
                                Layout.preferredWidth: 80
                                Layout.minimumWidth: 80
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }

                            Item{
                                Layout.preferredWidth: 100
                                Layout.minimumWidth: 100
                                Layout.preferredHeight: 32
                                Label {
                                    text: qsTr("Сохран.")
                                    opacity: rootwindow.currentType === "Признаки" || rootwindow.currentType === "Уставка" || paramType === "Уставка"
                                    Layout.preferredWidth: 100
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.fill:parent
                                }
                            }
                            Item{
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32

                                Label {
                                    text: qsTr("Триггер")
                                    opacity: rootwindow.currentType === "Признаки"
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.fill:parent
                                }
                            }
                            Item {
                                Layout.preferredWidth: 150
                                Layout.minimumWidth: 150
                                Layout.preferredHeight: 32
                                Label {
                                    text: qsTr("Параметры")
                                    opacity: rootwindow.currentType === "Аналоговые входы"
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.fill:parent
                                }
                            }
                            Item{
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: 100
                                Layout.minimumWidth: 100
                                Label {
                                    text: qsTr("Знач. по умолч.")
                                    opacity: !(rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы")
                                    anchors.fill:parent
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Item{
                                Layout.preferredWidth: 120
                                Layout.minimumWidth: 120
                                Layout.preferredHeight: 32
                                Label { text: qsTr("Антидребезг")
                                    anchors.fill:parent
                                    opacity: rootwindow.currentType === "Дискретные входы"
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Item{
                                Layout.preferredWidth: 80
                                Layout.minimumWidth: 80
                                Layout.preferredHeight: 32
                                Label { text: qsTr("Значение")
                                    anchors.fill:parent
                                    opacity: rootwindow.currentType === "Уставка"
                                    color: "#1e293b"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Label {
                                text: ""
                                Layout.preferredWidth: 100
                                Layout.minimumWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    delegate: Rectangle {
                        width: Math.max(listView.width, 1600)
                        id: rowItem
                        height: Math.max(180, nameField.height + 20)
                        color: index % 2 === 0 ? "#ffffff" : "#f8fafc"
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
                        property var itemData: dataModel.get(originalIndex)
                        RowLayout {
                            z: 1
                            anchors.fill: parent
                            spacing: 0

                            TextField {
                                text: itemData.ioIndex
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 50
                                Layout.maximumWidth: 50
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
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                id: nameField
                                text: itemData.name
                                Layout.preferredWidth: 350
                                Layout.minimumHeight: 32
                                Layout.preferredHeight: Math.max(32, contentHeight + topPadding + bottomPadding)

                                color: (itemData.isNameDuplicate || false) ? appTheme.danger : appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignTop
                                wrapMode: TextInput.WordWrap  // Перенос по словам

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: (itemData.isNameDuplicate || false) ? appTheme.danger :
                                        (parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border))
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
                                Layout.preferredWidth: 250
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 200
                                color: itemData.isCodeNameDuplicate ? appTheme.danger : appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: (itemData.isCodeNameDuplicate || false) ? appTheme.danger :
                                        (parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border))
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

                            Item{
                                Layout.preferredHeight: 30
                                Layout.minimumWidth: 120
                                Layout.preferredWidth: 120
                                ComboBox {
                                    id: telecommandIndexBox
                                    opacity: rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы"
                                    model: rootwindow.currentType === "Аналоговые входы" ? telemeasureModel : telesignalModel
                                    textRole: "text"
                                    Layout.alignment: Qt.AlignLeft
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    currentIndex: {
                                        if (!itemData) return 0
                                        return model.indexOf(itemData.TYindex || "bool")
                                    }
                                    onCurrentTextChanged: {
                                        if (itemData) {
                                            dataModel.setProperty(originalIndex, "TYindex", currentText)
                                        }
                                    }
                                    background: Rectangle {
                                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                        border.width: 1
                                        radius: 4
                                        antialiasing: true

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    function currentValue() {
                                        if (currentIndex < 0 || currentIndex >= count) return -1;
                                        return model.get(currentIndex).value;
                                    }
                                }
                            }
                            ComboBox {
                                editable: true
                                model: ["bool", "float", "unsigned int", "unsigned short", "unsigned char", "unsigned long long"]
                                currentIndex: model.indexOf(itemData.type || "bool")
                                onCurrentTextChanged: dataModel.setProperty(originalIndex, "type", currentText)
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 100
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 80
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }

                            Item{
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 100
                                ComboBox {
                                    opacity: rootwindow.currentType === "Признаки" || rootwindow.currentType === "Уставка"
                                    model: ["Нет", "Да"]
                                    currentIndex: model.indexOf(itemData.saving || "Нет")
                                    onCurrentTextChanged: dataModel.setProperty(originalIndex, "saving", currentText)
                                    font.pixelSize: 13
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    background: Rectangle {
                                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                        border.width: 1
                                        radius: 4
                                        antialiasing: true

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                            Item{
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 100
                                ComboBox {
                                    opacity: rootwindow.currentType === "Признаки"
                                    editable: true
                                    model: triggerModel
                                    currentIndex: triggerModel.indexOf(itemData.sector)
                                    onCurrentTextChanged: dataModel.setProperty(originalIndex, "sector", currentText)
                                    font.pixelSize: 13
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    background: Rectangle {
                                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                        border.width: 1
                                        radius: 4
                                        antialiasing: true

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                            Item {
                                Layout.preferredWidth: 150
                                Layout.fillHeight: true
                                opacity: rootwindow.currentType === "Аналоговые входы"

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    Repeater {
                                        model: meas_meta.length

                                        RowLayout {
                                            id: rowMeas
                                            spacing: 10
                                            Layout.preferredHeight: 32

                                            property var meta: meas_meta[index]
                                            property int tgt: originalIndex

                                            CheckBox {
                                                id: cb
                                                text: rowMeas.meta.label
                                                Layout.preferredWidth: 140
                                                Layout.preferredHeight: 32

                                                function sync() {
                                                    const src = dataModel.get(rowMeas.tgt)
                                                    checked = !!(src && src[rowMeas.meta.flag])
                                                    val.enabled = checked
                                                    val.opacity = checked ? 1 : 0
                                                    val.text = (src && src[rowMeas.meta.buf]) ? src[rowMeas.meta.buf] : ""
                                                }

                                                Component.onCompleted: sync()

                                                onToggled: {
                                                    if (rowMeas.tgt < 0) return
                                                    dataModel.setProperty(rowMeas.tgt, rowMeas.meta.flag, checked)
                                                    if (checked) {
                                                        var has = findLinkedMeasIndexFor(rowMeas.meta.kind, rowMeas.tgt)
                                                        if (has < 0) createLinkedMeasFor(rowMeas.meta.kind, rowMeas.tgt)
                                                        syncMeasDefValue(rowMeas.meta.kind, rowMeas.tgt)
                                                    } else {
                                                        removeLinkedMeasFor(rowMeas.meta.kind, rowMeas.tgt)
                                                    }
                                                    val.enabled = checked
                                                    val.opacity = checked ? 1 : 0
                                                }

                                                Connections {
                                                    target: dataModel
                                                    function onDataChanged() { cb.sync() }
                                                }
                                            }

                                            Item {
                                                Layout.preferredWidth: 150
                                                Layout.minimumWidth: 150
                                                Layout.maximumWidth: 150
                                                Layout.preferredHeight: 32

                                                TextField {
                                                    id: val
                                                    anchors.fill: parent
                                                    placeholderText: qsTr("def_value")
                                                    enabled: cb.checked
                                                    opacity: cb.checked ? 1 : 0

                                                    onTextChanged: {
                                                        if (rowMeas.tgt < 0) return
                                                        dataModel.setProperty(rowMeas.tgt, rowMeas.meta.buf, text)
                                                        syncMeasDefValue(rowMeas.meta.kind, rowMeas.tgt)
                                                    }

                                                    background: Rectangle {
                                                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                                        border.color: parent.activeFocus ? appTheme.accent
                                                            : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                                        border.width: 1
                                                        radius: 4
                                                        antialiasing: true
                                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Item{
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 100
                                TextField {
                                    opacity: !(rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Дискретные входы")
                                    text: itemData.def_value
                                    color: appTheme.textPrimary
                                    font.pixelSize: 13
                                    font.weight: Font.Normal
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    leftPadding: 8
                                    rightPadding: 8
                                    topPadding: 6
                                    bottomPadding: 6

                                    selectByMouse: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    background: Rectangle {
                                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                        border.width: 1
                                        radius: 4
                                        antialiasing: true

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    onTextChanged: dataModel.setProperty(originalIndex, "def_value", text)
                                }
                            }
                            Item{
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 120
                                TextField {
                                    text: itemData.ad
                                    opacity: rootwindow.currentType === "Дискретные входы"
                                    color: appTheme.textPrimary
                                    font.pixelSize: 13
                                    font.weight: Font.Normal
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    leftPadding: 8
                                    rightPadding: 8
                                    topPadding: 6
                                    bottomPadding: 6

                                    selectByMouse: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    background: Rectangle {
                                        color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                        border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                        border.width: 1
                                        radius: 4
                                        antialiasing: true

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                    onTextChanged: dataModel.setProperty(originalIndex, "ad", text)

                                }
                            }
                            Item {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                RowLayout {
                                    id: cellSetpoint
                                    spacing: 6
                                    opacity: rootwindow.currentType === "Уставка"
                                    anchors.fill: parent
                                    CheckBox {
                                        id: spCheck
                                        text: qsTr("Значение")

                                        enabled: !isSetpointCommand(itemData)

                                        Component.onCompleted: {
                                            var v = !!(itemData && itemData[val_sp.flag]);
                                            spCheck.checked = v;
                                            val.opacity = v;
                                            var buf = (itemData && itemData[val_sp.buf]) ? itemData[val_sp.buf] : "";
                                            if (val.text !== buf) val.text = buf;
                                        }

                                        onToggled: {
                                            if (originalIndex < 0 || isSetpointCommand(itemData)) return;

                                            dataModel.setProperty(originalIndex, val_sp.flag, checked);

                                            if (checked) {
                                                var has = findValSetpointIndex(originalIndex);
                                                if (has < 0) createValSetpoint(originalIndex);
                                                syncValSetpointDefValue(originalIndex);
                                            } else {
                                                removeValSetpoint(originalIndex);
                                            }

                                            val.opacity = checked;
                                        }
                                    }
                                }

                                Connections {
                                    target: dataModel
                                    function onDataChanged() {
                                        if (isSetpointCommand(itemData)) return;

                                        var v = !!(itemData && itemData[val_sp.flag]);
                                        if (spCheck.checked !== v) spCheck.checked = v;

                                        var buf = (itemData && itemData[val_sp.buf]) ? itemData[val_sp.buf] : "";
                                        if (val.text !== buf) val.text = buf;

                                        val.opacity = spCheck.checked;
                                    }
                                }
                            }
                            Button {
                                text: qsTr("Удалить")
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.minimumWidth: 100

                                font.pixelSize: 13
                                font.weight: Font.Medium

                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(appTheme.danger, 1.2) : (parent.hovered ? appTheme.danger : Qt.lighter(appTheme.danger, 1.2))
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
            Button {
                Layout.alignment: Qt.AlignCenter
                text: qsTr("Добавить")
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40

                font.pixelSize: 14
                font.weight: Font.Medium

                background: Rectangle {
                    color: parent.pressed ? Qt.darker(appTheme.success, 1.3) : (parent.hovered ? Qt.darker(appTheme.success, 1.1) : appTheme.success)
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
                        "TYindex": "",
                        "blockName": "",
                        "ioa_address": "",
                        "asdu_address": 1,
                        "second_class_num": "",
                        "type_spont": "",
                        "type_back": "",
                        "type_percyc": "",
                        "type_def": "",
                        "oi_c_sc_na_1": 'false',
                        "oi_c_se_na_1": 'false',
                        "oi_c_se_nb_1": 'false',
                        "oi_c_dc_na_1": 'false',
                        "oi_c_bo_na_1": 'false',
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

        ColumnLayout {
            spacing: 0

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
                    model: getFilteredModel(rootwindow.currentType, false)
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

                            Label {
                                text: qsTr("IO")
                                Layout.preferredWidth: 50
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Наименование")
                                Layout.preferredWidth: 200
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Тип данных")
                                Layout.preferredWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес")
                                Layout.preferredWidth: 100
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Блок")
                                Layout.preferredWidth: 150
                                color: "#1e293b"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Item {
                                Layout.preferredWidth: 160
                            }
                        }
                    }

                    delegate: Rectangle {
                        width: listView.width
                        height: 70
                        color: index % 2 === 0 ? appTheme.surface : appTheme.surfaceVariant
                        required property int index
                        required property var model

                        // Мост к основному dataModel:
                        property int originalIndex: {
                            switch (rootwindow.currentType) {
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

                        property var itemData: (originalIndex >= 0 ? dataModel.get(originalIndex) : ({}))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0
                            z: 1

                            // IO колонка
                            Text {
                                text: itemData.ioIndex || ""
                                Layout.preferredWidth: 50
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            // Наименование
                            Text {
                                text: itemData.name || ""
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    ToolTip.visible: containsMouse && parent.text.length > 0
                                    ToolTip.text: itemData.name || ""
                                }
                            }

                            // Тип данных
                            Text {
                                text: itemData.type || ""
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            // Адрес
                            TextField {
                                id: addressField
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter

                                text: {
                                    if (originalIndex >= 0) {
                                        var addr = itemData.address
                                        return (addr !== undefined && addr !== null) ? String(addr) : ""
                                    }
                                    return ""
                                }

                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter

                                // Only allow numbers
                                validator: IntValidator { bottom: 1; top: 65535 }

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                onTextChanged: {
                                    if (originalIndex >= 0) {
                                        dataModel.setProperty(originalIndex, "address", text)
                                    }
                                }

                                onEditingFinished: {
                                    if (originalIndex < 0) return

                                    if (text === "" || text === null) {
                                        const blk = itemData.blockName || ""
                                        if (blk) {
                                            dataModel.setProperty(originalIndex, "address", "")
                                                Qt.callLater(() => mbAssignOne(blk, originalIndex, 1))
                                        }
                                    }
                                }

                                // Force refresh when model changes
                                Connections {
                                    target: dataModel
                                    function onDataChanged() {
                                        if (originalIndex >= 0) {
                                            var addr = itemData.address
                                            addressField.text = (addr !== undefined && addr !== null) ? String(addr) : ""
                                        }
                                    }
                                }
                            }

                            // Блок
                            ComboBox {
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter
                                model: ["Coil", "Discrete input", "Input register", "Holding register"]
                                font.pixelSize: 13

                                currentIndex: {
                                    const bn = itemData.blockName || "Coil"
                                    const i = model.indexOf(bn)
                                    return (i >= 0 ? i : 0)
                                }

                                onActivated: {
                                    if (originalIndex < 0) return
                                    const newBlock = model[currentIndex]
                                    const oldBlock = itemData.blockName || ""
                                    if (newBlock === oldBlock) return

                                    dataModel.setProperty(originalIndex, "blockName", newBlock)
                                    dataModel.setProperty(originalIndex, "address", "")
                                        Qt.callLater(() => onModbusBlockChanged(originalIndex, newBlock, oldBlock))
                                }

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }

                            // Пустая колонка в конце
                            Item {
                                Layout.preferredWidth: 160
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mekPageComponent
        ColumnLayout {
            Component.onCompleted: assignIOA()
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: appTheme.surfaceVariant
                border.color: appTheme.border
                border.width: 1
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Column {
                        Layout.fillWidth: true

                        Text {
                            text: qsTr("Объектная модель: ") + getCurrentObjectModelName()
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: appTheme.textPrimary
                        }

                        Text {
                            text: qsTr("Выбрано сигналов: ") + getCurrentObjectModelSignalCount()
                            font.pixelSize: 12
                            color: "#64748b"
                        }
                    }

                    Button {
                        text: qsTr("Выбрать модель")
                        onClicked: objectModelSelectorDialog.open()
                    }

                    Button {
                        text: qsTr("Выбрать все")
                        enabled: currentObjectModelId !== ""
                        onClicked: selectAllSignalsForCurrentModel()
                    }

                    Button {
                        text: qsTr("Очистить выбор")
                        enabled: currentObjectModelId !== ""
                        onClicked: clearAllSignalsForCurrentModel()
                    }
                }
            }

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
                    model: getFilteredModel(rootwindow.currentType, true)
                    spacing: 0
                    interactive: true
                    clip: true
                    headerPositioning: ListView.OverlayHeader

                    header: Rectangle {
                        z: 3
                        width: listView.width
                        height: 32
                        color: Qt.lighter(appTheme.surfaceVariant, 1.06)
                        antialiasing: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Qt.lighter(appTheme.border, 1.1)
                        }

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: appTheme.border
                        }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                            GradientStop { position: 1.0; color: appTheme.border }
                        }

                        layer.enabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0
                            Label {
                                text: qsTr("✓")
                                Layout.preferredWidth: 30
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Label {
                                text: qsTr("Наименование")
                                Layout.preferredWidth: 200
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: rootwindow.currentType === "Аналоговые входы" ? "Параметры": (rootwindow.currentType === "Уставка" ? "Тип" : "")
                                visible: (rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка")
                                Layout.preferredWidth: (rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка") ? 100 : 0
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Тип данных")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес ОИ")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес АСДУ")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Номер буфера")
                                Layout.preferredWidth: 130
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Тип при спорадике")
                                Layout.preferredWidth: 130
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Тип при фоновом")
                                Layout.preferredWidth: 130
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Тип при пер/цик")
                                Layout.preferredWidth: 130
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Тип при общем")
                                Layout.preferredWidth: 130
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: ""
                                Layout.preferredWidth: 100
                            }
                        }
                    }

                    delegate: Rectangle {
                        width: listView.width
                        id: rowItem
                        height: 180
                        color: index % 2 === 0 ? appTheme.surface : appTheme.surfaceVariant
                        required property int index
                        required property var model

                        property int originalIndex: {
                            switch (rootwindow.currentType) {
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
                                    return meksettingsModel.get(index).originalIndex
                                default:
                                    return -1
                            }
                        }

                        property var itemData: (originalIndex >= 0 ? dataModel.get(originalIndex) : ({}))

                        // Проверка, является ли это командой уставки
                        property bool isVal: isSetpointCommand(itemData)

                        // Подсветка для выбранных сигналов
                        Rectangle {
                            anchors.fill: parent
                            color: isSignalInCurrentObjectModel(index) ? "#e0f2fe" : "transparent"
                            border.color: isSignalInCurrentObjectModel(index) ? "#0ea5e9" : "transparent"
                            border.width: isSignalInCurrentObjectModel(index) ? 1 : 0
                            radius: 4
                            opacity: 0.5
                            z: 0
                        }

                        // ИСПРАВЛЕНИЕ: Обернули все элементы в один RowLayout
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0
                            z: 1

                            // Чекбокс
                            CheckBox {
                                Layout.preferredWidth: 30
                                Layout.alignment: Qt.AlignVCenter
                                checked: isSignalInCurrentObjectModel(index)
                                enabled: currentObjectModelId !== "" && !isVal // Запретить выбор команд

                                onClicked: {
                                    if (checked) {
                                        addSignalToCurrentObjectModel(index)
                                    } else {
                                        removeSignalFromCurrentObjectModel(index)
                                    }
                                }
                            }

                            // Название
                            Text {
                                id: leftName
                                text: itemData.name
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignVCenter
                                color: isVal ? "#6b7280" : appTheme.textPrimary // Серый цвет для команд
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            // Параметры
                            ColumnLayout {
                                Layout.preferredWidth: (rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка") ? 100 : 0
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3
                                visible: (rootwindow.currentType === "Аналоговые входы" || rootwindow.currentType === "Уставка")
                                Repeater {
                                    model: rootwindow.currentType === "Аналоговые входы"
                                        ? ["Значение","Апертура","КТТ","Upper","Lower"]
                                        : rootwindow.currentType === "Уставка"
                                            ? (itemData.val_setpoint_enabled && !isVal
                                                ? ["Команда", "Значение"]
                                                : ["Команда"])
                                            : ""
                                    delegate: Text {
                                        text: modelData
                                        color: isVal ? "#6b7280" : "#475569"
                                        font.pixelSize: 12
                                        font.bold: true
                                        Layout.preferredWidth: 100
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            // Тип данных
                            ColumnLayout {
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: Text {
                                        text: __getByRole(modelData, "type")
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        color: isVal ? "#6b7280" : appTheme.textPrimary
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }
                                }
                            }

                            // === КОЛОНКА: Адрес ОИ ("ioa_address") ===
                            ColumnLayout {
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: TextField {
                                        // Для первого элемента (основного значения) показываем его собственный IOA адрес
                                        text: {
                                            if (index === 0) {
                                                // Основной элемент - показываем его собственный ioa_address
                                                return itemData.ioa_address || ""
                                            } else {
                                                // Дополнительные элементы (апертура, КТТ и т.д.)
                                                return __getByRole(modelData, "ioa_address") || ""
                                            }
                                        }
                                        onEditingFinished: {
                                            if (!isVal) {
                                                if (index === 0) {
                                                    // Записываем в основной элемент
                                                    dataModel.setProperty(originalIndex, "ioa_address", text)
                                                } else {
                                                    // Записываем в связанный элемент
                                                    __setByRole(modelData, "ioa_address", text)
                                                }
                                            }
                                        }
                                        selectByMouse: true
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 32
                                        color: isVal ? "#6b7280" : appTheme.textPrimary
                                        font.pixelSize: 13
                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // === КОЛОНКА: Адрес АСДУ ("asdu_address") ===
                            ColumnLayout {
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: TextField {
                                        text: __getByRole(modelData, "asdu_address") || ""
                                        onEditingFinished: {
                                            if (!isVal) {
                                                __setByRole(modelData, "asdu_address", text)
                                            }
                                        }
                                        selectByMouse: true
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 32
                                        color: isVal ? "#6b7280" : appTheme.textPrimary
                                        font.pixelSize: 13
                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // === КОЛОНКА: Номер буфера ("second_class_num") ===
                            ColumnLayout {
                                Layout.preferredWidth: 130
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: ComboBox {
                                        property var choices: [
                                            "NOT_USE","DEFAULT", "1", "2", "3", "4", "5", "6", "7", "8"
                                        ]
                                        model: choices
                                        Layout.preferredWidth: 130
                                        Layout.preferredHeight: 32
                                        font.pixelSize: 13
                                        property bool _init: false

                                        Component.onCompleted: {
                                            const wanted = __getByRole(itemData.codeName, "second_class_num") || "DEFAULT"
                                            const idx = choices.indexOf(wanted)
                                            currentIndex = idx >= 0 ? idx : choices.indexOf("DEFAULT")
                                            _init = true
                                        }

                                        onCurrentIndexChanged: {
                                            if (_init && currentIndex >= 0 && !isVal) {
                                                __setByRole(modelData, "second_class_num", choices[currentIndex])
                                            }
                                        }

                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // === КОЛОНКА: Спорадика ("type_spont") ===
                            ColumnLayout {
                                Layout.preferredWidth: 130
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: ComboBox {
                                        property var choices: [
                                            "NOT_USE", "DEFAULT", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1",
                                            "M_BO_NA_1", "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1",
                                            "M_ME_TB_1", "M_ME_NC_1", "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1",
                                            "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"
                                        ]
                                        model: choices
                                        editable: !(rootwindow.currentType === "Уставка" && index === 0)
                                        enabled:  !(rootwindow.currentType === "Уставка" && index === 0)
                                        Layout.preferredWidth: 130
                                        Layout.preferredHeight: 32
                                        font.pixelSize: 13
                                        property bool _init: false

                                        function initCombo() {
                                            if (_init) return
                                            if (!itemData || !itemData.codeName) return

                                            const wanted = __getByRole(itemData.codeName, "type_spont") || "NOT_USE"
                                            const idx = item.link_kind !== "val_setpoint"  ? setTypeCombo(choices,"type_spont", itemData ) : choices.indexOf(wanted)

                                            console.log("INIT type_spont for", idx)

                                            currentIndex = idx >= 0 ? idx : choices.indexOf("NOT_USE")
                                            _init = true

                                        }

                                        Component.onCompleted: Qt.callLater(initCombo)

                                        onModelChanged: Qt.callLater(initCombo)
                                        onCountChanged: Qt.callLater(initCombo)

                                        Connections {
                                            target: itemData
                                            onCodeNameChanged: Qt.callLater(initCombo)
                                        }

                                        onCurrentIndexChanged: {
                                            if (_init && !isVal) {
                                                __setByRole(modelData, "type_spont", choices[currentIndex])
                                            }
                                        }

                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // === КОЛОНКА: Фоновый ("type_back") ===
                            ColumnLayout {
                                Layout.preferredWidth: 130
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: ComboBox {
                                        property var choices: [
                                            "NOT_USE", "DEFAULT", "M_SP_NA_1", "M_DP_NA_1", "M_BO_NA_1", "M_ME_NA_1",
                                            "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"
                                        ]
                                        model: choices
                                        editable: !(rootwindow.currentType === "Уставка" && index === 0)
                                        enabled:  !(rootwindow.currentType === "Уставка" && index === 0)
                                        Layout.preferredWidth: 130
                                        Layout.preferredHeight: 32
                                        font.pixelSize: 13
                                        property bool _init: false


                                        function initCombo() {
                                            if (_init) return
                                            if (!itemData || !itemData.codeName) return

                                            const wanted = __getByRole(itemData.codeName, "type_back") || "NOT_USE"
                                            const idx = item.link_kind !== "val_setpoint"  ? setTypeCombo(choices,"type_back", itemData ) : choices.indexOf(wanted)

                                            console.log("INIT type_back for", itemData.codeName, "=", wanted)

                                            currentIndex = idx >= 0 ? idx : choices.indexOf("NOT_USE")
                                            _init = true
                                        }

                                        Component.onCompleted: Qt.callLater(initCombo)

                                        onModelChanged: Qt.callLater(initCombo)
                                        onCountChanged: Qt.callLater(initCombo)

                                        Connections {
                                            target: itemData   // <-- ВАЖНО! НЕ dataModel!
                                            onCodeNameChanged: Qt.callLater(initCombo)
                                        }

                                        onCurrentIndexChanged: {
                                            if (_init && !isVal) {
                                                __setByRole(modelData, "type_back", choices[currentIndex])
                                            }
                                        }

                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // === КОЛОНКА: Пер/цик ("type_percyc") ===
                            ColumnLayout {
                                Layout.preferredWidth: 130
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: ComboBox {
                                        property var choices: [
                                            "NOT_USE", "DEFAULT", "M_ME_NA_1", "M_ME_NB_1", "M_ME_NC_1", "M_ME_ND_1"
                                        ]
                                        model: choices
                                        editable: !(rootwindow.currentType === "Уставка" && index === 0)
                                        enabled:  !(rootwindow.currentType === "Уставка" && index === 0)
                                        Layout.preferredWidth: 130
                                        Layout.preferredHeight: 32
                                        font.pixelSize: 13
                                        property bool _init: false

                                        function initCombo() {
                                            if (_init) return
                                            if (!itemData || !itemData.codeName) return

                                            const wanted = __getByRole(itemData.codeName, "type_percyc") || "NOT_USE"
                                            const idx = item.link_kind !== "val_setpoint"  ? setTypeCombo(choices,"type_percyc", itemData ) : choices.indexOf(wanted)

                                            console.log("INIT type_percyc for", itemData.codeName, "=", wanted)

                                            currentIndex = idx >= 0 ? idx : choices.indexOf("NOT_USE")
                                            _init = true
                                        }

                                        Component.onCompleted: Qt.callLater(initCombo)

                                        onModelChanged: Qt.callLater(initCombo)
                                        onCountChanged: Qt.callLater(initCombo)

                                        Connections {
                                            target: itemData   
                                            onCodeNameChanged: Qt.callLater(initCombo)
                                        }

                                        onCurrentIndexChanged: {
                                            if (_init && !isVal) {
                                                __setByRole(modelData, "type_percyc", choices[currentIndex])
                                            }
                                        }

                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // === КОЛОНКА: Общий ("type_def") ===
                            ColumnLayout {
                                Layout.preferredWidth: 130
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4
                                Repeater {
                                    model: __codesForRow(itemData)
                                    delegate: ComboBox {
                                        property var choices: [
                                            "NOT_USE", "DEFAULT", "M_SP_NA_1", "M_SP_TA1", "M_DP_NA_1", "M_DP_TA_1",
                                            "M_BO_NA_1", "M_BO_TA_1", "M_ME_NA_1", "M_ME_TA_1", "M_ME_NB1",
                                            "M_ME_TB_1", "M_ME_NC_1", "M_ME_TC_1", "M_ME_ND_1", "M_SP_TB_1",
                                            "M_DP_TB_1", "M_BO_TB_1", "M_ME_TD_1", "M_ME_TF_1"
                                        ]
                                        model: choices
                                        editable: !(rootwindow.currentType === "Уставка" && index === 0)
                                        enabled:  !(rootwindow.currentType === "Уставка" && index === 0)
                                        Layout.preferredWidth: 130
                                        Layout.preferredHeight: 32
                                        font.pixelSize: 13
                                        property bool _init: false

                                        function initCombo() {
                                            if (_init) return
                                            if (!itemData || !itemData.codeName) return

                                            const wanted = __getByRole(itemData.codeName, "type_def") || "NOT_USE"
                                            const idx = item.link_kind !== "val_setpoint"  ? setTypeCombo(choices,"type_def", itemData ) : choices.indexOf(wanted)

                                            currentIndex = idx >= 0 ? idx : choices.indexOf("NOT_USE")
                                            _init = true
                                        }

                                        Component.onCompleted: Qt.callLater(initCombo)

                                        onModelChanged: Qt.callLater(initCombo)
                                        onCountChanged: Qt.callLater(initCombo)

                                        Connections {
                                            target: itemData
                                            onCodeNameChanged: Qt.callLater(initCombo)
                                        }

                                        onCurrentIndexChanged: {
                                            if (_init && !isVal) {
                                                __setByRole(modelData, "type_def", choices[currentIndex])
                                            }
                                        }

                                        background: Rectangle {
                                            color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                            border.color: parent.activeFocus ? appTheme.accent
                                                : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                            border.width: 1
                                            radius: 4
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                }
                            }

                            // Пустая колонка в конце
                            Item {
                                Layout.preferredWidth: 100
                            }
                        }
                    }
                }
            }
        }
    }
    Dialog {
        id: objectModelSelectorDialog
        title: qsTr("Выбор объектной модели")
        width: 400
        height: 300

        Column {
            anchors.fill: parent
            spacing: 10

            Text {
                text: qsTr("Выберите объектную модель для работы:")
                font.pixelSize: 14
            }

            ListView {
                width: parent.width
                height: 200
                model: objectModelsConfig

                delegate: Rectangle {
                    width: parent.width
                    height: 40
                    color: mouse.containsMouse ? Qt.lighter(appTheme.surfaceVariant, 1.06) : "transparent"
                    border.color: currentObjectModelId === model.id ? "#0ea5e9" : "transparent"
                    border.width: 2
                    radius: 4

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            currentObjectModelId = model.id
                            objectModelSelectorDialog.close()
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: model.type === "MEK" ? Qt.darker(appTheme.success, 1.1) : appTheme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            Text {
                                text: model.name
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: model.type + " (" + (model.signalIds ? model.signalIds.length : 0) + " сигналов)"
                                font.pixelSize: 11
                                color: "#64748b"
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                Button {
                    text: qsTr("Создать новую модель")
                    onClicked: {
                        objectModelSelectorDialog.close()
                        createObjectModelDialog.open()
                    }
                }

                Button {
                    text: qsTr("Отмена")
                    onClicked: objectModelSelectorDialog.close()
                }
            }
        }
    }
    Component {
        id: mek101PageComponent
        ColumnLayout {
            id: pageRoot1
            spacing: 0

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
                    model: getFilteredModel(rootwindow.currentType, false)
                    spacing: 0
                    interactive: true
                    clip: true
                    headerPositioning: ListView.OverlayHeader

                    header: Rectangle {
                        z: 2
                        width: listView.width
                        height: 32
                        color: Qt.lighter(appTheme.surfaceVariant, 1.06)
                        antialiasing: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Qt.lighter(appTheme.border, 1.1)
                        }

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: appTheme.border
                        }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                            GradientStop { position: 1.0; color: appTheme.border }
                        }

                        layer.enabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0

                            Label {
                                text: qsTr("IO")
                                Layout.preferredWidth: 50
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Наименование")
                                Layout.preferredWidth: 200
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес ОИ")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес АСДУ")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Исп. в спорадике")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Исп. в цикл/период")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Исп. в фон. сканир")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Разрешить адрес")
                                Layout.preferredWidth: 150
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Группа опроса")
                                Layout.preferredWidth: 150
                                color: appTheme.textPrimary
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

                    delegate: Rectangle {
                        width: listView.width
                        height: 70
                        color: index % 2 === 0 ? appTheme.surface : appTheme.surfaceVariant
                        required property int index
                        required property var model

                        property int originalIndex: {
                            switch (rootwindow.currentType) {
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

                        property var itemData: (originalIndex >= 0 ? dataModel.get(originalIndex) : ({}))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0
                            z: 1

                            // IO колонка
                            Text {
                                text: itemData.ioIndex
                                Layout.preferredWidth: 50
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Наименование колонка
                            Text {
                                text: itemData.name
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    ToolTip.visible: containsMouse && parent.text.length > 0
                                    ToolTip.text: itemData.name || ""
                                }
                            }

                            // Адрес ОИ
                            TextField {
                                text: itemData.ioa_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                onTextChanged: dataModel.setProperty(originalIndex, "ioa_address", text)
                            }

                            // Адрес АСДУ
                            TextField {
                                text: itemData.asdu_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                onTextChanged: dataModel.setProperty(originalIndex, "asdu_address", text)
                            }

                            // Исп. в спорадике
                            Switch {
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                checked: itemData.use_in_spont_101 || false

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "use_in_spont_101", checked)
                            }

                            // Исп. в цикл/период
                            Switch {
                                checked: itemData.use_in_back_101 || false
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "use_in_back_101", checked)
                            }

                            // Исп. в фон. сканир
                            Switch {
                                checked: itemData.use_in_percyc_101 || false
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "use_in_percyc_101", checked)
                            }

                            // Разрешить адрес
                            Switch {
                                checked: itemData.allow_address_101 || false
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 150
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "allow_address_101", checked)
                            }

                            // Группа опроса
                            ComboBox {
                                id: surveyGroupCombo101
                                model: ["GENERAL SURVEY", "GROUP 1", "GROUP 2", "GROUP 3", "GROUP 4",
                                    "GROUP 5", "GROUP 6", "GROUP 7", "GROUP 8"]
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                property string _currentValue: itemData.survey_group_101 || ""
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
                                    if (_initialized && currentIndex >= 0) {
                                        dataModel.setProperty(originalIndex, "survey_group_101", model[currentIndex]);
                                    }
                                }
                            }

                            // Пустая колонка в конце
                            Item {
                                Layout.preferredWidth: 120
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: mek104PageComponent
        ColumnLayout {
            id: pageRoot
            spacing: 0

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
                    model: getFilteredModel(rootwindow.currentType, false)
                    spacing: 0
                    interactive: true
                    clip: true
                    headerPositioning: ListView.OverlayHeader

                    header: Rectangle {
                        z: 2
                        width: listView.width
                        height: 32
                        color: Qt.lighter(appTheme.surfaceVariant, 1.06)
                        antialiasing: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Qt.lighter(appTheme.border, 1.1)
                        }

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: appTheme.border
                        }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                            GradientStop { position: 1.0; color: appTheme.border }
                        }

                        layer.enabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0

                            Label {
                                text: qsTr("IO")
                                Layout.preferredWidth: 50
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Наименование")
                                Layout.preferredWidth: 200
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес ОИ")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Адрес АСДУ")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Исп. в спорадике")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Исп. в цикл/период")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Исп. в фон. сканир")
                                Layout.preferredWidth: 100
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Разрешить адрес")
                                Layout.preferredWidth: 150
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                            Label {
                                text: qsTr("Группа опроса")
                                Layout.preferredWidth: 150
                                color: appTheme.textPrimary
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

                    delegate: Rectangle {
                        width: listView.width
                        height: 70
                        color: index % 2 === 0 ? appTheme.surface : appTheme.surfaceVariant
                        required property int index
                        required property var model

                        property int originalIndex: {
                            switch (rootwindow.currentType) {
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

                        property var itemData: (originalIndex >= 0 ? dataModel.get(originalIndex) : ({}))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0
                            z: 1

                            // IO колонка
                            Text {
                                text: itemData.ioIndex
                                Layout.preferredWidth: 50
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Наименование колонка
                            Text {
                                text: itemData.name
                                Layout.preferredWidth: 200
                                Layout.alignment: Qt.AlignVCenter
                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    ToolTip.visible: containsMouse && parent.text.length > 0
                                    ToolTip.text: itemData.name || ""
                                }
                            }

                            // Адрес ОИ
                            TextField {
                                text: itemData.ioa_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                onTextChanged: dataModel.setProperty(originalIndex, "ioa_address", text)
                            }

                            // Адрес АСДУ
                            TextField {
                                text: itemData.asdu_address || ""
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                color: appTheme.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Normal

                                leftPadding: 8
                                rightPadding: 8
                                topPadding: 6
                                bottomPadding: 6

                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                onTextChanged: dataModel.setProperty(originalIndex, "asdu_address", text)
                            }

                            // Исп. в спорадике
                            Switch {
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                checked: itemData.use_in_spont_104 || false

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "use_in_spont_104", checked)
                            }

                            // Исп. в цикл/период
                            Switch {
                                checked: itemData.use_in_back_104 || false
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "use_in_back_104", checked)
                            }

                            // Исп. в фон. сканир
                            Switch {
                                checked: itemData.use_in_percyc_104 || false
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 100
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "use_in_percyc_104", checked)
                            }

                            // Разрешить адрес
                            Switch {
                                checked: itemData.allow_address_104 || false
                                implicitWidth: 44
                                implicitHeight: 24
                                Layout.preferredWidth: 150
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                                indicator: Rectangle {
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 24
                                    radius: 12

                                    color: parent.checked ? appTheme.accent : appTheme.surfaceVariant
                                    border.color: parent.checked ? appTheme.accent :
                                        (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
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
                                        border.color: parent.parent.checked ? "#ffffff" : Qt.lighter(appTheme.border, 1.25)
                                        border.width: 1

                                        Behavior on x {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                onCheckedChanged: dataModel.setProperty(originalIndex, "allow_address_104", checked)
                            }

                            // Группа опроса
                            ComboBox {
                                id: surveyGroupCombo104
                                model: ["GENERAL SURVEY", "GROUP 1", "GROUP 2", "GROUP 3", "GROUP 4",
                                    "GROUP 5", "GROUP 6", "GROUP 7", "GROUP 8"]
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: 13

                                background: Rectangle {
                                    color: enabled ? appTheme.surface : appTheme.surfaceVariant
                                    border.color: parent.activeFocus ? appTheme.accent : (parent.hovered ? Qt.lighter(appTheme.border, 1.25) : appTheme.border)
                                    border.width: 1
                                    radius: 4
                                    antialiasing: true

                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                property string _currentValue: itemData.survey_group_104 || ""
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
                                    if (_initialized && currentIndex >= 0) {
                                        dataModel.setProperty(originalIndex, "survey_group_104", model[currentIndex]);
                                    }
                                }
                            }

                            // Пустая колонка в конце
                            Item {
                                Layout.preferredWidth: 120
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
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: "#f8fafc"
            border.color: "#e2e8f0"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 18

                Label { text: "Модель: " + currentModelName; font.bold: true; color: "#1e293b" }
                Label { text: hasUnsavedChanges ? "● Несохраненные изменения" : "✓ Сохранено"; color: hasUnsavedChanges ? "#dc2626" : "#059669" }
                Label { text: "Сигналов в разделе: " + selectedSignalCount; color: "#334155" }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Дополнительно"
                    onClicked: advancedDrawer.open()
                }
            }
        }

        TabBar {
            id: workflowTabs
            Layout.fillWidth: true
            currentIndex: workflowStep
            onCurrentIndexChanged: workflowStep = currentIndex
            TabButton { text: "1. Проект/модель" }
            TabButton { text: "2. Сигналы" }
            TabButton { text: "3. Протоколы" }
            TabButton { text: "4. Валидация" }
            TabButton { text: "5. Экспорт" }
        }

        Rectangle {
            visible: workflowStep === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                Label { text: "Шаг 1: выберите проект и объектную модель"; font.pixelSize: 20; font.bold: true }
                RowLayout {
                    Button { text: "Импорт проекта"; onClicked: fileDialog.open() }
                    Button { text: "Управление моделями"; onClicked: objectModelsManagerDialog.open() }
                    Button { text: "Управление протоколами"; onClicked: protocolManagerDialog.open() }
                }
            }
        }

        TabBar {
            id: protocolTabs
            visible: workflowStep >= 2

            Layout.fillWidth: true
            currentIndex: 0
            property int tabWidth: 180

            // Add background styling to match header
            background: Rectangle {
                color: Qt.lighter(appTheme.surfaceVariant, 1.06)
                antialiasing: true

                // Top separator line
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: appTheme.border
                }

                // Bottom separator line
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.lighter(appTheme.border, 1.1)
                }

                // Gradient background
                gradient: Gradient {
                    GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                    GradientStop { position: 1.0; color: appTheme.border }
                }
            }
            TabButton{text: qsTr("Общее")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка общих параметров")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            TabButton{text: qsTr("Modbus")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка настроек Modbus")
                visible: modbus
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
                width: visible ? tabBar.tabWidth : 0
            }
            TabButton{text: qsTr("MEK")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка настроек MEK")
                visible: mek
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
                width: visible ? tabBar.tabWidth : 0

            }
            TabButton{text: qsTr("MEK101")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка настроек MEK101")
                visible: mek_101
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
                width: visible ? tabBar.tabWidth : 0
            }
            TabButton{text: qsTr("MEK104")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка настроек MEK104")
                visible: mek_104
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
        }
        TabBar {
            id: tabBar
            visible: workflowStep === 1 || workflowStep === 2
            Layout.fillWidth: true
            Layout.preferredHeight: tabBar.implicitHeight
            Layout.maximumHeight: tabBar.implicitHeight
            clip: true

            // Add background styling to match header
            background: Rectangle {
                color: Qt.lighter(appTheme.surfaceVariant, 1.06)
                antialiasing: true

                // Top separator line
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: appTheme.border
                }

                // Bottom separator line
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.lighter(appTheme.border, 1.1)
                }

                // Gradient background
                gradient: Gradient {
                    GradientStop { position: 0.0; color: appTheme.surfaceVariant }
                    GradientStop { position: 1.0; color: appTheme.border }
                }
            }

            TabButton {
                text: qsTr("Аналоговые входы")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка аналоговых входов")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            TabButton {
                text: qsTr("Дискретные входы")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка дискретных входов")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            TabButton {
                text: qsTr("Аналоговый выход")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка аналоговых выходов")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            TabButton {
                text: qsTr("Дискретный выход")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка дискретных выходов")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            TabButton {
                text: qsTr("Признаки")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка признаков")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            TabButton {
                text: qsTr("Команда уставки")
                Accessible.name: text
                Accessible.description: qsTr("Вкладка команд уставок")
                background: Rectangle {
                    color: parent.checked ? appTheme.border : "transparent"
                    border.color: parent.checked ? Qt.lighter(appTheme.border, 1.1) : "transparent"
                    border.width: parent.checked ? 1 : 0
                }
            }
            function activateTab(tabName) {
                for (var i = 0; i < count; i++) {
                    if (itemAt(i).text === tabName && itemAt(i).visible) {
                        currentIndex = i;
                        return true;
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
                                case 0: rootwindow.currentType = "Аналоговые входы"; break;
                                case 1: rootwindow.currentType = "Дискретные входы"; break;
                                case 2: rootwindow.currentType = "Аналоговый выход"; break;
                                case 3: rootwindow.currentType = "Дискретный выход"; break;
                                case 4: rootwindow.currentType = "Признаки"; break;
                                case 5: rootwindow.currentType = "Уставка"; break;
                                default: rootwindow.currentType = "";
                            }
                            console.log(rootwindow.currentType);
                        }
                    }
                }
            }
        }

        StackLayout {
            id: swipeView
            visible: workflowStep === 1 || workflowStep === 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 280
            currentIndex: tabBar.currentIndex

            Loader {
                id: loader1
                active: tabBar.currentIndex === 0
                sourceComponent: {
                    switch(currentProtocol) {
                        case "Общее": return parameterPageComponent
                        case "Modbus": return modbusPageComponent
                        case "MEK": return mekPageComponent
                        case "MEK101": return mek101PageComponent
                        case "MEK104": return mek104PageComponent
                    }
                }
                asynchronous: true
                onLoaded: {
                    item.paramType = "Аналоговые входы"
                    item.listView = listView
                    item.addClicked.connect(() => { rootwindow.currentType = "Аналоговые входы" })
                }
            }
            Loader {
                id: loader2
                active: tabBar.currentIndex === 1
                sourceComponent: {
                    switch(currentProtocol) {
                        case "Общее": return parameterPageComponent
                        case "Modbus": return modbusPageComponent
                        case "MEK": return mekPageComponent
                        case "MEK101": return mek101PageComponent
                        case "MEK104": return mek104PageComponent
                    }
                }
                asynchronous: true
                onLoaded: {
                    item.paramType = "Дискретные входы"
                    item.listView = listView
                    item.addClicked.connect(() => { rootwindow.currentType = "Дискретные входы" })
                }
            }
            Loader {
                id: loader3
                active: tabBar.currentIndex === 2
                sourceComponent: {
                    switch(currentProtocol) {
                        case "Общее": return parameterPageComponent
                        case "Modbus": return modbusPageComponent
                        case "MEK": return mekPageComponent
                        case "MEK101": return mek101PageComponent
                        case "MEK104": return mek104PageComponent
                    }
                }
                asynchronous: true
                onLoaded: {
                    item.paramType = "Аналоговый выход"
                    item.listView = listView
                    item.addClicked.connect(() => { rootwindow.currentType = "Аналоговый выход" })
                }
            }
            Loader {
                id: loader4
                active: tabBar.currentIndex === 3
                sourceComponent: {
                    switch(currentProtocol) {
                        case "Общее": return parameterPageComponent1
                        case "Modbus": return modbusPageComponent
                        case "MEK": return mekPageComponent
                        case "MEK101": return mek101PageComponent
                        case "MEK104": return mek104PageComponent
                    }
                }
                asynchronous: true
                onLoaded: {
                    item.paramType = "Дискретный выход"
                    item.listView = listView1
                    item.addClicked.connect(() => { rootwindow.currentType = "Дискретный выход" })
                }
            }
            Loader {
                id: loader5
                active: tabBar.currentIndex === 4
                sourceComponent: {
                    switch(currentProtocol) {
                        case "Общее": return parameterPageComponent
                        case "Modbus": return modbusPageComponent
                        case "MEK": return mekPageComponent
                        case "MEK101": return mek101PageComponent
                        case "MEK104": return mek104PageComponent
                    }
                }
                asynchronous: true
                onLoaded: {
                    item.paramType = "Признаки"
                    item.listView = listView
                    item.addClicked.connect(() => { rootwindow.currentType = "Признаки" })
                }
            }
            Loader {
                id: loader6
                active: tabBar.currentIndex === 5
                sourceComponent: {
                    switch(currentProtocol) {
                        case "Общее": return parameterPageComponent
                        case "Modbus": return modbusPageComponent
                        case "MEK": return mekPageComponent
                        case "MEK101": return mek101PageComponent
                        case "MEK104": return mek104PageComponent
                    }
                }
                asynchronous: true
                onLoaded: {
                    item.paramType = "Уставка"
                    item.listView = listView
                    item.addClicked.connect(() => { rootwindow.currentType = "Уставка" })
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

        Rectangle {
            visible: workflowStep === 3
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                Label { text: "Шаг 4: валидация"; font.pixelSize: 20; font.bold: true }
                Label { text: hasUnsavedChanges ? "Есть несохраненные изменения" : "Изменения сохранены" }
                Label { text: "Проверьте заполнение сигналов и соответствия протоколам перед экспортом." }
            }
        }

        Rectangle {
            visible: workflowStep === 4
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                Label { text: "Шаг 5: экспорт/генерация"; font.pixelSize: 20; font.bold: true }
                RowLayout {
                    Button { text: "Экспорт JSON"; onClicked: saveFileDialog.open() }
                    Button { text: "Генерация кода"; onClicked: { jsonSelectDialog.exportType = "code"; jsonSelectDialog.open() } }
                    Button { text: "Генерация Excel"; onClicked: { jsonSelectDialog.exportType = "exel"; jsonSelectDialog.open() } }
                }
            }
        }
     }

    Drawer {
        id: advancedDrawer
        edge: Qt.RightEdge
        width: Math.min(rootwindow.width * 0.32, 420)
        height: rootwindow.height

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            Label { text: "Расширенные и отладочные операции"; font.bold: true; font.pixelSize: 16 }
            Button {
                text: modbus ? "Удалить Modbus" : "Добавить Modbus"
                onClicked: {
                    modbus = !modbus;
                    if (modbus) tabBar.updateFocus();
                }
            }
            Button {
                text: mek ? "Удалить MEK" : "Добавить MEK"
                Layout.preferredWidth: rootwindow.isWideDesktop ? 150 : 130
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
            Button { enabled: mek; visible: mek; text: mek_101 ? "Удалить MEK_101" : "Добавить MEK_101"; onClicked: mek_101 = !mek_101 }
            Button { enabled: mek; visible: mek; text: mek_104 ? "Удалить MEK_104" : "Добавить MEK_104"; onClicked: mek_104 = !mek_104 }
            Button { text: "Настроить ETH"; onClicked: ethConfigDialog.open() }
            Button { text: "Настроить RS"; onClicked: rsConfigDialog.open() }
            Button {
                text: "Export to JSON"
                visible: rootwindow.isWideDesktop && !rootwindow.isCompactMode
                Layout.preferredWidth: 145
                onClicked: saveFileDialog.open()
            }
            Button {
                text: "Generate code"
                visible: rootwindow.isWideDesktop && !rootwindow.isCompactMode
                Layout.preferredWidth: 145
                onClicked: {
                    jsonSelectDialog.exportType = "code"
                    jsonSelectDialog.open()
                }
            }
            Button {
                text: "Generate exel"
                visible: rootwindow.isWideDesktop && !rootwindow.isCompactMode
                Layout.preferredWidth: 145
                onClicked: {
                    jsonSelectDialog.exportType = "exel"
                    jsonSelectDialog.open()
                }
            }
            Button {
                text: "MEK indexing"
                visible: rootwindow.isWideDesktop && !rootwindow.isCompactMode
                Layout.preferredWidth: 130
                onClicked: assignIOA
            }
            Button {
                text: qsTr("Debug Full Model")
                onClicked: {
                    if (dataModel.count === 0) {
                        console.log("Model is empty!")
                        return
                    }
                    console.log("----- FULL MODEL DUMP -----");
                    for (var i = 0; i < dataModel.count; i++) {
                        var item = dataModel.get(i);
                        console.log(`\nItem ${i}: ${item.paramType} "${item.name}"`);
                    }
                    console.log("----- END DUMP -----");
                }
            }
            Button { text: "MEK indexing"; onClicked: assignIOA }
            Item { Layout.fillHeight: true }
        }
    }

            Button {
                text: qsTr("Настроить ETH")
                onClicked: {
                    ethcounter = ethcounter + 1
                    ethConfigDialog.open()
                }
            }
            Button {
                text: qsTr("Настроить RS")
                onClicked: {
                    initializeMekProperties()
                }
            }
            Item {
                Layout.fillWidth: true
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Export to JSON")
                onClicked: {
                    if (rootwindow.currentBldePath !== "") {
                        saveToBlde(rootwindow.currentBldePath)
                        hasUnsavedChanges = false
                    } else {
                        saveFileDialog.open()
                    }
                }
            }

            Button {
                text: qsTr("Generate code")
                onClicked: {
                    jsonSelectDialog.exportType = "code"
                    onClicked: jsonSelectDialog.open()
                }
            }
            Button {
                text: qsTr("Generate exel")
                onClicked: {
                    jsonSelectDialog.exportType = "exel"
                    onClicked: jsonSelectDialog.open()
                }
            }

            Button {
                text: qsTr("MEK indexing")
                onClicked: {
                    assignIOA
                }
            }
        }
    }



    Material.theme: Material.Light
    Material.accent: Material.Purple


//region Functions
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
            if (item.paramType === "Аналоговый выход" || item.paramType === "Дискретный выход") {
                dataModel.setProperty(i, "oi_c_sc_na_1", 'true')
            }
            else if (item.paramType === "Уставка") {
                if (item.type === "bool") {
                    dataModel.setProperty(i, "oi_c_sc_na_1", 'true')
                }
                else if (item.type === "unsigned short" || item.type === "unsigned int") {
                    dataModel.setProperty(i, "oi_c_se_na_1", 'true')
                }
                else if (item.type === "float") {
                    dataModel.setProperty(i, "oi_c_se_nb_1", 'true')
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

    // === ШАГ адреса (в регистрах/битах) по блоку и типу данных ===
    function mbStep(blockType, dataType) {
        const t = (dataType || "").toLowerCase()
        if (blockType === "Coil" || blockType === "Discrete input") return 1  // битовые
        switch (t) {
            case "bool": case "uint16": case "int16": case "unsigned short": case "short":
                return 1
            case "uint32": case "int32": case "unsigned int": case "int": case "float":
                return 2
            case "uint64": case "int64": case "double":
                return 4
            default:
                return 1
        }
    }

    // === собрать занятые адреса в блоке ===
    function mbOccupied(blockType) {
        const occ = new Set()
        for (let i = 0; i < dataModel.count; i++) {
            const it = dataModel.get(i)
            if (it.blockName !== blockType) continue
            const base = parseInt(it.address)
            if (!base || base <= 0) continue
            const step = mbStep(blockType, it.type || it.dataType)
            for (let j = 0; j < step; j++) occ.add(base + j)
        }
        return occ
    }

    function mbFits(occ, start, step) {
        for (let j = 0; j < step; j++) if (occ.has(start + j)) return false
        return true
    }

    function mbNextFree(occ, step, fromAddr) {
        let a = Math.max(1, fromAddr|0)
        while (!mbFits(occ, a, step)) a++
        return a
    }

    // === Назначить адрес конкретному элементу (по originalIndex) ===
    function mbAssignOne(blockType, originalIndex, fromAddr) {
        const it = dataModel.get(originalIndex)
        if (!it || it.blockName !== blockType) return
        const step = mbStep(blockType, it.type || it.dataType)
        const occ = mbOccupied(blockType)
        const addr = mbNextFree(occ, step, fromAddr || 1)
        dataModel.setProperty(originalIndex, "address", String(addr))
    }

    // === Компактизировать блок: пронумеровать подряд (стабильно по порядку) ===
    function mbCompactBlock(blockType) {
        // Соберём индексы элементов этого блока в стабильном порядке (ioIndex -> number; иначе originalIndex)
        const rows = []
        for (let i = 0; i < dataModel.count; i++) {
            const it = dataModel.get(i)
            if (it.blockName !== blockType) continue
            const k = (it.ioIndex !== undefined && it.ioIndex !== null) ? (parseInt(it.ioIndex) || 0) : i
            rows.push({orig: i, key: k})
        }
            rows.sort((a,b)=>a.key-b.key)

        const occ = new Set()
        for (const r of rows) {
            const it = dataModel.get(r.orig)
            const step = mbStep(blockType, it.type || it.dataType)
            const addr = mbNextFree(occ, step, 1)
            dataModel.setProperty(r.orig, "address", String(addr))
            for (let j=0;j<step;j++) occ.add(addr+j)
        }
    }

    // === При смене блока у строки ===
    function onModbusBlockChanged(originalIndex, newBlock, oldBlock) {
        // Обновили блок и сбросили адрес у текущей строки уже в делегате → здесь выдаём адрес текущему
        mbAssignOne(newBlock, originalIndex, 1)
        // Приведём к порядку старый и новый блок (чтобы без дыр)
        if (oldBlock && oldBlock !== newBlock) mbCompactBlock(oldBlock)
        mbCompactBlock(newBlock)
    }

    // === При смене типа данных у строки (если зависит шаг) ===
    function onModbusDataTypeChanged(originalIndex) {
        const it = dataModel.get(originalIndex)
        const blk = it.blockName || ""
        if (!blk) return
        // Просто пересоберём последовательность блока
        mbCompactBlock(blk)
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
    function createObjectModel(name, type) {
        var newId = type.toLowerCase() + "_obj_" + Date.now();
        objectModelsConfig.append({
            id: newId,
            name: name,
            type: type,
            signalIds: Qt.createQmlObject('import QtQml.Models 2.15; ListModel {}', objectModelsConfig),
            protocolIds: Qt.createQmlObject('import QtQml.Models 2.15; ListModel {}', objectModelsConfig)
        });

        // Set as current
        currentObjectModelId = newId;

        // Enable corresponding tab
        if (type === "MEK") {
            mek = true;
        } else if (type === "MODBUS") {
            modbus = true;
        }
        tabBar.updateFocus();
    }

    function createInterface(type, config = {}) {
        var newId = type.toLowerCase() + "_int_" + Date.now();
        var counter = type === "RS" ? rscounter : ethcounter;
        var interfaceName = type + counter;

        switch(type) {
            case "ETH":
                // Add ONE entry to interfaceModelsConfig for this ETH interface
                interfaceModelsConfig.append({
                    id: newId,
                    type: "ETH",
                    name: interfaceName,
                    IP: config.ip || "",
                    MASK: config.mask || "",
                    GATE: config.gate || "",
                    MAC_HIGH: config.high || "",
                    MAC_LOW: config.low || "",
                    IPC1: config.ipc1 || "",
                    IPC2: config.ipc2 || "",
                    IPC3: config.ipc3 || "",
                    IPC4: config.ipc4 || "",
                    ADDRESS: config.addr || "",
                    PORT1: config.port1 || "",
                    PORT2: config.port2 || "",
                    PORT3: config.port3 || "",
                    PORT4: config.port4 || ""
                });

                ethcounter++;
                break;

            case "RS":
                // Add ONE entry to interfaceModelsConfig for this RS interface
                interfaceModelsConfig.append({
                    id: newId,
                    type: "RS",
                    name: interfaceName,
                    PARITY: config.parity || "",
                    BAUDRATE: config.baudrate || "",
                    WORD_LEN: config.wordLen || "",
                    STOP_BITS: config.stopBits || "",
                    ADDRESS: config.addr || ""
                });

                rscounter++;
                break;

            default:
                console.log("Unknown Interface type:", type);
                return;
        }

        console.log("Created", type, "Interface with ID:", newId);
    }


    function createProtocol(name, type, objectModelId, interfaceId, config ={}) {
        var newId = type.toLowerCase() + "_prot_" + Date.now();

        protocolModelsConfig.append({
            id: newId,
            name: name,
            type: type,
            objectModelId: objectModelId,
            interfaceId: interfaceId,
            signalMappings: [],
            ASDU: config.asdu || "",
            LINK_LEN: config.link_address_len || "",
            ASDU_LEN: config.asdu_len || "",
            REASON_LEN: config.reason_len || "",
            IOA_LEN: config.ioa_len || "",
            SYNC: config.sync || "",
            TELECONTROL: config.telecontrol || "",
            PERCYC_PERIOD: config.percyc_period || "",
            BACK_PERIOD: config.back_period || ""
        });

        // Добавляем протокол к объектной модели
        for (var i = 0; i < objectModelsConfig.count; i++) {
            if (objectModelsConfig.get(i).id === objectModelId) {
                var currentModel = objectModelsConfig.get(i);
                var protocolsList = currentModel.protocolIds;

                if (protocolsList && typeof protocolsList.append === 'function') {
                    protocolsList.append({protocolId: newId});
                } else {
                    if (!protocolsList) {
                        protocolsList = [newId];
                    } else if (Array.isArray(protocolsList)) {
                        protocolsList.push(newId);
                    } else {
                        protocolsList = [newId];
                    }
                    objectModelsConfig.setProperty(i, "protocolIds", protocolsList);
                }
                break;
            }
        }

        currentProtocolId = newId;

        // Включаем соответствующую вкладку
        if (type === "MEK_101") {
            mek_101 = true;
        } else if (type === "MEK_104") {
            mek_104 = true;
        }

        tabBar.updateFocus();
    }
    function getCurrentObjectModelName() {
        if (currentObjectModelId === "") return "Не выбрана"

        for (var i = 0; i < objectModelsConfig.count; i++) {
            if (objectModelsConfig.get(i).id === currentObjectModelId) {
                return objectModelsConfig.get(i).name
            }
        }
        return "Неизвестная модель"
    }

    function getCurrentObjectModelSignalCount() {
        if (currentObjectModelId === "") return 0

        for (var i = 0; i < objectModelsConfig.count; i++) {
            if (objectModelsConfig.get(i).id === currentObjectModelId) {
                var signalIds = objectModelsConfig.get(i).signalIds || []
                // Check if it's a ListModel or array
                if (signalIds && typeof signalIds.count !== 'undefined') {
                    return signalIds.count
                } else if (Array.isArray(signalIds)) {
                    return signalIds.length
                }
                return 0
            }
        }
        return 0
    }

    function addSignalToCurrentObjectModel(signalIndex) {
        console.log("addSignalToCurrentObjectModel called with index:", signalIndex)

        if (currentObjectModelId === "") {
            console.log("No current object model selected")
            return
        }

        for (var i = 0; i < objectModelsConfig.count; i++) {
            var item = objectModelsConfig.get(i)
            if (item.id === currentObjectModelId) {
                console.log("Found matching object model at index:", i)

                var signalIds = item.signalIds

                if (signalIds && typeof signalIds.count !== 'undefined') {
                    var exists = false
                    for (var j = 0; j < signalIds.count; j++) {
                        if (signalIds.get(j).signalId === signalIndex) {
                            exists = true
                            break
                        }
                    }

                    if (!exists) {
                        signalIds.append({"signalId": signalIndex})
                    }
                } else {
                    var signalArray = signalIds || []
                    if (signalArray.indexOf(signalIndex) === -1) {
                        signalArray.push(signalIndex)
                        objectModelsConfig.setProperty(i, "signalIds", signalArray)
                        console.log("Added signal to array")
                    }
                }
                break
            }
        }
    }

    function removeSignalFromCurrentObjectModel(signalIndex) {
        console.log("removeSignalFromCurrentObjectModel called with index:", signalIndex)

        if (currentObjectModelId === "") {
            console.log("No current object model selected")
            return
        }

        for (var i = 0; i < objectModelsConfig.count; i++) {
            var item = objectModelsConfig.get(i)
            if (item.id === currentObjectModelId) {
                console.log("Found matching object model at index:", i)

                var signalIds = item.signalIds

                if (signalIds && typeof signalIds.count !== 'undefined') {
                    for (var j = 0; j < signalIds.count; j++) {
                        if (signalIds.get(j).signalId === signalIndex) {
                            signalIds.remove(j)
                            console.log("Removed signal from ListModel")
                            break
                        }
                    }
                } else {
                    var signalArray = signalIds || []
                    var indexToRemove = signalArray.indexOf(signalIndex)
                    if (indexToRemove !== -1) {
                        signalArray.splice(indexToRemove, 1)
                        objectModelsConfig.setProperty(i, "signalIds", signalArray)
                        console.log("Removed signal from array")
                    }
                }
                break
            }
        }
    }


    function isSignalInCurrentObjectModel(signalIndex) {
        if (currentObjectModelId === "") return false

        for (var i = 0; i < objectModelsConfig.count; i++) {
            var item = objectModelsConfig.get(i)
            if (item.id === currentObjectModelId) {
                var signalIds = item.signalIds

                if (signalIds && typeof signalIds.count !== 'undefined') {
                    for (var j = 0; j < signalIds.count; j++) {
                        if (signalIds.get(j).signalId === signalIndex) {return true
                        }
                    }
                    return false
                } else if (signalIds && Array.isArray(signalIds)) {
                    return signalIds.indexOf(signalIndex) !== -1
                }
            }
        }
        return false
    }

    function addSignalToCurrentObjectModelListModel(signalIndex) {
        if (currentObjectModelId === "") return

        for (var i = 0; i < objectModelsConfig.count; i++) {
            if (objectModelsConfig.get(i).id === currentObjectModelId) {
                var signalIds = objectModelsConfig.get(i).signalIds

                var exists = false
                if (signalIds && typeof signalIds.count !== 'undefined') {
                    for (var j = 0; j < signalIds.count; j++) {
                        if (signalIds.get(j).signalId === signalIndex) {
                            exists = true
                            break
                        }
                    }
                    if (!exists) {
                        signalIds.append({"signalId": signalIndex})
                    }
                }
                break
            }
        }
    }

    function removeSignalFromCurrentObjectModelListModel(signalIndex) {
        if (currentObjectModelId === "") return

        for (var i = 0; i < objectModelsConfig.count; i++) {
            if (objectModelsConfig.get(i).id === currentObjectModelId) {
                var signalIds = objectModelsConfig.get(i).signalIds

                if (signalIds && typeof signalIds.count !== 'undefined') {
                    for (var j = 0; j < signalIds.count; j++) {
                        if (signalIds.get(j) === signalIndex) {
                            signalIds.remove(j)
                            break
                        }
                    }
                }
                break
            }
        }
    }

    function selectAllSignalsForCurrentModel() {
        if (currentObjectModelId === "") return

        for (var i = 0; i < dataModel.count; i++) {
            addSignalToCurrentObjectModel(i)
        }
    }

    function clearAllSignalsForCurrentModel() {
        if (currentObjectModelId === "") return

        // Get the current signal list first
        var signalsToRemove = []
        for (var i = 0; i < objectModelsConfig.count; i++) {
            var item = objectModelsConfig.get(i)
            if (item.id === currentObjectModelId) {
                var signalIds = item.signalIds

                if (signalIds && typeof signalIds.count !== 'undefined') {
                    for (var j = 0; j < signalIds.count; j++) {
                        signalsToRemove.push(signalIds.get(j).signalId)
                    }
                }
                break
            }
        }

        // Remove each signal
        for (var k = 0; k < signalsToRemove.length; k++) {
            removeSignalFromCurrentObjectModel(signalsToRemove[k])
        }
    }
    function convertSignalIdsToListModel(array) {
        const listModel = Qt.createQmlObject('import QtQml.Models 2.15; ListModel {}', rootwindow);
        for (let i = 0; i < array.length; i++) {
            listModel.append(array[i]);
        }
        return listModel;
    }

    function importObjectModels(rawList) {
        objectModelsConfig.clear();
        for (let i = 0; i < rawList.length; i++) {
            const raw = rawList[i];

            const model = {
                id: raw.id,
                name: raw.name,
                type: raw.type,
                signalIds: convertSignalIdsToListModel(raw.signalIds || []),
                protocolIds: convertSignalIdsToListModel(raw.protocolIds || [])
            };

            objectModelsConfig.append(model);
        }
    }

    function updateTabs() {
        for (var i = 0; i < objectModelsConfig.count; i++) {
            if (objectModelsConfig.get(i).type == "MEK") {
                  mek = true
            }
            if (objectModelsConfig.get(i).type == "MODBUS") {
                modbus = true
            }
        }
        for (var i = 0; i < protocolModelsConfig.count; i++) {
            if(protocolModelsConfig.get(i).type = "MEK_101") {
                mek_101 = true
            }
            if(protocolModelsConfig.get(i).type = "MEK_104") {
                mek_104 = true
            }

        }

    }
    //endregion
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


//выбор тсов из подрузки параметров current system в дискретных выходах
//настройки мека, big endian в модбасе
//#include "MEK101_server.h" or 104///// modbus_server.h, числами адреса иоа и асду
// верхний нижний предел измерений
//если float, то всегда заканчивается f
