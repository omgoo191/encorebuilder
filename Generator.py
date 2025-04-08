import json
from pathlib import Path
import os


def main():
    current_dir = Path(os.getcwd())

    file_name = input("Введите имя JSON файла (например: export.json): ").strip()
    json_path = current_dir / file_name

    if not json_path.exists():
        print(f"Ошибка: Файл '{file_name}' не найден в директории: {current_dir}")
        input("Нажмите Enter для выхода...")
        return

    try:
        with json_path.open("r", encoding="utf-8") as file:
            data = json.load(file)
            data = [
                {k: v.replace('\n', '').strip() if isinstance(v, str) else v
                 for k, v in obj.items()}
                for obj in data
            ]
    except json.JSONDecodeError:
        print(f"Ошибка: Файл '{file_name}' содержит некорректный JSON")
        input("Нажмите Enter для выхода...")
        return
    # Маппинг типов для info_objects.cpp
    type_mapping_info = {
        "bool": "Bool",
        "float": "Float",
        "unsigned int": "UInt",
        "unsigned char": "UChar",
        "unsigned short": "UShort"
    }

    TM_mapping = {
        "bool": "BOOL",
        "float": "FLOAT",
        "unsigned int": "UINT",
        "unsigned char": "UCHAR",
        "unsigned short": "USHORT"
    }

    type_block_info = {
        "Coil": "coils",
        "Discrete input": "discrete_input",
        "Holding register": "holding_registers",
        "Input register": "input_registers"
    }

    # Начальные строки для каждого файла
    defines_content = """
    
    """
    info_objects_content = """#include "defines.h"
    
    namespace core {
        void AddInfoObjects() {
    """
    tele_content = """#include "defines.h"
    
    namespace core {
        void AddTelesignalizations() {
    """
    telecommands_content = """#include "defines.h"
    
    namespace core {
        void AddTelecommands() {
    """
    saved_parameters_content = """#include "defines.h"
    
    namespace core {
        void AddStoredParameters() {
    """
    communications_content = """
    /**
     * @file communications.cpp
     * @author Мизикин Владислав
     * @date 
     * @brief
     *
     *
     */
    /* Includes ------------------------------------------------------------------*/
    
    #include "defines.h"
    #include "core.h"
    #include "modbus.h"
    
    /* Private typedef -----------------------------------------------------------*/
    
    /* Private define ------------------------------------------------------------*/
    
    /* Private variables ---------------------------------------------------------*/
    
    /* Private function prototypes -----------------------------------------------*/
    
    /* Private functions ---------------------------------------------------------*/
    
    /* Exported methods ----------------------------------------------------------*/
    
    namespace core {
        void Core::InitCommunications() {
    """

    telemeasurments_content = """#include "defines.h"
    namespace core {
        void AddTelemeasurments() {
    """

    # Список блоков для communications.cpp
    block_types = ["Input register", "Holding register", "Discrete input", "Coil"]

    # Генерация макросов и вызовов функций по каждому объекту
    for obj in data:

        # Генерация макроса
        defines_content += (f"#define ind_{obj['codeName'].strip()} {obj['ioIndex'].strip()} /* {obj['name'].strip()} */\n")

        # Определение типа для info_objects (приведение к нужному виду)
        orig_type = obj.get("type", "")
        mapped_type = type_mapping_info.get(orig_type, orig_type)
        info_objects_content += (f"        Add{mapped_type}InfoObject(ind_{obj['codeName']}); //{obj['name'].strip()}\n")

        # Генерация для telesignalizations.cpp (если paramType == \"Входные сигналы\" и поле \"ad\" задано)
        if obj.get("paramType") == "Входные сигналы" and obj.get("ad"):
            tele_content += (f"        AddTelesignalization(ind_{obj['codeName']}, parameters::TelesignalizationIndexes::{obj['codeName']}, ind_{obj['ad']});\n")

        # Генерация для telecommands.cpp (если paramType == \"Выходные сигналы\")
        if obj.get("paramType") == "Выходные сигналы":
            telecommands_content += (f"        AddTelecommand(ind_{obj['codeName']}, parameters::TelecommandIndexes::{obj['codeName']});\n")

        # Генерация для saved_parameters.cpp (если paramType == \"Признаки\" и saving == \"Да\" или paramType == \"Уставки\")
        if (obj.get("paramType") == "Признаки" and obj.get("saving") == "Да") or obj.get("paramType") == "Уставки":
            saved_parameters_content += (f"        AddStoredObject(ind_{obj['codeName']});\n")

        # Генерация для telemeasurments.cpp
        ktt_param = f"ind_{obj['ktt']}" if obj.get("ktt") else "std::nullopt"
        aperture_param = f"ind_{obj['aperture']}" if obj.get("aperture") else "std::nullopt"
        TM_type = obj.get("type", "")
        TM_type_name = TM_mapping.get(TM_type, TM_type)
        telemeasurments_content += (
            f" AddTelemeasurment<InfoObject::InfoElement::CurrentType::{TM_type_name}>(ind_{obj['codeName']}, parameters::TelemeasurmentIndexes::{obj['codeName']}, {ktt_param}, " \
            f"{aperture_param});\n")

    # Формирование кода для communications.cpp:
    for block in block_types:
        count = sum(1 for obj in data if obj.get("blockName") == block)
        if count > 0:
            # Здесь имя поля формируется: все буквы в нижнем регистре, пробел заменяется на _ и добавляется ptr
            field_name = block.lower().replace(" ", "_") + "ptr"
            communications_content += f"        modbus_object_model.{field_name} = std::make_shared<modbus::ModbusSingleBitDataBlock>({count});\n"

    for obj in data:
        if obj.get("address"):
            orig_block = obj.get("blockName", "")
            mapped_block = type_block_info.get(orig_block, orig_block)
            communications_content += f"        modbus_object_model.{mapped_block}_ptr->AddElement({obj['address']}, &GetInfoObject(ind_{obj['codeName']}), modbus::Format::FORMAT_BIG_ENDIAN);\n"

    # Добавление настроек RS485
    communications_content += (
        "        current_system_.RS485_interfaces[parameters::Interfaces::RS1_INDEX]->ChangeSettings(\n"
        "            GetInfoObject(ind_PT_RS1_BAUDRATE).GetValue<unsigned int>(),\n"
        "            static_cast<STM32::UART_Interface::WordLength>(GetInfoObject(ind_PT_RS1_WORD_LENGTH).GetValue<bool>()),\n"
        "            static_cast<STM32::UART_Interface::StopBits>(GetInfoObject(ind_PT_RS1_STOP_BITS).GetValue<bool>()),\n"
        "            static_cast<STM32::UART_Interface::Parity>(GetInfoObject(ind_PT_RS1_PARITY).GetValue<unsigned char>())\n"
        "        );\n"
    )
    communications_content += ("        current_system_.RS485_interfaces[parameters::Interfaces::RS2_INDEX]->ChangeSettings(\n"
                               "            GetInfoObject(ind_PT_RS2_BAUDRATE).GetValue<unsigned int>(),\n"
                               "            static_cast<STM32::UART_Interface::WordLength>(GetInfoObject(ind_PT_RS2_WORD_LENGTH).GetValue<bool>()),\n"
                               "            static_cast<STM32::UART_Interface::StopBits>(GetInfoObject(ind_PT_RS2_STOP_BITS).GetValue<bool>()),\n"
                               "            static_cast<STM32::UART_Interface::Parity>(GetInfoObject(ind_PT_RS2_PARITY).GetValue<unsigned char>())\n"
                               "        );\n"
                               )

    # Завершающие строки файлов
    defines_content += "\n"
    info_objects_content += "    \n}\n}\n"
    tele_content += "    \n}\n}\n"
    telecommands_content += "    \n}\n}\n"
    saved_parameters_content += "    \n}\n}\n"
    communications_content += "    \n}\n}\n"
    telemeasurments_content += "    \n}\n}\n"
    # Запись в файлы
    with open("defines.h", "w", encoding="utf-8") as f:
        f.write(defines_content)
    with open("info_objects.cpp", "w", encoding="utf-8") as f:
        f.write(info_objects_content)
    with open("telesignalizations.cpp", "w", encoding="utf-8") as f:
        f.write(tele_content)
    with open("telecommands.cpp", "w", encoding="utf-8") as f:
        f.write(telecommands_content)
    with open("saved_parameters.cpp", "w", encoding="utf-8") as f:
        f.write(saved_parameters_content)
    with open("communications.cpp", "w", encoding="utf-8") as f:
        f.write(communications_content)
    with open("telemeasurments.cpp", "w", encoding="utf-8") as f:
        f.write(telemeasurments_content)

    print("Все файлы сгенерированы!")


if __name__ == "__main__":
    main()
