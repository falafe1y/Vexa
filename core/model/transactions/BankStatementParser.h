#pragma once
#include "BankCsvProfile.h"

#include <QDateTime>
#include <QString>
#include <QStringList>
#include <QVector>

// Understands the rows of a statement table by the profile of the bank: dates, amounts, their sign,
// currency, description and recipient, and the fingerprints that recognize the same row again.
class BankStatementParser final
{
public:
    static BankCsvParseResult parse(
        const QVector<QStringList>& rows,
        const BankCsvProfile& profile
        );
    static bool parseAmountMinor(const QString& text, qint64& minorUnits);
    static QDateTime parseDateTime(
        const QString& text,
        const QString& format
        );
};
