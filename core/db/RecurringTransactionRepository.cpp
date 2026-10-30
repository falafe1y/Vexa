#include "RecurringTransactionRepository.h"

#include <QDate>
#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

RecurringTransactionRepository::RecurringTransactionRepository(Database& database)
    : database_(database.connection())
{
}

QString RecurringTransactionRepository::lastError() const { return lastError_; }
void RecurringTransactionRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<RecurringTransaction> RecurringTransactionRepository::loadRecurringTransactions()
{
    QVector<RecurringTransaction> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, account_id, category_id, type, amount_minor, "
            "       amount_currency, recurrence_type, weekday, day_of_month, "
            "       week_of_month, starts_on, generated_through "
            "FROM recurring_transactions "
            "ORDER BY created_at, name COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(RecurringTransaction(
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toString(),
            query.value(3).toString(),
            query.value(4).toInt() == 0
                ? TransactionType::Income
                : TransactionType::Expense,
            query.value(5).toLongLong(),
            currencyFromCode(query.value(6).toString()),
            static_cast<RecurrenceType>(query.value(7).toInt()),
            query.value(8).toInt(),
            query.value(9).toInt(),
            query.value(10).toInt(),
            QDate::fromString(query.value(11).toString(), Qt::ISODate),
            QDate::fromString(query.value(12).toString(), Qt::ISODate)));
    }
    return result;
}

bool RecurringTransactionRepository::insertRecurringTransaction(
    const RecurringTransaction& recurring
    )
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO recurring_transactions("
        "id, name, account_id, category_id, type, amount_minor, amount_currency, "
        "recurrence_type, weekday, day_of_month, week_of_month, "
        "starts_on, generated_through, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"));
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    query.addBindValue(recurring.id());
    query.addBindValue(recurring.name().trimmed());
    query.addBindValue(recurring.accountId());
    query.addBindValue(recurring.categoryId());
    query.addBindValue(
        recurring.transactionType() == TransactionType::Income ? 0 : 1);
    query.addBindValue(recurring.amountMinor());
    query.addBindValue(currencyCode(recurring.currency()));
    query.addBindValue(static_cast<int>(recurring.recurrenceType()));
    query.addBindValue(recurring.weekday());
    query.addBindValue(recurring.dayOfMonth());
    query.addBindValue(recurring.weekOfMonth());
    query.addBindValue(recurring.startsOn().toString(Qt::ISODate));
    query.addBindValue(recurring.generatedThrough().toString(Qt::ISODate));
    query.addBindValue(now);
    query.addBindValue(now);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool RecurringTransactionRepository::updateRecurringTransaction(
    const RecurringTransaction& recurring
    )
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE recurring_transactions SET "
        "name = ?, account_id = ?, category_id = ?, type = ?, "
        "amount_minor = ?, amount_currency = ?, recurrence_type = ?, weekday = ?, "
        "day_of_month = ?, week_of_month = ?, starts_on = ?, "
        "updated_at = ? WHERE id = ?"));
    query.addBindValue(recurring.name().trimmed());
    query.addBindValue(recurring.accountId());
    query.addBindValue(recurring.categoryId());
    query.addBindValue(
        recurring.transactionType() == TransactionType::Income ? 0 : 1);
    query.addBindValue(recurring.amountMinor());
    query.addBindValue(currencyCode(recurring.currency()));
    query.addBindValue(static_cast<int>(recurring.recurrenceType()));
    query.addBindValue(recurring.weekday());
    query.addBindValue(recurring.dayOfMonth());
    query.addBindValue(recurring.weekOfMonth());
    query.addBindValue(recurring.startsOn().toString(Qt::ISODate));
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(recurring.id());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Recurring transaction was not found"));
        return false;
    }
    return true;
}

bool RecurringTransactionRepository::deleteRecurringTransaction(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "DELETE FROM recurring_transactions WHERE id = ?"));
    query.addBindValue(id);
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Recurring transaction was not found"));
        return false;
    }
    return true;
}
