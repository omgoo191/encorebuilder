cmake_minimum_required(VERSION 3.16)

project(Generator VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

#find_package(PythonInterp REQUIRED)
find_package(Qt6 6.7 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(PythonInterp REQUIRED)

qt_standard_project_setup()

qt_add_executable(appGenerator
    main.cpp
    saver.cpp
)

qt_add_qml_module(appGenerator
    URI Generator
    VERSION 1.0
    QML_FILES
        Main.qml
        ui/shell/AppShell.qml
        ui/components/TableHeaderRow.qml
        ui/dialogs/ManagerListDialog.qml
        ui/dialogs/StartupDialog.qml
        ui/tables/SignalTableView.qml
        ui/theme/Theme.qml
)

set(TS_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/i18n/app_ru.ts
)

find_program(LUPDATE_EXECUTABLE
    NAMES lupdate qt6-lupdate lupdate-qt6
)

if(LUPDATE_EXECUTABLE)
    add_custom_target(translations_update
        COMMAND ${LUPDATE_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/Main.qml
            ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
            -ts ${TS_FILES}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Updating Qt translation source files (.ts)"
    )
else()
    message(WARNING "Qt lupdate tool was not found. 'translations_update' target is unavailable.")
endif()

#set(PYTHON_SCRIPT "${CMAKE_SOURCE_DIR}/Generator.py")
#set(JSON_FILE "${CMAKE_SOURCE_DIR}/output/export.json")
#add_custom_target(runPythonScript ALL
#        COMMAND ${PYTHON_EXECUTABLE} ${PYTHON_SCRIPT} ${JSON_FILE}
#        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
#        COMMENT "�������")
# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appGenerator PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appGenerator
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appGenerator
    PRIVATE Qt6::Quick
)

include(GNUInstallDirs)
install(TARGETS appGenerator
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
