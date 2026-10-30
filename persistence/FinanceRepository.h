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
    // Purchase price of the coins without trades, by "exchangeId|coin"
    // Rate history of deposits by account id: a list of {"from": "yyyy-MM-dd", "bps": int}, sorted by day

private:

    void setLastError(const QString& error);

    std::shared_ptr<DatabaseKeyStore> keyStore_;
    Database db_;
    QSqlDatabase& database_; // the connection of db_
    QString lastError_;
};
