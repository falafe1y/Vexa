#include "LedgerPresentation.h"

#include <QLocale>

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

QString editableAmount(qint64 minor, int decimals)
{
    QString digits = QString::number(minor);
    const bool negative = digits.startsWith(QLatin1Char('-'));
    if (negative) digits.remove(0, 1);
    while (digits.size() <= decimals) digits.prepend(QLatin1Char('0'));
    if (decimals > 0) digits.insert(digits.size() - decimals, QLatin1Char(','));
    if (negative) digits.prepend(QLatin1Char('-'));
    return digits;
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
        {"type", static_cast<int>(account.type)},
        {"openingInput", editableAmount(credit
            ? account.availableBalanceMinor - account.balanceMinor + account.openingBalanceMinor
            : account.openingBalanceMinor, account.decimalPlaces)},
        {"limitInput", editableAmount(account.creditLimitMinor, account.decimalPlaces)},
        {"currencyCode", account.currencyCode},
        {"isCreditCard", credit},
        {"includeDebtInTotal", account.includeDebtInTotal},
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

    return {
        {"id", idText(operation.id)},
        {"dateText", operation.date.toString(operationDateFormat)},
        {"accountId", idText(operation.accountId)},
        {"secondaryId", idText(transfer ? operation.toAccountId : operation.categoryId)},
        {"amountInput", editableAmount(operation.amountMinor, operation.decimalPlaces)},
        {"type", static_cast<int>(operation.type)},
        {"typeText", transfer ? QStringLiteral("Перевод")
                             : income ? QStringLiteral("Доход") : QStringLiteral("Расход")},
        {"accountText", operation.accountName},
        {"secondaryAccountText", transfer ? QStringLiteral("→ ") + operation.toAccountName : QString{}},
        {"categoryText", transfer ? QStringLiteral("—") : operation.categoryName},
        {"primaryAmountText", primary},
        {"secondaryAmountText", secondary},
        {"descriptionText", operation.description}
    };
}

QVariantList expenseSummaryRows(const services::ExpenseSummary& summary,
    int decimals, const QString& currencyCode)
{
    QVariantList rows;
    rows.reserve(static_cast<qsizetype>(summary.categories.size()));
    const QLocale locale(QLocale::Russian, QLocale::Russia);
    long double cumulativeWeight = 0;

    for (const auto& category : summary.categories) {
        const auto share = category.weight / summary.totalWeight;
        const auto percent = static_cast<double>(share * 100);
        const auto shareText = percent < 0.1
            ? QStringLiteral("< 0,1 %")
            : locale.toString(percent, 'f', 1) + QStringLiteral(" %");
        const auto amountText = category.amountMinor == 0
            ? QStringLiteral("< ") + money(1, decimals, currencyCode)
            : money(category.amountMinor, decimals, currencyCode);

        const bool other = category.id.isNull();
        rows.push_back(QVariantMap{
            {"id", idText(category.id)},
            {"name", other ? QStringLiteral("Прочее") : category.name},
            {"amountText", amountText},
            {"shareText", shareText},
            {"isOther", other},
            {"startAngle", static_cast<double>(360 * cumulativeWeight / summary.totalWeight - 90)},
            {"sweepAngle", static_cast<double>(360 * share)}
        });
        cumulativeWeight += category.weight;
    }

    return rows;
}

} // namespace interfaces::presentation
