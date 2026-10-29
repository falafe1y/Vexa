# Core database: the SQLCipher connection and the schema; later repositories.
add_library(core_db STATIC
    Database.cpp
    Database.h
    DatabaseSchema.cpp
    DatabaseSchema.h
)
target_link_libraries(core_db PUBLIC core_model Qt6::Sql vexa_storage)
