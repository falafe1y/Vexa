#pragma once
#include "BankCsvOperation.h"
#include "BankRecipientDictionary.h"
#include "BankRecipientRule.h"
#include "Category.h"
#include "TransactionRecipient.h"

struct BankRecipientMatch {
    TransactionRecipient recipient;
    // Exact-name rules use the recognized name before personal renaming.
    QString baseRecipientName;
    QString status = QStringLiteral("unknown");
    QString reason;
    QStringList categoryNames;
    QString rulePattern;
    QString ruleField = QStringLiteral("description");
    QString ruleMode = QStringLiteral("contains");
};

class BankRecipientMatcher final {
public:
    static QString normalize(const QString& text);
    static BankRecipientMatch identify(const BankRecipientDictionary& dictionary, const BankCsvOperation& operation,
                                      const QVector<BankRecipientRule>& rules = {});
    static bool ruleMatches(const BankCsvOperation& operation, const BankRecipientMatch& base,
                            const BankRecipientRule& rule);
    static QString bankRecipientName(const BankCsvOperation& operation);
    static QString keyForName(const BankRecipientDictionary& dictionary, const QString& name);
};
