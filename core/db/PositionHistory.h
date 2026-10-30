#pragma once

#include <QString>
#include <QVariant>
#include <QVariantMap>

// The current state of a position with its account and instrument, as read for the position history
inline const QString positionStateQuery = QStringLiteral(
    "SELECT p.id,p.account_id,p.instrument_id,p.quantity_micros,p.average_price_micros,p.settings_json,p.is_archived,"
    "a.currency,i.currency AS instrument_currency,i.symbol,i.type,i.terms_json,q.terms_json AS quote_terms "
    "FROM investment_positions p JOIN accounts a ON a.id=p.account_id "
    "JOIN investment_instruments i ON i.id=p.instrument_id LEFT JOIN investment_quotes q ON q.instrument_id=p.instrument_id");

// An average acquisition price is useful only when it is a monetary unit price
// in the account currency. Today's FX, nominal and accrued interest are not
// evidence of the amount originally paid.
QVariant averageAcquisitionCost(const QVariantMap& row);
