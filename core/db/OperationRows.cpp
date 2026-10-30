#include "OperationRows.h"

#include <QDateTime>
#include <QSqlError>
#include <QVariant>
#include <QStringList>

bool isTransferCategory(const QString& categoryId)
{
    return categoryId == QStringLiteral("transfer-in") ||
           categoryId == QStringLiteral("transfer-out");
}

bool ensureTransferCategories(QSqlDatabase& database, QString& error)
{
    struct TransferCategory
    {
        const char* id;
        int type;
    };
    const TransferCategory categories[] = {
        {"transfer-in", 0},
        {"transfer-out", 1}};

    QSqlQuery query(database);
    query.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO categories(id,name,type,is_system,created_at) "
        "VALUES (?, 'Перевод', ?, 1, ?)"));
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    for (const TransferCategory& category : categories) {
        query.bindValue(0, QString::fromLatin1(category.id));
        query.bindValue(1, category.type);
        query.bindValue(2, now);
        if (!query.exec()) {
            error = query.lastError().text();
            return false;
        }
    }
    return true;
}


TransferComponentIds transferComponentIds(
    const QString& id,
    const QString& categoryId
    )
{
    QString transferId;
    if (categoryId == QStringLiteral("transfer-out") &&
        id.endsWith(QStringLiteral("-out"))) {
        transferId = id.left(id.size() - 4);
    } else if (categoryId == QStringLiteral("transfer-in") &&
               id.endsWith(QStringLiteral("-in"))) {
        transferId = id.left(id.size() - 3);
    }

    if (transferId.isEmpty()) {
        return {};
    }

    return {
        transferId + QStringLiteral("-out"),
        transferId + QStringLiteral("-in"),
        true
    };
}

// Kind of a money row: a transfer leg, or plain income or expense. Investment kinds never come through here.
QString fiatKindFor(const QString& categoryId, const int type)
{
    if (categoryId == QStringLiteral("transfer-in") || categoryId == QStringLiteral("transfer-out")) {
        return QStringLiteral("transfer");
    }
    return type == 0 ? QStringLiteral("income") : QStringLiteral("expense");
}

void prepareTransactionInsert(QSqlQuery& query)
{
    query.prepare(QStringLiteral(
        "INSERT INTO transactions(id, account_id, category_id, type, "
        "amount_minor, occurred_at, description, project_id, created_at, recipient_json, "
        "kind, operation_id, quantity_micros) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"));
}

bool insertTransactionRow(
    QSqlQuery& query,
    const Transaction& transaction,
    const qint64 createdAt
    )
{
    query.bindValue(0, transaction.id());
    query.bindValue(1, transaction.accountId());
    query.bindValue(2, transaction.categoryId());
    query.bindValue(3, transaction.type() == TransactionType::Income ? 0 : 1);
    query.bindValue(4, transaction.money().minorUnits());
    query.bindValue(5, transaction.date().toMSecsSinceEpoch());
    query.bindValue(6, transaction.description().isNull() ? QStringLiteral("") : transaction.description());
    if (transaction.projectId().isEmpty()) {
        query.bindValue(7, QVariant());
    } else {
        query.bindValue(7, transaction.projectId());
    }
    query.bindValue(8, createdAt);
    query.bindValue(9, transaction.recipient().serialize());
    query.bindValue(10, fiatKindFor(transaction.categoryId(), transaction.type() == TransactionType::Income ? 0 : 1));
    // Both legs of a transfer share the identifier without the "-out" / "-in" suffix.
    const auto components = transferComponentIds(transaction.id(), transaction.categoryId());
    query.bindValue(11, components.valid ? QVariant(components.outgoing.left(components.outgoing.size() - 4)) : QVariant());
    return query.exec();
}

// Replacement deletes/reinserts rows; retain bank statement identities across edits.
QMap<QString, bool> bankLinksForOperation(QSqlDatabase& database, const QString& id, QString& error)
{
    QMap<QString, bool> links;
    QSqlQuery lookup(database);
    lookup.prepare(QStringLiteral("SELECT category_id,type FROM transactions WHERE id=?"));
    lookup.addBindValue(id);
    if (!lookup.exec() || !lookup.next()) {
        error = QStringLiteral("Transaction was not found"); return links;
    }
    const auto category = lookup.value(0).toString();
    const bool income = lookup.value(1).toInt() == 0;
    const auto components = transferComponentIds(id, category);
    lookup.finish();
    lookup.prepare(QStringLiteral("SELECT l.row_key,t.type FROM bank_import_links l "
        "JOIN transactions t ON t.id=l.transaction_id WHERE t.id=? OR t.id=? OR t.id=?"));
    lookup.addBindValue(id);
    lookup.addBindValue(components.valid ? components.outgoing : id);
    lookup.addBindValue(components.valid ? components.incoming : id);
    if (!lookup.exec()) { error = lookup.lastError().text(); return links; }
    while (lookup.next()) links.insert(lookup.value(0).toString(), lookup.value(1).toInt() == 0);
    if (lookup.lastError().isValid()) error = lookup.lastError().text();
    if (id.startsWith("bankcsv-") && !isTransferCategory(category)) links.insert(id, income);
    return links;
}

bool restoreBankLinks(QSqlDatabase& database, const QMap<QString, bool>& links,
    const QString& outgoingId, const QString& incomingId, QString& error)
{
    QSqlQuery query(database);
    query.prepare(QStringLiteral("INSERT INTO bank_import_links(row_key,transaction_id) VALUES(?,?)"));
    for (auto it = links.cbegin(); it != links.cend(); ++it) {
        query.bindValue(0, it.key()); query.bindValue(1, it.value() ? incomingId : outgoingId);
        if (!query.exec()) { error = query.lastError().text(); return false; }
    }
    return true;
}

bool deleteOperationRows(
    QSqlDatabase& database,
    const QString& id,
    QString& error
    )
{
    QSqlQuery lookup(database);
    lookup.prepare(QStringLiteral(
        "SELECT category_id FROM transactions WHERE id = ?"));
    lookup.addBindValue(id);
    if (!lookup.exec()) {
        error = lookup.lastError().text();
        return false;
    }
    if (!lookup.next()) {
        error = QStringLiteral("Transaction was not found");
        return false;
    }

    const QString categoryId = lookup.value(0).toString();
    lookup.finish();
    const TransferComponentIds componentIds = transferComponentIds(id, categoryId);

    QSqlQuery deletion(database);
    if (isTransferCategory(categoryId) && componentIds.valid) {
        deletion.prepare(QStringLiteral(
            "DELETE FROM transactions "
            "WHERE (id = ? AND category_id = 'transfer-out') "
            "   OR (id = ? AND category_id = 'transfer-in')"));
        deletion.addBindValue(componentIds.outgoing);
        deletion.addBindValue(componentIds.incoming);
    } else {
        deletion.prepare(QStringLiteral(
            "DELETE FROM transactions WHERE id = ? AND kind IN ('income','expense','transfer')"));
        deletion.addBindValue(id);
    }

    if (!deletion.exec() || deletion.numRowsAffected() < 1) {
        error = deletion.lastError().isValid()
            ? deletion.lastError().text()
            : QStringLiteral("Transaction was not found");
        return false;
    }
    return true;
}
