# Core database: the SQLCipher connection, the schema and the repositories.
add_library(core_db STATIC
    BankImportRepository.cpp
    BankImportRepository.h
    CategoryRepository.cpp
    CategoryRepository.h
    CryptoRepository.cpp
    CryptoRepository.h
    Database.cpp
    Database.h
    DatabaseSchema.cpp
    DatabaseSchema.h
    HistorySavepoint.h
    InvestmentRepository.cpp
    InvestmentRepository.h
    NotesRepository.cpp
    NotesRepository.h
    PlanningRepository.cpp
    PlanningRepository.h
    PositionHistory.cpp
    PositionHistory.h
    PriceHistory.cpp
    PriceHistory.h
    ProjectRepository.cpp
    ProjectRepository.h
    RecurringTransactionRepository.cpp
    RecurringTransactionRepository.h
    SettingsRepository.cpp
    SettingsRepository.h
    SqlRow.cpp
    SqlRow.h
)
target_link_libraries(core_db PUBLIC core_model Qt6::Sql vexa_storage)
