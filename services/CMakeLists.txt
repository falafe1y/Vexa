add_library(services STATIC
    AccountService.cpp
    AccountService.h

    ArchiveService.cpp
    ArchiveService.h

    CategoryService.cpp
    CategoryService.h

    OperationService.cpp
    OperationService.h

    LedgerReadService.cpp
    LedgerReadService.h

    ReadData.h

    LedgerService.cpp
    LedgerService.h

    SettingsService.h
    SettingsService.cpp
)

target_compile_features(services PUBLIC cxx_std_20)

target_include_directories(services
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(services
    PUBLIC
        Qt6::Core
        core_model
    PRIVATE
        core_db
)