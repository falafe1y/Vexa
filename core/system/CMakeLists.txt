# Core system: what comes from the operating system — files and content:// documents,
# CSV, XLSX and PDF statements, the stores of secrets (Windows Credential Manager,
# Secret Service, Android Keystore); later system events.
add_library(core_system STATIC
    AndroidVault.cpp
    AndroidVault.h
    BankCsvImporter.cpp
    BankCsvImporter.h
    ContentUriIo.cpp
    ContentUriIo.h
    CsvCodec.cpp
    CsvCodec.h
    ExchangeCredentials.cpp
    ExchangeCredentials.h
    PasswordStore.cpp
    PasswordStore.h
    PdfStatementReader.cpp
    PdfStatementReader.h
    XlsxReader.cpp
    XlsxReader.h
)
target_link_libraries(core_system PUBLIC core_model Qt6::Core ZLIB::ZLIB)
if(WIN32)
    target_link_libraries(core_system PRIVATE advapi32 crypt32)
elseif(UNIX AND NOT APPLE AND NOT ANDROID)
    find_package(Qt6 REQUIRED COMPONENTS DBus)
    target_link_libraries(core_system PUBLIC Qt6::DBus)
endif()
