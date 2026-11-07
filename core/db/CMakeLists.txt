add_library(core_db STATIC
    Database.cpp
    Database.h
)

target_include_directories(core_db PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

target_link_libraries(core_db
    PUBLIC Qt6::Core core_model
    PRIVATE Qt6::Sql
)
