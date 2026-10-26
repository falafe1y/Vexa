#pragma once

#include "../analytics/InvestmentReturn.h"

#include <QDate>
#include <QMap>
#include <QString>
#include <QVariantList>

// Stablecoins are money pegged to the dollar: their yield would only show the rouble moving, so they are not measured.
bool isStableCoin(const QString& coin);

// CBR dollar rates by day (roubles per dollar, in micros) from the stored history rows of the USD currency.
// An official CBR rate of a day wins over estimated or manual values for the same day.
QMap<QDate, qint64> rubPerUsdByDate(const QVariantList& rows);

struct CoinReturn {
    qint64 valueMinor = 0;        // what the coin is worth now, in kopecks
    AnnualReturn annual;          // annual rate in percent, or the reason it cannot be computed
    QDate firstMissingRateDate;   // earliest trade day without a CBR rate; invalid when every day has one
    bool untracked = false;       // part of the coin has no trade behind it (deposit, bot, transfer)
};

// The simple annual return of one coin held on an exchange: its price now against the average purchase price
// (weighted by the quantity bought), scaled to a year. The return is in dollars; no compounding.
// quantity: the coin in all sections of the exchange; priceUsd: its current price in dollars, 0 when unknown.
// history: the exchange's history rows (see BybitProvider::parseOperation).
// costBasis: the purchase of the coins that have no trade behind them: {"priceUsd", "date" as ISO day}; empty when unknown.
CoinReturn coinReturnOf(const QString& coin, double quantity, double priceUsd, qint64 usdRubNowMicros,
                        const QVariantList& history, qint64 nowMillis,
                        const QVariantMap& costBasis = {});
