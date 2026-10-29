#include "SettingsRepository.h"

#include <QSqlError>
#include <QSqlQuery>

#include <cmath>

SettingsRepository::SettingsRepository(Database& database)
    : database_(database.connection())
{
}

QString SettingsRepository::lastError() const { return lastError_; }
void SettingsRepository::setLastError(const QString& error) { lastError_ = error; }

QString SettingsRepository::loadAppCurrency() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings WHERE key = 'app_currency'")) &&
        query.next()) {
        return query.value(0).toString();
    }
    return QStringLiteral("RUB");
}

bool SettingsRepository::saveAppCurrency(const QString& currency)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) VALUES('app_currency', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(currency);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QString SettingsRepository::loadAnalyticsCurrency() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings WHERE key = 'analytics_currency'")) &&
        query.next()) {
        return query.value(0).toString();
    }
    return QStringLiteral("USD");
}

bool SettingsRepository::saveAnalyticsCurrency(const QString& currency)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) VALUES('analytics_currency', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(currency);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QString SettingsRepository::loadSelectedAsset() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings WHERE key = 'selected_asset'")) &&
        query.next()) {
        return query.value(0).toString();
    }
    return QStringLiteral("fiat");
}

bool SettingsRepository::saveSelectedAsset(const QString& asset)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) VALUES('selected_asset', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(asset);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool SettingsRepository::loadAutomaticCurrencyRates() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'automatic_currency_rates'")) &&
        query.next()) {
        return query.value(0).toString() != QStringLiteral("0");
    }
    return true;
}

double SettingsRepository::loadManualUsdToRubRate() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'manual_usd_to_rub_rate'")) &&
        query.next()) {
        bool valid = false;
        const double value = query.value(0).toString().toDouble(&valid);
        if (valid && std::isfinite(value) && value > 0.0) {
            return value;
        }
    }
    return 90.909090909;
}

double SettingsRepository::loadManualRubToRubRate() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'manual_rub_to_rub_rate'")) &&
        query.next()) {
        bool valid = false;
        const double value = query.value(0).toString().toDouble(&valid);
        if (valid && std::isfinite(value) && value > 0.0) {
            return value;
        }
    }
    return 1.0;
}

double SettingsRepository::loadManualEurToRubRate() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'manual_eur_to_rub_rate'")) &&
        query.next()) {
        bool valid = false;
        const double value = query.value(0).toString().toDouble(&valid);
        if (valid && std::isfinite(value) && value > 0.0) {
            return value;
        }
    }
    return 106.363636364;
}

double SettingsRepository::loadManualCnyToRubRate() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral("SELECT value FROM settings WHERE key = 'manual_cny_to_rub_rate'")) && query.next()) {
        bool valid = false;
        const double value = query.value(0).toString().toDouble(&valid);
        if (valid && std::isfinite(value) && value > 0.0) return value;
    }
    return kDefaultCnyToRubRate;
}

bool SettingsRepository::saveAutomaticCurrencyRates(const bool enabled)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) "
        "VALUES('automatic_currency_rates', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(enabled ? QStringLiteral("1") : QStringLiteral("0"));
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool SettingsRepository::saveManualCurrencyRates(
    const double rublesPerRub,
    const double rublesPerUsd,
    const double rublesPerEur,
    const double rublesPerCny
    )
{
    if (!std::isfinite(rublesPerRub) || rublesPerRub <= 0.0 ||
        !std::isfinite(rublesPerUsd) || rublesPerUsd <= 0.0 ||
        !std::isfinite(rublesPerEur) || rublesPerEur <= 0.0 ||
        !std::isfinite(rublesPerCny) || rublesPerCny <= 0.0) {
        setLastError(QStringLiteral("Currency rates must be positive numbers"));
        return false;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) VALUES(?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    const auto saveRate = [&query](const QString& key, const double value)
    {
        query.bindValue(0, key);
        query.bindValue(1, QString::number(value, 'g', 15));
        return query.exec();
    };
    if (!saveRate(QStringLiteral("manual_rub_to_rub_rate"), rublesPerRub) ||
        !saveRate(QStringLiteral("manual_usd_to_rub_rate"), rublesPerUsd) ||
        !saveRate(QStringLiteral("manual_eur_to_rub_rate"), rublesPerEur) ||
        !saveRate(QStringLiteral("manual_cny_to_rub_rate"), rublesPerCny)) {
        setLastError(query.lastError().text());
        database_.rollback();
        return false;
    }
    if (!database_.commit()) {
        setLastError(database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}
