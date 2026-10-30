#pragma once
#include "../model/analytics/AnalyticsHistory.h"

#include <QString>

// The table of daily snapshots for one kind of asset
inline QString snapshotTable(AssetDailyValuation::Kind kind) {
    switch(kind) {
    case AssetDailyValuation::Fiat: return QStringLiteral("fiat_daily_snapshots");
    case AssetDailyValuation::Crypto: return QStringLiteral("crypto_daily_snapshots");
    case AssetDailyValuation::Investment: return QStringLiteral("investment_daily_snapshots");
    }
    return {};
}
