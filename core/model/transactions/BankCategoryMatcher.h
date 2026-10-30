#pragma once

#include "BankCsvOperation.h"
#include "BankRecipientMatcher.h"
#include "BankCategoryRule.h"
#include "Category.h"
#include <QSet>

struct BankCategorySuggestion
{
    QString merchant;
    QString categoryId;
    QString reason;
    bool needsReview = true;
};

class BankCategoryMatcher final
{
public:
    static QString normalize(const QString& text);
    static QString merchant(const BankRecipientDictionary& dictionary, const QString& description);
    static bool isSpecialOperation(const QString& description);
    static BankCategorySuggestion suggest(
        const BankRecipientDictionary& dictionary,
        const BankCsvOperation& operation,
        const QVector<Category>& categories,
        const QSet<QString>& archived,
        const QVector<BankCategoryRule>& rules,
        const QString& fallbackCategoryId,
        const BankRecipientMatch* recipient = nullptr);
};
