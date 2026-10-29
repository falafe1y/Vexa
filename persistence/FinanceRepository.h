#pragma once
#include "../core/db/Database.h"
#include "storage/DatabaseEncryption.h"

#include "../core/model/transactions/Transaction.h"
#include "../core/model/transactions/BankCategoryRule.h"
#include "../core/model/transactions/BankRecipientRule.h"
#include "../core/model/transactions/RecurringTransaction.h"
#include "../core/model/accounts/DepositSettings.h"
#include "../core/model/transactions/Category.h"
#include "../core/model/accounts/Account.h"
#include "../core/model/crypto/CryptoWallet.h"
#include "../core/model/crypto/CryptoTransaction.h"
#include "../core/model/investments/InvestmentInstrument.h"
#include "../core/model/investments/InvestmentPosition.h"
#include "../core/model/investments/InvestmentQuote.h"
#include "../core/model/investments/InvestmentOperation.h"
#include "../core/model/analytics/AnalyticsHistory.h"
#include "../core/model/planning/Project.h"
#include "../core/model/planning/Budget.h"
#include "../core/model/planning/FinancialGoal.h"
#include "../core/model/analytics/FinancialTrajectory.h"

#include <QSqlDatabase>
#include <QDate>
#include <QDateTime>
#include <QSet>
#include <QMap>
#include <QVector>
#include <QVariant>

#include <array>
#include <optional>

class FinanceRepository
{
public:
    static bool migrateBackup(const DatabaseAccess& access, const QString& workspace, QString& error);
    struct Summary
    {
        std::array<qint64, kCurrencyCount> balance{};
        std::array<qint64, kCurrencyCount> income{};
        std::array<qint64, kCurrencyCount> expense{};
    };

    struct RecurringOccurrence
    {
        QDate date;
        Transaction transaction;
    };

    struct DepositInterestOccurrence
    {
        QDate date;
        Transaction transaction;
    };


    bool saveDailyValuations(const DailyValuationBatch& batch);
    QVariantList loadDailyValuations(AssetDailyValuation::Kind kind, const QDate& from = {}, const QDate& to = {});
    QVariantList loadPositionHistory(const QString& positionId);
    QVariantList loadPriceHistory(AssetDailyValuation::Kind kind, const QString& assetId);
    QVariantList loadFxHistory(const QString& currency);
    bool saveHistoricalFxRates(const QVector<HistoricalFxRate>& rates);
    QVariantList loadPerformanceAccounts();
    QVariantMap loadAccountCreationDates();
    QVariantList loadAllPositionHistory();
    QString loadPerformanceInflation() const;
    bool savePerformanceInflation(const QString& value);
    QVariantMap loadPerformanceDeposit() const;
    bool savePerformanceDeposit(const QVariantMap& value);
    QVariantMap loadBenchmarkSelection() const;
    bool saveBenchmarkSelection(const QVariantMap& descriptor);
    QVariantList loadBenchmarkPrices(const QString& key);
    bool benchmarkHistoryCovered(const QString& key,const QDate& from,const QDate& to);
    bool saveBenchmarkHistory(const QVariantMap& descriptor,const QVariantList& prices,const QDate& from,const QDate& to);
    QVariant investmentCostBasis(const QString& positionId) const;
    QVector<CapitalSnapshot> loadCapitalSnapshots();
    bool saveCapitalSnapshot(const CapitalSnapshot& snapshot);
    FinancialTrajectorySettings loadFinancialTrajectorySettings() const;
    bool saveFinancialTrajectorySettings(
        const FinancialTrajectorySettings& settings);


    explicit FinanceRepository(const QString& databasePath = {}, const QByteArray& databaseKey = {},
                               std::shared_ptr<DatabaseKeyStore> keyStore = {});
    ~FinanceRepository();

    FinanceRepository(const FinanceRepository&) = delete;
    FinanceRepository& operator=(const FinanceRepository&) = delete;

    bool isOpen() const;
    QString lastError() const;
    bool backupDatabase(const QString& destinationPath);
    // Replace all user data atomically; retain a backup of the previous state.
    bool restoreDatabase(const QString& sourcePath, qint64* restoredRecords = nullptr,
                         QString* previousBackupPath = nullptr);
    QString databasePath() const;
    // The connection, for the repositories split out of this class; temporary until they own it
    Database& database();
    bool clearAllUserData();
    QVector<Transaction> loadTransactions();
    QVector<Project> loadProjects();
    QVector<RecurringTransaction> loadRecurringTransactions();
    QVector<DepositSettings> loadDepositSettings();
    QVector<Category> loadCategories();
    QVector<Account> loadAccounts();
    QVector<InvestmentInstrument> loadInvestmentInstruments();
    QVector<InvestmentPosition> loadInvestmentPositions();
    QVector<InvestmentQuote> loadInvestmentQuotes();
    // Purchase price of the coins without trades, by "exchangeId|coin"
    // Rate history of deposits by account id: a list of {"from": "yyyy-MM-dd", "bps": int}, sorted by day
    QVariantMap loadDepositRateSteps() const;
    bool saveDepositRateSteps(const QString& accountId, const QVariantList& steps);
    QSet<QString> loadArchivedCategoryIds();
    Summary loadSummary();
    bool insertTransaction(const Transaction& transaction);
    bool insertProject(const Project& project);
    bool updateProject(const Project& project);
    bool archiveProject(const QString& id);
    bool insertTransfer(
        const Transaction& outgoing,
        const Transaction& incoming
        );
    bool insertTransactions(const QVector<Transaction>& transactions,
                            const QVector<BankCategoryRule>& rules = {},
                            const QVector<BankRecipientRule>& recipientRules = {},
                            const QMap<QString, QString>& bankLinks = {},
                            const QSet<QString>& replacedBankTransactions = {});
    bool updateTransaction(const Transaction& transaction);
    bool replaceTransaction(
        const QString& currentId,
        const Transaction& replacement
        );
    bool replaceTransactionWithTransfer(
        const QString& currentId,
        const Transaction& outgoing,
        const Transaction& incoming
        );
    bool deleteTransaction(const QString& id);
    bool deleteHistoryRows(const QVariantList& rows);
    bool insertRecurringTransaction(
        const RecurringTransaction& recurring
        );
    bool updateRecurringTransaction(
        const RecurringTransaction& recurring
        );
    bool deleteRecurringTransaction(const QString& id);
    bool materializeRecurringOccurrences(
        const QString& recurringId,
        const QVector<RecurringOccurrence>& occurrences,
        const QDate& generatedThrough,
        int* insertedCount = nullptr
        );
    bool insertCategory(const Category& category);
    bool insertAccount(const Account& account);
    bool insertDepositAccount(
        const Account& account,
        const DepositSettings& settings
        );
    bool updateAccount(const Account& account);
    bool updateAccountAndDeposit(
        const Account& account,
        const std::optional<DepositSettings>& settings
        );
    bool deleteAccount(const QString& id);
    bool materializeDepositInterest(
        const DepositSettings& settings,
        const QVector<DepositInterestOccurrence>& occurrences,
        const QDate& generatedThrough,
        int* insertedCount = nullptr
        );
    bool saveCryptoPrice(
        const QString& symbol,
        qint64 priceUsdMicros,
        const QDateTime& fetchedAtUtc
        );
    bool insertInvestmentInstrument(const InvestmentInstrument& instrument);
    bool updateInvestmentInstrument(const InvestmentInstrument& instrument);
    bool archiveInvestmentInstrument(const QString& id);
    bool insertInvestmentPosition(const InvestmentPosition& position);
    bool updateInvestmentPosition(const InvestmentPosition& position);
    bool deleteInvestmentPosition(const QString& id);
    bool archiveInvestmentPosition(const QString& id);
    bool saveInvestmentQuote(const InvestmentQuote& quote);
    QVector<InvestmentOperation> loadInvestmentOperations();
    bool saveInvestmentBundle(const InvestmentInstrument& instrument,
        const InvestmentPosition& position, const std::optional<InvestmentQuote>& quote,
        bool editing, const std::optional<InvestmentOperation>& operation = {},
        const std::optional<qint64>& openingCostMinor = {}, bool clearCostBasis = false,
        const QVector<InvestmentOperation>& charges = {});
    bool bookInvestmentOperation(const InvestmentOperation& operation,
        const InvestmentPosition& expected, const InvestmentPosition& updated, bool close,
        const std::optional<InvestmentQuote>& quote = {}, const QVector<InvestmentOperation>& charges = {});
    bool insertAccountCharge(const InvestmentOperation& operation);
    bool hasInvestmentOperations(const QString& positionId) const;
    bool updateCategoryName(const QString& id, const QString& name);
    bool archiveCategory(const QString& id);

private:
    bool migrateAnalyticsHistorySchema();
    bool appendPositionState(const QString& id, const QString& event);
    bool completePositionEvent(const InvestmentOperation& operation, const QVariant& previousBasis,
                               qint64 beforeQuantity, qint64 afterQuantity);
    bool savePriceHistory(const QString& kind, const QString& assetId, qint64 priceMicros,
                          const QDateTime& quotedAt, const QString& currency,
                          const QString& source, const QString& termsJson = QStringLiteral("{}"));

    void setLastError(const QString& error);

    std::shared_ptr<DatabaseKeyStore> keyStore_;
    Database db_;
    QSqlDatabase& database_; // the connection of db_
    QString lastError_;
};
