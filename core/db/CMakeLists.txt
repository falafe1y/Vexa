# Core database: the SQLCipher connection, the schema and the repositories.
add_library(core_db STATIC
    Database.cpp
    Database.h
    DatabaseSchema.cpp
    DatabaseSchema.h
    NotesRepository.cpp
    NotesRepository.h
)
target_link_libraries(core_db PUBLIC core_model Qt6::Sql vexa_storage)
