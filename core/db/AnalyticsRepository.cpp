#include "AnalyticsRepository.h"

#include "HistorySavepoint.h"
#include "SnapshotTables.h"
#include "SqlRow.h"
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QPair>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

#include <optional>

namespace {
QVariant optionalValue(const std::optional<qint64>& value) { return value ? QVariant(*value) : QVariant(); }
}

AnalyticsRepository::AnalyticsRepository(Database& database)
    : database_(database.connection())
{
}

QString AnalyticsRepository::lastError() const { return lastError_; }
void AnalyticsRepository::setLastError(const QString& error) { lastError_ = error; }

bool AnalyticsRepository::saveDailyValuations(const DailyValuationBatch& batch) {
    if(!batch.date.isValid() || !batch.observedAtUtc.isValid()
       || batch.observedAtUtc.toLocalTime().date()!=batch.date){setLastError(QStringLiteral("Некорректная дата дневной оценки"));return false;}
    HistorySavepoint atomic(database_);if(!atomic.active()){setLastError(database_.lastError().text());return false;}
    QSqlQuery q(database_);q.prepare("SELECT observed_at FROM daily_valuation_runs WHERE snapshot_date=?");
    q.addBindValue(batch.date.toString(Qt::ISODate));
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    if(q.next() && q.value(0).toLongLong()>batch.observedAtUtc.toMSecsSinceEpoch())return atomic.commit();
    q.finish();
    for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment}) {
        q.prepare("DELETE FROM "+snapshotTable(kind)+" WHERE snapshot_date=?");q.addBindValue(batch.date.toString(Qt::ISODate));
        if(!q.exec()){setLastError(q.lastError().text());return false;}
    }
    QSet<QString> ids;
    for(const auto& a:batch.assets){
        const auto table=snapshotTable(a.kind), key=QString::number(int(a.kind))+":"+a.sourceId;
        if(table.isEmpty() || a.sourceId.isEmpty() || a.accountId.isEmpty() || a.currency.isEmpty() || a.source.isEmpty()
           || ids.contains(key) || (a.costBasisMinor && *a.costBasisMinor<0)
           || (!a.valueMinor && a.issues.isEmpty())){setLastError(QStringLiteral("Некорректная или повторная оценка актива"));return false;}
        ids.insert(key);
        q.prepare("INSERT INTO "+table+"(snapshot_date,source_id,account_id,instrument_id,currency,value_minor,quantity_atomic,quantity_decimals,"
                  "price_micros,cost_basis_minor,valued_at,observed_at,source,issues,details_json) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
        q.addBindValue(batch.date.toString(Qt::ISODate));q.addBindValue(a.sourceId);q.addBindValue(a.accountId);
        q.addBindValue(a.instrumentId.isNull()?QStringLiteral(""):a.instrumentId);q.addBindValue(a.currency);
        q.addBindValue(optionalValue(a.valueMinor));q.addBindValue(optionalValue(a.quantityAtomic));q.addBindValue(a.quantityDecimals);
        q.addBindValue(optionalValue(a.priceMicros));q.addBindValue(optionalValue(a.costBasisMinor));
        q.addBindValue(a.valuedAtUtc.isValid()?QVariant(a.valuedAtUtc.toMSecsSinceEpoch()):QVariant());
        q.addBindValue(batch.observedAtUtc.toMSecsSinceEpoch());q.addBindValue(a.source);
        q.addBindValue(a.issues.isNull()?QStringLiteral(""):a.issues);q.addBindValue(a.detailsJson);
        if(!q.exec()){setLastError(q.lastError().text());return false;}
    }
    for(const auto& rate:batch.rates){
        if(rate.currency.isEmpty() || !rate.rateDate.isValid() || !rate.observedAtUtc.isValid() || rate.source.isEmpty() || rate.rubPerUnitMicros<=0){
            setLastError(QStringLiteral("Некорректный исторический курс"));return false;
        }
        q.prepare("INSERT INTO fx_rate_history(currency,rate_date,source,rub_per_unit_micros,observed_at) VALUES(?,?,?,?,?) "
                  "ON CONFLICT(currency,rate_date,source) DO UPDATE SET rub_per_unit_micros=excluded.rub_per_unit_micros,observed_at=excluded.observed_at "
                  "WHERE excluded.observed_at>=fx_rate_history.observed_at");
        q.addBindValue(rate.currency);q.addBindValue(rate.rateDate.toString(Qt::ISODate));q.addBindValue(rate.source);
        q.addBindValue(rate.rubPerUnitMicros);q.addBindValue(rate.observedAtUtc.toMSecsSinceEpoch());
        if(!q.exec()){setLastError(q.lastError().text());return false;}
    }
    q.prepare("INSERT INTO daily_valuation_runs(snapshot_date,observed_at) VALUES(?,?) ON CONFLICT(snapshot_date) DO UPDATE SET observed_at=excluded.observed_at");
    q.addBindValue(batch.date.toString(Qt::ISODate));q.addBindValue(batch.observedAtUtc.toMSecsSinceEpoch());
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    if(batch.totalMinor){
        if(batch.totalCurrency.isEmpty()){setLastError(QStringLiteral("Не указана валюта общего капитала"));return false;}
        q.prepare("INSERT INTO capital_snapshots(snapshot_date,currency,total_minor,updated_at) VALUES(?,?,?,?) ON CONFLICT(snapshot_date) DO UPDATE SET currency=excluded.currency,total_minor=excluded.total_minor,updated_at=excluded.updated_at");
        q.addBindValue(batch.date.toString(Qt::ISODate));q.addBindValue(batch.totalCurrency);q.addBindValue(*batch.totalMinor);q.addBindValue(batch.observedAtUtc.toMSecsSinceEpoch());
        if(!q.exec()){setLastError(q.lastError().text());return false;}
    } else {
        q.prepare("DELETE FROM capital_snapshots WHERE snapshot_date=?");q.addBindValue(batch.date.toString(Qt::ISODate));
        if(!q.exec()){setLastError(q.lastError().text());return false;}
    }
    return atomic.commit();
}

QVariantList AnalyticsRepository::loadDailyValuations(AssetDailyValuation::Kind kind,const QDate& from,const QDate& to) {
    QVariantList rows;const auto table=snapshotTable(kind);if(table.isEmpty())return rows;
    QSqlQuery q(database_);q.prepare("SELECT * FROM "+table+" WHERE (?='' OR snapshot_date>=?) AND (?='' OR snapshot_date<=?) ORDER BY snapshot_date,source_id");
    for(auto date:{from,from,to,to})q.addBindValue(date.isValid()?date.toString(Qt::ISODate):QStringLiteral(""));
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}

QVariantList AnalyticsRepository::loadPriceHistory(AssetDailyValuation::Kind kind,const QString& id) {
    QVariantList rows;
    const QString table=kind==AssetDailyValuation::Crypto?QStringLiteral("crypto_price_history"):
        kind==AssetDailyValuation::Investment?QStringLiteral("investment_price_history"):QString();
    if(table.isEmpty())return rows;
    QSqlQuery q(database_);q.prepare("SELECT * FROM "+table+" WHERE asset_id=? ORDER BY quoted_at,source");q.addBindValue(id);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}

QVariantList AnalyticsRepository::loadFxHistory(const QString& currency) {
    QVariantList rows;QSqlQuery q(database_);q.prepare("SELECT * FROM fx_rate_history WHERE currency=? ORDER BY rate_date,source");q.addBindValue(currency);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}

bool AnalyticsRepository::saveHistoricalFxRates(const QVector<HistoricalFxRate>& rates)
{
    if (rates.isEmpty())
        return true;
    HistorySavepoint atomic(database_);
    if (!atomic.active()) {
        setLastError(database_.lastError().text());
        return false;
    }
    for (const auto& rate : rates) {
        if (rate.currency.isEmpty() || !rate.rateDate.isValid() || !rate.observedAtUtc.isValid()
            || rate.source.isEmpty() || rate.rubPerUnitMicros <= 0) {
            setLastError(QStringLiteral("Некорректный исторический курс"));
            return false;
        }
        QSqlQuery q(database_);
        q.prepare("INSERT INTO fx_rate_history(currency,rate_date,source,rub_per_unit_micros,observed_at) VALUES(?,?,?,?,?) "
                  "ON CONFLICT(currency,rate_date,source) DO UPDATE SET rub_per_unit_micros=excluded.rub_per_unit_micros,observed_at=excluded.observed_at "
                  "WHERE excluded.observed_at>=fx_rate_history.observed_at");
        q.addBindValue(rate.currency);
        q.addBindValue(rate.rateDate.toString(Qt::ISODate));
        q.addBindValue(rate.source);
        q.addBindValue(rate.rubPerUnitMicros);
        q.addBindValue(rate.observedAtUtc.toMSecsSinceEpoch());
        if (!q.exec()) {
            setLastError(q.lastError().text());
            return false;
        }
    }
    return atomic.commit();
}

QVariantList AnalyticsRepository::loadPerformanceAccounts() {
    QVariantList result; QSqlQuery q(database_);
    if(!q.exec("SELECT id,name,currency,initial_balance_minor,created_at,account_type FROM accounts WHERE is_archived=0 AND account_type IN (6,7) ORDER BY created_at,id")){setLastError(q.lastError().text());return result;}
    while(q.next())result.append(rowMap(q));return result;
}

QVariantMap AnalyticsRepository::loadAccountCreationDates() {
    QVariantMap result; QSqlQuery q(database_);
    if(!q.exec("SELECT id,created_at FROM accounts")){setLastError(q.lastError().text());return result;}
    while(q.next())result.insert(q.value(0).toString(),q.value(1).toLongLong());
    return result;
}

QString AnalyticsRepository::loadPerformanceInflation() const {
    QSqlQuery q(database_);q.prepare("SELECT value FROM settings WHERE key='performance_annual_inflation'");
    return q.exec() && q.next()?q.value(0).toString():QString();
}

bool AnalyticsRepository::savePerformanceInflation(const QString& value) {
    QSqlQuery q(database_);q.prepare("INSERT INTO settings(key,value) VALUES('performance_annual_inflation',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");q.addBindValue(value.isNull()?QStringLiteral(""):value);
    if(q.exec())return true;setLastError(q.lastError().text());return false;
}

QVariantMap AnalyticsRepository::loadPerformanceDeposit() const {
    QSqlQuery q(database_);q.prepare("SELECT value FROM settings WHERE key='performance_deposit'");
    return q.exec() && q.next()?QJsonDocument::fromJson(q.value(0).toString().toUtf8()).object().toVariantMap():QVariantMap();
}

bool AnalyticsRepository::savePerformanceDeposit(const QVariantMap& value) {
    QSqlQuery q(database_);q.prepare("INSERT INTO settings(key,value) VALUES('performance_deposit',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
    q.addBindValue(QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(value)).toJson(QJsonDocument::Compact)));
    if(q.exec())return true;setLastError(q.lastError().text());return false;
}

QVariantMap AnalyticsRepository::loadBenchmarkSelection() const {
    QSqlQuery q(database_);q.prepare("SELECT value FROM settings WHERE key='investment_benchmark'");
    return q.exec() && q.next()?QJsonDocument::fromJson(q.value(0).toString().toUtf8()).object().toVariantMap():QVariantMap();
}

bool AnalyticsRepository::saveBenchmarkSelection(const QVariantMap& descriptor) {
    QSqlQuery q(database_);q.prepare("INSERT INTO settings(key,value) VALUES('investment_benchmark',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
    q.addBindValue(QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(descriptor)).toJson(QJsonDocument::Compact)));
    if(q.exec())return true;setLastError(q.lastError().text());return false;
}

QVariantList AnalyticsRepository::loadBenchmarkPrices(const QString& key) {
    QVariantList rows;QSqlQuery q(database_);q.prepare("SELECT * FROM benchmark_daily_prices WHERE benchmark_key=? ORDER BY price_date");q.addBindValue(key);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}

bool AnalyticsRepository::benchmarkHistoryCovered(const QString& key,const QDate& from,const QDate& to) {
    QSqlQuery q(database_);q.prepare("SELECT 1 FROM benchmark_history_ranges WHERE benchmark_key=? AND from_date<=? AND to_date>=? LIMIT 1");
    q.addBindValue(key);q.addBindValue(from.toString(Qt::ISODate));q.addBindValue(to.toString(Qt::ISODate));return q.exec() && q.next();
}

bool AnalyticsRepository::saveBenchmarkHistory(const QVariantMap& descriptor,const QVariantList& prices,const QDate& from,const QDate& to) {
    const auto key=descriptor.value("key").toString();if(key.isEmpty() || !from.isValid() || !to.isValid() || from>to){setLastError(QStringLiteral("Некорректная история ориентира."));return false;}
    HistorySavepoint atomic(database_);if(!atomic.active())return false;
    QSqlQuery q(database_);q.prepare("DELETE FROM benchmark_daily_prices WHERE benchmark_key=? AND price_date>=? AND price_date<=?");q.addBindValue(key);q.addBindValue(from.toString(Qt::ISODate));q.addBindValue(to.toString(Qt::ISODate));
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    for(const auto& v:prices){const auto r=v.toMap();const auto date=QDate::fromString(r.value("price_date").toString(),Qt::ISODate);
        if(!date.isValid() || date<from || date>to){setLastError(QStringLiteral("Цена вне периода загрузки."));return false;}
        q.prepare("INSERT INTO benchmark_daily_prices(benchmark_key,price_date,price_micros,currency,issues,observed_at) VALUES(?,?,?,?,?,?)");
        q.addBindValue(key);q.addBindValue(date.toString(Qt::ISODate));q.addBindValue(r.value("price_micros"));q.addBindValue(r.value("currency").toString().isNull()?QStringLiteral(""):r.value("currency").toString());q.addBindValue(r.value("issues").toString().isNull()?QStringLiteral(""):r.value("issues").toString());q.addBindValue(QDateTime::currentMSecsSinceEpoch());
        if(!q.exec()){setLastError(q.lastError().text());return false;}
    }
    q.prepare("INSERT OR REPLACE INTO benchmark_history_ranges(benchmark_key,from_date,to_date,observed_at) VALUES(?,?,?,?)");q.addBindValue(key);q.addBindValue(from.toString(Qt::ISODate));q.addBindValue(to.toString(Qt::ISODate));q.addBindValue(QDateTime::currentMSecsSinceEpoch());
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    return saveBenchmarkSelection(descriptor) && atomic.commit();
}

QVector<CapitalSnapshot> AnalyticsRepository::loadCapitalSnapshots()
{
    QVector<CapitalSnapshot> snapshots;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT snapshot_date,currency,total_minor FROM capital_snapshots "
            "ORDER BY snapshot_date"))) {
        setLastError(query.lastError().text());
        return snapshots;
    }
    while (query.next()) {
        snapshots.append({QDate::fromString(query.value(0).toString(), Qt::ISODate),
                          currencyFromCode(query.value(1).toString()),
                          query.value(2).toLongLong()});
    }
    return snapshots;
}

bool AnalyticsRepository::saveCapitalSnapshot(const CapitalSnapshot& snapshot)
{
    if (!snapshot.date.isValid()) {
        setLastError(QStringLiteral("Invalid capital snapshot"));
        return false;
    }
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO capital_snapshots(snapshot_date,currency,total_minor,updated_at) "
        "VALUES(?,?,?,?) ON CONFLICT(snapshot_date) DO UPDATE SET "
        "currency=excluded.currency,total_minor=excluded.total_minor,updated_at=excluded.updated_at"));
    query.addBindValue(snapshot.date.toString(Qt::ISODate));
    query.addBindValue(currencyCode(snapshot.currency));
    query.addBindValue(snapshot.totalMinor);
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    return true;
}

FinancialTrajectorySettings AnalyticsRepository::loadFinancialTrajectorySettings() const
{
    FinancialTrajectorySettings result;
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("SELECT value FROM settings WHERE key=?"));
    const auto value = [&query](const QString& key, const QVariant& fallback) {
        query.bindValue(0, key);
        if (!query.exec() || !query.next()) { query.finish(); return fallback; }
        const QVariant result = query.value(0); query.finish(); return result;
    };
    result.analysisMonths = value(QStringLiteral("trajectory_analysis_months"), 6).toInt();
    result.horizonMonths = value(QStringLiteral("trajectory_horizon_months"), 12).toInt();
    result.annualReturnPercent = value(QStringLiteral("trajectory_return"), 9.0).toDouble();
    result.annualInflationPercent = value(QStringLiteral("trajectory_inflation"), 6.0).toDouble();
    result.incomeChangePercent = value(QStringLiteral("trajectory_income_change"), 10.0).toDouble();
    result.expenseChangePercent = value(QStringLiteral("trajectory_expense_change"), 5.0).toDouble();
    result.purchaseMinor = value(QStringLiteral("trajectory_purchase_minor"), 0).toLongLong();
    result.purchaseMonth = value(QStringLiteral("trajectory_purchase_month"), 0).toInt();
    result.allSources = value(QStringLiteral("trajectory_all_sources"), 1).toInt() != 0;
    const QJsonArray sourceIds = QJsonDocument::fromJson(
        value(QStringLiteral("trajectory_sources"), QStringLiteral("[]")).toString().toUtf8()).array();
    for (const QJsonValue& item : sourceIds) {
        result.sourceIds.append(item.toString());
    }
    return result;
}

bool AnalyticsRepository::saveFinancialTrajectorySettings(
    const FinancialTrajectorySettings& settings)
{
    if (!database_.transaction()) { setLastError(database_.lastError().text()); return false; }
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key,value) VALUES(?,?) "
        "ON CONFLICT(key) DO UPDATE SET value=excluded.value"));
    const QVector<QPair<QString, QVariant>> values{
        {QStringLiteral("trajectory_analysis_months"), settings.analysisMonths},
        {QStringLiteral("trajectory_horizon_months"), settings.horizonMonths},
        {QStringLiteral("trajectory_return"), settings.annualReturnPercent},
        {QStringLiteral("trajectory_inflation"), settings.annualInflationPercent},
        {QStringLiteral("trajectory_income_change"), settings.incomeChangePercent},
        {QStringLiteral("trajectory_expense_change"), settings.expenseChangePercent},
        {QStringLiteral("trajectory_purchase_minor"), settings.purchaseMinor},
        {QStringLiteral("trajectory_purchase_month"), settings.purchaseMonth},
        {QStringLiteral("trajectory_all_sources"), settings.allSources ? 1 : 0},
        {QStringLiteral("trajectory_sources"), QString::fromUtf8(QJsonDocument(
            QJsonArray::fromStringList(settings.sourceIds)).toJson(QJsonDocument::Compact))}};
    for (const auto& item : values) {
        query.bindValue(0, item.first); query.bindValue(1, item.second);
        if (!query.exec()) { setLastError(query.lastError().text()); database_.rollback(); return false; }
        query.finish();
    }
    if (!database_.commit()) { setLastError(database_.lastError().text()); return false; }
    return true;
}
