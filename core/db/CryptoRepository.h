#pragma once
#include "Database.h"
#include "../model/crypto/CryptoTransaction.h"
#include "../model/crypto/CryptoWallet.h"
#include <QDateTime>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

// Crypto wallets and exchange connections: names, balances, transactions, snapshots,
// coin prices, cost basis of coins and the refresh state kept in settings.
class CryptoRepository
{
public:
    struct CryptoPriceSnapshot
    {
        qint64 priceUsdMicros = 0;
        QDateTime fetchedAtUtc;
    };

    explicit CryptoRepository(Database& database);

    QString cryptoWalletName(const QString& id) const;
    bool setCryptoWalletName(const QString& id, const QString& name);
    QVariantList loadCryptoExchanges() const;
    bool saveCryptoExchange(const QVariantMap& account);
    bool saveCryptoExchangeSnapshot(const QString& id, const QVariantList& holdings,
                                   const QVariantList& operations, qint64 fetchedAtMs);
    bool deleteCryptoExchange(const QString& id);
    QVector<CryptoWallet> loadCryptoWallets();
    QVector<CryptoTransaction> loadCryptoTransactions();
    bool insertCryptoWallet(const CryptoWallet& wallet);
    bool updateCryptoWalletBalance(
        const QString& id,
        qint64 balanceAtomic,
        const QDateTime& fetchedAtUtc
        );
    bool deleteCryptoWallet(const QString& id);
    bool replaceCryptoTransactions(
        const QString& walletId,
        const QVector<CryptoTransaction>& transactions,
        const QDateTime& fetchedAtUtc
        );
    CryptoPriceSnapshot loadCryptoPrice(const QString& symbol) const;
    QDateTime loadCryptoRefreshAttemptUtc() const;
    bool saveCryptoRefreshAttemptUtc(const QDateTime& attemptedAtUtc);
    QDateTime loadCryptoPriceAttemptUtc() const;
    bool saveCryptoPriceAttemptUtc(const QDateTime& attemptedAtUtc);
    QString loadCryptoManualState() const;
    bool saveCryptoManualState(const QString& state);
    // Purchase price of the coins without trades, by "exchangeId|coin"
    QVariantMap loadCryptoCostBasis() const;
    bool saveCryptoCostBasis(const QString& exchangeId, const QString& coin, const QVariantMap& basis);
    qint64 loadCryptoHistoryFromMs(const QString& exchangeId) const;
    bool saveCryptoHistoryFromMs(const QString& exchangeId, qint64 fromMs);
    bool saveCryptoPrice(
        const QString& symbol,
        qint64 priceUsdMicros,
        const QDateTime& fetchedAtUtc
        );
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
