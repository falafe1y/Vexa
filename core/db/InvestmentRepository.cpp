#include "InvestmentRepository.h"

#include "HistorySavepoint.h"
#include "PositionHistory.h"
#include "PriceHistory.h"
#include "SqlRow.h"
#include <QDate>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QTimeZone>

#include <limits>

namespace {
bool insertInvestmentOperation(QSqlDatabase& database, const InvestmentOperation& op, QString& error)
{
    if(op.id.isEmpty() || op.accountId.isEmpty() || (op.instrumentId.isEmpty() && op.kind!="fee" && op.kind!="tax") || !op.occurredAtUtc.isValid()
        || (op.feeMinor && *op.feeMinor<0) || (op.taxMinor && *op.taxMinor<0)) {
        error=QStringLiteral("Некорректная инвестиционная операция");return false;
    }
    QSqlQuery q(database);q.prepare("INSERT INTO transactions(id,account_id,category_id,type,amount_minor,occurred_at,"
        "description,recipient_json,created_at,kind,position_id,instrument_id,quantity_micros,price_micros,"
        "trade_currency,fee_minor,tax_minor) SELECT ?,?,NULL,?,?,?,?,'{}',?,?,?,?,?,?,?,?,? "
        "WHERE EXISTS (SELECT 1 FROM accounts WHERE id=? AND asset_type=2 AND account_type=6 AND is_archived=0)");
    q.addBindValue(op.id);q.addBindValue(op.accountId);
    q.addBindValue(op.cashDeltaMinor>=0?0:1);q.addBindValue(op.cashDeltaMinor>=0?op.cashDeltaMinor:-op.cashDeltaMinor);
    q.addBindValue(op.occurredAtUtc.toMSecsSinceEpoch());q.addBindValue(op.description.isNull()?QStringLiteral(""):op.description);
    q.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());q.addBindValue(op.kind);
    q.addBindValue(op.positionId.isEmpty()?QVariant():QVariant(op.positionId));
    q.addBindValue(op.instrumentId.isEmpty()?QVariant():QVariant(op.instrumentId));q.addBindValue(op.quantityDeltaMicros);
    q.addBindValue(op.tradePriceMicros ? QVariant(*op.tradePriceMicros) : QVariant());
    q.addBindValue(op.tradeCurrency.isEmpty() ? QVariant() : QVariant(op.tradeCurrency));
    q.addBindValue(op.feeMinor ? QVariant(*op.feeMinor) : QVariant());
    q.addBindValue(op.taxMinor ? QVariant(*op.taxMinor) : QVariant());
    q.addBindValue(op.accountId);
    if(!q.exec() || q.numRowsAffected()!=1){error=q.lastError().isValid()?q.lastError().text():QStringLiteral("Счёт не найден");return false;}return true;
}
}

InvestmentRepository::InvestmentRepository(Database& database)
    : database_(database.connection())
{
}

QString InvestmentRepository::lastError() const { return lastError_; }
void InvestmentRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<InvestmentInstrument> InvestmentRepository::loadInvestmentInstruments()
{
    QVector<InvestmentInstrument> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, symbol, isin, name, type, currency, "
            "       market_code, primary_board_id, terms_json "
            "FROM investment_instruments WHERE is_archived = 0 "
            "ORDER BY name COLLATE NOCASE, symbol COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(InvestmentInstrument(
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toString(),
            query.value(3).toString(),
            static_cast<InvestmentInstrumentType>(query.value(4).toInt()),
            currencyFromCode(query.value(5).toString()),
            query.value(6).toString(),
            query.value(7).toString(), InvestmentTerms::deserialize(query.value(8).toString())));
    }
    return result;
}

QVector<InvestmentPosition> InvestmentRepository::loadInvestmentPositions()
{
    QVector<InvestmentPosition> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT p.id, p.account_id, p.instrument_id, "
            "       p.quantity_micros, p.average_price_micros, "
            "       p.created_at, p.updated_at, p.settings_json "
            "FROM investment_positions p "
            "JOIN accounts a ON a.id = p.account_id "
            "JOIN investment_instruments i ON i.id = p.instrument_id "
            "WHERE p.is_archived = 0 AND a.is_archived = 0 "
            "  AND i.is_archived = 0 "
            "ORDER BY p.created_at, p.id"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(InvestmentPosition(
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toString(),
            query.value(3).toLongLong(),
            query.value(4).toLongLong(),
            QDateTime::fromMSecsSinceEpoch(
                query.value(5).toLongLong(), QTimeZone::UTC),
            QDateTime::fromMSecsSinceEpoch(
                query.value(6).toLongLong(), QTimeZone::UTC),
            InvestmentPositionSettings::deserialize(query.value(7).toString())));
    }
    return result;
}

QVector<InvestmentQuote> InvestmentRepository::loadInvestmentQuotes()
{
    QVector<InvestmentQuote> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT q.instrument_id, q.price_micros, q.quoted_at, q.terms_json "
            "FROM investment_quotes q "
            "JOIN investment_instruments i ON i.id = q.instrument_id "
            "WHERE i.is_archived = 0 "
            "ORDER BY q.quoted_at DESC, q.instrument_id"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(InvestmentQuote(
            query.value(0).toString(),
            query.value(1).toLongLong(),
            QDateTime::fromMSecsSinceEpoch(
                query.value(2).toLongLong(), QTimeZone::UTC),
            InvestmentTerms::deserialize(query.value(3).toString())));
    }
    return result;
}

bool InvestmentRepository::insertInvestmentInstrument(
    const InvestmentInstrument& instrument
    )
{
    const QString id = instrument.id().trimmed();
    const QString symbol = instrument.symbol().trimmed();
    const QString isin = instrument.isin().isNull()?QStringLiteral(""):instrument.isin().trimmed().toUpper();
    const QString name = instrument.name().trimmed();
    const QString marketCode = instrument.marketCode().trimmed().toUpper();
    const QString primaryBoardId =
        instrument.primaryBoardId().trimmed().toUpper();
    const int type = static_cast<int>(instrument.type());
    if (id.isEmpty() || symbol.isEmpty() || name.isEmpty() ||
        type < static_cast<int>(InvestmentInstrumentType::Stock) ||
        type > static_cast<int>(InvestmentInstrumentType::Option)) {
        setLastError(QStringLiteral("Invalid investment instrument"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO investment_instruments("
        "id, symbol, isin, name, type, currency, market_code, "
        "primary_board_id, terms_json, is_archived, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)"));
    query.addBindValue(id);
    query.addBindValue(symbol);
    query.addBindValue(isin);
    query.addBindValue(name);
    query.addBindValue(type);
    query.addBindValue(currencyCode(instrument.currency()));
    query.addBindValue(marketCode);
    query.addBindValue(primaryBoardId);
    query.addBindValue(instrument.terms().serialize());
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool InvestmentRepository::updateInvestmentInstrument(
    const InvestmentInstrument& instrument
    )
{
    const QString symbol = instrument.symbol().trimmed();
    const QString isin = instrument.isin().isNull()?QStringLiteral(""):instrument.isin().trimmed().toUpper();
    const QString name = instrument.name().trimmed();
    const QString marketCode = instrument.marketCode().trimmed().toUpper();
    const QString primaryBoardId =
        instrument.primaryBoardId().trimmed().toUpper();
    const int type = static_cast<int>(instrument.type());
    if (instrument.id().trimmed().isEmpty() || symbol.isEmpty() ||
        name.isEmpty() ||
        type < static_cast<int>(InvestmentInstrumentType::Stock) ||
        type > static_cast<int>(InvestmentInstrumentType::Option)) {
        setLastError(QStringLiteral("Invalid investment instrument"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE investment_instruments "
        "SET symbol = ?, isin = ?, name = ?, type = ?, currency = ?, "
        "    market_code = ?, primary_board_id = ?, terms_json = ? "
        "WHERE id = ? AND is_archived = 0 "
        "  AND (currency = ? OR ("
        "      NOT EXISTS (SELECT 1 FROM investment_positions "
        "          WHERE instrument_id = ? AND is_archived = 0) "
        "      AND NOT EXISTS (SELECT 1 FROM investment_quotes "
        "          WHERE instrument_id = ?)))"));
    query.addBindValue(symbol);
    query.addBindValue(isin);
    query.addBindValue(name);
    query.addBindValue(type);
    query.addBindValue(currencyCode(instrument.currency()));
    query.addBindValue(marketCode);
    query.addBindValue(primaryBoardId);
    query.addBindValue(instrument.terms().serialize());
    query.addBindValue(instrument.id());
    query.addBindValue(currencyCode(instrument.currency()));
    query.addBindValue(instrument.id());
    query.addBindValue(instrument.id());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Investment instrument was not found or its currency cannot be changed"));
        return false;
    }
    return true;
}

bool InvestmentRepository::archiveInvestmentInstrument(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE investment_instruments SET is_archived = 1 "
        "WHERE id = ? AND is_archived = 0 "
        "  AND NOT EXISTS ("
        "      SELECT 1 FROM investment_positions "
        "      WHERE instrument_id = ? AND is_archived = 0)"));
    query.addBindValue(id);
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Investment instrument was not found or has positions"));
        return false;
    }
    return true;
}

bool InvestmentRepository::insertInvestmentPosition(
    const InvestmentPosition& position
    )
{
    HistorySavepoint atomic(database_);
    if (!atomic.active()) { setLastError(database_.lastError().text()); return false; }

    if (position.id().trimmed().isEmpty() ||
        position.accountId().trimmed().isEmpty() ||
        position.instrumentId().trimmed().isEmpty() ||
        position.quantityMicros() <= 0 ||
        position.averagePriceMicros() < 0 ||
        (position.settings().direction != 1 && position.settings().direction != -1) ||
        position.settings().blockedMarginMinor < 0 || position.settings().manualFxRateMicros < 0) {
        setLastError(QStringLiteral("Invalid investment position"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO investment_positions("
        "id, account_id, instrument_id, quantity_micros, "
        "average_price_micros, settings_json, is_archived, created_at, updated_at) "
        "SELECT ?, ?, ?, ?, ?, ?, 0, ?, ? "
        "WHERE EXISTS ("
        "    SELECT 1 FROM accounts "
        "    WHERE id = ? AND asset_type = 2 AND is_archived = 0) "
        "AND EXISTS ("
        "    SELECT 1 FROM investment_instruments "
        "    WHERE id = ? AND is_archived = 0)"));
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    query.addBindValue(position.id());
    query.addBindValue(position.accountId());
    query.addBindValue(position.instrumentId());
    query.addBindValue(position.quantityMicros());
    query.addBindValue(position.averagePriceMicros());
    query.addBindValue(position.settings().serialize());
    query.addBindValue(now);
    query.addBindValue(now);
    query.addBindValue(position.accountId());
    query.addBindValue(position.instrumentId());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Investment account or instrument was not found"));
        return false;
    }
    if (!appendPositionState(position.id(), "opening")) return false;
    return atomic.commit();
}

bool InvestmentRepository::updateInvestmentPosition(
    const InvestmentPosition& position
    )
{
    HistorySavepoint atomic(database_);
    if (!atomic.active()) { setLastError(database_.lastError().text()); return false; }

    if (position.id().trimmed().isEmpty() ||
        position.accountId().trimmed().isEmpty() ||
        position.instrumentId().trimmed().isEmpty() ||
        position.quantityMicros() <= 0 ||
        position.averagePriceMicros() < 0 ||
        (position.settings().direction != 1 && position.settings().direction != -1) ||
        position.settings().blockedMarginMinor < 0 || position.settings().manualFxRateMicros < 0) {
        setLastError(QStringLiteral("Invalid investment position"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE investment_positions "
        "SET account_id = ?, instrument_id = ?, quantity_micros = ?, "
        "    average_price_micros = ?, settings_json = ?, updated_at = ? "
        "WHERE id = ? AND is_archived = 0 "
        "  AND EXISTS (SELECT 1 FROM accounts "
        "      WHERE id = ? AND asset_type = 2 AND is_archived = 0) "
        "  AND EXISTS (SELECT 1 FROM investment_instruments "
        "      WHERE id = ? AND is_archived = 0)"));
    query.addBindValue(position.accountId());
    query.addBindValue(position.instrumentId());
    query.addBindValue(position.quantityMicros());
    query.addBindValue(position.averagePriceMicros());
    query.addBindValue(position.settings().serialize());
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(position.id());
    query.addBindValue(position.accountId());
    query.addBindValue(position.instrumentId());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Investment position, account or instrument was not found"));
        return false;
    }
    if (!appendPositionState(position.id(), "correction")) return false;
    return atomic.commit();
}

bool InvestmentRepository::deleteInvestmentPosition(const QString& id)
{
    HistorySavepoint atomic(database_);
    if (!atomic.active()) { setLastError(database_.lastError().text()); return false; }

    if (!appendPositionState(id, "delete")) return false;
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "DELETE FROM investment_positions WHERE id = ?"));
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Investment position was not found"));
        return false;
    }
    return atomic.commit();
}

bool InvestmentRepository::archiveInvestmentPosition(const QString& id)
{
    HistorySavepoint atomic(database_);
    if (!atomic.active()) { setLastError(database_.lastError().text()); return false; }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE investment_positions SET is_archived = 1, updated_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Investment position was not found"));
        return false;
    }
    if (!appendPositionState(id, "archive")) return false;
    return atomic.commit();
}

bool InvestmentRepository::saveInvestmentQuote(const InvestmentQuote& quote)
{
    HistorySavepoint atomic(database_);
    if (!atomic.active()) { setLastError(database_.lastError().text()); return false; }

    if (quote.instrumentId().trimmed().isEmpty() ||
        !quote.quotedAtUtc().isValid()) {
        setLastError(QStringLiteral("Invalid investment quote"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO investment_quotes(instrument_id, price_micros, quoted_at, terms_json) "
        "SELECT ?, ?, ?, ? WHERE EXISTS ("
        "    SELECT 1 FROM investment_instruments "
        "    WHERE id = ? AND is_archived = 0 AND (? > 0 OR type = 9 OR (type = 10 AND ? = 0))) "
        "ON CONFLICT(instrument_id) DO UPDATE SET "
        "price_micros = excluded.price_micros, "
        "quoted_at = excluded.quoted_at, terms_json = excluded.terms_json "
        "WHERE excluded.quoted_at >= investment_quotes.quoted_at"));
    query.addBindValue(quote.instrumentId());
    query.addBindValue(quote.priceMicros());
    query.addBindValue(
        quote.quotedAtUtc().toUTC().toMSecsSinceEpoch());
    query.addBindValue(quote.terms().serialize());
    query.addBindValue(quote.instrumentId());
    query.addBindValue(quote.priceMicros());
    query.addBindValue(quote.priceMicros());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Investment instrument was not found or quote is stale"));
        return false;
    }
    QSqlQuery currency(database_); currency.prepare("SELECT currency,terms_json FROM investment_instruments WHERE id=?"); currency.addBindValue(quote.instrumentId());
    if (!currency.exec() || !currency.next()) { setLastError(currency.lastError().text()); return false; }
    const auto terms = quote.terms().currencyCode.isEmpty() ? InvestmentTerms::deserialize(currency.value(1).toString()) : quote.terms();
    const QString code = terms.currencyCode.isEmpty() ? currency.value(0).toString() : terms.currencyCode;
    if (!savePriceHistory(database_, lastError_, "investment", quote.instrumentId(), quote.priceMicros(), quote.quotedAtUtc(), code,
                         terms.quoteSource.isEmpty() ? QStringLiteral("market") : terms.quoteSource, terms.serialize())) return false;
    return atomic.commit();
}

QVector<InvestmentOperation> InvestmentRepository::loadInvestmentOperations()
{
    QVector<InvestmentOperation> result; QSqlQuery q(database_);
    if (!q.exec("SELECT t.id,t.account_id,t.position_id,t.instrument_id,t.kind,"
                "CASE WHEN t.type=0 THEN t.amount_minor ELSE -t.amount_minor END,"
                "t.quantity_micros,t.occurred_at,t.description,t.fee_minor,t.tax_minor,t.price_micros,t.trade_currency "
                "FROM transactions t JOIN accounts a ON a.id=t.account_id WHERE a.is_archived=0 "
                "AND t.kind IN ('buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry') ORDER BY t.occurred_at DESC,t.id")) {
        setLastError(q.lastError().text()); return result;
    }
    while(q.next()) { InvestmentOperation op{q.value(0).toString(),q.value(1).toString(),q.value(2).toString(),q.value(3).toString(),
        q.value(4).toString(),q.value(5).toLongLong(),q.value(6).toLongLong(),
        QDateTime::fromMSecsSinceEpoch(q.value(7).toLongLong(),QTimeZone::UTC),q.value(8).toString()};
        if (!q.value(9).isNull()) op.feeMinor=q.value(9).toLongLong();
        if (!q.value(10).isNull()) op.taxMinor=q.value(10).toLongLong();
        if (!q.value(11).isNull()) op.tradePriceMicros=q.value(11).toLongLong();
        op.tradeCurrency=q.value(12).toString(); result.append(op);
    }
    return result;
}

bool InvestmentRepository::hasInvestmentOperations(const QString& id) const
{
    QSqlQuery q(database_);q.prepare("SELECT 1 FROM transactions WHERE position_id=? AND kind IN ('buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry') LIMIT 1");q.addBindValue(id);
    return q.exec() && q.next();
}

bool InvestmentRepository::saveInvestmentBundle(const InvestmentInstrument& instrument,
    const InvestmentPosition& position, const std::optional<InvestmentQuote>& quote,
    bool editing, const std::optional<InvestmentOperation>& operation, const std::optional<qint64>& openingCostMinor, bool clearCostBasis,
    const QVector<InvestmentOperation>& charges)
{
    if(operation && (editing || operation->positionId!=position.id() || operation->accountId!=position.accountId()
        || operation->instrumentId!=position.instrumentId() || operation->kind!="buy" || openingCostMinor)) {
        setLastError(QStringLiteral("Операция открытия не соответствует позиции"));return false;
    }
    if(openingCostMinor && (instrument.type()==InvestmentInstrumentType::Future || instrument.type()==InvestmentInstrumentType::Option || position.settings().direction!=1)) {
        setLastError(QStringLiteral("Стоимость приобретения не применяется к этой позиции"));return false;
    }
    if(openingCostMinor && *openingCostMinor<0){setLastError(QStringLiteral("Стоимость приобретения не может быть отрицательной"));return false;}
    if(!database_.transaction()){setLastError(database_.lastError().text());return false;}
    const auto fail=[&](){const auto error=lastError_;database_.rollback();setLastError(error);return false;};
    QSqlQuery q(database_);q.prepare("SELECT is_archived FROM investment_instruments WHERE id=?");q.addBindValue(instrument.id());
    if(!q.exec()){setLastError(q.lastError().text());return fail();}
    const bool exists=q.next();const bool archived=exists && q.value(0).toBool();q.finish();
    if(archived){q.prepare("UPDATE investment_instruments SET is_archived=0 WHERE id=?");q.addBindValue(instrument.id());
        if(!q.exec()){setLastError(q.lastError().text());return fail();}}
    if(!(exists?updateInvestmentInstrument(instrument):insertInvestmentInstrument(instrument)))return fail();
    if(!(editing?updateInvestmentPosition(position):insertInvestmentPosition(position)))return fail();
    if(quote && !saveInvestmentQuote(*quote))return fail();
    if(operation){QString error;if(!insertInvestmentOperation(database_,*operation,error)){setLastError(error);return fail();}
        // The position history books the purchase with its commission: the cost of the position includes it.
        InvestmentOperation historyOp=*operation;
        for(const auto& charge:charges)historyOp.cashDeltaMinor+=charge.cashDeltaMinor;
        if(!completePositionEvent(historyOp,QVariant(qint64(0)),0,position.quantityMicros())) return fail();
        for(const auto& charge:charges){
            if(charge.positionId!=position.id() || charge.accountId!=position.accountId() || charge.instrumentId!=position.instrumentId() || charge.quantityDeltaMicros!=0){
                setLastError(QStringLiteral("Комиссия относится к другой позиции"));return fail();
            }
            if(!insertInvestmentOperation(database_,charge,error)){setLastError(error);return fail();}
        }
    } else if(openingCostMinor || clearCostBasis) {
        QSqlQuery cost(database_); cost.prepare("UPDATE investment_position_history SET cost_basis_minor=?,issues=? WHERE sequence=(SELECT max(sequence) FROM investment_position_history WHERE position_id=?)");
        cost.addBindValue(openingCostMinor?QVariant(*openingCostMinor):QVariant());
        cost.addBindValue(openingCostMinor?QStringLiteral(""):QStringLiteral("cost_unknown"));cost.addBindValue(position.id());
        if(!cost.exec()){setLastError(cost.lastError().text());return fail();}
    }
    if(!database_.commit()){setLastError(database_.lastError().text());return fail();}return true;
}

bool InvestmentRepository::bookInvestmentOperation(const InvestmentOperation& op,
    const InvestmentPosition& expected, const InvestmentPosition& updated, bool close,
    const std::optional<InvestmentQuote>& quote, const QVector<InvestmentOperation>& charges)
{
    if(op.positionId!=expected.id() || op.accountId!=expected.accountId() || op.instrumentId!=expected.instrumentId()
        || (close?0:updated.quantityMicros())-expected.quantityMicros()!=op.quantityDeltaMicros
        || updated.id()!=expected.id() || updated.accountId()!=expected.accountId() || updated.instrumentId()!=expected.instrumentId()) {
        setLastError(QStringLiteral("Операция не соответствует позиции"));return false;
    }
    if(!database_.transaction()){setLastError(database_.lastError().text());return false;}
    const auto fail=[&](const QString& error){database_.rollback();setLastError(error);return false;};
    QSqlQuery q(database_);q.prepare("SELECT quantity_micros,settings_json,average_price_micros FROM investment_positions WHERE id=? AND is_archived=0");q.addBindValue(expected.id());
    if(!q.exec() || !q.next())return fail(QStringLiteral("Позиция не найдена"));
    if(q.value(0).toLongLong()!=expected.quantityMicros() || q.value(2).toLongLong()!=expected.averagePriceMicros()
        || InvestmentPositionSettings::deserialize(q.value(1).toString()).serialize()!=expected.settings().serialize())return fail(QStringLiteral("Позиция уже изменилась; откройте операцию заново"));
    q.finish();
    if(op.kind=="buy" || op.kind=="sell" || op.kind=="expiry" || op.kind=="margin") {
        q.prepare("SELECT max(occurred_at) FROM transactions WHERE position_id=? AND kind IN ('buy','sell','expiry','margin')");q.addBindValue(expected.id());
        if(!q.exec() || !q.next())return fail(q.lastError().text());
        if(!q.value(0).isNull() && q.value(0).toLongLong()/1000>op.occurredAtUtc.toSecsSinceEpoch())return fail(QStringLiteral("Изменение позиции предшествует последней записанной операции"));
        q.finish();
    }
    const QVariant previousBasis = investmentCostBasis(expected.id());
    if(!(close?archiveInvestmentPosition(expected.id()):updateInvestmentPosition(updated)))return fail(lastError_);
    if(quote && !saveInvestmentQuote(*quote))return fail(lastError_);
    QString error;if(!insertInvestmentOperation(database_,op,error))return fail(error);
    // The position history books a sale net of its commission and tax, which are rows of their own.
    InvestmentOperation historyOp=op;
    for(const auto& charge:charges)historyOp.cashDeltaMinor+=charge.cashDeltaMinor;
    if(!completePositionEvent(historyOp,previousBasis,expected.quantityMicros(),close?0:updated.quantityMicros()))return fail(lastError_);
    // Commission and tax of a sale are rows of their own: same position, same transaction, no change of the holding.
    for(const auto& charge:charges){
        if(charge.positionId!=op.positionId || charge.accountId!=op.accountId || charge.instrumentId!=op.instrumentId || charge.quantityDeltaMicros!=0)
            return fail(QStringLiteral("Комиссия или налог относятся к другой позиции"));
        if(!insertInvestmentOperation(database_,charge,error))return fail(error);
    }
    if(!database_.commit())return fail(database_.lastError().text());return true;
}

bool InvestmentRepository::insertAccountCharge(const InvestmentOperation& operation)
{
    // A commission or a tax of the brokerage account itself: a row without a position or an instrument.
    if(!database_.transaction()){setLastError(database_.lastError().text());return false;}
    QString error;
    if(!insertInvestmentOperation(database_,operation,error)){database_.rollback();setLastError(error);return false;}
    if(!database_.commit()){database_.rollback();setLastError(database_.lastError().text());return false;}
    return true;
}

QVariant InvestmentRepository::investmentCostBasis(const QString& id) const {
    QSqlQuery q(database_);q.prepare("SELECT cost_basis_minor FROM investment_position_history WHERE position_id=? ORDER BY sequence DESC LIMIT 1");q.addBindValue(id);
    return q.exec() && q.next()?q.value(0):QVariant();
}

bool InvestmentRepository::appendPositionState(const QString& id,const QString& event) {
    QSqlQuery q(database_);q.prepare(positionStateQuery+" WHERE p.id=?");
    q.addBindValue(id);if(!q.exec() || !q.next()){setLastError(QStringLiteral("Не удалось сохранить историю позиции"));return false;}
    const auto row=rowMap(q);const qint64 qty=row.value("quantity_micros").toLongLong();
    const bool closed=row.value("is_archived").toBool() || event=="delete";
    const auto settings=InvestmentPositionSettings::deserialize(row.value("settings_json").toString());
    const auto quotedTerms=InvestmentTerms::deserialize(row.value("quote_terms").toString());
    const auto terms=quotedTerms.currencyCode.isEmpty()?InvestmentTerms::deserialize(row.value("terms_json").toString()):quotedTerms;
    QJsonObject state{{"symbol",row.value("symbol").toString()}, {"type",row.value("type").toInt()},
        {"averagePriceMicros",QString::number(row.value("average_price_micros").toLongLong())},
        {"quantityMicros",QString::number(qty)}, {"settings",QJsonDocument::fromJson(settings.serialize().toUtf8()).object()},
        {"terms",QJsonDocument::fromJson(terms.serialize().toUtf8()).object()}};
    QVariant basis;QString issues=QStringLiteral("cost_unknown");
    bool useAverage=event=="opening" || event=="baseline";
    if(event=="correction" || event=="archive" || event=="delete") {
        QSqlQuery prior(database_);prior.prepare("SELECT account_id,instrument_id,quantity_micros,cost_basis_minor,state_json,event,currency FROM investment_position_history WHERE position_id=? ORDER BY sequence DESC LIMIT 1");prior.addBindValue(id);
        if(!prior.exec()){setLastError(prior.lastError().text());return false;}
        if(prior.next()){
            const auto old=QJsonDocument::fromJson(prior.value(4).toString().toUtf8()).object();
            const bool same=prior.value(0)==row.value("account_id") && prior.value(1)==row.value("instrument_id")
               && prior.value(2).toLongLong()==qty && old.value("averagePriceMicros")==state.value("averagePriceMicros")
               && old.value("settings").toObject().value("direction").toInt(1)==settings.direction
               && prior.value(6)==row.value("currency");
            if(same)basis=prior.value(3);
            useAverage=event=="correction" && (!same || (basis.isNull()
                && (prior.value(5)=="opening" || prior.value(5)=="baseline")));
        }
    }
    if(basis.isNull() && useAverage && !closed)basis=averageAcquisitionCost(row);
    if(!basis.isNull())issues.clear();
    if(closed && !basis.isNull())basis=qint64(0);
    const auto now=QDateTime::currentMSecsSinceEpoch();q.finish();
    q.prepare("INSERT INTO investment_position_history(position_id,account_id,instrument_id,currency,event,occurred_at,recorded_at,quantity_micros,cost_basis_minor,state_json,issues) VALUES(?,?,?,?,?,?,?,?,?,?,?)");
    q.addBindValue(id);q.addBindValue(row.value("account_id"));q.addBindValue(row.value("instrument_id"));q.addBindValue(row.value("currency"));q.addBindValue(event);
    q.addBindValue(now);q.addBindValue(now);q.addBindValue(closed?0:qty);q.addBindValue(basis);
    q.addBindValue(QString::fromUtf8(QJsonDocument(state).toJson(QJsonDocument::Compact)));q.addBindValue(issues);
    if(!q.exec()){setLastError(q.lastError().text());return false;}return true;
}

bool InvestmentRepository::completePositionEvent(const InvestmentOperation& op,const QVariant& previousBasis,qint64 before,qint64 after) {
    QSqlQuery q(database_);q.prepare("SELECT sequence,state_json FROM investment_position_history WHERE position_id=? ORDER BY sequence DESC LIMIT 1");q.addBindValue(op.positionId);
    if(!q.exec() || !q.next()){setLastError(QStringLiteral("Не найдена история позиции"));return false;}
    const auto sequence=q.value(0);auto state=QJsonDocument::fromJson(q.value(1).toString().toUtf8()).object();
    q.finish();
    q.prepare("SELECT terms_json FROM investment_quotes WHERE instrument_id=?");q.addBindValue(op.instrumentId);
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    if(q.next()){
        const auto terms=InvestmentTerms::deserialize(q.value(0).toString());
        if(!terms.currencyCode.isEmpty())state.insert("terms",QJsonDocument::fromJson(terms.serialize().toUtf8()).object());
    }
    const auto settings=state.value("settings").toObject();const int type=state.value("type").toInt();
    const bool ordinary=type!=9 && type!=10 && settings.value("direction").toInt(1)==1;
    QVariant basis=previousBasis,released,realized;QString issues;
    const auto checked=[&](const __int128_t n,QVariant& value){
        if(n>std::numeric_limits<qint64>::max() || n<std::numeric_limits<qint64>::min())return false;
        value=static_cast<qint64>(n);return true;
    };
    if(!ordinary){basis={};issues="derivative_cost_not_applicable";}
    else if(op.kind=="buy"){
        if(op.quantityDeltaMicros<=0 || after-before!=op.quantityDeltaMicros || op.cashDeltaMinor>=0){setLastError(QStringLiteral("Некорректное приобретение позиции"));return false;}
        if(!basis.isNull() && !checked(__int128_t(basis.toLongLong())-op.cashDeltaMinor,basis)){setLastError(QStringLiteral("Стоимость приобретения вне диапазона"));return false;}
    } else if(op.kind=="sell" || op.kind=="expiry"){
        if(before<=0 || after<0 || after>=before || op.quantityDeltaMicros!=after-before){setLastError(QStringLiteral("Некорректное уменьшение позиции"));return false;}
        if(!basis.isNull()){
            const qint64 old=basis.toLongLong();const qint64 used=after==0?old:static_cast<qint64>(__int128_t(old)*(before-after)/before);
            released=used;basis=old-used;
            if(!checked(__int128_t(op.cashDeltaMinor)-used,realized)){setLastError(QStringLiteral("Результат продажи вне диапазона"));return false;}
        } else if(after==0) basis=qint64(0);
    } else if(op.kind=="amortization"){
        q.finish();q.prepare("SELECT state_json FROM investment_position_history WHERE position_id=? AND sequence<? ORDER BY sequence DESC LIMIT 1");
        q.addBindValue(op.positionId);q.addBindValue(sequence);
        if(!q.exec()){setLastError(q.lastError().text());return false;}
        const auto oldState=q.next()?QJsonDocument::fromJson(q.value(0).toString().toUtf8()).object():QJsonObject();
        const auto oldFace=oldState.value("terms").toObject().value("face").toString().toLongLong();
        const auto newFace=state.value("terms").toObject().value("face").toString().toLongLong();
        if(!basis.isNull() && oldFace>0 && newFace>=0 && newFace<oldFace){
            const qint64 old=basis.toLongLong(),remaining=static_cast<qint64>(__int128_t(old)*newFace/oldFace);
            released=old-remaining;basis=remaining;
            if(!checked(__int128_t(op.cashDeltaMinor)-(old-remaining),realized)){setLastError(QStringLiteral("Результат погашения вне диапазона"));return false;}
        }else{basis={};issues="amortization_cost_unknown";}
    }
    if(basis.isNull() && issues.isEmpty())issues="cost_unknown";
    if(!op.feeMinor || !op.taxMinor)issues+=(issues.isEmpty()?QString():QStringLiteral(";"))+"charges_unknown";
    q.finish();q.prepare("UPDATE investment_position_history SET event=?,operation_id=?,occurred_at=?,before_quantity_micros=?,quantity_micros=?,"
        "before_cost_minor=?,cost_basis_minor=?,released_cost_minor=?,realized_net_minor=?,issues=?,state_json=? WHERE sequence=?");
    q.addBindValue(op.kind);q.addBindValue(op.id);q.addBindValue(op.occurredAtUtc.toMSecsSinceEpoch());q.addBindValue(before);q.addBindValue(after);
    q.addBindValue(previousBasis);q.addBindValue(basis);q.addBindValue(released);q.addBindValue(realized);q.addBindValue(issues);q.addBindValue(QString::fromUtf8(QJsonDocument(state).toJson(QJsonDocument::Compact)));q.addBindValue(sequence);
    if(!q.exec() || q.numRowsAffected()!=1){setLastError(q.lastError().text());return false;}
    // Previously captured dates affected by a newly booked historical event must be recalculated.
    const auto day=op.occurredAtUtc.toLocalTime().date().toString(Qt::ISODate);
    if(op.occurredAtUtc.toLocalTime().date()<QDate::currentDate()) {
        q.prepare("UPDATE investment_daily_snapshots SET issues=CASE WHEN instr(issues,'history_changed')>0 THEN issues ELSE issues||';history_changed' END WHERE account_id=? AND snapshot_date>=?");
        q.addBindValue(op.accountId);q.addBindValue(day);if(!q.exec()){setLastError(q.lastError().text());return false;}
    }
    return true;
}

QVariantList InvestmentRepository::loadPositionHistory(const QString& id) {
    QVariantList rows;QSqlQuery q(database_);q.prepare("SELECT * FROM investment_position_history WHERE position_id=? ORDER BY sequence");q.addBindValue(id);
    if(!q.exec()){setLastError(q.lastError().text());return rows;}while(q.next())rows.append(rowMap(q));return rows;
}

QVariantList InvestmentRepository::loadAllPositionHistory() {
    QVariantList result; QSqlQuery q(database_);
    if(!q.exec("SELECT * FROM investment_position_history ORDER BY sequence")){setLastError(q.lastError().text());return result;}
    while(q.next())result.append(rowMap(q));return result;
}
