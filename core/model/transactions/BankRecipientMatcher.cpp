#include "BankRecipientMatcher.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

#include <algorithm>

namespace {

bool tokenMatch(const QString& text, const QString& pattern)
{
    return !pattern.isEmpty() && (" " + text + " ").contains(" " + pattern + " ");
}


QString bankName(const BankCsvOperation& operation)
{
    QString name = operation.rawRecipient.trimmed();
    if (name.isEmpty()) {
        // Only explicit named fields can provide an unknown name. Never use a full descriptor.
        static const QRegularExpression label(QStringLiteral(
            "(?:^|[;\\n])\\s*(?:получатель|торговая точка|наименование тсп|место операции)\\s*[:=]\\s*([^;\\n]+)"),
            QRegularExpression::CaseInsensitiveOption);
        const auto match = label.match(operation.description);
        if (match.hasMatch()) name = match.captured(1).trimmed();
    }
    static const QRegularExpression letters(QStringLiteral("\\p{L}"), QRegularExpression::UseUnicodePropertiesOption);
    static const QRegularExpression service(QStringLiteral(
        "(?:номер операции|дата операции|сумма операции|оплата услуг|оплата товаров|списание средств|покупка по карте)"
        "|^(?:покупка|оплата|перевод|списание|зачисление|payment|purchase)\\s"),
        QRegularExpression::CaseInsensitiveOption);
    if (name.size() > 160 || !letters.match(name).hasMatch() || service.match(name).hasMatch()) return {};
    const auto key = BankRecipientMatcher::normalize(name);
    if (QStringList{"покупка", "оплата", "перевод", "платеж", "услуги", "неизвестно",
        "google pay", "apple pay", "samsung pay", "mir pay"}.contains(key)) return {};
    return name;
}

BankRecipientMatch baseMatch(const BankRecipientDictionary& dictionary, const BankCsvOperation& operation)
{
    const auto explicitName = bankName(operation);
    auto text = BankRecipientMatcher::normalize(explicitName.isEmpty() ? operation.description : explicitName);
    // A wallet used to pay is not the merchant. Preserve the original descriptor.
    for (const auto& wallet : QStringList{"google pay", "apple pay", "samsung pay", "mir pay"})
        text.replace(QRegularExpression("(?:^| )" + wallet + "(?= |$)"), " ");
    text = text.simplified();
    const auto context = BankRecipientMatcher::normalize(operation.description);
    const bool paymentContext = tokenMatch(context, "pos") || tokenMatch(context, "оплата")
        || tokenMatch(context, "покупка") || tokenMatch(context, "payment");
    QVector<const BankRecipientDictionary::Entry*> hits;
    for (const auto& entry : dictionary.entries()) {
        for (const auto& expression : entry.expressions) {
            if (expression.match(text).hasMatch()) {
                hits.append(&entry);
                break;
            }
        }
    }
    // Specific services replace all their ancestors; different services still conflict.
    for (int n = hits.size() - 1; n >= 0; --n) {
        const auto id = hits[n]->id;
        bool parent = false;
        for (const auto* item : hits) {
            auto ancestor = item->parent;
            for (int depth = 0; !ancestor.isEmpty() && depth < 16; ++depth) {
                if (ancestor == id) { parent = true; break; }
                const auto found = std::find_if(dictionary.entries().cbegin(), dictionary.entries().cend(), [&](const auto& entry) {
                    return entry.id == ancestor;
                });
                ancestor = found == dictionary.entries().cend() ? QString() : found->parent;
            }
            if (parent) break;
        }
        if (parent) hits.removeAt(n);
    }
    BankRecipientMatch result;
    if (hits.size() > 1) {
        result.status = "ambiguous";
        result.reason = QStringLiteral("Найдены разные получатели — выберите имя вручную");
        return result;
    }
    if (hits.size() == 1) {
        const auto* entry = hits.front();
        const bool uncertain = entry->contextual && explicitName.isEmpty()
            && !paymentContext && !entry->aliases.contains(text);
        result.recipient = {entry->name, "dict:" + entry->id, "dictionary"};
        result.status = uncertain ? "candidate" : "known";
        result.reason = uncertain ? QStringLiteral("Предположительно — проверьте получателя") : QStringLiteral("Локальный справочник");
        result.categoryNames = entry->categories;
        result.ruleField = "recipient";
        result.ruleMode = "exact";
        result.rulePattern = entry->name;
        if (uncertain) {
            // A tentative name cannot be the basis of an exact-name rule yet.
            result.ruleField = "description";
            result.ruleMode = "contains";
            for (int n = 0; n < entry->expressions.size(); ++n) {
                if (entry->expressions[n].match(text).hasMatch()) {
                    result.rulePattern = BankRecipientMatcher::normalize(entry->expressions[n].match(text).captured());
                    break;
                }
            }
        }
    } else if (!explicitName.isEmpty()) {
        result.recipient = {explicitName, BankRecipientMatcher::keyForName(dictionary, explicitName), "bank"};
        result.status = "known";
        result.reason = QStringLiteral("Получатель из выписки");
        result.ruleField = "bank_recipient";
        result.ruleMode = "exact";
        result.rulePattern = explicitName;
    } else {
        result.reason = QStringLiteral("Получатель не определён");
    }
    if (!operation.recipientId.trimmed().isEmpty() && result.status == "known") {
        result.ruleField = "recipient_id";
        result.ruleMode = "exact";
        result.rulePattern = operation.recipientId;
    }
    return result;
}
}

QString BankRecipientMatcher::normalize(const QString& text)
{
    auto result = text.normalized(QString::NormalizationForm_KC).toCaseFolded();
    result.replace(QChar(0x0451), QChar(0x0435));
    result.replace(QRegularExpression(QStringLiteral("[^\\p{L}\\p{N}]+")), QStringLiteral(" "));
    return result.simplified();
}

QString BankRecipientMatcher::bankRecipientName(const BankCsvOperation& operation)
{
    return bankName(operation);
}

QString BankRecipientMatcher::keyForName(const BankRecipientDictionary& dictionary, const QString& name)
{
    const auto key = normalize(name);
    if (key.isEmpty()) return {};
    for (const auto& entry : dictionary.entries())
        if (normalize(entry.name) == key) return "dict:" + entry.id;
    return "name:" + key;
}

bool BankRecipientMatcher::ruleMatches(const BankCsvOperation& operation,
    const BankRecipientMatch& base, const BankRecipientRule& rule)
{
    if ((operation.signedMinor > 0 ? CategoryType::Income : CategoryType::Expense) != rule.type) return false;
    QString value;
    if (rule.field == "description") value = operation.description;
    else if (rule.field == "bank_recipient") value = bankName(operation);
    else if (rule.field == "recipient_id") value = operation.recipientId;
    else if (rule.field == "recipient") value = base.status == "known" ? base.recipient.name : QString();
    else return false;
    const auto pattern = normalize(rule.pattern);
    const auto text = normalize(value);
    if (pattern.isEmpty()) return false;
    if (rule.matchMode == "exact") return text == pattern;
    return rule.matchMode == "contains" && rule.field != "recipient_id" && tokenMatch(text, pattern);
}

BankRecipientMatch BankRecipientMatcher::identify(const BankRecipientDictionary& dictionary, const BankCsvOperation& operation,
    const QVector<BankRecipientRule>& rules)
{
    auto result = baseMatch(dictionary, operation);
    result.baseRecipientName = result.status == "known" ? result.recipient.name : QString();
    QString chosen, pattern, field, mode;
    int best = -1;
    bool conflict = false;
    for (const auto& rule : rules) {
        if (rule.name.trimmed().isEmpty() || !ruleMatches(operation, result, rule)) continue;
        const int score = (rule.field == "recipient_id" ? 10000 : rule.matchMode == "exact" ? 1000 : 0)
            + normalize(rule.pattern).size();
        if (score > best) {
            best = score;
            chosen = rule.name.trimmed();
            pattern = rule.pattern;
            field = rule.field;
            mode = rule.matchMode;
            conflict = false;
        } else if (score == best && normalize(chosen) != normalize(rule.name)) {
            conflict = true;
        }
    }
    if (conflict) {
        result.recipient = {};
        result.status = "ambiguous";
        result.categoryNames.clear();
        result.reason = QStringLiteral("Конфликт правил получателя — проверьте имя");
    } else if (best >= 0) {
        result.recipient = {chosen, keyForName(dictionary, chosen), "rule"};
        result.status = "known";
        result.reason = QStringLiteral("Ваше правило получателя");
        result.rulePattern = pattern;
        result.ruleField = field;
        result.ruleMode = mode;
        result.categoryNames.clear();
        for (const auto& entry : dictionary.entries()) {
            if ("dict:" + entry.id == result.recipient.key) {
                result.categoryNames = entry.categories;
                break;
            }
        }
    }
    return result;
}
