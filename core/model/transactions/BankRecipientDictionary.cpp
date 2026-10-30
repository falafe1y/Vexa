#include "BankRecipientDictionary.h"
#include "BankRecipientMatcher.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

BankRecipientDictionary BankRecipientDictionary::fromJson(const QByteArray& bytes)
{
    BankRecipientDictionary dictionary;
    auto& result = dictionary.entries_;
    const auto json = QJsonDocument::fromJson(bytes).object();
    for (const auto& value : json.value("recipients").toArray()) {
        const auto object = value.toObject();
        Entry entry;
        entry.id = object.value("id").toString();
        entry.name = object.value("name").toString();
        entry.parent = object.value("parent").toString();
        entry.contextual = object.value("contextual").toBool();
        for (const auto& alias : object.value("aliases").toArray())
            entry.aliases.append(BankRecipientMatcher::normalize(alias.toString()));
        entry.aliases.append(BankRecipientMatcher::normalize(entry.name));
        entry.aliases.removeDuplicates();
        for (const auto& category : object.value("categories").toArray())
            entry.categories.append(category.toString());
        for (const auto& alias : entry.aliases) {
            const auto expression = QStringLiteral("(?:^|[^\\p{L}\\p{N}])%1(?:[0-9]{2,})?(?=$|[^\\p{L}\\p{N}])")
                .arg(QRegularExpression::escape(alias));
            entry.expressions.append(QRegularExpression(expression, QRegularExpression::UseUnicodePropertiesOption));
        }
        if (!entry.id.isEmpty() && !entry.name.isEmpty()) result.append(entry);
    }
    return dictionary;
}
