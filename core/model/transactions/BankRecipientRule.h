#pragma once
#include "Category.h"

#include <QString>

// A remembered recipient name for bank statement rows that match the pattern
struct BankRecipientRule {
    QString pattern;
    QString field = QStringLiteral("description");
    QString matchMode = QStringLiteral("contains");
    CategoryType type = CategoryType::Expense;
    QString name;
};
