#include "AccountRepository.h"

#include <QDate>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSqlError>
#include <QSqlQuery>

namespace
{
AssetType assetTypeFromInt(const int value)
{
    if (value == 1) {
        return AssetType::Crypto;
    }
    if (value == 2) {
        return AssetType::Investment;
    }
    return AssetType::Fiat;
}

bool upsertDepositSettings(
    QSqlDatabase& database,
    const DepositSettings& settings,
    QString& error
    )
{
    QSqlQuery query(database);
    query.prepare(QStringLiteral(
        "INSERT INTO deposit_settings("
        "account_id, annual_rate_bps, payout_frequency, payout_day, "
        "starts_on, generated_through, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(account_id) DO UPDATE SET "
        "annual_rate_bps = excluded.annual_rate_bps, "
        "payout_frequency = excluded.payout_frequency, "
        "payout_day = excluded.payout_day, "
        "starts_on = excluded.starts_on, "
        "generated_through = excluded.generated_through, "
        "updated_at = excluded.updated_at"));
    query.addBindValue(settings.accountId());
    query.addBindValue(settings.annualRateBasisPoints());
    query.addBindValue(
        settings.payoutFrequency() == DepositPayoutFrequency::Daily ? 1 : 0);
    query.addBindValue(settings.payoutDay());
    query.addBindValue(settings.startsOn().toString(Qt::ISODate));
    query.addBindValue(settings.generatedThrough().toString(Qt::ISODate));
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    if (!query.exec()) {
        error = query.lastError().text();
        return false;
    }
    return true;
}
}

AccountRepository::AccountRepository(Database& database)
    : database_(database.connection())
{
}

QString AccountRepository::lastError() const { return lastError_; }
void AccountRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<Account> AccountRepository::loadAccounts()
{
    QVector<Account> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, asset_type, account_type, currency, "
            "       initial_balance_minor, credit_limit_minor, counts_debt "
            "FROM accounts WHERE is_archived = 0 "
            "ORDER BY asset_type, created_at, name COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(Account(
            query.value(0).toString(),
            query.value(1).toString(),
            assetTypeFromInt(query.value(2).toInt()),
            static_cast<AccountType>(query.value(3).toInt()),
            currencyFromCode(query.value(4).toString()),
            query.value(5).toLongLong(),
            query.value(6).toLongLong(),
            query.value(7).toInt() != 0));
    }
    return result;
}

QVector<DepositSettings> AccountRepository::loadDepositSettings()
{
    QVector<DepositSettings> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT d.account_id, d.annual_rate_bps, d.payout_frequency, "
            "       d.payout_day, d.starts_on, d.generated_through "
            "FROM deposit_settings d "
            "JOIN accounts a ON a.id = d.account_id "
            "WHERE a.is_archived = 0 AND a.account_type = 7 "
            "ORDER BY a.created_at, d.account_id"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(DepositSettings(
            query.value(0).toString(),
            query.value(1).toInt(),
            query.value(2).toInt() == 1
                ? DepositPayoutFrequency::Daily
                : DepositPayoutFrequency::Monthly,
            query.value(3).toInt(),
            QDate::fromString(query.value(4).toString(), Qt::ISODate),
            QDate::fromString(query.value(5).toString(), Qt::ISODate)));
    }
    return result;
}

bool AccountRepository::insertAccount(const Account& account)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO accounts(id, name, asset_type, account_type, currency, "
        "initial_balance_minor, credit_limit_minor, counts_debt, is_archived, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)"));
    query.addBindValue(account.id());
    query.addBindValue(account.name());
    query.addBindValue(static_cast<int>(account.assetType()));
    query.addBindValue(static_cast<int>(account.type()));
    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.initialBalanceMinor());
    query.addBindValue(account.creditLimitMinor());
    query.addBindValue(account.countsDebt() ? 1 : 0);
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());

    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool AccountRepository::insertDepositAccount(
    const Account& account,
    const DepositSettings& settings
    )
{
    if (account.type() != AccountType::Deposit ||
        account.id() != settings.accountId() ||
        !database_.transaction()) {
        setLastError(database_.lastError().isValid()
            ? database_.lastError().text()
            : QStringLiteral("Invalid deposit account"));
        return false;
    }

    QString error;
    if (!insertAccount(account) ||
        !upsertDepositSettings(database_, settings, error) ||
        !database_.commit()) {
        if (!error.isEmpty()) {
            setLastError(error);
        } else if (database_.lastError().isValid()) {
            setLastError(database_.lastError().text());
        }
        database_.rollback();
        return false;
    }
    return true;
}

bool AccountRepository::updateAccount(const Account& account)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE accounts "
        "SET name = ?, asset_type = ?, account_type = ?, currency = ?, "
        "    initial_balance_minor = ?, credit_limit_minor = ?, counts_debt = ? "
        "WHERE id = ? AND is_archived = 0 "
        "  AND (currency = ? OR NOT EXISTS ("
        "      SELECT 1 FROM transactions WHERE account_id = ?"
        "  )) AND (currency = ? OR NOT EXISTS (SELECT 1 FROM transactions WHERE account_id = ? AND kind IN ('buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry'))) "
        "AND (account_type = ? OR NOT EXISTS (SELECT 1 FROM transactions WHERE account_id = ? AND kind IN ('buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry')))"));
    query.addBindValue(account.name());
    query.addBindValue(static_cast<int>(account.assetType()));
    query.addBindValue(static_cast<int>(account.type()));
    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.initialBalanceMinor());
    query.addBindValue(account.creditLimitMinor());
    query.addBindValue(account.countsDebt() ? 1 : 0);
    query.addBindValue(account.id());
    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.id());

    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.id());
    query.addBindValue(static_cast<int>(account.type()));
    query.addBindValue(account.id());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Account was not found or its currency cannot be changed"));
        return false;
    }
    return true;
}

bool AccountRepository::updateAccountAndDeposit(
    const Account& account,
    const std::optional<DepositSettings>& settings
    )
{
    if ((account.type() == AccountType::Deposit) != settings.has_value() ||
        (settings && settings->accountId() != account.id()) ||
        !database_.transaction()) {
        setLastError(database_.lastError().isValid()
            ? database_.lastError().text()
            : QStringLiteral("Invalid deposit settings"));
        return false;
    }

    QString error;
    bool settingsSaved = false;
    if (settings) {
        settingsSaved = upsertDepositSettings(database_, *settings, error);
    } else {
        QSqlQuery deletion(database_);
        deletion.prepare(QStringLiteral(
            "DELETE FROM deposit_settings WHERE account_id = ?"));
        deletion.addBindValue(account.id());
        settingsSaved = deletion.exec();
        if (!settingsSaved) {
            error = deletion.lastError().text();
        }
    }

    if (!updateAccount(account) || !settingsSaved || !database_.commit()) {
        if (!error.isEmpty()) {
            setLastError(error);
        } else if (database_.lastError().isValid()) {
            setLastError(database_.lastError().text());
        }
        database_.rollback();
        return false;
    }
    return true;
}

QVariantMap AccountRepository::loadDepositRateSteps() const
{
    static const QString prefix = QStringLiteral("deposit_rate_steps:");
    QVariantMap result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT key, value FROM settings WHERE key LIKE 'deposit_rate_steps:%'"))) {
        return result;
    }
    while (query.next()) {
        const QString accountId = query.value(0).toString().mid(prefix.size());
        result.insert(accountId, QJsonDocument::fromJson(query.value(1).toByteArray()).array().toVariantList());
    }
    return result;
}

bool AccountRepository::saveDepositRateSteps(const QString& accountId, const QVariantList& steps)
{
    const QString key = QStringLiteral("deposit_rate_steps:") + accountId;
    QSqlQuery query(database_);
    if (steps.isEmpty()) {
        query.prepare(QStringLiteral("DELETE FROM settings WHERE key = ?"));
        query.addBindValue(key);
    } else {
        query.prepare(QStringLiteral(
            "INSERT INTO settings(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
        query.addBindValue(key);
        query.addBindValue(QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(steps))
                                                 .toJson(QJsonDocument::Compact)));
    }
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}
