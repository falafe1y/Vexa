#pragma once

#include <QDateTime>
#include <QSqlDatabase>
#include <QString>

// Adds one price to crypto_price_history or investment_price_history (kind "crypto" or "investment").
// On failure the reason is written to error.
bool savePriceHistory(QSqlDatabase& database, QString& error, const QString& kind, const QString& id, qint64 price,
    const QDateTime& at, const QString& currency, const QString& source, const QString& terms = QStringLiteral("{}"));
