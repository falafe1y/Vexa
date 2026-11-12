cmake_minimum_required(VERSION 3.16)

project(Vexa VERSION 0.0.2 LANGUAGES CXX)

set(VEXA_PUBLISHER "Vishnevsky")

if(WIN32)
    enable_language(RC)

    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/version.rc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/version.rc"
        @ONLY
    )
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Sql Network)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

add_subdirectory(core/model)
add_subdirectory(core/db)
add_subdirectory(services)
add_subdirectory(interfaces)

qt_add_executable(Vexa
    main.cpp
)

set_source_files_properties(
    ui/desktop/common/DesktopTheme.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(Vexa
    URI UI
    QML_FILES
        Main.qml
        ui/desktop/MainView.qml
        ui/desktop/common/ActionButton.qml
        ui/desktop/common/DesktopTheme.qml
        ui/desktop/common/DialogActions.qml
        ui/desktop/common/EditorialText.qml
        ui/desktop/common/FormDialog.qml
        ui/desktop/common/FormError.qml
        ui/desktop/common/InputField.qml
        ui/desktop/common/PageHeading.qml
        ui/desktop/common/SelectField.qml
        ui/desktop/common/BaseCurrencySelector.qml
        ui/desktop/common/PopupMenu.qml
        ui/desktop/common/PopupMenuItem.qml
        ui/desktop/pages/dashboard/AccountCard.qml
        ui/desktop/pages/dashboard/AccountsSection.qml
        ui/desktop/pages/dashboard/AssetSummary.qml
        ui/desktop/dialogs/AccountDialog.qml
        ui/desktop/dialogs/CategoryDialog.qml
        ui/desktop/dialogs/OperationDialog.qml
        ui/desktop/dialogs/RemovalDialog.qml
        ui/desktop/pages/dashboard/HistoryRow.qml
        ui/desktop/navigation/Sidebar.qml
        ui/desktop/pages/categories/CategoriesPage.qml
        ui/desktop/pages/dashboard/DashboardPage.qml
        ui/desktop/pages/settings/SettingsPage.qml
)

# Exactly the editorial font files used by Vexa-original. Qt ships them with the app.
qt_add_resources(Vexa "editorial_fonts"
    PREFIX "/fonts/editorial"
    BASE "assets/fonts/editorial"
    FILES
        assets/fonts/editorial/Arimo-400-normal.ttf
        assets/fonts/editorial/Arimo-700-normal.ttf
        assets/fonts/editorial/Cousine-400-normal.ttf
        assets/fonts/editorial/Cousine-700-normal.ttf
        assets/fonts/editorial/Gelasio-400-italic.ttf
        assets/fonts/editorial/Gelasio-700-italic.ttf
        assets/fonts/editorial/PTSerif-400-normal.ttf
        assets/fonts/editorial/PTSerif-400-italic.ttf
        assets/fonts/editorial/PTSerif-700-normal.ttf
        assets/fonts/editorial/PTSerif-700-italic.ttf
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(Vexa PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.Vexa
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_compile_definitions(Vexa PRIVATE "VEXA_VERSION=\"${PROJECT_VERSION}\"")

target_link_libraries(Vexa
    PRIVATE
    Qt6::Quick
    core_model
    core_db
    services
    interfaces
)

if(WIN32 AND MINGW)
    target_link_options(Vexa PRIVATE
        -static-libgcc
        -static-libstdc++
    )
endif()

install(TARGETS Vexa
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(WIN32)
    target_sources(Vexa PRIVATE
        "${CMAKE_CURRENT_BINARY_DIR}/version.rc"
    )
endif()
