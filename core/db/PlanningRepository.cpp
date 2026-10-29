#include "PlanningRepository.h"

#include "../model/money/Currency.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QVariant>

namespace
{
bool replaceBudgetScopes(QSqlDatabase& database, const Budget& budget)
{
    QSqlQuery deleteAccounts(database);
    deleteAccounts.prepare(QStringLiteral(
        "DELETE FROM budget_accounts WHERE budget_id = ?"));
    deleteAccounts.addBindValue(budget.id());
    if (!deleteAccounts.exec()) {
        return false;
    }

    QSqlQuery deleteCategories(database);
    deleteCategories.prepare(QStringLiteral(
        "DELETE FROM budget_category_limits WHERE budget_id = ?"));
    deleteCategories.addBindValue(budget.id());
    if (!deleteCategories.exec()) {
        return false;
    }

    QSqlQuery account(database);
    account.prepare(QStringLiteral(
        "INSERT INTO budget_accounts(budget_id, account_id) VALUES(?, ?)"));
    for (const QString& accountId : budget.accountIds()) {
        account.bindValue(0, budget.id());
        account.bindValue(1, accountId);
        if (!account.exec()) {
            return false;
        }
    }

    QSqlQuery category(database);
    category.prepare(QStringLiteral(
        "INSERT INTO budget_category_limits(budget_id, category_id, limit_minor) "
        "VALUES(?, ?, ?)"));
    for (const BudgetCategoryLimit& limit : budget.categoryLimits()) {
        category.bindValue(0, budget.id());
        category.bindValue(1, limit.categoryId);
        category.bindValue(2, limit.limitMinor);
        if (!category.exec()) {
            return false;
        }
    }
    return true;
}

bool saveBudgetMonth(
    QSqlDatabase& database,
    const QString& budgetId,
    const QDate& month,
    const qint64 limitMinor
    )
{
    QSqlQuery query(database);
    query.prepare(QStringLiteral(
        "INSERT INTO budget_months(budget_id, month, limit_minor) "
        "VALUES(?, ?, ?) ON CONFLICT(budget_id, month) DO UPDATE SET "
        "limit_minor = excluded.limit_minor"));
    query.addBindValue(budgetId);
    query.addBindValue(QDate(month.year(), month.month(), 1).toString(Qt::ISODate));
    query.addBindValue(limitMinor);
    return query.exec();
}
}

PlanningRepository::PlanningRepository(Database& database)
    : database_(database.connection())
{
}

QString PlanningRepository::lastError() const { return lastError_; }
void PlanningRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<Budget> PlanningRepository::loadBudgets()
{
    QVector<Budget> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, currency, default_limit_minor, "
            "all_accounts, all_categories, starts_on "
            "FROM budgets WHERE is_archived = 0 "
            "ORDER BY created_at, name COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        const QString id = query.value(0).toString();
        QStringList accountIds;
        QSqlQuery accounts(database_);
        accounts.prepare(QStringLiteral(
            "SELECT account_id FROM budget_accounts "
            "WHERE budget_id = ? ORDER BY account_id"));
        accounts.addBindValue(id);
        if (!accounts.exec()) {
            setLastError(accounts.lastError().text());
            return {};
        }
        while (accounts.next()) {
            accountIds.append(accounts.value(0).toString());
        }

        QVector<BudgetCategoryLimit> categoryLimits;
        QSqlQuery categories(database_);
        categories.prepare(QStringLiteral(
            "SELECT category_id, limit_minor FROM budget_category_limits "
            "WHERE budget_id = ? ORDER BY category_id"));
        categories.addBindValue(id);
        if (!categories.exec()) {
            setLastError(categories.lastError().text());
            return {};
        }
        while (categories.next()) {
            categoryLimits.append({
                categories.value(0).toString(),
                categories.value(1).toLongLong()});
        }

        result.append(Budget(
            id,
            query.value(1).toString(),
            currencyFromCode(query.value(2).toString()),
            query.value(3).toLongLong(),
            query.value(4).toBool(),
            query.value(5).toBool(),
            accountIds,
            categoryLimits,
            QDate::fromString(query.value(6).toString(), Qt::ISODate)));
    }
    return result;
}

qint64 PlanningRepository::loadBudgetLimit(
    const QString& budgetId,
    const QDate& month,
    const qint64 fallback
    )
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "SELECT limit_minor FROM budget_months "
        "WHERE budget_id = ? AND month = ?"));
    query.addBindValue(budgetId);
    query.addBindValue(QDate(month.year(), month.month(), 1).toString(Qt::ISODate));
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return fallback;
    }
    return query.next() ? query.value(0).toLongLong() : fallback;
}

bool PlanningRepository::insertBudget(const Budget& budget, const QDate& month)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO budgets(id, name, currency, default_limit_minor, "
        "all_accounts, all_categories, starts_on, is_archived, created_at, updated_at) "
        "VALUES(?, ?, ?, ?, ?, ?, ?, 0, ?, ?)"));
    query.addBindValue(budget.id());
    query.addBindValue(budget.name());
    query.addBindValue(currencyCode(budget.currency()));
    query.addBindValue(budget.defaultLimitMinor());
    query.addBindValue(budget.allAccounts() ? 1 : 0);
    query.addBindValue(budget.allCategories() ? 1 : 0);
    query.addBindValue(budget.startsOn().toString(Qt::ISODate));
    query.addBindValue(now);
    query.addBindValue(now);
    if (!query.exec() || !replaceBudgetScopes(database_, budget) ||
        !saveBudgetMonth(database_, budget.id(), month,
                         budget.defaultLimitMinor()) ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
            ? query.lastError().text() : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool PlanningRepository::updateBudget(const Budget& budget, const QDate& month)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE budgets SET name = ?, currency = ?, default_limit_minor = ?, "
        "all_accounts = ?, all_categories = ?, updated_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(budget.name());
    query.addBindValue(currencyCode(budget.currency()));
    query.addBindValue(budget.defaultLimitMinor());
    query.addBindValue(budget.allAccounts() ? 1 : 0);
    query.addBindValue(budget.allCategories() ? 1 : 0);
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(budget.id());
    if (!query.exec() || query.numRowsAffected() != 1 ||
        !replaceBudgetScopes(database_, budget) ||
        !saveBudgetMonth(database_, budget.id(), month,
                         budget.defaultLimitMinor()) ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
            ? query.lastError().text() : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool PlanningRepository::archiveBudget(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE budgets SET is_archived = 1, updated_at = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    query.addBindValue(id);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return query.numRowsAffected() == 1;
}

bool PlanningRepository::ensureBudgetMonth(
    const QString& budgetId,
    const QDate& month,
    const qint64 limitMinor
    )
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO budget_months(budget_id, month, limit_minor) "
        "VALUES(?, ?, ?)"));
    query.addBindValue(budgetId);
    query.addBindValue(QDate(month.year(), month.month(), 1).toString(Qt::ISODate));
    query.addBindValue(limitMinor);
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

QVector<FinancialGoal> PlanningRepository::loadFinancialGoals()
{
    QVector<FinancialGoal> goals;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id,name,currency,target_minor,deadline,all_sources,source_ids "
            "FROM financial_goals ORDER BY rowid"))) {
        setLastError(query.lastError().text());
        return goals;
    }
    while (query.next()) {
        FinancialGoal goal;
        goal.id = query.value(0).toString();
        goal.name = query.value(1).toString();
        goal.currency = currencyFromCode(query.value(2).toString());
        goal.targetMinor = query.value(3).toLongLong();
        goal.deadline = QDate::fromString(query.value(4).toString(), Qt::ISODate);
        goal.allSources = query.value(5).toBool();
        const auto sources = QJsonDocument::fromJson(query.value(6).toByteArray()).array();
        for (const auto& source : sources) goal.sourceIds.append(source.toString());
        goals.append(goal);
    }
    return goals;
}

bool PlanningRepository::saveFinancialGoal(const FinancialGoal& goal, bool editing)
{
    if (goal.id.isEmpty() || goal.name.trimmed().isEmpty() || goal.name.size() > 80 ||
        goal.targetMinor <= 0 || (!goal.allSources && goal.sourceIds.isEmpty())) {
        setLastError(QStringLiteral("Invalid financial goal"));
        return false;
    }
    QSqlQuery query(database_);
    query.prepare(editing ? QStringLiteral(
        "UPDATE financial_goals SET name=?,currency=?,target_minor=?,deadline=?,"
        "all_sources=?,source_ids=? WHERE id=?") : QStringLiteral(
        "INSERT INTO financial_goals(name,currency,target_minor,deadline,all_sources,source_ids,id) "
        "VALUES(?,?,?,?,?,?,?)"));
    query.addBindValue(goal.name.trimmed());
    query.addBindValue(currencyCode(goal.currency));
    query.addBindValue(goal.targetMinor);
    query.addBindValue(goal.deadline.isValid() ? QVariant(goal.deadline.toString(Qt::ISODate)) : QVariant());
    query.addBindValue(goal.allSources ? 1 : 0);
    query.addBindValue(QString::fromUtf8(QJsonDocument(
        QJsonArray::fromStringList(goal.sourceIds)).toJson(QJsonDocument::Compact)));
    query.addBindValue(goal.id);
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    if (query.numRowsAffected() != 1) {
        setLastError(QStringLiteral("Financial goal not found")); return false;
    }
    return true;
}

bool PlanningRepository::deleteFinancialGoal(const QString& id)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral("DELETE FROM financial_goals WHERE id=?"));
    query.addBindValue(id);
    if (!query.exec()) { setLastError(query.lastError().text()); return false; }
    return query.numRowsAffected() == 1;
}
