#pragma once
#include "Database.h"
#include "../model/transactions/Category.h"
#include <QSet>
#include <QString>
#include <QVector>

// Income and expense categories: the list, archived ones, adding, renaming, archiving.
class CategoryRepository
{
public:
    explicit CategoryRepository(Database& database);

    QVector<Category> loadCategories();
    QSet<QString> loadArchivedCategoryIds();
    bool insertCategory(const Category& category);
    bool updateCategoryName(const QString& id, const QString& name);
    bool archiveCategory(const QString& id);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
