cmake_minimum_required(VERSION 3.16)

project(Vexa VERSION 0.1.1 LANGUAGES CXX)

set(VEXA_PUBLISHER "Vishnevsky")
set(vexa_icon_dir "${CMAKE_CURRENT_SOURCE_DIR}/assets/icons")

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

if(ANDROID)
    if(CMAKE_HOST_WIN32)
        include("D:/Qt/android_openssl/android_openssl.cmake")
    else()
        include("/home/kega/Android/Sdk/android_openssl/android_openssl.cmake")
    endif()

    add_android_openssl_libraries(Vexa)
    set_target_properties(Vexa PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${vexa_icon_dir}/android"
        QT_ANDROID_APP_ICON "@mipmap/vexa_launcher"
    )
elseif(IOS)
    set(vexa_ios_icons "${vexa_icon_dir}/ios/Assets.xcassets")
    target_sources(Vexa PRIVATE "${vexa_ios_icons}")
    set_source_files_properties("${vexa_ios_icons}" PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources"
    )
    set_target_properties(Vexa PROPERTIES
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    )
elseif(APPLE)
    set(vexa_macos_icon "${vexa_icon_dir}/macos/Vexa.icns")
    target_sources(Vexa PRIVATE "${vexa_macos_icon}")
    set_source_files_properties("${vexa_macos_icon}" PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources"
    )
    set_target_properties(Vexa PROPERTIES MACOSX_BUNDLE_ICON_FILE "Vexa.icns")
endif()

if(NOT ANDROID AND NOT IOS)
    if(WIN32)
        set(vexa_window_icon "${vexa_icon_dir}/windows/vexa.png")
    else()
        set(vexa_window_icon "${vexa_icon_dir}/linux/hicolor/256x256/apps/vexa.png")
    endif()
    set_source_files_properties("${vexa_window_icon}" PROPERTIES QT_RESOURCE_ALIAS "vexa.png")
    qt_add_resources(Vexa "window_icon" PREFIX "/icons" FILES "${vexa_window_icon}")
endif()

option(VEXA_MOBILE_UI "Force the phone interface" OFF)
option(VEXA_TABLET_UI "Force the tablet interface" OFF)

if(ANDROID OR IOS OR VEXA_MOBILE_UI OR VEXA_TABLET_UI)
    set(vexa_ui_dir ui/mobile)
    set(vexa_ui_prefix Mobile)
    set(vexa_ui_theme MobileTheme)
    set(vexa_ui_entry_type MobileMainView)
    set(vexa_ui_entry_files ${vexa_ui_dir}/${vexa_ui_entry_type}.qml)
else()
    set(vexa_ui_dir ui/desktop)
    set(vexa_ui_prefix "")
    set(vexa_ui_theme DesktopTheme)
    set(vexa_ui_entry_type Main)
    set(vexa_ui_entry_files ${vexa_ui_entry_type}.qml ${vexa_ui_dir}/MainView.qml)
endif()

if(VEXA_TABLET_UI OR ((ANDROID OR IOS) AND NOT VEXA_MOBILE_UI))
    set(vexa_tablet_files
        ui/tablet/TabletMainView.qml
        ui/tablet/common/TabletPageHeader.qml
        ui/tablet/common/TabletSectionHeading.qml
        ui/tablet/common/TabletRowActions.qml
        ui/tablet/navigation/TabletSidebar.qml
        ui/tablet/pages/analytics/TabletAnalyticsPage.qml
        ui/tablet/pages/categories/TabletCategoriesPage.qml
        ui/tablet/pages/dashboard/TabletAccountCard.qml
        ui/tablet/pages/dashboard/TabletAccountsSection.qml
        ui/tablet/pages/dashboard/TabletAssetSummary.qml
        ui/tablet/pages/dashboard/TabletDashboardPage.qml
        ui/tablet/pages/dashboard/TabletHistoryRow.qml
        ui/tablet/pages/dashboard/TabletOperationButton.qml
        ui/tablet/pages/settings/TabletSettingsPage.qml
    )
    if(VEXA_TABLET_UI)
        set(vexa_ui_entry_type TabletMainView)
    else()
        target_compile_definitions(Vexa PRIVATE VEXA_AUTO_TABLET_UI)
    endif()
endif()

set_source_files_properties(
    ${vexa_ui_dir}/common/${vexa_ui_theme}.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(Vexa
    URI UI
    QML_FILES
        ${vexa_ui_entry_files}
        ${vexa_tablet_files}
        ui/common/ExpenseBreakdown.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}ActionButton.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}AmountField.qml
        ${vexa_ui_dir}/common/${vexa_ui_theme}.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}DialogActions.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}EditorialText.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}FormDialog.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}FormError.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}InputField.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}PageHeading.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}SelectField.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}BaseCurrencySelector.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}PopupMenu.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}PopupMenuItem.qml
        ${vexa_ui_dir}/common/${vexa_ui_prefix}ContextActionMenu.qml
        ${vexa_ui_dir}/pages/dashboard/${vexa_ui_prefix}AccountCard.qml
        ${vexa_ui_dir}/pages/dashboard/${vexa_ui_prefix}AccountsSection.qml
        ${vexa_ui_dir}/pages/dashboard/${vexa_ui_prefix}AssetSummary.qml
        ${vexa_ui_dir}/dialogs/${vexa_ui_prefix}AccountDialog.qml
        ${vexa_ui_dir}/dialogs/${vexa_ui_prefix}CategoryDialog.qml
        ${vexa_ui_dir}/dialogs/${vexa_ui_prefix}OperationDialog.qml
        ${vexa_ui_dir}/dialogs/${vexa_ui_prefix}RemovalDialog.qml
        ${vexa_ui_dir}/pages/dashboard/${vexa_ui_prefix}HistoryRow.qml
        ${vexa_ui_dir}/navigation/${vexa_ui_prefix}Sidebar.qml
        ${vexa_ui_dir}/pages/analytics/${vexa_ui_prefix}AnalyticsPage.qml
        ${vexa_ui_dir}/pages/categories/${vexa_ui_prefix}CategoriesPage.qml
        ${vexa_ui_dir}/pages/dashboard/${vexa_ui_prefix}DashboardPage.qml
        ${vexa_ui_dir}/pages/settings/${vexa_ui_prefix}SettingsPage.qml
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

target_compile_definitions(Vexa PRIVATE
    "VEXA_VERSION=\"${PROJECT_VERSION}\""
    "VEXA_UI_ENTRY_TYPE=\"${vexa_ui_entry_type}\""
)

target_link_libraries(Vexa
    PRIVATE
    Qt6::Quick
    Qt6::Sql
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
    set_source_files_properties("${CMAKE_CURRENT_BINARY_DIR}/version.rc" PROPERTIES
        OBJECT_DEPENDS "${vexa_icon_dir}/windows/vexa.ico"
    )
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT ANDROID)
    install(
        FILES cmake/vexa.desktop
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
    )
    install(
        DIRECTORY "${vexa_icon_dir}/linux/hicolor/"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor"
    )
endif()
