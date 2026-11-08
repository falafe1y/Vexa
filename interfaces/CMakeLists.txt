add_library(interfaces STATIC
    LedgerInterface.h
    LedgerInterface.cpp
    LedgerInterfaceCommands.cpp
)

target_include_directories(interfaces
    PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(interfaces
    PUBLIC
        Qt6::Core
        services
    PRIVATE
        core_model
)
