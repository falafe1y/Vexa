#pragma once
#include "Database.h"
#include "../model/planning/Budget.h"
#include "../model/planning/FinancialGoal.h"
#include <QDate>
#include <QString>
#include <QVector>

// What the user plans: budgets with their monthly limits, and financial goals.
class PlanningRepository
{
public:
    explicit PlanningRepository(Database& database);

    QVector<Budget> loadBudgets();
    qint64 loadBudgetLimit(
        const QString& budgetId,
        const QDate& month,
        qint64 fallback
        );
    bool insertBudget(const Budget& budget, const QDate& month);
    bool updateBudget(const Budget& budget, const QDate& month);
    bool archiveBudget(const QString& id);
    bool ensureBudgetMonth(
        const QString& budgetId,
        const QDate& month,
        qint64 limitMinor
        );
    QVector<FinancialGoal> loadFinancialGoals();
    bool saveFinancialGoal(const FinancialGoal& goal, bool editing);
    bool deleteFinancialGoal(const QString& id);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
