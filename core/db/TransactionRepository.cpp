#include "TransactionRepository.h"

#include "InvestmentRepository.h"
#include "OperationRows.h"
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSqlError>
#include <QSqlQuery>
#include <QTimeZone>
#include <QVariant>

TransactionRepository::TransactionRepository(Database& database)
    : db_(database)
    , database_(database.connection())
{
}

QString TransactionRepository::lastError() const { return lastError_; }
void TransactionRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<Transaction> TransactionRepository::loadTransactions()
{
    QVector<Transaction> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT t.id, t.account_id, t.category_id, t.amount_minor, "
            "t.type, t.occurred_at, t.description, a.currency, t.project_id, t.recipient_json "
            "FROM transactions t JOIN accounts a ON a.id = t.account_id "
            "WHERE t.kind IN ('income','expense','transfer') "
            "ORDER BY t.occurred_at DESC, t.created_at DESC"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(Transaction(
            query.value(0).toString(), query.value(1).toString(),
            query.value(2).toString(),
            Money(query.value(3).toLongLong(),
                  currencyFromCode(query.value(7).toString())),
            query.value(4).toInt() == 0
                ? TransactionType::Income : TransactionType::Expense,
            QDateTime::fromMSecsSinceEpoch(
                query.value(5).toLongLong(), QTimeZone::UTC),
            query.value(6).toString(),
            query.value(8).toString(), TransactionRecipient::deserialize(query.value(9).toString())));
    }
    return result;
}

TransactionRepository::Summary TransactionRepository::loadSummary()
{
    Summary summary;

    QSqlQuery accounts(database_);
    if (!accounts.exec(QStringLiteral(
            "SELECT a.currency, "
            "       SUM(a.initial_balance_minor + COALESCE(t.net_amount, 0)) "
            "FROM accounts a "
            "LEFT JOIN ("
            "    SELECT account_id, "
            "           SUM(CASE "
            "                   WHEN type = 0 THEN amount_minor "
            "                   WHEN type = 1 THEN -amount_minor "
            "               END) AS net_amount "
            "    FROM transactions "
            "    GROUP BY account_id"
            ") t ON t.account_id = a.id "
            "WHERE a.is_archived = 0 "
            "GROUP BY a.currency"))) {
        setLastError(accounts.lastError().text());
        return summary;
    }

    while (accounts.next()) {
        const Currency currency = currencyFromCode(accounts.value(0).toString());
        summary.balance[currencyIndex(currency)] = accounts.value(1).toLongLong();
    }

    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT t.type, a.currency, SUM(t.amount_minor), t.category_id "
            "FROM transactions t JOIN accounts a ON a.id = t.account_id "
            "WHERE a.is_archived = 0 AND t.kind IN ('income','expense','coupon','dividend','fee','tax') "
            "GROUP BY t.type, a.currency, t.category_id"))) {
        setLastError(query.lastError().text());
        return summary;
    }

    while (query.next()) {
        const QString categoryId = query.value(3).toString();
        if (categoryId == QStringLiteral("transfer-in") ||
            categoryId == QStringLiteral("transfer-out")) {
            continue;
        }
        const int type = query.value(0).toInt();
        const Currency currency = currencyFromCode(query.value(1).toString());
        auto& values = type == 0 ? summary.income : summary.expense;
        const qint64 amount = query.value(2).toLongLong();
        values[currencyIndex(currency)] += amount;
    }
    return summary;
}

bool TransactionRepository::insertTransaction(const Transaction& transaction)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (isTransferCategory(transaction.categoryId()) &&
        !ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }

    QSqlQuery query(database_);
    prepareTransactionInsert(query);

    if (!insertTransactionRow(
            query,
            transaction,
            QDateTime::currentDateTimeUtc().toMSecsSinceEpoch()) ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool TransactionRepository::insertTransfer(
    const Transaction& outgoing,
    const Transaction& incoming
    )
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (!ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }

    QSqlQuery query(database_);
    prepareTransactionInsert(query);
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();

    if (!insertTransactionRow(query, outgoing, createdAt) ||
        !insertTransactionRow(query, incoming, createdAt) ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool TransactionRepository::insertTransactions(
    const QVector<Transaction>& transactions,
    const QVector<BankCategoryRule>& rules,
    const QVector<BankRecipientRule>& recipientRules,
    const QMap<QString, QString>& bankLinks,
    const QSet<QString>& replacedBankTransactions
    )
{
    if (transactions.isEmpty() && rules.isEmpty() && recipientRules.isEmpty() && bankLinks.isEmpty()
        && replacedBankTransactions.isEmpty()) {
        return true;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    bool containsTransfer = false;
    for (const Transaction& transaction : transactions) {
        if (isTransferCategory(transaction.categoryId())) {
            containsTransfer = true;
            break;
        }
    }
    QString error;
    if (containsTransfer && !ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }

    QSqlQuery remove(database_);
    remove.prepare(QStringLiteral("DELETE FROM transactions WHERE id=? AND id LIKE 'bankcsv-%' "
        "AND category_id NOT IN ('transfer-in','transfer-out') AND COALESCE(project_id,'')=''"));
    for (const auto& id : replacedBankTransactions) {
        if (!bankLinks.contains(id)) {
            setLastError(QStringLiteral("Не сохранена связь заменяемой банковской операции"));
            database_.rollback(); return false;
        }
        remove.bindValue(0, id);
        if (!remove.exec() || remove.numRowsAffected() != 1) {
            setLastError(QStringLiteral("Банковская операция для объединения изменилась"));
            database_.rollback(); return false;
        }
    }
    QSqlQuery query(database_);
    prepareTransactionInsert(query);
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    for (const Transaction& transaction : transactions) {
        if (!insertTransactionRow(query, transaction, createdAt)) {
            setLastError(query.lastError().text());
            database_.rollback();
            return false;
        }
    }
    // Transactions and remembered choices are committed together.
    QSqlQuery ruleQuery(database_);
    ruleQuery.prepare(QStringLiteral(
        "INSERT INTO bank_category_rules(pattern,match_mode,type,category_id,match_field) "
        "SELECT ?,?,?,id,? FROM categories WHERE id=? AND type=? AND is_archived=0 "
        "AND id NOT IN ('transfer-in','transfer-out') "
        "ON CONFLICT(pattern,match_mode,type) DO UPDATE SET category_id=excluded.category_id,match_field=excluded.match_field"));
    for (const auto& rule : rules) {
        const QString pattern = rule.pattern.trimmed();
        if (pattern.isEmpty() || (rule.matchMode != QStringLiteral("exact") &&
            rule.matchMode != QStringLiteral("contains"))) {
            setLastError(QStringLiteral("Некорректное правило категорий"));
            database_.rollback(); return false;
        }
        const int type = rule.type == CategoryType::Income ? 0 : 1;
        ruleQuery.bindValue(0, pattern); ruleQuery.bindValue(1, rule.matchMode);
        ruleQuery.bindValue(2, type); ruleQuery.bindValue(3, rule.field);
        ruleQuery.bindValue(4, rule.categoryId); ruleQuery.bindValue(5, type);
        if (!ruleQuery.exec() || ruleQuery.numRowsAffected() != 1) {
            setLastError(ruleQuery.lastError().isValid() ? ruleQuery.lastError().text()
                         : QStringLiteral("Категория правила недоступна"));
            database_.rollback(); return false;
        }
    }
    QSqlQuery recipientQuery(database_);
    recipientQuery.prepare(QStringLiteral(
        "INSERT INTO bank_recipient_rules(pattern,match_field,match_mode,type,recipient_name) VALUES(?,?,?,?,?) "
        "ON CONFLICT(pattern,match_field,match_mode,type) DO UPDATE SET recipient_name=excluded.recipient_name"));
    for (const auto& rule : recipientRules) {
        const auto pattern = rule.pattern.trimmed();
        const auto name = rule.name.trimmed();
        if (pattern.isEmpty() || pattern.size() > 240 || name.isEmpty() || name.size() > 160 ||
            (rule.field == "recipient_id" && rule.matchMode != "exact")) {
            setLastError(QStringLiteral("Некорректное правило получателя"));
            database_.rollback();
            return false;
        }
        recipientQuery.bindValue(0, pattern);
        recipientQuery.bindValue(1, rule.field);
        recipientQuery.bindValue(2, rule.matchMode);
        recipientQuery.bindValue(3, rule.type == CategoryType::Income ? 0 : 1);
        recipientQuery.bindValue(4, name);
        if (!recipientQuery.exec()) {
            setLastError(recipientQuery.lastError().text());
            database_.rollback();
            return false;
        }
        recipientQuery.finish();
    }

    QSqlQuery link(database_);
    link.prepare(QStringLiteral("INSERT INTO bank_import_links(row_key,transaction_id) "
        "SELECT ?,id FROM transactions WHERE id=? AND category_id IN ('transfer-in','transfer-out')"));
    for (auto it = bankLinks.cbegin(); it != bankLinks.cend(); ++it) {
        link.bindValue(0, it.key()); link.bindValue(1, it.value());
        if (!link.exec() || link.numRowsAffected() != 1) {
            setLastError(link.lastError().isValid() ? link.lastError().text()
                : QStringLiteral("Не найдена сторона перевода для банковской операции"));
            database_.rollback(); return false;
        }
    }
    if (!database_.commit()) {
        setLastError(database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool TransactionRepository::updateTransaction(const Transaction& transaction)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE transactions "
        "SET account_id = ?, category_id = ?, type = ?, amount_minor = ?, "
        "    occurred_at = ?, description = ?, project_id = ?, recipient_json = ?, kind = ? "
        "WHERE id = ? AND kind IN ('income','expense','transfer')"));
    query.addBindValue(transaction.accountId());
    query.addBindValue(transaction.categoryId());
    query.addBindValue(transaction.type() == TransactionType::Income ? 0 : 1);
    query.addBindValue(transaction.money().minorUnits());
    query.addBindValue(transaction.date().toMSecsSinceEpoch());
    query.addBindValue(transaction.description().isNull() ? QStringLiteral("") : transaction.description());
    if (transaction.projectId().isEmpty()) {
        query.addBindValue(QVariant());
    } else {
        query.addBindValue(transaction.projectId());
    }
    query.addBindValue(transaction.recipient().serialize());
    query.addBindValue(fiatKindFor(transaction.categoryId(), transaction.type() == TransactionType::Income ? 0 : 1));
    query.addBindValue(transaction.id());

    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Transaction was not found"));
        return false;
    }
    return true;
}

bool TransactionRepository::replaceTransaction(
    const QString& currentId,
    const Transaction& replacement
    )
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (isTransferCategory(replacement.categoryId()) &&
        !ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }
    const auto bankLinks = bankLinksForOperation(database_, currentId, error);
    if (!error.isEmpty()) { setLastError(error); database_.rollback(); return false; }
    QSqlQuery insertion(database_);
    prepareTransactionInsert(insertion);
    const bool succeeded =
        deleteOperationRows(database_, currentId, error) &&
        insertTransactionRow(
            insertion,
            replacement,
            QDateTime::currentDateTimeUtc().toMSecsSinceEpoch()) &&
        restoreBankLinks(database_, bankLinks, replacement.id(), replacement.id(), error);

    if (!succeeded || !database_.commit()) {
        if (error.isEmpty()) {
            error = insertion.lastError().isValid()
                ? insertion.lastError().text()
                : database_.lastError().text();
        }
        setLastError(error);
        database_.rollback();
        return false;
    }
    return true;
}

bool TransactionRepository::replaceTransactionWithTransfer(
    const QString& currentId,
    const Transaction& outgoing,
    const Transaction& incoming
    )
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (!ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }
    const auto bankLinks = bankLinksForOperation(database_, currentId, error);
    if (!error.isEmpty()) { setLastError(error); database_.rollback(); return false; }
    QSqlQuery insertion(database_);
    prepareTransactionInsert(insertion);
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    const bool succeeded =
        deleteOperationRows(database_, currentId, error) &&
        insertTransactionRow(insertion, outgoing, createdAt) &&
        insertTransactionRow(insertion, incoming, createdAt) &&
        restoreBankLinks(database_, bankLinks, outgoing.id(), incoming.id(), error);

    if (!succeeded || !database_.commit()) {
        if (error.isEmpty()) {
            error = insertion.lastError().isValid()
                ? insertion.lastError().text()
                : database_.lastError().text();
        }
        setLastError(error);
        database_.rollback();
        return false;
    }
    return true;
}

bool TransactionRepository::deleteTransaction(const QString& id)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (!deleteOperationRows(database_, id, error) || !database_.commit()) {
        setLastError(error.isEmpty() ? database_.lastError().text() : error);
        database_.rollback();
        return false;
    }
    return true;
}

bool TransactionRepository::deleteHistoryRows(const QVariantList& rows)
{
    if (rows.isEmpty() || !database_.transaction()) {
        setLastError(QStringLiteral("No selection or database transaction unavailable"));
        return false;
    }
    QSet<QString> removedTransactions;
    QSet<QString> processed;
    QString error;
    const auto fail = [&](const QString& message) {
        setLastError(message);
        database_.rollback();
        return false;
    };
    for (const QVariant& value : rows) {
        const QVariantMap row = value.toMap();
        if (row.value(QStringLiteral("investmentTransfer")).toBool())
            return fail(QStringLiteral("Инвестиционная операция связана с количеством позиции; удаление отдельно от позиции не поддерживается"));
        const QString id = row.value(QStringLiteral("id")).toString();
        const QString type = row.value(QStringLiteral("type")).toString();
        const QString cryptoId = row.value(QStringLiteral("transactionId")).toString();
        const QString walletId = row.value(QStringLiteral("walletId")).toString();
        if (row.value("isExchange").toBool()) {
            const QString accountId = row.value("walletId").toString();
            const QString transactionId = row.value("transactionId").toString();
            QSqlQuery lookup(database_);
            lookup.prepare(QStringLiteral("SELECT history_json FROM crypto_exchanges WHERE id = ? AND is_archived = 0"));
            lookup.addBindValue(accountId);
            if (!lookup.exec() || !lookup.next()) return fail(QStringLiteral("Exchange account not found"));
            QVariantList history;
            for (const auto& value : QJsonDocument::fromJson(lookup.value(0).toByteArray()).array().toVariantList())
                if (value.toMap().value("transactionId").toString() != transactionId) history.append(value);
            lookup.finish();
            QSqlQuery update(database_);
            update.prepare(QStringLiteral("UPDATE crypto_exchanges SET history_json = ? WHERE id = ?"));
            update.addBindValue(QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(history)).toJson(QJsonDocument::Compact)));
            update.addBindValue(accountId);
            if (!update.exec()) return fail(update.lastError().text());
        } else if (!cryptoId.isEmpty()) {
            if (walletId.isEmpty()) return fail(QStringLiteral("Missing crypto wallet"));
            const QString key = QStringLiteral("crypto:") + walletId + ':' + cryptoId;
            if (processed.contains(key)) continue;
            processed.insert(key);
            QSqlQuery query(database_);
            query.prepare(QStringLiteral("DELETE FROM crypto_transactions WHERE wallet_id = ? AND transaction_id = ?"));
            query.addBindValue(walletId);
            query.addBindValue(cryptoId);
            if (!query.exec() || query.numRowsAffected() != 1)
                return fail(query.lastError().isValid() ? query.lastError().text() : QStringLiteral("Crypto operation not found"));
        } else if (type == QStringLiteral("investment_position")) {
            if (id.isEmpty()) return fail(QStringLiteral("Missing investment position"));
            const QString key = QStringLiteral("investment:") + id;
            if (processed.contains(key)) continue;
            processed.insert(key);
            InvestmentRepository investments(db_);
            if (!investments.deleteInvestmentPosition(id)) return fail(investments.lastError());
        } else if (type == QStringLiteral("investment_cash")) {
            return fail(QStringLiteral("Инвестиционная операция связана с количеством позиции; удаление отдельно от позиции не поддерживается"));
        } else {
            if (id.isEmpty()) return fail(QStringLiteral("Missing operation"));
            if (removedTransactions.contains(id)) continue;
            QSqlQuery lookup(database_);
            lookup.prepare(QStringLiteral("SELECT category_id FROM transactions WHERE id = ?"));
            lookup.addBindValue(id);
            if (!lookup.exec() || !lookup.next()) return fail(QStringLiteral("Operation not found"));
            const auto pair = transferComponentIds(id, lookup.value(0).toString());
            lookup.finish();
            if (!deleteOperationRows(database_, id, error)) return fail(error);
            removedTransactions.insert(id);
            if (pair.valid) {
                removedTransactions.insert(pair.outgoing);
                removedTransactions.insert(pair.incoming);
            }
        }
    }
    if (!database_.commit()) return fail(database_.lastError().text());
    return true;
}

bool TransactionRepository::materializeRecurringOccurrences(
    const QString& recurringId,
    const QVector<RecurringOccurrence>& occurrences,
    const QDate& generatedThrough,
    int* insertedCount
    )
{
    if (recurringId.isEmpty() || !generatedThrough.isValid()) {
        setLastError(QStringLiteral("Invalid recurring materialization range"));
        return false;
    }
    if (insertedCount) {
        *insertedCount = 0;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery occurrenceLookup(database_);
    occurrenceLookup.prepare(QStringLiteral(
        "SELECT 1 FROM recurring_transaction_occurrences "
        "WHERE recurring_id = ? AND occurrence_date = ?"));
    QSqlQuery transactionInsert(database_);
    prepareTransactionInsert(transactionInsert);
    QSqlQuery occurrenceInsert(database_);
    occurrenceInsert.prepare(QStringLiteral(
        "INSERT INTO recurring_transaction_occurrences("
        "recurring_id, occurrence_date, transaction_id) "
        "VALUES (?, ?, ?)"));
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    int inserted = 0;

    for (const RecurringOccurrence& occurrence : occurrences) {
        const QString date = occurrence.date.toString(Qt::ISODate);
        occurrenceLookup.bindValue(0, recurringId);
        occurrenceLookup.bindValue(1, date);
        if (!occurrenceLookup.exec()) {
            setLastError(occurrenceLookup.lastError().text());
            database_.rollback();
            return false;
        }
        const bool alreadyCreated = occurrenceLookup.next();
        occurrenceLookup.finish();
        if (alreadyCreated) {
            continue;
        }

        if (!insertTransactionRow(
                transactionInsert, occurrence.transaction, createdAt)) {
            setLastError(transactionInsert.lastError().text());
            database_.rollback();
            return false;
        }
        occurrenceInsert.bindValue(0, recurringId);
        occurrenceInsert.bindValue(1, date);
        occurrenceInsert.bindValue(2, occurrence.transaction.id());
        if (!occurrenceInsert.exec()) {
            setLastError(occurrenceInsert.lastError().text());
            database_.rollback();
            return false;
        }
        ++inserted;
    }

    QSqlQuery progress(database_);
    progress.prepare(QStringLiteral(
        "UPDATE recurring_transactions SET generated_through = CASE "
        "WHEN generated_through < ? THEN ? ELSE generated_through END, "
        "updated_at = ? WHERE id = ?"));
    const QString through = generatedThrough.toString(Qt::ISODate);
    progress.addBindValue(through);
    progress.addBindValue(through);
    progress.addBindValue(createdAt);
    progress.addBindValue(recurringId);
    if (!progress.exec() || progress.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(progress.lastError().isValid()
                         ? progress.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    if (insertedCount) {
        *insertedCount = inserted;
    }
    return true;
}

bool TransactionRepository::materializeDepositInterest(
    const DepositSettings& settings,
    const QVector<DepositInterestOccurrence>& occurrences,
    const QDate& generatedThrough,
    int* insertedCount
    )
{
    if (settings.accountId().isEmpty() || !generatedThrough.isValid()) {
        setLastError(QStringLiteral("Invalid deposit materialization range"));
        return false;
    }
    if (insertedCount) {
        *insertedCount = 0;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    // Older or cleared databases may not contain this built-in category.
    // Create it atomically with the interest; preserve an existing user's category.
    if (!occurrences.isEmpty()) {
        QSqlQuery category(database_);
        category.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO categories(id,name,type,is_system,created_at) "
            "VALUES ('deposit_interest', 'Проценты по вкладу', 0, 1, ?)"));
        category.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
        if (!category.exec()) {
            setLastError(category.lastError().text());
            database_.rollback();
            return false;
        }
    }

    QSqlQuery occurrenceLookup(database_);
    occurrenceLookup.prepare(QStringLiteral(
        "SELECT 1 FROM deposit_interest_occurrences "
        "WHERE account_id = ? AND occurrence_date = ?"));
    QSqlQuery transactionInsert(database_);
    prepareTransactionInsert(transactionInsert);
    QSqlQuery occurrenceInsert(database_);
    occurrenceInsert.prepare(QStringLiteral(
        "INSERT INTO deposit_interest_occurrences("
        "account_id, occurrence_date, transaction_id) VALUES (?, ?, ?)"));
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    int inserted = 0;

    for (const DepositInterestOccurrence& occurrence : occurrences) {
        const QString date = occurrence.date.toString(Qt::ISODate);
        occurrenceLookup.bindValue(0, settings.accountId());
        occurrenceLookup.bindValue(1, date);
        if (!occurrenceLookup.exec()) {
            setLastError(occurrenceLookup.lastError().text());
            database_.rollback();
            return false;
        }
        const bool alreadyCreated = occurrenceLookup.next();
        occurrenceLookup.finish();
        if (alreadyCreated) {
            continue;
        }

        if (!insertTransactionRow(
                transactionInsert, occurrence.transaction, createdAt)) {
            setLastError(transactionInsert.lastError().text());
            database_.rollback();
            return false;
        }
        occurrenceInsert.bindValue(0, settings.accountId());
        occurrenceInsert.bindValue(1, date);
        occurrenceInsert.bindValue(2, occurrence.transaction.id());
        if (!occurrenceInsert.exec()) {
            setLastError(occurrenceInsert.lastError().text());
            database_.rollback();
            return false;
        }
        ++inserted;
    }

    QSqlQuery progress(database_);
    progress.prepare(QStringLiteral(
        "UPDATE deposit_settings SET generated_through = CASE "
        "WHEN generated_through < ? THEN ? ELSE generated_through END, "
        "updated_at = ? WHERE account_id = ?"));
    const QString through = generatedThrough.toString(Qt::ISODate);
    progress.addBindValue(through);
    progress.addBindValue(through);
    progress.addBindValue(createdAt);
    progress.addBindValue(settings.accountId());
    if (!progress.exec() || progress.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(progress.lastError().isValid()
            ? progress.lastError().text()
            : database_.lastError().text());
        database_.rollback();
        return false;
    }
    if (insertedCount) {
        *insertedCount = inserted;
    }
    return true;
}
