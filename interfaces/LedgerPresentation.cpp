#include "LedgerPresentation.h"

namespace interfaces::presentation {

namespace {

QString idText(const QUuid& id)
{
    return id.toString(QUuid::WithoutBraces);
}

QString symbol(const QString& code)
{
    if (code == QStringLiteral("RUB")) return QStringLiteral("₽");
    if (code == QStringLiteral("USD")) return QStringLiteral("$");
    if (code == QStringLiteral("EUR")) return QStringLiteral("€");
    if (code == QStringLiteral("CNY")) return QStringLiteral("¥");
    return code;
}

QString accountTypeText(core::model::AccountType type)
{
    switch (type) {
    case core::model::AccountType::Cash:
        return QStringLiteral("Наличные");
    case core::model::AccountType::DebitCard:
        return QStringLiteral("Дебетовая карта");
    case core::model::AccountType::CreditCard:
        return QStringLiteral("Кредитная карта");
    }
    return {};
}

} // namespace

QString money(qint64 minor, int decimals, const QString& currencyCode)
{
    QString digits = QString::number(minor);
    const bool negative = digits.startsWith(QLatin1Char('-'));
    if (negative) digits.remove(0, 1);

    while (digits.size() <= decimals) digits.prepend(QLatin1Char('0'));

    QString fraction;
    if (decimals > 0) {
        fraction = digits.right(decimals);
        digits.chop(decimals);
    }

    for (qsizetype i = digits.size() - 3; i > 0; i -= 3) {
        digits.insert(i, QChar(0x202f));
    }

    if (decimals > 0) digits += QLatin1Char(',') + fraction;
    if (negative) digits.prepend(QChar(0x2212));

    return digits + QChar(0x00a0) + symbol(currencyCode);
}

QString accountsCaption(int count)
{
    const int lastHundred = count % 100;
    const int lastDigit = count % 10;
    QString word = QStringLiteral("счетов");

    if (lastHundred < 11 || lastHundred > 14) {
        if (lastDigit == 1) word = QStringLiteral("счет");
        else if (lastDigit >= 2 && lastDigit <= 4) word = QStringLiteral("счета");
    }

    return QString::number(count) + QLatin1Char(' ') + word;
}

QVariantMap accountRow(const services::AccountData& account)
{
    const bool credit = account.type == core::model::AccountType::CreditCard;
    const auto text = [&account](qint64 amount) {
        return money(amount, account.decimalPlaces, account.currencyCode);
    };

    return {
        {"id", idText(account.id)},
        {"name", account.name},
        {"typeText", accountTypeText(account.type)},
        {"currencyCode", account.currencyCode},
        {"isCreditCard", credit},
        {"primaryLabel", credit ? QStringLiteral("ДОСТУПНО") : QStringLiteral("ОСТАТОК")},
        {"primaryText", text(credit ? account.availableBalanceMinor : account.balanceMinor)},
        {"balanceText", text(account.balanceMinor)},
        {"creditLimitText", text(account.creditLimitMinor)},
        {"debtText", text(account.debtMinor)}
    };
}

QVariantMap categoryRow(const services::CategoryData& category)
{
    const bool income = category.type == core::model::CategoryType::Income;
    return {
        {"id", idText(category.id)},
        {"name", category.name},
        {"type", static_cast<int>(category.type)},
        {"typeText", income ? QStringLiteral("Доход") : QStringLiteral("Расход")}
    };
}

QVariantMap operationRow(const services::OperationData& operation)
{
    const bool income = operation.type == services::OperationType::Income;
    const bool transfer = operation.type == services::OperationType::Transfer;

    const auto amount = money(operation.amountMinor, operation.decimalPlaces,
                              operation.currencyCode);
    const QString primary = (income ? QStringLiteral("+") : QStringLiteral("−")) + amount;

    QString secondary;
    if (transfer) {
        secondary = QStringLiteral("+") + money(
            operation.receivedAmountMinor,
            operation.receivedDecimalPlaces,
            operation.receivedCurrencyCode
        );
    }

    const auto date = operation.date.toString(QStringLiteral("dd.MM.yyyy"));

    return {
        {"id", idText(operation.id)},
        {"dateText", date},
        {"type", static_cast<int>(operation.type)},
        {"typeText", transfer ? QStringLiteral("Перевод")
                             : income ? QStringLiteral("Доход") : QStringLiteral("Расход")},
        {"accountText", operation.accountName},
        {"secondaryAccountText", transfer ? QStringLiteral("→ ") + operation.toAccountName : QString{}},
        {"categoryText", transfer ? QStringLiteral("—") : operation.categoryName},
        {"primaryAmountText", primary},
        {"secondaryAmountText", secondary},
        {"descriptionText", QString{}}
    };
}

} // namespace interfaces::presentation
