#pragma once
#include "Database.h"
#include "../model/transactions/RecurringTransaction.h"
#include <QString>
#include <QVector>

// Recurring operations: the schedules from which operations are created on their dates.
class RecurringTransactionRepository
{
public:
    explicit RecurringTransactionRepository(Database& database);

    QVector<RecurringTransaction> loadRecurringTransactions();
    bool insertRecurringTransaction(
        const RecurringTransaction& recurring
        );
    bool updateRecurringTransaction(
        const RecurringTransaction& recurring
        );
    bool deleteRecurringTransaction(const QString& id);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
