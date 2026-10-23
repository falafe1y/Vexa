cmake_minimum_required(VERSION 3.16)

project(vexa VERSION 0.1 LANGUAGES C CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 QuickDialogs2 Sql Network Concurrent Svg)
find_package(ZLIB REQUIRED)
if(ANDROID)
    include(cmake/VexaAndroidOpenSSL.cmake)
endif()
add_subdirectory(core)
add_subdirectory(security)
add_subdirectory(storage)

qt_standard_project_setup(REQUIRES 6.10)

if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(vexa
    main.cpp
    resources.qrc
    services/BankRecipients.qrc
)

target_sources(vexa PRIVATE editorial-fonts.qrc)

set_source_files_properties(
    ui/mobile/MobileTheme.qml
    ui/mobile/MobileBackStack.qml
    ui/mobile/MobileFormat.qml
    ui/mobile/MobileAnalytics.qml
    ui/mobile/MobileMetricDefinitions.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(vexa
    URI Vexa
    QML_FILES
        ui/security/AccessWindow.qml
        ui/security/DatabaseWindow.qml
        ui/mobile/Mobile.qml
        ui/mobile/MobileText.qml
        ui/mobile/MobilePageHeader.qml
        ui/mobile/MobileDisclosure.qml
        ui/mobile/MobileAverageReturnPanel.qml
        ui/mobile/MobileEditorialOverview.qml
        ui/mobile/MobileCategoriesPage.qml
        ui/mobile/MobileTheme.qml
        ui/mobile/MobileBackStack.qml
        ui/mobile/MobileFormat.qml
        ui/mobile/MobileIcon.qml
        ui/mobile/MobileSvgIcon.qml
        ui/mobile/MobileCard.qml
        ui/mobile/MobileButton.qml
        ui/mobile/MobileChip.qml
        ui/mobile/MobileSegmented.qml
        ui/mobile/MobileField.qml
        ui/mobile/MobileCheckRow.qml
        ui/mobile/MobileAutoBackupSettings.qml
        ui/mobile/MobileListRow.qml
        ui/mobile/MobileIconButton.qml
        ui/mobile/MobileFab.qml
        ui/mobile/MobileProgress.qml
        ui/mobile/MobileSheet.qml
        ui/mobile/MobileTabBar.qml
        ui/mobile/MobileEmptyState.qml
        ui/mobile/MobileMorePage.qml
        ui/mobile/MobileNotesPage.qml
        ui/mobile/MobileBudgetsPage.qml
        ui/mobile/MobileBudgetSheet.qml
        ui/mobile/MobileGoalsPage.qml
        ui/mobile/MobileGoalSheet.qml
        ui/mobile/MobileCostBasisSheet.qml
        ui/mobile/MobileProjectsPage.qml
        ui/mobile/MobileProjectPage.qml
        ui/mobile/MobileTrajectoryPage.qml
        ui/mobile/MobileScheduledPage.qml
        ui/mobile/MobileDataPage.qml
        ui/mobile/MobileAnalytics.qml
        ui/mobile/MobileMetricDefinitions.qml
        ui/mobile/MobileMetricSheet.qml
        ui/mobile/MobileInfoButton.qml
        ui/mobile/MobileSeriesChart.qml
        ui/mobile/MobileBarChart.qml
        ui/mobile/MobileInvestmentDataQuality.qml
        ui/mobile/MobileInvestmentBenchmark.qml
        ui/mobile/MobileInvestmentDeposit.qml
        ui/mobile/MobileInvestmentRisk.qml
        ui/mobile/MobileInvestmentStructure.qml
        ui/mobile/MobileInvestmentPayments.qml
        ui/mobile/MobileInvestmentPerformance.qml
        ui/mobile/MobileAnalyticsPage.qml
        ui/computer/analytics/EditorialAnalyticsPage.qml
        ui/computer/analytics/EditorialAverageReturn.qml
        ui/computer/analytics/CostBasisDialog.qml
        ui/computer/categories/EditorialCategoriesPage.qml
        ui/computer/common/EditorialChart.qml
        ui/computer/common/EditorialCheck.qml
        ui/computer/common/EditorialChoice.qml
        ui/computer/common/EditorialDialog.qml
        ui/computer/common/EditorialDialogTitle.qml
        ui/computer/common/EditorialDialogForm.qml
        ui/computer/common/EditorialScrollView.qml
        ui/computer/common/EditorialLabel.qml
        ui/computer/common/EditorialStyle.js
        ui/computer/common/EditorialRowLayout.qml
        ui/computer/common/EditorialColumnLayout.qml
        ui/computer/common/EditorialMenu.qml
        ui/computer/common/EditorialMenuItem.qml
        ui/computer/common/EditorialDonut.qml
        ui/computer/common/EditorialField.qml
        ui/computer/common/EditorialLedgerPage.qml
        ui/computer/common/EditorialLegend.qml
        ui/computer/common/EditorialMasthead.qml
        ui/computer/common/EditorialMetrics.qml
        ui/computer/common/EditorialOperations.qml
        ui/computer/common/EditorialPage.qml
        ui/computer/common/EditorialReportSection.qml
        ui/computer/common/EditorialSection.qml
        ui/computer/common/EditorialSettingRow.qml
        ui/computer/notes/EditorialNotesPage.qml
        ui/computer/settings/EditorialSettingsPage.qml
        ui/computer/common/AutoScrollController.qml
        ui/computer/common/CachedPages.qml
        ui/computer/common/HardShadow.qml
        ui/computer/common/MiddleScrollArea.qml
        ui/computer/common/StyledButton.qml
        ui/computer/common/StyledCheckBox.qml
        ui/computer/common/StyledComboBox.qml
        ui/computer/common/StyledScrollBar.qml
        ui/computer/common/StyledTextField.qml
        ui/computer/common/SurfaceShadow.qml
        ui/computer/dashboard/EditorialText.qml
        ui/computer/dashboard/EditorialArrow.qml
        ui/computer/dashboard/EditorialAction.qml
        ui/computer/dashboard/EditorialSidebar.qml
        ui/computer/dashboard/EditorialDashboard.qml
        ui/computer/dashboard/DashboardData.js
        ui/computer/Desktop.qml
        ui/computer/accounts/InvestmentPositionDialog.qml
        ui/computer/accounts/InvestmentPositionsPanel.qml
        ui/computer/operations/BankCsvImportDialog.qml
        ui/computer/operations/BrokerOperationDialog.qml
        ui/computer/operations/InvestmentOperationDialog.qml
        ui/computer/operations/RecurringTransactionsDialog.qml
        ui/computer/budgets/BudgetDialog.qml
        ui/computer/goals/FinancialGoalDialog.qml
        ui/computer/goals/FinancialGoalsPage.qml
        ui/computer/trajectory/FinancialTrajectoryPage.qml
        ui/computer/analytics/InvestmentBenchmarkPanel.qml
        ui/computer/analytics/InvestmentDataQualityPanel.qml
        ui/computer/analytics/InvestmentDepositPanel.qml
        ui/computer/analytics/InvestmentMetricHelp.qml
        ui/computer/analytics/InvestmentPaymentsPanel.qml
        ui/computer/analytics/InvestmentPerformancePanel.qml
        ui/computer/analytics/AverageReturnPanel.qml
        ui/computer/analytics/InvestmentRiskPanel.qml
        ui/computer/analytics/InvestmentStructurePanel.qml
        ui/computer/settings/BackupDialogs.qml
        ui/computer/settings/DatabaseEncryptionSettings.qml
        ui/computer/settings/AutoBackupSettings.qml
        ui/computer/settings/PasswordSettings.qml
        # BankComboBox.qml
        # CategoryPicker.qml
        SOURCES ui/computer/notes/NotebookLayout.h
        SOURCES ui/computer/common/WindowScrollInput.h
        SOURCES ui/computer/common/WindowScrollInput.cpp
        SOURCES services/FinancialGoalCalculator.h
        SOURCES services/FinancialGoalCalculator.cpp
        SOURCES services/FinancialTrajectoryCalculator.h
        SOURCES services/FinancialTrajectoryCalculator.cpp
        SOURCES services/InvestmentBenchmark.h
        SOURCES services/InvestmentBenchmark.cpp
        SOURCES services/InvestmentBenchmarkProvider.h
        SOURCES services/InvestmentBenchmarkProvider.cpp
        SOURCES interface/FinanceControllerBenchmark.cpp
        SOURCES interface/FinanceControllerPerformance.cpp
        SOURCES services/CsvCodec.h
        SOURCES services/CsvCodec.cpp
        SOURCES services/ContentUriIo.h
        SOURCES services/BankCsvImporter.h
        SOURCES services/BankCsvImporter.cpp
        SOURCES services/BankRecipientMatcher.h
        SOURCES services/BankRecipientMatcher.cpp
        SOURCES services/BankImportReview.h
        SOURCES services/BankImportReview.cpp
        SOURCES services/BankCategoryMatcher.h
        SOURCES services/BankCategoryMatcher.cpp
        SOURCES services/PdfStatementReader.h
        SOURCES services/PdfStatementReader.cpp
        SOURCES services/XlsxReader.h
        SOURCES services/XlsxReader.cpp
        SOURCES services/CapitalHistoryCalculator.h
        SOURCES services/CapitalHistoryCalculator.cpp
        SOURCES services/CurrencyRateCache.h
        SOURCES services/CurrencyRateCache.cpp
        SOURCES services/CbrCurrencyRateProvider.h
        SOURCES services/CbrCurrencyRateProvider.cpp
        SOURCES services/CbrFxHistory.h
        SOURCES services/CbrFxHistory.cpp
        SOURCES services/TronUsdtParser.h
        SOURCES services/TronUsdtParser.cpp
        SOURCES services/CryptoParser.h
        SOURCES services/CryptoParser.cpp
        SOURCES services/CryptoProvider.h
        SOURCES services/CryptoProvider.cpp
        SOURCES services/BybitProvider.h
        SOURCES services/BybitProvider.cpp
        SOURCES services/ExchangeCredentials.h
        SOURCES services/ExchangeCredentials.cpp
        SOURCES services/MoexInvestmentParser.h
        SOURCES services/MoexInvestmentParser.cpp
        SOURCES services/MoexInvestmentProvider.h
        SOURCES services/MoexInvestmentProvider.cpp
        SOURCES interface/FinanceController.h
        SOURCES interface/FinanceController.cpp
        SOURCES persistence/FinanceRepository.h
        SOURCES persistence/FinanceRepository.cpp
        SOURCES persistence/FinanceRepositoryHistory.cpp
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(vexa PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.vexa
    MACOSX_BUNDLE_BUNDLE_NAME Vexa
    QT_ANDROID_APP_NAME Vexa
    QT_ANDROID_APP_ICON "@mipmap/vexa"
    QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/packaging/android"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(vexa
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::QuickDialogs2
        Qt6::Sql
        Qt6::Network
        Qt6::Concurrent
        Qt6::Svg
        ZLIB::ZLIB
        core
        vexa_access
        vexa_storage
)

if(ANDROID)
    vexa_deploy_android_openssl(vexa)
endif()
# Full debug information of the Qt Quick UI does not fit the 32-bit relocations of the Android linker;
# the APK ships without it, so the linker drops it.
if(ANDROID)
    target_link_options(vexa PRIVATE "-Wl,--strip-debug")
endif()

if(WIN32)
    enable_language(RC)
    configure_file(packaging/windows/vexa.rc.in
        "${CMAKE_CURRENT_BINARY_DIR}/vexa.rc" @ONLY)
    target_sources(vexa PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/vexa.rc")
    target_link_libraries(vexa PRIVATE crypt32)
endif()

install(TARGETS vexa
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(UNIX AND NOT APPLE AND NOT ANDROID)
    install(FILES packaging/linux/vexa.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES assets/icons/app/vexa.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
    install(FILES assets/icons/app/vexa.png
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/512x512/apps)
endif()

# Tests are slow to build on low-end machines. They are ON everywhere except Linux,
# where they are OFF by default. Override with -DVEXA_BUILD_TESTS=ON|OFF.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(VEXA_BUILD_TESTS_DEFAULT OFF)
else()
    set(VEXA_BUILD_TESTS_DEFAULT ON)
endif()
option(VEXA_BUILD_TESTS "Build unit and QML tests" ${VEXA_BUILD_TESTS_DEFAULT})
if(VEXA_BUILD_TESTS)
enable_testing()

if (NOT ANDROID)
find_package(Qt6 REQUIRED COMPONENTS Test)

add_executable(CurrencyConverterTest
    tests/CurrencyConverterTest.cpp
)

target_link_libraries(CurrencyConverterTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME CurrencyConverterTest
    COMMAND CurrencyConverterTest
)

add_executable(CurrencyRateCacheTest
    tests/CurrencyRateCacheTest.cpp
    services/CurrencyRateCache.cpp
    services/CbrCurrencyRateProvider.cpp
    services/CbrFxHistory.cpp
)

target_link_libraries(CurrencyRateCacheTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Network
        Qt6::Test
)

add_test(
    NAME CurrencyRateCacheTest
    COMMAND CurrencyRateCacheTest
)

add_executable(BalanceCalculatorTest
    tests/BalanceCalculatorTest.cpp
)

target_link_libraries(BalanceCalculatorTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME BalanceCalculatorTest
    COMMAND BalanceCalculatorTest
)

add_executable(TransactionDateFilterTest
    tests/TransactionDateFilterTest.cpp
)

target_link_libraries(TransactionDateFilterTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME TransactionDateFilterTest
    COMMAND TransactionDateFilterTest
)

add_executable(DepositInterestCalculatorTest
    tests/DepositInterestCalculatorTest.cpp
)

target_link_libraries(DepositInterestCalculatorTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME DepositInterestCalculatorTest
    COMMAND DepositInterestCalculatorTest
)

add_executable(FinanceRepositoryTest
    tests/FinanceRepositoryTest.cpp
    persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp
)

target_link_libraries(FinanceRepositoryTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Sql
        Qt6::Test
)

add_test(
    NAME FinanceRepositoryTest
    COMMAND FinanceRepositoryTest
)

file(GLOB investment_controller_test_sources CONFIGURE_DEPENDS
    services/*.cpp persistence/*.cpp interface/*.cpp)
add_executable(InvestmentControllerTest tests/InvestmentControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(InvestmentControllerTest PRIVATE core Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(InvestmentControllerTest PRIVATE crypt32)
endif()
add_test(NAME InvestmentControllerTest COMMAND InvestmentControllerTest)

add_executable(BackupRestoreControllerTest tests/BackupRestoreControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(BackupRestoreControllerTest PRIVATE core Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(BackupRestoreControllerTest PRIVATE crypt32)
endif()
add_test(NAME BackupRestoreControllerTest COMMAND BackupRestoreControllerTest)

add_executable(InvestmentAccountingRepositoryTest tests/InvestmentAccountingRepositoryTest.cpp
    persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp)
target_link_libraries(InvestmentAccountingRepositoryTest PRIVATE core_model Qt6::Core Qt6::Sql Qt6::Test)
add_test(NAME InvestmentAccountingRepositoryTest COMMAND InvestmentAccountingRepositoryTest)

add_executable(InvestmentValuationTest tests/InvestmentValuationTest.cpp)
target_link_libraries(InvestmentValuationTest PRIVATE core_model Qt6::Core Qt6::Test)
add_test(NAME InvestmentValuationTest COMMAND InvestmentValuationTest)

add_executable(InvestmentModelTest
    tests/InvestmentModelTest.cpp
)

target_link_libraries(InvestmentModelTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME InvestmentModelTest
    COMMAND InvestmentModelTest
)

add_executable(InvestmentRepositoryTest
    tests/InvestmentRepositoryTest.cpp
    persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp
)

target_link_libraries(InvestmentRepositoryTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Sql
        Qt6::Test
)

add_test(
    NAME InvestmentRepositoryTest
    COMMAND InvestmentRepositoryTest
)

add_executable(MoexInvestmentParserTest
    tests/MoexInvestmentParserTest.cpp
    services/MoexInvestmentParser.cpp
)

target_link_libraries(MoexInvestmentParserTest
    PRIVATE
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME MoexInvestmentParserTest
    COMMAND MoexInvestmentParserTest
)

add_executable(CsvCodecTest
    tests/CsvCodecTest.cpp
    services/CsvCodec.cpp
)

target_link_libraries(CsvCodecTest
    PRIVATE
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME CsvCodecTest
    COMMAND CsvCodecTest
)

add_executable(BankCsvImporterTest
    tests/BankCsvImporterTest.cpp
    services/BankCsvImporter.cpp
    services/PdfStatementReader.cpp
    services/CsvCodec.cpp
    services/XlsxReader.cpp
)

target_link_libraries(BankCsvImporterTest
    PRIVATE
        Qt6::Core
        Qt6::Test
        ZLIB::ZLIB
)

add_test(
    NAME BankCsvImporterTest
    COMMAND BankCsvImporterTest
)

add_executable(TronUsdtParserTest
    tests/TronUsdtParserTest.cpp
    services/TronUsdtParser.cpp
)

target_link_libraries(TronUsdtParserTest
    PRIVATE
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME TronUsdtParserTest
    COMMAND TronUsdtParserTest
)

add_executable(CryptoParserTest
    tests/CryptoParserTest.cpp
    services/CryptoParser.cpp
)

target_link_libraries(CryptoParserTest
    PRIVATE
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME CryptoParserTest
    COMMAND CryptoParserTest
)

add_executable(CapitalHistoryCalculatorTest
    tests/CapitalHistoryCalculatorTest.cpp
    services/CapitalHistoryCalculator.cpp
)

target_link_libraries(CapitalHistoryCalculatorTest
    PRIVATE
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME CapitalHistoryCalculatorTest
    COMMAND CapitalHistoryCalculatorTest
)

add_executable(FinancialGoalCalculatorTest
    tests/FinancialGoalCalculatorTest.cpp
    services/FinancialGoalCalculator.cpp
)
target_link_libraries(FinancialGoalCalculatorTest PRIVATE core_model Qt6::Core Qt6::Test)
add_test(NAME FinancialGoalCalculatorTest COMMAND FinancialGoalCalculatorTest)

add_executable(FinancialTrajectoryCalculatorTest
    tests/FinancialTrajectoryCalculatorTest.cpp
    services/FinancialTrajectoryCalculator.cpp
)
target_link_libraries(FinancialTrajectoryCalculatorTest PRIVATE Qt6::Core Qt6::Test)
add_test(NAME FinancialTrajectoryCalculatorTest COMMAND FinancialTrajectoryCalculatorTest)

add_executable(RecurringScheduleCalculatorTest
    tests/RecurringScheduleCalculatorTest.cpp
)

target_link_libraries(RecurringScheduleCalculatorTest
    PRIVATE
        core_model
        Qt6::Core
        Qt6::Test
)

add_test(
    NAME RecurringScheduleCalculatorTest
    COMMAND RecurringScheduleCalculatorTest
)
endif()

add_executable(PdfStatementReaderTest
    tests/PdfStatementReaderTest.cpp
    services/PdfStatementReader.cpp
    services/BankCsvImporter.cpp
    services/CsvCodec.cpp
    services/XlsxReader.cpp
)
target_link_libraries(PdfStatementReaderTest PRIVATE Qt6::Core Qt6::Gui Qt6::Test ZLIB::ZLIB)
add_test(NAME PdfStatementReaderTest COMMAND PdfStatementReaderTest)

# Scheduling, names and retention of automatic copies; no platform store is touched.
add_executable(AutoBackupTest
    tests/AutoBackupTest.cpp
    storage/AutoBackup.cpp
)
target_link_libraries(AutoBackupTest PRIVATE Qt6::Core Qt6::Test)
add_test(NAME AutoBackupTest COMMAND AutoBackupTest)

# Bank PDF statements are always read with Poppler's pdftotext.

add_executable(BybitProviderTest
    tests/BybitProviderTest.cpp
    services/BybitProvider.cpp
    persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp
)
target_link_libraries(BybitProviderTest PRIVATE core_model Qt6::Core Qt6::Test Qt6::Network Qt6::Sql)
add_test(NAME BybitProviderTest COMMAND BybitProviderTest)

add_executable(BankCategoryMatcherTest
    tests/BankCategoryMatcherTest.cpp
    services/BankCategoryMatcher.cpp
    services/BankRecipientMatcher.cpp
    services/BankRecipients.qrc
)
target_link_libraries(BankCategoryMatcherTest PRIVATE Qt6::Core Qt6::Test)
add_test(NAME BankCategoryMatcherTest COMMAND BankCategoryMatcherTest)

add_executable(BankImportReviewTest tests/BankImportReviewTest.cpp
    services/BankImportReview.cpp services/BankCategoryMatcher.cpp services/BankRecipientMatcher.cpp services/BankRecipients.qrc)
target_link_libraries(BankImportReviewTest PRIVATE Qt6::Core Qt6::Test)
add_test(NAME BankImportReviewTest COMMAND BankImportReviewTest)

add_executable(BankImportControllerTest tests/BankImportControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(BankImportControllerTest PRIVATE core Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(BankImportControllerTest PRIVATE crypt32)
endif()
add_test(NAME BankImportControllerTest COMMAND BankImportControllerTest)

add_executable(WindowScrollInputTest tests/WindowScrollInputTest.cpp ui/computer/common/WindowScrollInput.cpp)
target_link_libraries(WindowScrollInputTest PRIVATE Qt6::Gui Qt6::Test)
add_test(NAME WindowScrollInputTest COMMAND WindowScrollInputTest)
set_tests_properties(WindowScrollInputTest PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

if(NOT ANDROID)
    add_executable(PasswordLockTest tests/PasswordLockTest.cpp)
    target_link_libraries(PasswordLockTest PRIVATE vexa_access Qt6::Test)
    add_test(NAME PasswordLockTest COMMAND PasswordLockTest)
endif()

if(NOT ANDROID)
    add_executable(AppAccessTest tests/AppAccessTest.cpp)
    target_link_libraries(AppAccessTest PRIVATE vexa_access Qt6::Test)
    add_test(NAME AppAccessTest COMMAND AppAccessTest)
endif()

get_property(vexa_targets DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
foreach(vexa_target IN LISTS vexa_targets)
    get_target_property(vexa_target_type ${vexa_target} TYPE)
    if(vexa_target_type STREQUAL "EXECUTABLE")
        target_link_libraries(${vexa_target} PRIVATE vexa_storage)
    endif()
endforeach()

if(NOT ANDROID)
    add_executable(DatabaseEncryptionTest tests/DatabaseEncryptionTest.cpp
        persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp)
    target_link_libraries(DatabaseEncryptionTest PRIVATE core_model vexa_storage Qt6::Test)
    add_test(NAME DatabaseEncryptionTest COMMAND DatabaseEncryptionTest)
endif()

target_compile_definitions(vexa PRIVATE VEXA_APP_VERSION="${PROJECT_VERSION}")

add_executable(PortableBackupTest tests/PortableBackupTest.cpp
    persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp)
target_link_libraries(PortableBackupTest PRIVATE core_model vexa_storage Qt6::Test)
add_test(NAME PortableBackupTest COMMAND PortableBackupTest)

add_executable(AnalyticsHistoryRepositoryTest tests/AnalyticsHistoryRepositoryTest.cpp
    persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp)
target_link_libraries(AnalyticsHistoryRepositoryTest PRIVATE core_model vexa_storage Qt6::Test Qt6::Sql)
add_test(NAME AnalyticsHistoryRepositoryTest COMMAND AnalyticsHistoryRepositoryTest)

add_executable(AnalyticsHistoryControllerTest tests/AnalyticsHistoryControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(AnalyticsHistoryControllerTest PRIVATE core vexa_storage Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(AnalyticsHistoryControllerTest PRIVATE crypt32)
endif()
add_test(NAME AnalyticsHistoryControllerTest COMMAND AnalyticsHistoryControllerTest)

add_executable(InvestmentPerformanceTest tests/InvestmentPerformanceTest.cpp)
target_link_libraries(InvestmentPerformanceTest PRIVATE core_model Qt6::Core Qt6::Test)
add_test(NAME InvestmentPerformanceTest COMMAND InvestmentPerformanceTest)
add_executable(AverageReturnTest tests/AverageReturnTest.cpp)
target_link_libraries(AverageReturnTest PRIVATE core_model Qt6::Core Qt6::Test)
add_test(NAME AverageReturnTest COMMAND AverageReturnTest)
add_executable(AverageReturnControllerTest tests/AverageReturnControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(AverageReturnControllerTest PRIVATE core vexa_storage Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
add_test(NAME AverageReturnControllerTest COMMAND AverageReturnControllerTest)

add_executable(CryptoCostBasisTest tests/CryptoCostBasisTest.cpp)
target_link_libraries(CryptoCostBasisTest PRIVATE core_model Qt6::Core Qt6::Test)
add_test(NAME CryptoCostBasisTest COMMAND CryptoCostBasisTest)

add_executable(CbrFxHistoryTest tests/CbrFxHistoryTest.cpp services/CbrFxHistory.cpp)
target_link_libraries(CbrFxHistoryTest PRIVATE Qt6::Core Qt6::Test)
add_test(NAME CbrFxHistoryTest COMMAND CbrFxHistoryTest)

add_executable(CreditDebtFlagControllerTest tests/CreditDebtFlagControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(CreditDebtFlagControllerTest PRIVATE core vexa_storage Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
add_test(NAME CreditDebtFlagControllerTest COMMAND CreditDebtFlagControllerTest)

add_executable(TrajectoryControllerTest tests/TrajectoryControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(TrajectoryControllerTest PRIVATE core vexa_storage Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
add_test(NAME TrajectoryControllerTest COMMAND TrajectoryControllerTest)

add_executable(InvestmentStructureIncomeTest tests/InvestmentStructureIncomeTest.cpp)
target_link_libraries(InvestmentStructureIncomeTest PRIVATE core_model Qt6::Core Qt6::Test)
add_test(NAME InvestmentStructureIncomeTest COMMAND InvestmentStructureIncomeTest)

add_executable(InvestmentPerformanceControllerTest tests/InvestmentPerformanceControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(InvestmentPerformanceControllerTest PRIVATE core vexa_storage Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(InvestmentPerformanceControllerTest PRIVATE crypt32)
endif()
add_test(NAME InvestmentPerformanceControllerTest COMMAND InvestmentPerformanceControllerTest)

add_executable(InvestmentRiskTest tests/InvestmentRiskTest.cpp)
target_compile_features(InvestmentRiskTest PRIVATE cxx_std_17)
target_link_libraries(InvestmentRiskTest PRIVATE core_model)
add_test(NAME InvestmentRiskTest COMMAND InvestmentRiskTest)

add_executable(InvestmentBenchmarkTest tests/InvestmentBenchmarkTest.cpp services/InvestmentBenchmark.cpp)
target_link_libraries(InvestmentBenchmarkTest PRIVATE Qt6::Core Qt6::Test)
add_test(NAME InvestmentBenchmarkTest COMMAND InvestmentBenchmarkTest)

add_executable(InvestmentBenchmarkRepositoryTest tests/InvestmentBenchmarkRepositoryTest.cpp persistence/FinanceRepository.cpp persistence/FinanceRepositoryHistory.cpp services/InvestmentBenchmark.cpp)
target_link_libraries(InvestmentBenchmarkRepositoryTest PRIVATE core_model vexa_storage Qt6::Test Qt6::Sql)
add_test(NAME InvestmentBenchmarkRepositoryTest COMMAND InvestmentBenchmarkRepositoryTest)
add_executable(InvestmentBenchmarkControllerTest tests/InvestmentBenchmarkControllerTest.cpp ${investment_controller_test_sources} services/BankRecipients.qrc)
target_link_libraries(InvestmentBenchmarkControllerTest PRIVATE core vexa_storage Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(InvestmentBenchmarkControllerTest PRIVATE crypt32)
endif()
add_test(NAME InvestmentBenchmarkControllerTest COMMAND InvestmentBenchmarkControllerTest)

find_package(Qt6 QUIET COMPONENTS QuickTest)
if(TARGET Qt6::QuickTest)
    add_executable(UiNavigationTest tests/UiNavigationTest.cpp ui/computer/notes/NotebookLayout.h)
    target_link_libraries(UiNavigationTest PRIVATE Qt6::QuickTest Qt6::QuickControls2)
    target_compile_definitions(UiNavigationTest PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/qml")
    add_test(NAME UiNavigationTest COMMAND UiNavigationTest)
    set_tests_properties(UiNavigationTest PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
endif()
endif()
