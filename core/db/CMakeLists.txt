# Core database: the SQLCipher connection; later migrations and repositories.
add_library(core_db STATIC
    Database.cpp
    Database.h
)
target_link_libraries(core_db PUBLIC Qt6::Sql vexa_storage)
