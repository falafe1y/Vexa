#pragma once
#include "../model/money/Currency.h"
#include "../model/transactions/Transaction.h"

#include <QMap>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>

// Writing rows of the operations journal (transactions table): shared by the repositories
// that add or remove operations together with other data in one database transaction.

inline constexpr int currencyIndex(const Currency currency)
{
    return static_cast<int>(currency);
}

bool isTransferCategory(const QString& categoryId);
// Adds the built-in transfer categories when they are missing
bool ensureTransferCategories(QSqlDatabase& database, QString& error);

// The ids of the two rows of a transfer
struct TransferComponentIds
{
    QString outgoing;
    QString incoming;
    bool valid = false;
};
TransferComponentIds transferComponentIds(const QString& id, const QString& categoryId);

QString fiatKindFor(const QString& categoryId, int type);
void prepareTransactionInsert(QSqlQuery& query);
bool insertTransactionRow(QSqlQuery& query, const Transaction& transaction, qint64 createdAt);

QMap<QString, bool> bankLinksForOperation(QSqlDatabase& database, const QString& id, QString& error);
bool restoreBankLinks(QSqlDatabase& database, const QMap<QString, bool>& links,
    const QString& outgoingId, const QString& incomingId, QString& error);
// Removes an operation; a transfer is removed with both of its rows
bool deleteOperationRows(QSqlDatabase& database, const QString& id, QString& error);
