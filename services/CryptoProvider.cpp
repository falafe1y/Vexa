#include "CryptoProvider.h"

#include "CryptoParser.h"
#include "TronUsdtParser.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>

#include <cmath>

namespace
{

constexpr qsizetype kMaximumResponseSize = 2 * 1024 * 1024;

// A price as text ("83448.5") to millionths of a dollar; 0 when the text is not a positive number
qint64 priceToMicros(const QString& text)
{
    bool ok = false;
    const double price = text.toDouble(&ok);
    const double scaled = price * 1'000'000.0;
    if (!ok || !std::isfinite(scaled) || price <= 0.0) {
        return 0;
    }
    return std::llround(scaled);
}

// Bybit public tickers: {"retCode":0,"result":{"list":[{"symbol":"BTCUSDT","lastPrice":"83448.5",...}]}}
qint64 bybitLastPriceMicros(const QByteArray& response)
{
    const QJsonObject root = QJsonDocument::fromJson(response).object();
    if (root.value(QStringLiteral("retCode")).toInt(-1) != 0) {
        return 0;
    }
    const QJsonArray list = root.value(QStringLiteral("result")).toObject()
        .value(QStringLiteral("list")).toArray();
    if (list.isEmpty()) {
        return 0;
    }
    return priceToMicros(list.first().toObject()
        .value(QStringLiteral("lastPrice")).toString());
}

// Binance public ticker: {"symbol":"BTCUSDT","price":"83450.01000000"}
qint64 binanceLastPriceMicros(const QByteArray& response)
{
    return priceToMicros(QJsonDocument::fromJson(response).object()
        .value(QStringLiteral("price")).toString());
}
const QString kUsdtContract =
    QStringLiteral("TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t");

bool successfulResponse(QNetworkReply* reply, const QByteArray& response)
{
    const int statusCode = reply->attribute(
        QNetworkRequest::HttpStatusCodeAttribute).toInt();
    return reply->error() == QNetworkReply::NoError &&
           statusCode == 200 &&
           response.size() <= kMaximumResponseSize;
}

QString responseError(QNetworkReply* reply, const QByteArray& response)
{
    if (response.size() > kMaximumResponseSize) {
        return QStringLiteral("Crypto API response is too large");
    }
    const int statusCode = reply->attribute(
        QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (statusCode == 429) {
        return QStringLiteral("Crypto API rate limit exceeded");
    }
    return reply->errorString();
}

bool isSupportedWallet(const CryptoWallet& wallet)
{
    return (wallet.network() == QStringLiteral("TRON") &&
            wallet.symbol() == QStringLiteral("USDT") &&
            wallet.decimals() == 6) ||
           (wallet.network() == QStringLiteral("BITCOIN") &&
            wallet.symbol() == QStringLiteral("BTC") &&
            wallet.decimals() == 8) ||
           (wallet.network() == QStringLiteral("ETHEREUM") &&
            wallet.symbol() == QStringLiteral("ETH") &&
            wallet.decimals() == 8);
}

void addTronGridApiKey(QNetworkRequest& request)
{
    const QByteArray apiKey = qgetenv("VEXA_TRONGRID_API_KEY").trimmed();
    if (!apiKey.isEmpty()) {
        request.setRawHeader(QByteArrayLiteral("TRON-PRO-API-KEY"), apiKey);
    }
}

} // namespace

CryptoProvider::CryptoProvider(QObject* parent)
    : QObject(parent)
{
}

QNetworkRequest CryptoProvider::makeRequest(const QUrl& url) const
{
    QNetworkRequest request(url);
    request.setHeader(
        QNetworkRequest::UserAgentHeader,
        QStringLiteral("vexa/0.1"));
    request.setRawHeader(
        QByteArrayLiteral("Accept"),
        QByteArrayLiteral("application/json"));
    request.setTransferTimeout(15'000);
    return request;
}

QUrl CryptoProvider::ethereumApiUrl(
    const QString& action,
    const CryptoWallet& wallet,
    const bool includeHistoryParameters
    ) const
{
    const QString apiKey = qEnvironmentVariable("VEXA_BLOCKSCOUT_API_KEY")
        .trimmed();
    QUrl url(apiKey.isEmpty()
        ? QStringLiteral("https://eth.blockscout.com/api")
        : QStringLiteral("https://api.blockscout.com/v2/api"));
    QUrlQuery query;
    if (!apiKey.isEmpty()) {
        query.addQueryItem(QStringLiteral("apikey"), apiKey);
        query.addQueryItem(QStringLiteral("chainid"), QStringLiteral("1"));
    }
    query.addQueryItem(QStringLiteral("module"), QStringLiteral("account"));
    query.addQueryItem(QStringLiteral("action"), action);
    query.addQueryItem(QStringLiteral("address"), wallet.address());
    if (includeHistoryParameters) {
        query.addQueryItem(QStringLiteral("page"), QStringLiteral("1"));
        query.addQueryItem(QStringLiteral("offset"), QStringLiteral("50"));
        query.addQueryItem(QStringLiteral("sort"), QStringLiteral("desc"));
    }
    url.setQuery(query);
    return url;
}

void CryptoProvider::cancelAll()
{
    activeBalanceRequests_.clear();
    activeTransactionRequests_.clear();
    priceRequestActive_ = false;
    const auto replies = networkAccessManager_.findChildren<QNetworkReply*>();
    for (auto* reply : replies) {
        QObject::disconnect(reply, nullptr, this, nullptr);
        reply->abort();
        reply->deleteLater();
    }
}

bool CryptoProvider::requestBalance(const CryptoWallet& wallet)
{
    if (wallet.id().isEmpty() || !isSupportedWallet(wallet) ||
        activeBalanceRequests_.contains(wallet.id())) {
        return false;
    }

    QNetworkReply* reply = nullptr;
    if (wallet.network() == QStringLiteral("TRON")) {
        const QString parameter = tronUsdtBalanceParameter(wallet.address());
        if (parameter.isEmpty()) {
            return false;
        }
        QJsonObject payload;
        payload.insert(QStringLiteral("owner_address"), wallet.address());
        payload.insert(QStringLiteral("contract_address"), kUsdtContract);
        payload.insert(
            QStringLiteral("function_selector"),
            QStringLiteral("balanceOf(address)"));
        payload.insert(QStringLiteral("parameter"), parameter);
        payload.insert(QStringLiteral("visible"), true);

        QNetworkRequest request = makeRequest(QUrl(QStringLiteral(
            "https://api.trongrid.io/wallet/triggerconstantcontract")));
        addTronGridApiKey(request);
        request.setHeader(
            QNetworkRequest::ContentTypeHeader,
            QStringLiteral("application/json"));
        reply = networkAccessManager_.post(
            request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    } else if (wallet.network() == QStringLiteral("BITCOIN")) {
        if (!isValidBitcoinAddress(wallet.address())) {
            return false;
        }
        reply = networkAccessManager_.get(makeRequest(QUrl(QStringLiteral(
            "https://mempool.space/api/address/%1").arg(wallet.address()))));
    } else {
        if (!isValidEthereumAddress(wallet.address())) {
            return false;
        }
        reply = networkAccessManager_.get(makeRequest(ethereumApiUrl(
            QStringLiteral("balance"), wallet, false)));
    }

    activeBalanceRequests_.insert(wallet.id());
    QObject::connect(
        reply,
        &QNetworkReply::finished,
        this,
        [this, reply, wallet]()
        {
            finishBalanceRequest(reply, wallet);
        });
    return true;
}

// The prices of BTC and ETH come from the public tickers of Bybit (no key, no account);
// Binance answers for a coin when Bybit does not. USDT is a stablecoin and counts as one dollar.
struct CryptoProvider::PriceJob {
    QHash<QString, qint64> prices;
    int pending = 0;
    bool failed = false;
};

bool CryptoProvider::requestPrices()
{
    if (priceRequestActive_) {
        return false;
    }
    priceRequestActive_ = true;
    auto job = QSharedPointer<PriceJob>::create();
    job->prices.insert(QStringLiteral("USDT"), 1'000'000);
    for (const QString& symbol : {QStringLiteral("BTC"), QStringLiteral("ETH")}) {
        ++job->pending;
        fetchPrice(job, symbol, false);
    }
    return true;
}

void CryptoProvider::fetchPrice(
    const QSharedPointer<PriceJob>& job,
    const QString& symbol,
    const bool fromBinance
    )
{
    const QString pair = symbol + QStringLiteral("USDT");
    QUrl url(fromBinance
        ? QStringLiteral("https://api.binance.com/api/v3/ticker/price")
        : QStringLiteral("https://api.bybit.com/v5/market/tickers"));
    QUrlQuery query;
    if (!fromBinance) {
        query.addQueryItem(QStringLiteral("category"), QStringLiteral("spot"));
    }
    query.addQueryItem(QStringLiteral("symbol"), pair);
    url.setQuery(query);

    QNetworkReply* reply = networkAccessManager_.get(makeRequest(url));
    QObject::connect(
        reply,
        &QNetworkReply::finished,
        this,
        [this, job, symbol, fromBinance, reply]()
        {
            const QByteArray response = reply->readAll();
            const qint64 micros = successfulResponse(reply, response)
                ? (fromBinance
                       ? binanceLastPriceMicros(response)
                       : bybitLastPriceMicros(response))
                : 0;
            reply->deleteLater();
            if (micros > 0) {
                job->prices.insert(symbol, micros);
            } else if (!fromBinance) {
                // Bybit did not answer for this coin: ask Binance, the job stays pending
                fetchPrice(job, symbol, true);
                return;
            } else {
                job->failed = true;
            }
            if (--job->pending == 0) {
                finishPriceJob(job);
            }
        });
}

void CryptoProvider::finishPriceJob(const QSharedPointer<PriceJob>& job)
{
    priceRequestActive_ = false;
    const QDateTime fetchedAtUtc = QDateTime::currentDateTimeUtc();
    for (auto iterator = job->prices.cbegin(); iterator != job->prices.cend(); ++iterator) {
        emit priceUpdated(iterator.key(), iterator.value(), fetchedAtUtc);
    }
    if (job->failed) {
        emit requestFailed(
            QString(),
            QStringLiteral("Не удалось получить цены BTC или ETH ни с Bybit, ни с Binance"));
    }
    emit requestFinished();
}

bool CryptoProvider::requestTransactions(const CryptoWallet& wallet)
{
    if (wallet.id().isEmpty() || !isSupportedWallet(wallet) ||
        activeTransactionRequests_.contains(wallet.id())) {
        return false;
    }

    QUrl url;
    if (wallet.network() == QStringLiteral("TRON")) {
        if (!isValidTronAddress(wallet.address())) {
            return false;
        }
        url = QUrl(QStringLiteral(
            "https://api.trongrid.io/v1/accounts/%1/transactions/trc20")
            .arg(wallet.address()));
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("only_confirmed"), QStringLiteral("true"));
        query.addQueryItem(QStringLiteral("limit"), QStringLiteral("50"));
        query.addQueryItem(
            QStringLiteral("order_by"),
            QStringLiteral("block_timestamp,desc"));
        query.addQueryItem(QStringLiteral("contract_address"), kUsdtContract);
        url.setQuery(query);
    } else if (wallet.network() == QStringLiteral("BITCOIN")) {
        if (!isValidBitcoinAddress(wallet.address())) {
            return false;
        }
        url = QUrl(QStringLiteral("https://mempool.space/api/address/%1/txs")
            .arg(wallet.address()));
    } else {
        if (!isValidEthereumAddress(wallet.address())) {
            return false;
        }
        url = ethereumApiUrl(QStringLiteral("txlist"), wallet, true);
    }

    activeTransactionRequests_.insert(wallet.id());
    QNetworkRequest request = makeRequest(url);
    if (wallet.network() == QStringLiteral("TRON")) {
        addTronGridApiKey(request);
    }
    QNetworkReply* reply = networkAccessManager_.get(request);
    QObject::connect(
        reply,
        &QNetworkReply::finished,
        this,
        [this, reply, wallet]()
        {
            finishTransactionRequest(reply, wallet);
        });
    return true;
}

void CryptoProvider::finishBalanceRequest(
    QNetworkReply* reply,
    const CryptoWallet& wallet
    )
{
    activeBalanceRequests_.remove(wallet.id());
    const QByteArray response = reply->readAll();
    qint64 balanceAtomic = 0;
    QString error;
    bool parsed = false;
    if (successfulResponse(reply, response)) {
        if (wallet.network() == QStringLiteral("TRON")) {
            parsed = parseTronUsdtBalanceResponse(
                response, balanceAtomic, &error);
        } else if (wallet.network() == QStringLiteral("BITCOIN")) {
            parsed = parseBitcoinBalanceResponse(
                response, balanceAtomic, &error);
        } else {
            parsed = parseEthereumBalanceResponse(
                response, balanceAtomic, &error);
        }
    }
    if (parsed) {
        emit balanceUpdated(
            wallet.id(), balanceAtomic, QDateTime::currentDateTimeUtc());
    } else {
        if (error.isEmpty()) {
            error = responseError(reply, response);
        }
        emit requestFailed(wallet.id(), error);
    }

    reply->deleteLater();
    emit requestFinished();
}

void CryptoProvider::finishTransactionRequest(
    QNetworkReply* reply,
    const CryptoWallet& wallet
    )
{
    activeTransactionRequests_.remove(wallet.id());
    const QByteArray response = reply->readAll();
    QVector<CryptoTransaction> transactions;
    QString error;
    bool parsed = false;
    if (successfulResponse(reply, response)) {
        if (wallet.network() == QStringLiteral("TRON")) {
            parsed = parseTronUsdtTransactionsResponse(
                response, wallet.id(), transactions, &error);
        } else if (wallet.network() == QStringLiteral("BITCOIN")) {
            parsed = parseBitcoinTransactionsResponse(
                response,
                wallet.id(),
                wallet.address(),
                transactions,
                &error);
        } else {
            parsed = parseEthereumTransactionsResponse(
                response,
                wallet.id(),
                wallet.address(),
                transactions,
                &error);
        }
    }
    if (parsed) {
        emit transactionsUpdated(
            wallet.id(), transactions, QDateTime::currentDateTimeUtc());
    } else {
        if (error.isEmpty()) {
            error = responseError(reply, response);
        }
        emit requestFailed(wallet.id(), error);
    }

    reply->deleteLater();
    emit requestFinished();
}
