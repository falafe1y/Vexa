#pragma once
#include "Category.h"

#include <QString>

// A remembered choice of category for bank statement rows that match the pattern
struct BankCategoryRule
{
    QString pattern;
    QString matchMode = QStringLiteral("exact");
    QString categoryId;
    CategoryType type = CategoryType::Expense;
    QString field = QStringLiteral("legacy");
};
