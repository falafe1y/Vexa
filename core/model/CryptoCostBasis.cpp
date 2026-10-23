#include "CryptoCostBasis.h"

#include <QDateTime>
#include <QObject>
#include <QSet>

#include <algorithm>
#include <cmath>

bool isStableCoin(const QString& coin)
{
    static const QSet<QString> stable{QStringLiteral("USD"), QStringLiteral("USDT"), QStringLiteral("USDC"),
                                      QStringLiteral("FDUSD"), QStringLiteral("DAI"), QStringLiteral("TUSD"),
                                      QStringLiteral("BUSD"), QStringLiteral("USDE")};
    return stable.contains(coin.toUpper());
}

QMap<QDate, qint64> rubPerUsdByDate(const QVariantList& rows)
{
    QMap<QDate, qint64> rates;
    QMap<QDate, QString> sources;
    for (const QVariant& value : rows) {
        const QVariantMap row = value.toMap();
        const QDate day = QDate::fromString(row.value(QStringLiteral("rate_date")).toString(), Qt::ISODate);
        const qint64 micros = row.value(QStringLiteral("rub_per_unit_micros")).toLongLong();
        const QString source = row.value(QStringLiteral("source")).toString();
        if (!day.isValid() || micros <= 0)
            continue;
        if (sources.value(day) == QStringLiteral("CBR") && source != QStringLiteral("CBR"))
            continue;
        rates.insert(day, micros);
        sources.insert(day, source);
    }
    return rates;
}

CoinReturn coinReturnOf(const QString& coin, double quantity, double priceUsd, qint64 usdRubNowMicros,
                        const QVariantList& history, qint64 nowMillis, const QVariantMap& costBasis)
{
    // The simple return of a coin: the price now against its average purchase price, scaled to a year.
    // The average purchase price and day are weighted by the quantity bought. No compounding, no roubles.
    CoinReturn result;
    if (priceUsd <= 0 || usdRubNowMicros <= 0) {
        result.annual = AnnualReturn{std::nullopt, QStringLiteral("нет цены монеты или курса доллара"), 0};
        return result;
    }
    // Roubles = quantity × dollar price × CBR rate; kopecks are 1/100 of a rouble, micros are 1/1 000 000.
    result.valueMinor = std::llround(quantity * priceUsd * static_cast<double>(usdRubNowMicros) / 1e4);

    double boughtQuantity = 0;        // quantity bought in trades, plus the coins with a purchase given by the user
    double costUsd = 0;               // quantity × purchase price, summed
    double dayMsTimesQuantity = 0;    // quantity × purchase time (ms), summed
    double netQuantity = 0;           // all coin legs of the trades: buys add, sells subtract
    QString problem;
    for (const QVariant& value : history) {
        const QVariantMap row = value.toMap();
        // "symbol" is the currency of the row. A trade gives two rows: the coin leg (base) and the dollar leg (quote).
        const QString pair = row.value(QStringLiteral("pair")).toString();
        // Derivatives settle in a coin too (inverse contracts use BTC as margin): only spot trades are counted
        if (pair.isEmpty() || row.value(QStringLiteral("category")).toString() != QStringLiteral("spot")
            || row.value(QStringLiteral("symbol")).toString() != coin || !pair.startsWith(coin))
            continue;
        const QString quote = pair.mid(coin.size());
        if (!isStableCoin(quote)) {
            problem = QStringLiteral("есть сделки не за доллары");
            continue;
        }
        const QString side = row.value(QStringLiteral("tradeSide")).toString();
        bool priceOk = false, changeOk = false;
        const double tradePrice = row.value(QStringLiteral("tradePrice")).toString().toDouble(&priceOk);
        // The exact quantity of the coin is in "changeText"; "tradeQty" is rounded by the exchange
        const double change = row.value(QStringLiteral("changeText")).toString().toDouble(&changeOk);
        if ((side != QStringLiteral("Buy") && side != QStringLiteral("Sell")) || !priceOk || !changeOk
            || tradePrice <= 0) {
            problem = QStringLiteral("в истории есть сделка без цены или количества");
            continue;
        }
        const qint64 occurredAt = row.value(QStringLiteral("occurredAtMs")).toLongLong();
        netQuantity += change;
        if (side == QStringLiteral("Buy")) {
            boughtQuantity += change;
            costUsd += change * tradePrice;
            dayMsTimesQuantity += change * static_cast<double>(occurredAt);
        }
    }
    if (!problem.isEmpty()) {
        result.annual = AnnualReturn{std::nullopt, problem, 0};
        return result;
    }

    // Coins without a trade behind them (deposit, bot, transfer): the purchase given by the user stands in for them.
    // Without it they are not measured, see the checks below.
    const double tolerance = std::max(1e-7, 1e-6 * std::abs(quantity));
    const double untrackedQuantity = quantity - netQuantity;
    if (std::abs(untrackedQuantity) > tolerance) {
        result.untracked = true;
        const double basisPriceUsd = costBasis.value(QStringLiteral("priceUsd")).toDouble();
        const QDate basisDay = QDate::fromString(
            costBasis.value(QStringLiteral("date")).toString(), Qt::ISODate);
        if (untrackedQuantity > 0 && basisPriceUsd > 0 && basisDay.isValid()) {
            const double basisMs = static_cast<double>(QDateTime(basisDay, QTime(12, 0)).toMSecsSinceEpoch());
            boughtQuantity += untrackedQuantity;
            costUsd += untrackedQuantity * basisPriceUsd;
            dayMsTimesQuantity += untrackedQuantity * basisMs;
            netQuantity += untrackedQuantity;
        }
    }
    if (boughtQuantity <= 0 || costUsd <= 0) {
        result.annual = AnnualReturn{std::nullopt, QStringLiteral("нет сделок на бирже"), 0};
        return result;
    }
    // Every coin on the exchange must come from trades or from a given purchase
    if (std::abs(quantity - netQuantity) > tolerance) {
        result.annual = AnnualReturn{std::nullopt, QStringLiteral("часть монет пришла не сделками: ввод, вывод или покупка вне биржи"), 0};
        return result;
    }

    const double averagePriceUsd = costUsd / boughtQuantity;
    const double averageDayMs = dayMsTimesQuantity / boughtQuantity;
    const double days = (static_cast<double>(nowMillis) - averageDayMs) / 86400000.0;
    if (days < 30.0) {
        result.annual = AnnualReturn{std::nullopt, QStringLiteral("мало времени (меньше 30 дней)"), days};
        return result;
    }
    // The price gain in percent, scaled to a year: simple, without compounding
    const double gainPercent = (priceUsd / averagePriceUsd - 1.0) * 100.0;
    result.annual = AnnualReturn{gainPercent * 365.0 / days, QString(), days};
    return result;
}
