add_library(services STATIC
    LedgerService.cpp
    LedgerService.h
)

target_compile_features(services PUBLIC cxx_std_20)

target_include_directories(services
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(services
    PUBLIC
        Qt6::Core
    PRIVATE
        core_model
        core_db
)
