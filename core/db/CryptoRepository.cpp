#include "CryptoRepository.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include "HistorySavepoint.h"
#include "PriceHistory.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QTimeZone>
#include <QVariant>

CryptoRepository::CryptoRepository(Database& database)
    : database_(database.connection())
{
}

QString CryptoRepository::lastError() const { return lastError_; }
void CryptoRepository::setLastError(const QString& error) { lastError_ = error; }

QString CryptoRepository::cryptoWalletName(const QString& id) const
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("SELECT name FROM crypto_wallet_names WHERE id = ?"));
    query.addBindValue(id);
    return query.exec() && query.next() ? query.value(0).toString() : QString();
}

bool CryptoRepository::setCryptoWalletName(const QString& id, const QString& name)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("INSERT OR REPLACE INTO crypto_wallet_names(id, name) VALUES (?, ?)"));
    query.addBindValue(id); query.addBindValue(name);
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    return true;
}

QVariantList CryptoRepository::loadCryptoExchanges() const
{
    QVariantList result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral("SELECT id, name, holdings_json, history_json, fetched_at FROM crypto_exchanges WHERE is_archived = 0 ORDER BY rowid"))) return result;
    while (query.next()) {
        result.append(QVariantMap{{"id", query.value(0)}, {"name", query.value(1)},
            {"holdings", QJsonDocument::fromJson(query.value(2).toByteArray()).array().toVariantList()},
            {"history", QJsonDocument::fromJson(query.value(3).toByteArray()).array().toVariantList()},
            {"fetchedAtMs", query.value(4)}});
    }
    return result;
}

bool CryptoRepository::saveCryptoExchange(const QVariantMap& account)
{
    if (account.value("id").toString().isEmpty() || account.value("name").toString().trimmed().isEmpty()) return false;
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("INSERT INTO crypto_exchanges(id, name) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name WHERE is_archived = 0"));
    query.addBindValue(account.value("id")); query.addBindValue(account.value("name"));
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    return query.numRowsAffected() == 1;
}

bool CryptoRepository::saveCryptoExchangeSnapshot(const QString& id, const QVariantList& holdings,
                                                  const QVariantList& operations, qint64 fetchedAtMs)
{
    if (id.isEmpty() || fetchedAtMs <= 0 || !database_.transaction()) return false;
    QSqlQuery lookup(database_);
    lookup.prepare(QStringLiteral("SELECT history_json FROM crypto_exchanges WHERE id = ? AND is_archived = 0"));
    lookup.addBindValue(id);
    if (!lookup.exec() || !lookup.next()) { database_.rollback(); return false; }
    // Incremental updates keep earlier history and overwrite overlapping IDs without duplicates.
    QMap<QString, QVariantMap> merged;
    const auto old = QJsonDocument::fromJson(lookup.value(0).toByteArray()).array().toVariantList();
    lookup.finish();
    for (const auto& value : old) { const auto row = value.toMap(); merged.insert(row.value("transactionId").toString(), row); }
    for (const auto& value : operations) {
        const auto row = value.toMap();
        if (row.value("transactionId").toString().isEmpty() || row.value("occurredAtMs").toLongLong() <= 0) { database_.rollback(); return false; }
        merged.insert(row.value("transactionId").toString(), row);
    }
    QVariantList history;
    for (const auto& row : merged) history.append(row);
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("UPDATE crypto_exchanges SET holdings_json = ?, history_json = ?, fetched_at = ? WHERE id = ? AND is_archived = 0"));
    query.addBindValue(QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(holdings)).toJson(QJsonDocument::Compact)));
    query.addBindValue(QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(history)).toJson(QJsonDocument::Compact)));
    query.addBindValue(fetchedAtMs); query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1 || !database_.commit()) { setLastError(query.lastError().text()); database_.rollback(); return false; }
    return true;
}

bool CryptoRepository::deleteCryptoExchange(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("UPDATE crypto_exchanges SET is_archived = 1 WHERE id = ? AND is_archived = 0"));
    query.addBindValue(id);
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    return query.numRowsAffected() == 1;
}

QVector<CryptoWallet> CryptoRepository::loadCryptoWallets()
{
    QVector<CryptoWallet> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, address, network, symbol, decimals, balance_atomic, "
            "       balance_fetched_at, history_fetched_at "
            "FROM crypto_wallets WHERE is_archived = 0 "
            "ORDER BY created_at, symbol, address"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        const QVariant fetchedAt = query.value(6);
        result.append(CryptoWallet(
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toString(),
            query.value(3).toString(),
            query.value(4).toInt(),
            query.value(5).toLongLong(),
            fetchedAt.isNull()
                ? QDateTime()
                : QDateTime::fromMSecsSinceEpoch(
                      fetchedAt.toLongLong(), QTimeZone::UTC),
            query.value(7).isNull()
                ? QDateTime()
                : QDateTime::fromMSecsSinceEpoch(
                      query.value(7).toLongLong(), QTimeZone::UTC)));
    }
    return result;
}

QVector<CryptoTransaction> CryptoRepository::loadCryptoTransactions()
{
    QVector<CryptoTransaction> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT ct.wallet_id, ct.transaction_id, ct.from_address, "
            "       ct.to_address, ct.amount_atomic, ct.occurred_at "
            "FROM crypto_transactions ct "
            "JOIN crypto_wallets cw ON cw.id = ct.wallet_id "
            "WHERE cw.is_archived = 0 "
            "ORDER BY ct.occurred_at DESC, ct.transaction_id"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(CryptoTransaction(
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toString(),
            query.value(3).toString(),
            query.value(4).toLongLong(),
            QDateTime::fromMSecsSinceEpoch(
                query.value(5).toLongLong(), QTimeZone::UTC)));
    }
    return result;
}

bool CryptoRepository::insertCryptoWallet(const CryptoWallet& wallet)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO crypto_wallets("
        "id, address, network, symbol, decimals, balance_atomic, "
        "balance_fetched_at, is_archived, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)"));
    query.addBindValue(wallet.id());
    query.addBindValue(wallet.address());
    query.addBindValue(wallet.network());
    query.addBindValue(wallet.symbol());
    query.addBindValue(wallet.decimals());
    query.addBindValue(wallet.balanceAtomic());
    if (wallet.balanceFetchedAtUtc().isValid()) {
        query.addBindValue(
            wallet.balanceFetchedAtUtc().toUTC().toMSecsSinceEpoch());
    } else {
        query.addBindValue(QVariant());
    }
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());

    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool CryptoRepository::updateCryptoWalletBalance(
    const QString& id,
    const qint64 balanceAtomic,
    const QDateTime& fetchedAtUtc
    )
{
    if (balanceAtomic < 0 || !fetchedAtUtc.isValid()) {
        setLastError(QStringLiteral("Invalid crypto-wallet balance snapshot"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE crypto_wallets "
        "SET balance_atomic = ?, balance_fetched_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(balanceAtomic);
    query.addBindValue(fetchedAtUtc.toUTC().toMSecsSinceEpoch());
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Crypto wallet was not found"));
        return false;
    }
    return true;
}

bool CryptoRepository::deleteCryptoWallet(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE crypto_wallets SET is_archived = 1 "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Crypto wallet was not found"));
        return false;
    }
    return true;
}

bool CryptoRepository::replaceCryptoTransactions(
    const QString& walletId,
    const QVector<CryptoTransaction>& transactions,
    const QDateTime& fetchedAtUtc
    )
{
    if (walletId.isEmpty() || !fetchedAtUtc.isValid()) {
        setLastError(QStringLiteral("Invalid crypto transaction snapshot"));
        return false;
    }
    for (const CryptoTransaction& transaction : transactions) {
        if (transaction.walletId() != walletId ||
            transaction.transactionId().isEmpty() ||
            transaction.fromAddress().isEmpty() ||
            transaction.toAddress().isEmpty() ||
            transaction.amountAtomic() <= 0 ||
            !transaction.occurredAtUtc().isValid()) {
            setLastError(QStringLiteral("Invalid crypto transaction"));
            return false;
        }
    }

    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery deletion(database_);
    deletion.prepare(QStringLiteral(
        "DELETE FROM crypto_transactions WHERE wallet_id = ?"));
    deletion.addBindValue(walletId);
    if (!deletion.exec()) {
        setLastError(deletion.lastError().text());
        database_.rollback();
        return false;
    }

    QSqlQuery insertion(database_);
    insertion.prepare(QStringLiteral(
        "INSERT INTO crypto_transactions("
        "wallet_id, transaction_id, from_address, to_address, "
        "amount_atomic, occurred_at) VALUES (?, ?, ?, ?, ?, ?)"));
    for (const CryptoTransaction& transaction : transactions) {
        insertion.bindValue(0, transaction.walletId());
        insertion.bindValue(1, transaction.transactionId());
        insertion.bindValue(2, transaction.fromAddress());
        insertion.bindValue(3, transaction.toAddress());
        insertion.bindValue(4, transaction.amountAtomic());
        insertion.bindValue(
            5,
            transaction.occurredAtUtc().toUTC().toMSecsSinceEpoch());
        if (!insertion.exec()) {
            setLastError(insertion.lastError().text());
            database_.rollback();
            return false;
        }
    }

    QSqlQuery wallet(database_);
    wallet.prepare(QStringLiteral(
        "UPDATE crypto_wallets SET history_fetched_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    wallet.addBindValue(fetchedAtUtc.toUTC().toMSecsSinceEpoch());
    wallet.addBindValue(walletId);
    if (!wallet.exec() || wallet.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(wallet.lastError().isValid()
                         ? wallet.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

CryptoRepository::CryptoPriceSnapshot CryptoRepository::loadCryptoPrice(
    const QString& symbol
    ) const
{
    CryptoPriceSnapshot result;
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "SELECT price_usd_micros, fetched_at "
        "FROM crypto_prices WHERE symbol = ?"));
    query.addBindValue(symbol.trimmed().toUpper());
    if (query.exec() && query.next()) {
        const qint64 price = query.value(0).toLongLong();
        if (price > 0) {
            result.priceUsdMicros = price;
        }
        if (!query.value(1).isNull()) {
            result.fetchedAtUtc = QDateTime::fromMSecsSinceEpoch(
                query.value(1).toLongLong(), QTimeZone::UTC);
        }
    }
    return result;
}

QDateTime CryptoRepository::loadCryptoRefreshAttemptUtc() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'crypto_refresh_attempt_utc'")) &&
        query.next()) {
        bool ok = false;
        const qint64 milliseconds = query.value(0).toString().toLongLong(&ok);
        if (ok && milliseconds > 0) {
            return QDateTime::fromMSecsSinceEpoch(
                milliseconds, QTimeZone::UTC);
        }
    }
    return {};
}

bool CryptoRepository::saveCryptoRefreshAttemptUtc(
    const QDateTime& attemptedAtUtc
    )
{
    if (!attemptedAtUtc.isValid()) {
        setLastError(QStringLiteral("Invalid crypto refresh timestamp"));
        return false;
    }
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) "
        "VALUES('crypto_refresh_attempt_utc', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(QString::number(
        attemptedAtUtc.toUTC().toMSecsSinceEpoch()));
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QDateTime CryptoRepository::loadCryptoPriceAttemptUtc() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'crypto_price_attempt_utc'")) &&
        query.next()) {
        bool ok = false;
        const qint64 milliseconds = query.value(0).toString().toLongLong(&ok);
        if (ok && milliseconds > 0) {
            return QDateTime::fromMSecsSinceEpoch(
                milliseconds, QTimeZone::UTC);
        }
    }
    return {};
}

bool CryptoRepository::saveCryptoPriceAttemptUtc(
    const QDateTime& attemptedAtUtc
    )
{
    if (!attemptedAtUtc.isValid()) {
        setLastError(QStringLiteral("Invalid crypto price timestamp"));
        return false;
    }
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) "
        "VALUES('crypto_price_attempt_utc', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(QString::number(
        attemptedAtUtc.toUTC().toMSecsSinceEpoch()));
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QString CryptoRepository::loadCryptoManualState() const
{
    QSqlQuery query(database_);
    if (query.exec(QStringLiteral(
            "SELECT value FROM settings "
            "WHERE key = 'crypto_manual_refresh_state'")) &&
        query.next()) {
        return query.value(0).toString();
    }
    return {};
}

bool CryptoRepository::saveCryptoManualState(const QString& state)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO settings(key, value) "
        "VALUES('crypto_manual_refresh_state', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(state);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QVariantMap CryptoRepository::loadCryptoCostBasis() const
{
    static const QString prefix = QStringLiteral("crypto_cost_basis:");
    QVariantMap result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT key, value FROM settings WHERE key LIKE 'crypto_cost_basis:%'"))) {
        return result;
    }
    while (query.next()) {
        const QString key = query.value(0).toString().mid(prefix.size());
        result.insert(key, QJsonDocument::fromJson(query.value(1).toByteArray())
                               .object().toVariantMap());
    }
    return result;
}

bool CryptoRepository::saveCryptoCostBasis(
    const QString& exchangeId,
    const QString& coin,
    const QVariantMap& basis
    )
{
    const QString key = QStringLiteral("crypto_cost_basis:") + exchangeId + QLatin1Char('|') + coin;
    QSqlQuery query(database_);
    if (basis.isEmpty()) {
        query.prepare(QStringLiteral("DELETE FROM settings WHERE key = ?"));
        query.addBindValue(key);
    } else {
        query.prepare(QStringLiteral(
            "INSERT INTO settings(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
        query.addBindValue(key);
        query.addBindValue(QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(basis))
                                                 .toJson(QJsonDocument::Compact)));
    }
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

// The first day of the exchange history that was read completely; 0 while the exchange was never read that far back
qint64 CryptoRepository::loadCryptoHistoryFromMs(const QString& exchangeId) const
{
    QSqlQuery q(database_);
    q.prepare("SELECT value FROM settings WHERE key=?");
    q.addBindValue(QStringLiteral("crypto_history_from:") + exchangeId);
    return q.exec() && q.next() ? q.value(0).toLongLong() : 0;
}

bool CryptoRepository::saveCryptoHistoryFromMs(const QString& exchangeId, qint64 fromMs)
{
    QSqlQuery q(database_);
    q.prepare("INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
    q.addBindValue(QStringLiteral("crypto_history_from:") + exchangeId);
    q.addBindValue(QString::number(fromMs));
    if (!q.exec()) {
        setLastError(q.lastError().text());
        return false;
    }
    return true;
}

bool CryptoRepository::saveCryptoPrice(
    const QString& symbol,
    const qint64 priceUsdMicros,
    const QDateTime& fetchedAtUtc
    )
{
    HistorySavepoint atomic(database_);
    if (!atomic.active()) { setLastError(database_.lastError().text()); return false; }

    const QString normalizedSymbol = symbol.trimmed().toUpper();
    if ((normalizedSymbol != QStringLiteral("USDT") &&
         normalizedSymbol != QStringLiteral("BTC") &&
         normalizedSymbol != QStringLiteral("ETH")) ||
        priceUsdMicros <= 0 || !fetchedAtUtc.isValid()) {
        setLastError(QStringLiteral("Invalid crypto price snapshot"));
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO crypto_prices(symbol, price_usd_micros, fetched_at) "
        "VALUES(?, ?, ?) "
        "ON CONFLICT(symbol) DO UPDATE SET "
        "price_usd_micros = excluded.price_usd_micros, "
        "fetched_at = excluded.fetched_at WHERE excluded.fetched_at >= crypto_prices.fetched_at"));
    query.addBindValue(normalizedSymbol);
    query.addBindValue(priceUsdMicros);
    query.addBindValue(fetchedAtUtc.toUTC().toMSecsSinceEpoch());
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    if (!savePriceHistory(database_, lastError_, "crypto", normalizedSymbol, priceUsdMicros, fetchedAtUtc, "USD", "crypto_provider")) return false;
    return atomic.commit();
}
