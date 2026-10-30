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
    QVariantList loadPriceHistory(AssetDailyValuation::Kind kind, const QString& assetId);
    QVariantList loadFxHistory(const QString& currency);
    bool saveHistoricalFxRates(const QVector<HistoricalFxRate>& rates);
    QVariantList loadPerformanceAccounts();
    QVariantMap loadAccountCreationDates();
    QString loadPerformanceInflation() const;
    bool savePerformanceInflation(const QString& value);
    QVariantMap loadPerformanceDeposit() const;
    bool savePerformanceDeposit(const QVariantMap& value);
    QVariantMap loadBenchmarkSelection() const;
    bool saveBenchmarkSelection(const QVariantMap& descriptor);
    QVariantList loadBenchmarkPrices(const QString& key);
    bool benchmarkHistoryCovered(const QString& key,const QDate& from,const QDate& to);
    bool saveBenchmarkHistory(const QVariantMap& descriptor,const QVariantList& prices,const QDate& from,const QDate& to);
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
    QVector<DepositSettings> loadDepositSettings();
    QVector<Account> loadAccounts();
    // Purchase price of the coins without trades, by "exchangeId|coin"
    // Rate history of deposits by account id: a list of {"from": "yyyy-MM-dd", "bps": int}, sorted by day
    QVariantMap loadDepositRateSteps() const;
    bool saveDepositRateSteps(const QString& accountId, const QVariantList& steps);
    Summary loadSummary();
    bool insertTransaction(const Transaction& transaction);
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
    bool materializeRecurringOccurrences(
        const QString& recurringId,
        const QVector<RecurringOccurrence>& occurrences,
        const QDate& generatedThrough,
        int* insertedCount = nullptr
        );
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

private:
    bool migrateAnalyticsHistorySchema();

    void setLastError(const QString& error);

    std::shared_ptr<DatabaseKeyStore> keyStore_;
    Database db_;
    QSqlDatabase& database_; // the connection of db_
    QString lastError_;
};
