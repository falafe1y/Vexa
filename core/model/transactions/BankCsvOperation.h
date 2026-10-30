#pragma once

#include <QDateTime>
#include <QString>

// One row of a bank statement, read from the file and ready to become an operation
struct BankCsvOperation
{
    QDateTime occurredAt;
    qint64 signedMinor = 0;
    QString description;
    QString rawRecipient;
    QString recipientId;
    QString externalId;
    QString categoryName;
    QString currencyCode;
    QString fingerprint;
    QString legacyFingerprint;
    QString reviewFingerprint;
    int sourceRow = 0;
};
