# Core system: what comes from the operating system — files and content:// documents,
# CSV, XLSX and PDF statements, later the stores of secrets and system events.
add_library(core_system STATIC
    ContentUriIo.cpp
    ContentUriIo.h
    CsvCodec.cpp
    CsvCodec.h
    PdfStatementReader.cpp
    PdfStatementReader.h
    XlsxReader.cpp
    XlsxReader.h
)
target_link_libraries(core_system PUBLIC Qt6::Core ZLIB::ZLIB)
