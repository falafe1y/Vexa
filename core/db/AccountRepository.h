#pragma once
#include "Database.h"
#include "../model/accounts/Account.h"
#include "../model/accounts/DepositSettings.h"
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <optional>

// Accounts and deposit settings: the list, adding, editing, and the rate history of deposits.
class AccountRepository
{
public:
    explicit AccountRepository(Database& database);

    QVector<Account> loadAccounts();
    QVector<DepositSettings> loadDepositSettings();
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
    // Rate history of deposits by account id: a list of {"from": "yyyy-MM-dd", "bps": int}, sorted by day
    QVariantMap loadDepositRateSteps() const;
    bool saveDepositRateSteps(const QString& accountId, const QVariantList& steps);
    bool deleteAccount(const QString& id);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    Database& db_;
    QSqlDatabase& database_;
    QString lastError_;
};
