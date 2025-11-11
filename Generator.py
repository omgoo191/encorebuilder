# -*- coding: utf-8 -*-


import json
import sys
from pathlib import Path
from datetime import datetime

# ---------- Helpers ----------

def norm_str(s):
    if isinstance(s, str):
        return s.replace("\\n", "").strip()
    return s

def norm_bool(v):
    if isinstance(v, bool):
        return v
    if v is None:
        return False
    s = str(v).strip().lower()
    return s in ("1", "true", "yes", "да", "y", "on")

def norm_paramtype(s):
    s = norm_str(s) or ""
    # unify singular/plural
    return {"уставка": "Уставки", "уставки": "Уставки"}.get(s.lower(), s)

def safe_get(d, key, default=None):
    return d.get(key, default)

def as_int(v, default=None):
    try:
        return int(v)
    except Exception:
        return default



# ---------- Main ----------

def main(json_file):
    json_path = Path(json_file).resolve()
    current_date = datetime.now().strftime("%d.%m.%Y")
    if not json_path.exists():
        print(f"Error: File '{json_file}' not found at resolved path: {json_path}", file=sys.stderr)
        return 1

    try:
        with json_path.open("r", encoding="utf-8") as file:
            json_data = json.load(file)
            if "signals" not in json_data:
                print("Error: No 'signals' array found in JSON", file=sys.stderr)
                return 1

            signals = json_data["signals"]
            # normalize and clean
            data = []
            for obj in signals:
                clean = {}
                for k, v in obj.items():
                    if isinstance(v, str):
                        clean[k] = norm_str(v)
                    else:
                        clean[k] = v
                # normalize booleans where keys typically boolean
                for key in list(clean.keys()):
                    if key.startswith("allow_address_") or key.startswith("use_in_") or key.startswith("oi_c_"):
                        clean[key] = norm_bool(clean[key])
                # normalize commonly boolean-ish
                for key in ("saving", "logicuse"):
                    if key in clean:
                        # keep "Да"/"" for Excel elsewhere, but here we will keep original string and add bools
                        clean[key + "_bool"] = norm_bool(clean[key])
                # normalize paramType
                if "paramType" in clean:
                    clean["paramType"] = norm_paramtype(clean["paramType"])
                data.append(clean)

            protocols = json_data.get("protocols", [])
            # normalize protocol entries too
            protos = []
            for p in protocols:
                p2 = {k: norm_str(v) if isinstance(v, str) else v for k, v in p.items()}
                p2["type"] = norm_str(p2.get("type"))
                protos.append(p2)
    except json.JSONDecodeError:
        print("Ошибка: Файл содержит некорректный JSON", file=sys.stderr)
        return 1
    telecommand_count = sum(1 for obj in data if obj.get("paramType") in ("Аналоговый выход", "Дискретный выход"))
    telesignal_count  = sum(1 for obj in data if obj.get("paramType") == "Дискретные входы" and obj.get("ad"))
    # Type mappings for InfoObjects / Telemeasurements
    type_mapping_info = {
        "bool": "Bool",
        "float": "Float",
        "unsigned int": "UInt",
        "unsigned char": "UChar",
        "unsigned short": "UShort",
        "unsigned long long": "ULong"
    }
    TM_mapping = {
        "bool": "BOOL",
        "float": "FLOAT",
        "unsigned int": "UINT",
        "unsigned char": "UCHAR",
        "unsigned short": "USHORT",
        "unsigned long long": "ULONG"
    }
    type_block_info = {
        "Coil": "coils",
        "Discrete input": "discrete_input",
        "Holding register": "holding_registers",
        "Input register": "input_registers"
    }
    modbus_block_class = {
        "Coil": "ModbusSingleBitDataBlock",
        "Discrete input": "ModbusSingleBitDataBlock",
        "Holding register": "ModbusHoldingRegisterBlock",  # adjust to your SDK
        "Input register": "ModbusInputRegisterBlock",      # adjust to your SDK
    }

    # --- тип -> InfoElement::CurrentType (строка enum'а)
    CURRENT_TYPE = {
        "bool": "BOOL",
        "char": "CHAR",
        "unsigned char": "UCHAR",
        "short": "SHORT",
        "unsigned short": "USHORT",
        "int": "INT",
        "unsigned int": "UINT",
        "float": "FLOAT",
    }

# --- определить категорию (POINT / SETPOINT / MEAS)
    def detect_category(paramType: str, typ: str) -> str | None:
        t = (typ or "").strip().lower()
        p = (paramType or "").strip()
        # твоя текущая логика:
        # - ТС: дискретные входы или признаки (bool)
        if p in ("Дискретные входы", "Признаки") and t == "bool":
            return "POINT"
        if p == "Признаки" and t != "bool":
            return "SETPOINT"
        # - измерения: аналоговые входы
        if p == "Аналоговые входы" and (obj.get("ktt") or obj.get("aperture")):
            return "MEAS"
        return None

# --- дефолтные TypeID по категории и текущему типу
# возвращает строку с именем перечисления без префикса: например "M_SP_NA_1"
    def default_typeid_for(which: str, category: str, current_type: str) -> str | None:
        # which ∈ {"REQ", "ST", "BC", "CP"}
        # POINT (ТС)
        if category == "POINT":
            if current_type == "BOOL":
                return {
                    "REQ": "M_SP_NA_1",
                    "ST":  "M_SP_TB_1",
                    "BS": "M_SP_NA_1",
                    # BC/CP конкретных дефолтов в твоём ObjectModel нет — оставляем None
                }.get(which)
            if current_type in ("CHAR", "UCHAR"):
                return {
                    "REQ": "M_DP_NA_1",
                    "ST":  "M_DP_TB_1",
                    "BS": "M_DP_NA_1",
                }.get(which)
            return None

    # SETPOINT (уставки/команды трактуем по типу так же, как у тебя в AddSetpoint)
        if category == "SETPOINT":
            if current_type in ("CHAR", "UCHAR", "SHORT", "USHORT"):
                return {
                    "REQ": "M_ME_NA_1",
                    "ST":  "M_ME_TD_1",
                    "BS": "M_ME_NA_1",
                }.get(which)
            if current_type in ("BOOL", "INT", "UINT"):
                return {
                    "REQ": "M_BO_NA_1",
                    "ST":  "M_BO_TB_1",
                    "BS": "M_BO_NA_1",
                }.get(which)
            if current_type == "FLOAT":
                return {
                    "REQ": "M_ME_NC_1",
                    "ST":  "M_ME_TF_1",
                    "BS": "M_ME_NC_1",
                }.get(which)
            return None

        # MEAS (измерения)
        if category == "MEAS":
            if current_type in ("SHORT", "USHORT"):
                return {
                    "REQ": "M_ME_NA_1",
                    "ST":  "M_ME_TD_1",
                    "PC":  "M_ME_NA_1",  # у тебя в AddMeasurement ставится PC = ME_NA_1
                    "BS": "M_ME_NC_1",
                }.get(which)
            if current_type == "FLOAT":
                return {
                    "REQ": "M_ME_NC_1",
                    "ST":  "M_ME_TF_1",
                    "PC":  "M_ME_NC_1",  # PC = ME_NC_1
                    "BS":  "M_ME_NC_1",  # PC = ME_NC_1
                }.get(which)
            return None

        return None


    def get_ref(obj, key):
        ref_code = norm_str(obj.get(key))
        return by_code.get(ref_code) if ref_code else None

    def get_ref_field(obj, ref_key, field, default=None):
        ref = get_ref(obj, ref_key)
        return ref.get(field, default) if ref else "std:nullopt"

    # ---------- File headers ----------
    defines_content = f"""/**
 * @file defines.h
 * @date {current_date}
 * @brief Auto-generated definitions
 */
#pragma once

// Capacity will be set below
"""

    info_objects_content = f"""/**
 * @file info_objects.cpp
 * @date {current_date}
 * @brief Auto-generated
 */
#include "defines.h"
#include "core.h"

namespace core {{
void Core::InitInfoObjects() {{
"""

    tele_content = f"""/**
 * @file telesignalizations.cpp
 * @date {current_date}
 * @brief Auto-generated
 */
#include "defines.h"
#include "core.h"

namespace core {{
void Core::InitTelesignalizations() {{
GetCurrentSystem().ReserveTelesignalizations({telesignal_count});
"""

    telecommands_content = f"""/**
 * @file telecommands.cpp
 * @date {current_date}
 * @brief Auto-generated
 */
#include "defines.h"
#include "core.h"

namespace core {{
void Core::InitTelecommands() {{
 GetCurrentSystem().ReserveTelecommands({telecommand_count});
"""

    saved_parameters_content = f"""/**
 * @file saved_parameters.cpp
 * @date {current_date}
 * @brief Auto-generated
 */
#include "defines.h"
#include "core.h"

namespace core {{
void Core::InitSavedParameters() {{
"""

    communications_content = f"""/**
 * @file communications.cpp
 * @date {current_date}
 * @brief Auto-generated
 */
#include "defines.h"
#include "core.h"
#include "modbus_server.h"
#include "MEK101_server.h"

namespace core {{
void Core::InitCommunications() {{
"""

    telemeasurements_content = f"""/**
 * @file telemeasurements.cpp
 * @date {current_date}
 * @brief Auto-generated
 */
#include "defines.h"
#include "core.h"

namespace core {{
void Core::InitTelemeasurements() {{
"""

    mek_asdu_addresses = f"""/**
 * @file mek_asdu_addresses.h
 * @date {current_date}
 * @brief Auto-generated
 */
#pragma once

"""

    mek_ioa_addresses = f"""/**
 * @file mek_ioa_addresses.h
 * @date {current_date}
 * @brief Auto-generated
 */
#pragma once

"""

    # ---------- Generate by objects ----------
    for obj in data:
        code = norm_str(obj.get("codeName", "")) or "NONAME"
        name = norm_str(obj.get("name", "")) or code
        io_idx = norm_str(obj.get("ioIndex", "")) or ""
        asdu_addr = norm_str(obj.get("asdu_address", "")) or ""
        ioa_addr = norm_str(obj.get("ioa_address", "")) or ""
        blockName = norm_str(obj.get("blockName", "")) or ""
        paramType = norm_str(obj.get("paramType", "")) or ""
        typ = norm_str(obj.get("type", "")) or ""
        saving_bool = bool(obj.get("saving_bool", False))

        # addresses headers
        if asdu_addr:
            mek_asdu_addresses += f"#define {code}_MEK_ASDU_ADDR {asdu_addr} /* {name} */\n"
        if ioa_addr:
            mek_ioa_addresses  += f"#define {code}_MEK_IOA_ADDR  {ioa_addr}  /* {name} */\n"

        # defines.h indices
        if io_idx != "":
            defines_content += f"#define ind_{code} {io_idx} /* {name} */\n"

        # info objects
        mapped_type = type_mapping_info.get(typ, typ if typ else "Float")
        def_value = obj.get("def_value", None)
        if def_value not in (None, ""):
            info_objects_content += f"    Add{mapped_type}InfoObject(ind_{code}).SetValue({def_value}); // {name}\n"
        else:
            info_objects_content += f"    Add{mapped_type}InfoObject(ind_{code}); // {name}\n"

        # telesignalizations: only discrete inputs with 'ad' mapping
        if paramType == "Дискретные входы" and obj.get("ad"):
            ad_code = norm_str(obj.get("ad"))
            tele_content += f"    AddTelesignalization(ind_{code}, parameters::TelesignalizationIndexes::{code}, ind_{ad_code});\n"

        # telecommands: outputs only
        if paramType in ("Аналоговый выход", "Дискретный выход"):
            telecommands_content += f"    AddTelecommand(ind_{code}, parameters::TelecommandIndexes::{code});\n"

        # saved parameters: 'Признаки' with saving flag OR 'Уставки'
        if (paramType == "Признаки" and saving_bool) or (paramType == "Уставки") or (paramType == "Дискретный выход" and saving_bool):
            saved_parameters_content += f"    AddStoredObject(ind_{code});\n"

        # telemeasurements: only analog inputs
        if paramType == "Аналоговые входы" and (obj.get("ktt") or obj.get("aperture")):
            ktt_param = f"ind_{obj['ktt']}" if obj.get("ktt") else "std::nullopt"
            aperture_param = f"ind_{obj['aperture']}" if obj.get("aperture") else "std::nullopt"
            TM_type = TM_mapping.get(typ, typ if typ else "FLOAT")
            # Keep the original project method name to avoid linkage issues if it exists
            telemeasurements_content += (
        f"    AddTelemeasurement<info_object::InfoElement::CurrentType::{TM_type}>(ind_{code}, "
        f"parameters::TelemeasurementIndexes::{code}, {ktt_param}, {aperture_param});\n"
    )

    # ---------- communications.cpp: Modbus data blocks ----------
    block_types = ["Input register", "Holding register", "Discrete input", "Coil"]
    for block in block_types:
        count = sum(1 for obj in data if norm_str(obj.get("blockName")) == block)
        if count > 0:
            field_name = block.lower().replace(" ", "_") + "ptr"
            cls = modbus_block_class.get(block, "ModbusSingleBitDataBlock")
            communications_content += f"    modbus_object_model.{field_name} = std::make_shared<modbus::{cls}>({count});\n"

    # map elements by address
    for obj in data:
        address = obj.get("address")
        if address not in (None, ""):
            code = norm_str(obj.get("codeName", "")) or "NONAME"
            orig_block = norm_str(obj.get("blockName", ""))
            mapped_block = type_block_info.get(orig_block, orig_block)
            communications_content += (
                f"    modbus_object_model.{mapped_block}_ptr->AddElement({address}, &GetInfoObject(ind_{code}), "
                f"modbus::Format::FORMAT_BIG_ENDIAN);\n"
            )

    # MEK mappings and protocol flags
    for obj in data:
        code = norm_str(obj.get("codeName", "")) or "NONAME"
        name = norm_str(obj.get("name", "")) or code
        ioa_addr = norm_str(obj.get("ioa_address", "")) or ""
        paramType = norm_str(obj.get("paramType", "")) or ""
        typ = norm_str(obj.get("type", "")) or ""
        second_class = norm_str(obj.get("second_class_num", "NOT_USE")) or "NOT_USE"
        asdu_addr = norm_str(obj.get("asdu_address", "")) or ""
        aperture = norm_str(obj.get("aperture", "")) or ""
        by_code = { norm_str(o.get("codeName")): o for o in data if o.get("codeName") }
        setpoint_val = typ = norm_str(obj.get("setpoint", "")) or "std::nullopt"
        if not ioa_addr:
            continue



        for key, func, which in (
                ("type_spont",  "AssignTypeID_ForST",  "ST"),
                ("type_back",   "AssignTypeID_ForBS",  "BS"),
                ("type_percyc", "AssignTypeID_ForPC",  "PC"),
                ("type_def",    "AssignTypeID_ForREQ", "REQ")
        ):
            tval = norm_str(obj.get(key))
            if not tval or tval == "NOT_USE":
                continue

            category = detect_category(paramType, typ)
            curr_type = CURRENT_TYPE.get(typ.lower() if typ else "", None)
            default_tid = default_typeid_for(which, category, curr_type) if (category and curr_type) else None

            if default_tid and tval == default_tid:
                # совпало с дефолтом → пропускаем
                continue

            # если дефолта нет или оно другое → пишем
            communications_content += (
                f"    mek_object_model->{func}(MEK::M_TypeID::{tval}, {ioa_addr}, {asdu_addr});\n"
            )

        # Points / Commands based on param type
        if paramType in ("Дискретные входы", "Признаки") and typ == "bool":
            # Tele-signalization point (bool states)
            communications_content += (
                f"    mek_object_model->AddPoint({{&GetInfoObject(ind_{code}), MEK::Priority::{second_class}}}, "
                f"{ioa_addr}, {asdu_addr});  // {name}\n"
            )
        elif paramType == "Признаки" and typ != "bool":
            communications_content += (
                f"    mek_object_model->AddSetpoint({{&GetInfoObject(ind_{code}), MEK::Priority::{second_class}}}, "
                f"{ioa_addr}, {asdu_addr});  // {name}\n"
            )
        elif paramType == "Уставки":
            if typ == "bool":
                communications_content += (
                    f"    mek_object_model->AddSingleCommand({{&GetInfoObject(ind_{code}), std::nullopt}}, "
                    f"{ioa_addr}, {asdu_addr});  // {name}\n"
                )
        elif paramType == "Аналоговые входы" and (obj.get("ktt") or obj.get("aperture")):
            ap_code = norm_str(obj.get("aperture"))
            ap_setpoint = get_ref_field(obj, "aperture", "setpoint", "")
            ktt_param = f"{obj['ktt']}_IOA_ADDR" if obj.get("ktt") else "std::nullopt"
            ktt_setpoint = get_ref_field(obj, "ktt", "setpoint", "")
            lower_param = f"{obj['lower']}_IOA_ADDR" if obj.get("lower") else "std::nullopt"
            lower_setpoint = get_ref_field(obj, "lower", "setpoint", "")
            upper_setpoint = get_ref_field(obj, "upper", "setpoint", "")
            upper_param = f"{obj['upper']}_IOA_ADDR" if obj.get("upper") else "std::nullopt"
            setpoint_val = f"{obj['setpoint']}_IOA_ADDR" if obj.get("setpoint") else "std::nullopt"
            communications_content += f"""  mek_object_model->AddMeasurement(
    {{
            &GetInfoObject(ind_{code}),
            MEK::Priority::{second_class},
        
            {{{{
                {{
                    &GetInfoObject(ind_{ap_code}),
                    {{{{
                        &GetInfoObject(ind_{ap_code}),
                        MEK::Priority::{second_class},
                        {ap_setpoint},
                        {asdu_addr}
                    }}}}
                }},
                {ap_code}_IOA_ADDR,
                {asdu_addr}
            }}}},
            {{{{
                {{
                    &GetInfoObject(ind_{ktt_param}),
                    {{{{
                        &GetInfoObject(ind_{ktt_param}),
                        MEK::Priority::{second_class},
                        {ktt_setpoint},
                        {asdu_addr}
                    }}}}
                }},
                {ktt_param}_IOA_ADDR,
                {asdu_addr}
            }}}},
            {{{{
                {{
                    &GetInfoObject(ind_{lower_param}),
                    {{{{
                        &GetInfoObject(ind_{lower_param}),
                        MEK::Priority::{second_class},
                        {lower_setpoint},
                        {asdu_addr}
                    }}}}
                }},
                {lower_param}_IOA_ADDR,
                {asdu_addr}
            }}}},
            {{{{
                {{
                    &GetInfoObject(ind_{upper_param}),
                    {{{{
                        &GetInfoObject(ind_{upper_param}),
                        MEK::Priority::{second_class},  
                        {upper_setpoint},
                        {asdu_addr}
                    }}}}
                }},
                {upper_param}_IOA_ADDR,
                {asdu_addr}
            }}}}
         ,
        {code}_IOA_ADDR,
        {asdu_addr});
        """
        else:
            communications_content += (
                f"    mek_object_model->AddSetpointCommand({{&GetInfoObject(ind_{code}), "
                f"{{{{&GetInfoObject(ind_{code}), MEK::Priority::{second_class}, {ioa_addr}, {asdu_addr}}}}}}}, "
                f"{ioa_addr}, {asdu_addr});  // {name}\n"
            )

        # Map IO to command types by flags
        if norm_bool(obj.get("oi_c_bo_na_1")):
            communications_content += f"    mek_object_model->AssignIO_ForBO({ioa_addr}, {asdu_addr});\n"
        if norm_bool(obj.get("oi_c_dc_na_1")):
            communications_content += f"    mek_object_model->AssignIO_ForDC({ioa_addr}, {asdu_addr});\n"
        if norm_bool(obj.get("oi_c_sc_na_1")):
            communications_content += f"    mek_object_model->AssignIO_ForSC({ioa_addr}, {asdu_addr});\n"
        if norm_bool(obj.get("oi_c_se_na_1")):
            communications_content += f"    mek_object_model->AssignIO_ForSE_NA({ioa_addr}, {asdu_addr});\n"
        if norm_bool(obj.get("oi_c_se_nb_1")):
            communications_content += f"    mek_object_model->AssignIO_ForSE_NC({ioa_addr}, {asdu_addr});\n"

        # Protocol-specific configuration
        for prot in protos:
            ptype = prot.get("type")
            if ptype == "MEK_101":
                if not norm_bool(obj.get("allow_address_101")):
                    communications_content += f"    mek_101_server->AllowAddressUsage(false, {ioa_addr}, {asdu_addr});\n"
                sgrp = norm_str(obj.get("survey_group_101"))
                if sgrp and sgrp != "NOT_USE":
                    communications_content += f"    mek_101_server->DetermineGroupForIC(MEK::InterrogationGroup::{sgrp}, {ioa_addr}, {asdu_addr});\n"
                if not norm_bool(obj.get("use_in_back_101")):
                    communications_content += f"    mek_101_server->DetermineUsageInBC(false, {ioa_addr}, {asdu_addr});\n"
                if not norm_bool(obj.get("use_in_spont_101")):
                    communications_content += f"    mek_101_server->DetermineUsageInST(false, {ioa_addr}, {asdu_addr});\n"
                if not norm_bool(obj.get("use_in_percyc_101")):
                    communications_content += f"    mek_101_server->DetermineUsageInCP(false, {ioa_addr}, {asdu_addr});\n"

            # if ptype == "MEK_104":
            #     if norm_bool(obj.get("allow_address_104")):
            #         communications_content += f"    mek_104_server->AllowAddressUsage(true, {code}_MEK_IOA_ADDR;\n"
            #     sgrp = norm_str(obj.get("survey_group_104"))
            #     if sgrp and sgrp != "NOT_USE":
            #         communications_content += f"    mek_104_server->DetermineGroupForIC(MEK::InterrogationGroup::{sgrp}, {code}_MEK_IOA_ADDR;\n"
            #     if norm_bool(obj.get("use_in_back_104")):
            #         communications_content += f"    mek_104_server->DetermineUsageInBC(true, {code}_MEK_IOA_ADDR;\n"
            #     if norm_bool(obj.get("use_in_spont_104")):
            #         communications_content += f"    mek_104_server->DetermineUsageInST(true, {code}_MEK_IOA_ADDR;\n"
            #     if norm_bool(obj.get("use_in_percyc_104")):
            #         communications_content += f"    mek_104_server->DetermineUsageInCP(true, {code}_MEK_IOA_ADDR;\n"

    # ---------- finalize contents ----------
    total = len(data)

    info_objects_content += "}\n}\n"
    tele_content += "}\n}\n"
    telecommands_content += "}\n}\n"
    saved_parameters_content += "}\n}\n"
    communications_content += "}\n}\n"
    telemeasurements_content += "}\n}\n"
    mek_asdu_addresses += "\n"
    mek_ioa_addresses += "\n"

    # ---------- write files ----------
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
    with open("telemeasurements.cpp", "w", encoding="utf-8") as f:
        f.write(telemeasurements_content)
    with open("mek_asdu_addresses.h", "w", encoding="utf-8") as f:
        f.write(mek_asdu_addresses)
    with open("mek_ioa_addresses.h", "w", encoding="utf-8") as f:
        f.write(mek_ioa_addresses)

    print("Генерация завершена (patched).")
    return 0

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python Generator_patched.py <json_file>", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
