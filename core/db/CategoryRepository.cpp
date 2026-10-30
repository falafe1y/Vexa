#include "CategoryRepository.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

CategoryRepository::CategoryRepository(Database& database)
    : database_(database.connection())
{
}

QString CategoryRepository::lastError() const { return lastError_; }
void CategoryRepository::setLastError(const QString& error) { lastError_ = error; }

QVector<Category> CategoryRepository::loadCategories()
{
    QVector<Category> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, type FROM categories "
            "ORDER BY type, name COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(Category(
            query.value(0).toString(),
            query.value(1).toString(),
            query.value(2).toInt() == 0
                ? CategoryType::Income
                : CategoryType::Expense));
    }
    return result;
}

QSet<QString> CategoryRepository::loadArchivedCategoryIds()
{
    QSet<QString> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id FROM categories WHERE is_archived = 1"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.insert(query.value(0).toString());
    }
    return result;
}

bool CategoryRepository::insertCategory(const Category& category)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO categories(id, name, type, is_system, created_at) "
        "VALUES (?, ?, ?, 0, ?)"));
    query.addBindValue(category.id());
    query.addBindValue(category.name());
    query.addBindValue(category.type() == CategoryType::Income ? 0 : 1);
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());

    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool CategoryRepository::updateCategoryName(
    const QString& id,
    const QString& name
    )
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE categories SET name = ? "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(name);
    query.addBindValue(id);

    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Category was not found"));
        return false;
    }
    return true;
}

bool CategoryRepository::archiveCategory(const QString& id)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery recurring(database_);
    recurring.prepare(QStringLiteral(
        "DELETE FROM recurring_transactions WHERE category_id = ?"));
    recurring.addBindValue(id);
    if (!recurring.exec()) {
        setLastError(recurring.lastError().text());
        database_.rollback();
        return false;
    }

    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE categories SET is_archived = 1 "
        "WHERE id = ? AND is_archived = 0"));
    query.addBindValue(id);

    if (!query.exec() || query.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : database_.lastError().isValid()
                           ? database_.lastError().text()
                           : QStringLiteral("Category was not found"));
        database_.rollback();
        return false;
    }
    return true;
}
