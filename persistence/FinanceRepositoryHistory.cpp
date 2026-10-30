#include "FinanceRepository.h"
#include "../core/db/HistorySavepoint.h"
#include "../core/db/InvestmentRepository.h"
#include "../core/db/PositionHistory.h"
#include "../core/db/PriceHistory.h"
#include "../core/db/SqlRow.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlRecord>
#include <QTimeZone>
#include <limits>

namespace {
QString snapshotTable(AssetDailyValuation::Kind kind) {
    switch(kind) {
    case AssetDailyValuation::Fiat: return QStringLiteral("fiat_daily_snapshots");
    case AssetDailyValuation::Crypto: return QStringLiteral("crypto_daily_snapshots");
    case AssetDailyValuation::Investment: return QStringLiteral("investment_daily_snapshots");
    }
    return {};
}
QVariant optionalValue(const std::optional<qint64>& value) { return value ? QVariant(*value) : QVariant(); }
}

bool FinanceRepository::migrateAnalyticsHistorySchema() {
    InvestmentRepository investments(db_);
    HistorySavepoint atomic(database_);
    if(!atomic.active()){setLastError(database_.lastError().text());return false;}
    QSqlQuery q(database_);
    const auto exec=[&](const QString& sql){if(q.exec(sql))return true;setLastError(q.lastError().text());return false;};
    const auto ensure=[&](const QString& column,const QString& definition){
        if(!exec("PRAGMA table_info(transactions)"))return false;
        while(q.next())if(q.value(1).toString()==column){q.finish();return true;}
        q.finish();return exec("ALTER TABLE transactions ADD COLUMN "+column+" "+definition);
    };
    if(!ensure("fee_minor","INTEGER CHECK(fee_minor>=0)")
       || !ensure("tax_minor","INTEGER CHECK(tax_minor>=0)")
       || !ensure("trade_currency","TEXT"))return false;
    const QString definition=
        "(snapshot_date TEXT NOT NULL CHECK(length(snapshot_date)=10),source_id TEXT NOT NULL,"
        "account_id TEXT NOT NULL,instrument_id TEXT NOT NULL DEFAULT '',currency TEXT NOT NULL,"
        "value_minor INTEGER,quantity_atomic INTEGER,quantity_decimals INTEGER NOT NULL CHECK(quantity_decimals BETWEEN 0 AND 18),"
        "price_micros INTEGER,cost_basis_minor INTEGER CHECK(cost_basis_minor>=0),valued_at INTEGER,"
        "observed_at INTEGER NOT NULL,source TEXT NOT NULL,issues TEXT NOT NULL DEFAULT '',details_json TEXT NOT NULL DEFAULT '{}',"
        "PRIMARY KEY(snapshot_date,source_id))";
    for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment}) {
        const auto table=snapshotTable(kind);
        if(!exec("CREATE TABLE IF NOT EXISTS "+table+definition)
           || !exec("CREATE INDEX IF NOT EXISTS idx_"+table+"_account_date ON "+table+"(account_id,snapshot_date)"))return false;
    }
    const QStringList statements{
        "CREATE TABLE IF NOT EXISTS daily_valuation_runs(snapshot_date TEXT PRIMARY KEY,observed_at INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS crypto_price_history(asset_id TEXT NOT NULL,quoted_at INTEGER NOT NULL,"
        "source TEXT NOT NULL,price_micros INTEGER NOT NULL,currency TEXT NOT NULL,observed_at INTEGER NOT NULL,terms_json TEXT NOT NULL DEFAULT '{}',"
        "PRIMARY KEY(asset_id,quoted_at,source))",
        "CREATE TABLE IF NOT EXISTS investment_price_history(asset_id TEXT NOT NULL,quoted_at INTEGER NOT NULL,"
        "source TEXT NOT NULL,price_micros INTEGER NOT NULL,currency TEXT NOT NULL,observed_at INTEGER NOT NULL,terms_json TEXT NOT NULL DEFAULT '{}',"
        "PRIMARY KEY(asset_id,quoted_at,source))",
        "CREATE TABLE IF NOT EXISTS fx_rate_history(currency TEXT NOT NULL,rate_date TEXT NOT NULL,source TEXT NOT NULL,"
        "rub_per_unit_micros INTEGER NOT NULL CHECK(rub_per_unit_micros>0),observed_at INTEGER NOT NULL,"
        "PRIMARY KEY(currency,rate_date,source))",
        "CREATE TABLE IF NOT EXISTS investment_position_history(sequence INTEGER PRIMARY KEY,position_id TEXT NOT NULL,"
        "account_id TEXT NOT NULL,instrument_id TEXT NOT NULL,currency TEXT NOT NULL,event TEXT NOT NULL,"
        "operation_id TEXT,occurred_at INTEGER NOT NULL,recorded_at INTEGER NOT NULL,quantity_micros INTEGER NOT NULL,"
        "before_quantity_micros INTEGER,cost_basis_minor INTEGER CHECK(cost_basis_minor>=0),before_cost_minor INTEGER,"
        "released_cost_minor INTEGER,realized_net_minor INTEGER,state_json TEXT NOT NULL,issues TEXT NOT NULL DEFAULT '')",
        "CREATE INDEX IF NOT EXISTS idx_position_history_position ON investment_position_history(position_id,sequence)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_position_history_operation ON investment_position_history(operation_id) WHERE operation_id IS NOT NULL"
    };
    for(const auto& sql:statements)if(!exec(sql))return false;
    for(const auto& action:{QStringLiteral("INSERT"),QStringLiteral("UPDATE"),QStringLiteral("DELETE")}) {
        QString predicate;
        if(action!="DELETE")predicate="(account_id=NEW.account_id AND snapshot_date>=date(NEW.occurred_at/1000,'unixepoch','localtime'))";
        if(action!="INSERT")predicate+=(predicate.isEmpty()?QString():QStringLiteral(" OR "))+"(account_id=OLD.account_id AND snapshot_date>=date(OLD.occurred_at/1000,'unixepoch','localtime'))";
        QString body;
        for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment}) {
            const auto table=snapshotTable(kind);
            body+="UPDATE "+table+" SET issues=CASE WHEN instr(issues,'history_changed')>0 THEN issues ELSE issues||';history_changed' END WHERE "+predicate+";";
        }
        if(!exec("CREATE TRIGGER IF NOT EXISTS history_transactions_"+action.toLower()+" AFTER "+action+" ON transactions BEGIN "+body+" END"))return false;
    }
    QString body;
    for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment})
        body+="UPDATE "+snapshotTable(kind)+" SET issues=CASE WHEN instr(issues,'history_changed')>0 THEN issues ELSE issues||';history_changed' END WHERE account_id=NEW.id;";
    if(!exec("CREATE TRIGGER IF NOT EXISTS history_account_basis AFTER UPDATE OF initial_balance_minor,currency ON accounts "
             "WHEN OLD.initial_balance_minor<>NEW.initial_balance_minor OR OLD.currency<>NEW.currency BEGIN "+body+" END"))return false;
    // Baselines record the observed state, without creating past purchase operations.
    QStringList positions;
    if(!exec("SELECT id FROM investment_positions WHERE NOT EXISTS (SELECT 1 FROM investment_position_history h WHERE h.position_id=investment_positions.id)"))return false;
    while(q.next())positions.append(q.value(0).toString());q.finish();
    for(const auto& id:positions)if(!investments.appendPositionState(id,"baseline")){setLastError(investments.lastError());return false;}
    // Repair the initial states recorded before average prices were used for
    // acquisition cost. Append a correction; do not rewrite historical sales,
    // explicit cost corrections or previously captured daily valuations.
    positions.clear();
    if(!exec(positionStateQuery+" WHERE p.is_archived=0 AND EXISTS (SELECT 1 FROM investment_position_history h "
        "WHERE h.position_id=p.id AND h.sequence=(SELECT max(sequence) FROM investment_position_history WHERE position_id=p.id) "
        "AND h.event IN ('opening','baseline') AND h.cost_basis_minor IS NULL) "
        "AND NOT EXISTS (SELECT 1 FROM transactions o WHERE o.position_id=p.id)"))return false;
    while(q.next())if(!averageAcquisitionCost(rowMap(q)).isNull())positions.append(q.value("id").toString());q.finish();
    for(const auto& id:positions)if(!investments.appendPositionState(id,"correction")){setLastError(investments.lastError());return false;}
    const qint64 now=QDateTime::currentMSecsSinceEpoch();
    q.prepare("INSERT OR IGNORE INTO crypto_price_history(asset_id,quoted_at,source,price_micros,currency,observed_at) "
              "SELECT symbol,fetched_at,'legacy',price_usd_micros,'USD',? FROM crypto_prices c WHERE NOT EXISTS (SELECT 1 FROM crypto_price_history h WHERE h.asset_id=c.symbol)");q.addBindValue(now);
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    q.prepare("INSERT OR IGNORE INTO investment_price_history(asset_id,quoted_at,source,price_micros,currency,observed_at,terms_json) "
              "SELECT q.instrument_id,q.quoted_at,'legacy',q.price_micros,i.currency,?,q.terms_json FROM investment_quotes q JOIN investment_instruments i ON i.id=q.instrument_id WHERE NOT EXISTS (SELECT 1 FROM investment_price_history h WHERE h.asset_id=q.instrument_id)");q.addBindValue(now);
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    if(!exec("CREATE TABLE IF NOT EXISTS benchmark_daily_prices(benchmark_key TEXT NOT NULL,price_date TEXT NOT NULL,price_micros INTEGER CHECK(price_micros>0),currency TEXT NOT NULL,issues TEXT NOT NULL,observed_at INTEGER NOT NULL,PRIMARY KEY(benchmark_key,price_date))")
        || !exec("CREATE TABLE IF NOT EXISTS benchmark_history_ranges(benchmark_key TEXT NOT NULL,from_date TEXT NOT NULL,to_date TEXT NOT NULL,observed_at INTEGER NOT NULL,PRIMARY KEY(benchmark_key,from_date,to_date))"))return false;
    return atomic.commit();
}

bool FinanceRepository::saveDailyValuations(const DailyValuationBatch& batch) {
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

QVariantList FinanceRepository::loadDailyValuations(AssetDailyValuation::Kind kind,const QDate& from,const QDate& to) {
    QVariantList rows;const auto table=snapshotTable(kind);if(table.isEmpty())return rows;
    QSqlQuery q(database_);q.prepare("SELECT * FROM "+table+" WHERE (?='' OR snapshot_date>=?) AND (?='' OR snapshot_date<=?) ORDER BY snapshot_date,source_id");
    for(auto date:{from,from,to,to})q.addBindValue(date.isValid()?date.toString(Qt::ISODate):QStringLiteral(""));
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}
QVariantList FinanceRepository::loadPriceHistory(AssetDailyValuation::Kind kind,const QString& id) {
    QVariantList rows;
    const QString table=kind==AssetDailyValuation::Crypto?QStringLiteral("crypto_price_history"):
        kind==AssetDailyValuation::Investment?QStringLiteral("investment_price_history"):QString();
    if(table.isEmpty())return rows;
    QSqlQuery q(database_);q.prepare("SELECT * FROM "+table+" WHERE asset_id=? ORDER BY quoted_at,source");q.addBindValue(id);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}
QVariantList FinanceRepository::loadFxHistory(const QString& currency) {
    QVariantList rows;QSqlQuery q(database_);q.prepare("SELECT * FROM fx_rate_history WHERE currency=? ORDER BY rate_date,source");q.addBindValue(currency);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}

QVariantList FinanceRepository::loadPerformanceAccounts() {
    QVariantList result; QSqlQuery q(database_);
    if(!q.exec("SELECT id,name,currency,initial_balance_minor,created_at,account_type FROM accounts WHERE is_archived=0 AND account_type IN (6,7) ORDER BY created_at,id")){setLastError(q.lastError().text());return result;}
    while(q.next())result.append(rowMap(q));return result;
}
QVariantMap FinanceRepository::loadAccountCreationDates() {
    QVariantMap result; QSqlQuery q(database_);
    if(!q.exec("SELECT id,created_at FROM accounts")){setLastError(q.lastError().text());return result;}
    while(q.next())result.insert(q.value(0).toString(),q.value(1).toLongLong());
    return result;
}
QString FinanceRepository::loadPerformanceInflation() const {
    QSqlQuery q(database_);q.prepare("SELECT value FROM settings WHERE key='performance_annual_inflation'");
    return q.exec() && q.next()?q.value(0).toString():QString();
}
bool FinanceRepository::savePerformanceInflation(const QString& value) {
    QSqlQuery q(database_);q.prepare("INSERT INTO settings(key,value) VALUES('performance_annual_inflation',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");q.addBindValue(value.isNull()?QStringLiteral(""):value);
    if(q.exec())return true;setLastError(q.lastError().text());return false;
}

QVariantMap FinanceRepository::loadPerformanceDeposit() const {
    QSqlQuery q(database_);q.prepare("SELECT value FROM settings WHERE key='performance_deposit'");
    return q.exec() && q.next()?QJsonDocument::fromJson(q.value(0).toString().toUtf8()).object().toVariantMap():QVariantMap();
}
bool FinanceRepository::savePerformanceDeposit(const QVariantMap& value) {
    QSqlQuery q(database_);q.prepare("INSERT INTO settings(key,value) VALUES('performance_deposit',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
    q.addBindValue(QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(value)).toJson(QJsonDocument::Compact)));
    if(q.exec())return true;setLastError(q.lastError().text());return false;
}

QVariantMap FinanceRepository::loadBenchmarkSelection() const {
    QSqlQuery q(database_);q.prepare("SELECT value FROM settings WHERE key='investment_benchmark'");
    return q.exec() && q.next()?QJsonDocument::fromJson(q.value(0).toString().toUtf8()).object().toVariantMap():QVariantMap();
}
bool FinanceRepository::saveBenchmarkSelection(const QVariantMap& descriptor) {
    QSqlQuery q(database_);q.prepare("INSERT INTO settings(key,value) VALUES('investment_benchmark',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
    q.addBindValue(QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(descriptor)).toJson(QJsonDocument::Compact)));
    if(q.exec())return true;setLastError(q.lastError().text());return false;
}
QVariantList FinanceRepository::loadBenchmarkPrices(const QString& key) {
    QVariantList rows;QSqlQuery q(database_);q.prepare("SELECT * FROM benchmark_daily_prices WHERE benchmark_key=? ORDER BY price_date");q.addBindValue(key);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}
bool FinanceRepository::benchmarkHistoryCovered(const QString& key,const QDate& from,const QDate& to) {
    QSqlQuery q(database_);q.prepare("SELECT 1 FROM benchmark_history_ranges WHERE benchmark_key=? AND from_date<=? AND to_date>=? LIMIT 1");
    q.addBindValue(key);q.addBindValue(from.toString(Qt::ISODate));q.addBindValue(to.toString(Qt::ISODate));return q.exec() && q.next();
}
bool FinanceRepository::saveBenchmarkHistory(const QVariantMap& descriptor,const QVariantList& prices,const QDate& from,const QDate& to) {
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

bool FinanceRepository::saveHistoricalFxRates(const QVector<HistoricalFxRate>& rates)
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

// The first day of the exchange history that was read completely; 0 while the exchange was never read that far back
