#include "LedgerReadService.h"

#include "ExchangeRate.h"
#include "Ledger.h"
#include "Operation.h"

#include <QSet>

#include <algorithm>
#include <map>
#include <numeric>
#include <stdexcept>
#include <utility>
#include <variant>
#include <vector>

namespace services {

namespace {

QString toCurrencyCode(core::model::Currency currency)
{
    const auto code = currency.code();

    return QString::fromLatin1(
        code.data(),
        static_cast<qsizetype>(code.size())
        );
}

} // namespace

AccountList LedgerReadService::accounts() const
{
    AccountList result;
    const auto accounts = ledger_.accounts();

    result.reserve(accounts.size());

    for (const auto& account : accounts) {
        if (account.isArchived()) {
            continue;
        }

        AccountData data;

        data.id = account.id();
        data.name = account.name();
        data.type = account.type();

        data.currencyCode = toCurrencyCode(account.currency());
        data.decimalPlaces = account.currency().decimalPlaces();

        data.openingBalanceMinor = account.openingBalance().minorUnits();
        data.balanceMinor =
            ledger_.balance(account.id()).minorUnits();

        data.creditLimitMinor =
            account.creditLimit().minorUnits();

        data.debtMinor =
            ledger_.debt(account.id()).minorUnits();

        data.availableBalanceMinor =
            ledger_.availableBalance(account.id()).minorUnits();

        data.includeDebtInTotal = account.includesDebtInTotal();
        result.push_back(data);
    }

    std::sort(
        result.begin(),
        result.end(),
        [](const AccountData& left, const AccountData& right) {
            const int comparison = QString::compare(
                left.name,
                right.name,
                Qt::CaseInsensitive
                );

            if (comparison != 0) {
                return comparison < 0;
            }

            return left.id.toString(QUuid::WithoutBraces)
                   < right.id.toString(QUuid::WithoutBraces);
        }
        );

    return result;
}

CategoryList LedgerReadService::categories() const
{
    CategoryList result;
    const auto categories = ledger_.categories();

    result.reserve(categories.size());

    for (const auto& category : categories) {
        if (category.isArchived()) {
            continue;
        }

        CategoryData data;

        data.id = category.id();
        data.name = category.name();
        data.type = category.type();

        result.push_back(data);
    }

    std::sort(
        result.begin(),
        result.end(),
        [](const CategoryData& left, const CategoryData& right) {
            const int comparison = QString::compare(
                left.name,
                right.name,
                Qt::CaseInsensitive
                );

            if (comparison != 0) {
                return comparison < 0;
            }

            return left.id.toString(QUuid::WithoutBraces)
                   < right.id.toString(QUuid::WithoutBraces);
        }
        );

    return result;
}

OperationData LedgerReadService::makeOperationData(
    const core::model::Operation& operation) const
{
    using core::model::Money;
    using core::model::Operation;

    OperationData data;

    data.id = operation.id();
    data.date = operation.date();
    data.description = operation.description();

    const auto fillAccountAndAmount =
        [this, &data](const QUuid& accountId, Money amount) {
            const auto& account = ledger_.account(accountId);

            data.accountId = account.id();
            data.accountName = account.name();

            data.amountMinor = amount.minorUnits();
            data.currencyCode = toCurrencyCode(amount.currency());

            data.decimalPlaces =
                amount.currency().decimalPlaces();
        };

    const auto& details = operation.details();

    if (const auto* income = std::get_if<Operation::Income>(&details)) {
        data.type = OperationType::Income;

        fillAccountAndAmount(income->accountId, income->amount);

        const auto& category = ledger_.category(income->categoryId);

        data.categoryId = category.id();
        data.categoryName = category.name();
    } else if (
        const auto* expense = std::get_if<Operation::Expense>(&details)
        ) {
        data.type = OperationType::Expense;

        fillAccountAndAmount(expense->accountId, expense->amount);

        const auto& category = ledger_.category(expense->categoryId);

        data.categoryId = category.id();
        data.categoryName = category.name();
    } else {
        const auto& transfer = std::get<Operation::Transfer>(details);

        data.type = OperationType::Transfer;

        fillAccountAndAmount(
            transfer.fromAccountId,
            transfer.sentAmount
            );

        const auto& receiver = ledger_.account(transfer.toAccountId);

        data.toAccountId = receiver.id();
        data.toAccountName = receiver.name();

        data.receivedAmountMinor =
            transfer.receivedAmount.minorUnits();

        data.receivedCurrencyCode =
            toCurrencyCode(transfer.receivedAmount.currency());

        data.receivedDecimalPlaces =
            transfer.receivedAmount.currency().decimalPlaces();
    }

    return data;
}

ExpenseSummary LedgerReadService::expenseSummary(core::model::Currency currency) const
{
    using core::model::ExchangeRate;
    using core::model::Money;
    using core::model::Operation;

    using CurrencyTotals = std::map<std::string_view, Money>;
    const auto addAmount = [](CurrencyTotals& totals, Money amount) {
        const auto [position, inserted] = totals.try_emplace(amount.currency().code(), amount);
        if (!inserted) position->second = position->second + amount;
    };

    std::map<QUuid, CurrencyTotals> subtotals;
    for (qint64 i = 0; i < ledger_.operationCount(); ++i) {
        const auto& operation = ledger_.operationAt(static_cast<std::size_t>(i));
        const auto* expense = std::get_if<Operation::Expense>(&operation.details());
        if (!expense) continue;

        addAmount(subtotals[expense->categoryId], expense->amount);
    }

    const auto convertTotal = [currency](const CurrencyTotals& amounts) {
        auto total = Money::fromMinorUnits(0, currency);
        for (const auto& entry : amounts) {
            const auto& amount = entry.second;
            total = total + ExchangeRate::fixed(amount.currency(), currency).convert(amount);
        }
        return total.minorUnits();
    };

    ExpenseSummary summary;
    summary.categories.reserve(subtotals.size());
    CurrencyTotals allAmounts;

    for (const auto& [id, amounts] : subtotals) {
        long double weight = 0;
        for (const auto& entry : amounts) {
            const auto& amount = entry.second;
            addAmount(allAmounts, amount);
            const auto rate = ExchangeRate::fixed(amount.currency(), currency);

            // Доля учитывает и расходы меньше минимальной единицы базовой валюты.
            weight += static_cast<long double>(amount.minorUnits())
                * rate.numerator() / rate.denominator();
        }

        summary.categories.push_back({id, {}, 0, weight});
        summary.totalWeight += weight;
    }

    summary.totalMinor = convertTotal(allAmounts);
    constexpr std::size_t separateCategoryLimit = 7;
    auto& categories = summary.categories;
    const auto otherBegin = categories.begin() + std::min(categories.size(), separateCategoryLimit);
    std::partial_sort(categories.begin(), otherBegin, categories.end(),
        [](const ExpenseCategoryData& left, const ExpenseCategoryData& right) {
            if (left.weight != right.weight) return left.weight > right.weight;
            return left.id < right.id;
        });

    for (auto category = categories.begin(); category != otherBegin; ++category) {
        category->name = ledger_.category(category->id).name();
        category->amountMinor = convertTotal(subtotals.at(category->id));
    }

    if (otherBegin != categories.end()) {
        CurrencyTotals otherAmounts;
        long double otherWeight = 0;
        for (auto category = otherBegin; category != categories.end(); ++category) {
            for (const auto& entry : subtotals.at(category->id)) {
                addAmount(otherAmounts, entry.second);
            }
            otherWeight += category->weight;
        }

        categories.erase(otherBegin, categories.end());
        // Пустой ID обозначает сводную строку, которая не соответствует категории журнала.
        categories.push_back({{}, {}, convertTotal(otherAmounts), otherWeight});
    }
    return summary;
}

OperationPage LedgerReadService::operations(
    qint64 offset,
    qint64 limit,
    const OperationFilter& filter,
    const QString& baseCurrencyCode) const
{
    using core::model::Currency;
    using core::model::ExchangeRate;
    using core::model::Money;

    if (offset < 0 || limit <= 0 || filter.type < -1 || filter.type > 2) {
        throw std::invalid_argument("Invalid history request");
    }

    const auto currency = filter.accountId.isNull()
        ? Currency::fromCode(baseCurrencyCode.toStdString())
        : ledger_.account(filter.accountId).currency();

    const auto searchText = filter.searchText.trimmed();
    QString numericSearch = searchText;
    numericSearch.remove(QChar(' '));
    numericSearch.remove(QChar(0x00a0));
    numericSearch.remove(QChar(0x202f));
    numericSearch.replace(QLatin1Char(','), QLatin1Char('.'));
    if (numericSearch.startsWith(QLatin1Char('+'))
        || numericSearch.startsWith(QLatin1Char('-'))
        || numericSearch.startsWith(QChar(0x2212))) {
        numericSearch.remove(0, 1);
    }

    const auto amountMatches = [&numericSearch](qint64 minor, int decimals) {
        if (numericSearch.isEmpty()) return false;
        auto text = QString::number(minor).rightJustified(decimals + 1, QLatin1Char('0'));
        if (decimals > 0) text.insert(text.size() - decimals, QLatin1Char('.'));
        return text.contains(numericSearch);
    };

    using CurrencyTotals = std::map<std::string_view, Money>;
    std::map<QDate, CurrencyTotals> dailyTotals;
    const auto addAmount = [](CurrencyTotals& totals, Money amount) {
        const auto [position, inserted] = totals.try_emplace(amount.currency().code(), amount);
        if (!inserted) position->second = position->second + amount;
    };

    std::vector<std::size_t> indices;
    indices.reserve(static_cast<std::size_t>(ledger_.operationCount()));

    for (qint64 i = 0; i < ledger_.operationCount(); ++i) {
        const auto& operation = ledger_.operationAt(static_cast<std::size_t>(i));
        const auto data = makeOperationData(operation);
        const bool transfer = data.type == OperationType::Transfer;
        if (!filter.accountId.isNull()
            && data.accountId != filter.accountId && data.toAccountId != filter.accountId) continue;
        if (!filter.categoryId.isNull() && data.categoryId != filter.categoryId) continue;
        if (filter.type >= 0 && static_cast<int>(data.type) != filter.type) continue;

        const auto searchable = data.accountName + QLatin1Char(' ') + data.toAccountName
            + QLatin1Char(' ') + data.categoryName + QLatin1Char(' ') + data.description
            + QLatin1Char(' ') + data.date.toString(QStringLiteral("dd.MM.yyyy"));
        if (!searchText.isEmpty() && !searchable.contains(searchText, Qt::CaseInsensitive)
            && !amountMatches(data.amountMinor, data.decimalPlaces)
            && !(transfer && amountMatches(data.receivedAmountMinor, data.receivedDecimalPlaces))) continue;

        indices.push_back(static_cast<std::size_t>(i));
        auto& amounts = dailyTotals[data.date];
        if (transfer) {
            if (filter.accountId.isNull()) continue;
            if (data.toAccountId == filter.accountId) {
                addAmount(amounts, Money::fromMinorUnits(data.receivedAmountMinor, currency));
            } else {
                addAmount(amounts, Money::fromMinorUnits(-data.amountMinor, currency));
            }
        } else {
            const auto sourceCurrency = Currency::fromCode(data.currencyCode.toStdString());
            addAmount(amounts, Money::fromMinorUnits(
                data.type == OperationType::Income ? data.amountMinor : -data.amountMinor,
                sourceCurrency));
        }
    }

    std::sort(indices.begin(), indices.end(),
        [this](std::size_t leftIndex, std::size_t rightIndex) {
            const auto& left = ledger_.operationAt(leftIndex);
            const auto& right = ledger_.operationAt(rightIndex);
            if (left.date() != right.date()) return left.date() > right.date();
            return leftIndex > rightIndex;
        });

    OperationPage page;
    page.currencyCode = toCurrencyCode(currency);
    page.decimalPlaces = currency.decimalPlaces();
    page.limit = limit;
    page.totalCount = static_cast<qint64>(indices.size());
    page.offset = std::min(offset, page.totalCount);
    const auto count = std::min(limit, page.totalCount - page.offset);
    page.items.reserve(static_cast<std::size_t>(count));

    QSet<QDate> includedDays;
    for (qint64 i = 0; i < count; ++i) {
        const auto index = indices.at(static_cast<std::size_t>(page.offset + i));
        auto data = makeOperationData(ledger_.operationAt(index));
        if (!includedDays.contains(data.date)) {
            auto total = Money::fromMinorUnits(0, currency);
            for (const auto& [code, amount] : dailyTotals.at(data.date)) {
                total = total + ExchangeRate::fixed(amount.currency(), currency).convert(amount);
            }
            page.days.push_back({data.date, total.minorUnits()});
            includedDays.insert(data.date);
        }
        page.items.push_back(std::move(data));
    }

    page.nextOffset = page.offset + count;
    page.hasMore = page.nextOffset < page.totalCount;
    return page;
}

} // namespace services
