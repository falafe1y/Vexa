# Core database: the SQLCipher connection, the schema and the repositories.
add_library(core_db STATIC
    BankImportRepository.cpp
    BankImportRepository.h
    CryptoRepository.cpp
    CryptoRepository.h
    Database.cpp
    Database.h
    DatabaseSchema.cpp
    DatabaseSchema.h
    NotesRepository.cpp
    NotesRepository.h
    PlanningRepository.cpp
    PlanningRepository.h
    SettingsRepository.cpp
    SettingsRepository.h
)
target_link_libraries(core_db PUBLIC core_model Qt6::Sql vexa_storage)
