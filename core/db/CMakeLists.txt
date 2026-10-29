# Core database: the SQLCipher connection, the schema and the repositories.
add_library(core_db STATIC
    BankImportRepository.cpp
    BankImportRepository.h
    Database.cpp
    Database.h
    DatabaseSchema.cpp
    DatabaseSchema.h
    NotesRepository.cpp
    NotesRepository.h
    SettingsRepository.cpp
    SettingsRepository.h
)
target_link_libraries(core_db PUBLIC core_model Qt6::Sql vexa_storage)
