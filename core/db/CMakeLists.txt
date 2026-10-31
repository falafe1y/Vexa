# Core database: the SQLCipher driver and connection, encryption, portable backups,
# the schema and the repositories.
add_library(core_db STATIC
    AccountRepository.cpp
    AccountRepository.h
    AnalyticsRepository.cpp
    AnalyticsRepository.h
    BankImportRepository.cpp
    BankImportRepository.h
    CategoryRepository.cpp
    CategoryRepository.h
    CipherDriver.cpp
    CipherDriver.h
    CryptoRepository.cpp
    CryptoRepository.h
    Database.cpp
    Database.h
    DatabaseEncryption.cpp
    DatabaseEncryption.h
    DatabaseMaintenance.cpp
    DatabaseMaintenance.h
    DatabaseSchema.cpp
    DatabaseSchema.h
    HistorySavepoint.h
    InvestmentRepository.cpp
    InvestmentRepository.h
    NotesRepository.cpp
    NotesRepository.h
    OperationRows.cpp
    OperationRows.h
    PlanningRepository.cpp
    PlanningRepository.h
    PortableBackup.cpp
    PortableBackup.h
    PositionHistory.cpp
    PositionHistory.h
    PreparedDatabase.cpp
    PreparedDatabase.h
    PriceHistory.cpp
    PriceHistory.h
    ProjectRepository.cpp
    ProjectRepository.h
    RecurringTransactionRepository.cpp
    RecurringTransactionRepository.h
    SettingsRepository.cpp
    SettingsRepository.h
    SnapshotTables.h
    SqlRow.cpp
    SqlRow.h
    TransactionRepository.cpp
    TransactionRepository.h
)
set_target_properties(core_db PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_compile_features(core_db PUBLIC cxx_std_17)
target_link_libraries(core_db PUBLIC core_model Qt6::Sql PRIVATE vexa_sqlcipher)
