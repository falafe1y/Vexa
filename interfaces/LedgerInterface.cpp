#include "LedgerInterface.h"

#include "Currency.h"

#include <QVariantMap>

#include <utility>

namespace interfaces {

namespace {

// Форматируем целое число минимальных единиц без double.
// Например: 12345, 2, "RUB" -> "123,45 RUB".
QString formatMoney(
    qint64 minorUnits,
    int decimalPlaces,
    const QString& currencyCode)
{
    QString digits = QString::number(minorUnits);

    const bool negative = digits.startsWith(QLatin1Char('-'));

    if (negative) {
        digits.remove(0, 1);
    }

    if (decimalPlaces > 0) {
        while (digits.size() <= decimalPlaces) {
            digits.prepend(QLatin1Char('0'));
        }

        digits.insert(
            digits.size() - decimalPlaces,
            QLatin1Char(',')
        );
    }

    if (negative) {
        digits.prepend(QLatin1Char('-'));
    }

    return digits + QLatin1Char(' ') + currencyCode;
}

QString idToString(const QUuid& id)
{
    return id.toString(QUuid::WithoutBraces);
}

QVariantMap makeAccountRow(const services::AccountData& account)
{
    const auto moneyText = [&account](qint64 amount) {
        return formatMoney(
            amount,
            account.decimalPlaces,
            account.currencyCode
        );
    };

    return QVariantMap{
        {"id", idToString(account.id)},
        {"name", account.name},
        {"type", static_cast<int>(account.type)},
        {"currencyCode", account.currencyCode},

        {"isCreditCard",
         account.type == core::model::AccountType::CreditCard},

        {"balanceText", moneyText(account.balanceMinor)},
        {"creditLimitText", moneyText(account.creditLimitMinor)},
        {"debtText", moneyText(account.debtMinor)},

        {"availableBalanceText",
         moneyText(account.availableBalanceMinor)}
    };
}

QVariantMap makeCategoryRow(const services::CategoryData& category)
{
    const bool income =
        category.type == core::model::CategoryType::Income;

    return QVariantMap{
        {"id", idToString(category.id)},
        {"name", category.name},
        {"type", static_cast<int>(category.type)},

        {"typeText",
         income ? QStringLiteral("Доход")
                : QStringLiteral("Расход")}
    };
}

QVariantMap makeOperationRow(const services::OperationData& operation)
{
    QString typeText;

    switch (operation.type) {
    case services::OperationType::Income:
        typeText = QStringLiteral("Доход");
        break;

    case services::OperationType::Expense:
        typeText = QStringLiteral("Расход");
        break;

    case services::OperationType::Transfer:
        typeText = QStringLiteral("Перевод");
        break;
    }

    const bool transfer =
        operation.type == services::OperationType::Transfer;

    QString receivedAmountText;

    if (transfer) {
        receivedAmountText = formatMoney(
            operation.receivedAmountMinor,
            operation.receivedDecimalPlaces,
            operation.receivedCurrencyCode
        );
    }

    return QVariantMap{
        {"id", idToString(operation.id)},

        {"dateText", operation.date.toString(
            QStringLiteral("dd.MM.yyyy")
        )},

        {"type", static_cast<int>(operation.type)},
        {"typeText", typeText},
        {"isTransfer", transfer},

        {"accountId", idToString(operation.accountId)},
        {"accountName", operation.accountName},

        {"categoryId", idToString(operation.categoryId)},
        {"categoryName", operation.categoryName},

        {"amountText", formatMoney(
            operation.amountMinor,
            operation.decimalPlaces,
            operation.currencyCode
        )},

        {"toAccountId", idToString(operation.toAccountId)},
        {"toAccountName", operation.toAccountName},

        {"receivedAmountText", receivedAmountText}
    };
}

} // namespace

LedgerInterface::LedgerInterface(
    services::LedgerService& service,
    QString totalCurrencyCode,
    QObject* parent)
    : QObject(parent),
      service_(service),
      totalCurrencyCode_(std::move(totalCurrencyCode))
{
    const auto currency = core::model::Currency::fromCode(
        totalCurrencyCode_.toStdString()
    );

    totalDecimalPlaces_ = currency.decimalPlaces();

    totalBalanceText_ = formatMoney(
        0,
        totalDecimalPlaces_,
        totalCurrencyCode_
    );

    connect(
        &service_,
        &services::LedgerService::loaded,
        this,
        [this](qint64, qint64, qint64) {
            ready_ = true;
            emit readyChanged();

            refresh();
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::changed,
        this,
        [this]() {
            refresh();
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::accountsReady,
        this,
        [this](const services::AccountList& accounts) {
            QVariantList items;

            items.reserve(
                static_cast<qsizetype>(accounts.size())
            );

            for (const auto& account : accounts) {
                items.push_back(makeAccountRow(account));
            }

            emit accountsReceived(items);
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::categoriesReady,
        this,
        [this](const services::CategoryList& categories) {
            QVariantList items;

            items.reserve(
                static_cast<qsizetype>(categories.size())
            );

            for (const auto& category : categories) {
                items.push_back(makeCategoryRow(category));
            }

            emit categoriesReceived(items);
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::totalBalanceReady,
        this,
        [this](qint64 minorUnits, const QString& currencyCode) {
            if (currencyCode != totalCurrencyCode_) {
                return;
            }

            const auto text = formatMoney(
                minorUnits,
                totalDecimalPlaces_,
                currencyCode
            );

            if (text == totalBalanceText_) {
                return;
            }

            totalBalanceText_ = text;

            emit totalBalanceChanged();
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::operationsReady,
        this,
        [this](const services::OperationPage& page) {
            if (!historyLoading_) {
                return;
            }

            historyLoading_ = false;

            // Пока ожидали ответ, журнал изменился.
            // Старый ответ не передаём в QML.
            if (historyReloadPending_) {
                historyReloadPending_ = false;
                reloadHistory();
                return;
            }

            QVariantList items;

            items.reserve(
                static_cast<qsizetype>(page.items.size())
            );

            for (const auto& operation : page.items) {
                items.push_back(makeOperationRow(operation));
            }

            const bool replace =
                historyReplace_ || page.resetRequired;

            historyNextOffset_ = page.nextOffset;
            historyVersion_ = page.version;
            historyHasMore_ = page.hasMore;
            historyReplace_ = false;

            emit historyReceived(items, replace);
            emit historyStateChanged();
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::requestFailed,
        this,
        [this](const QString& requestName,
               const QString& message) {
            if (requestName == QStringLiteral("operations")) {
                historyLoading_ = false;

                if (historyReloadPending_) {
                    historyReloadPending_ = false;
                    reloadHistory();
                } else {
                    emit historyStateChanged();
                }
            }

            emit errorOccurred(message);
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::commandFailed,
        this,
        [this](const QString&, const QString& message) {
            emit errorOccurred(message);
        },
        Qt::QueuedConnection
    );

    connect(
        &service_,
        &services::LedgerService::failed,
        this,
        [this](const QString& message) {
            emit errorOccurred(message);
        },
        Qt::QueuedConnection
    );
}

void LedgerInterface::refresh()
{
    if (!ready_) {
        return;
    }

    service_.requestAccounts();
    service_.requestCategories();
    service_.requestTotalBalance(totalCurrencyCode_);

    reloadHistory();
}

void LedgerInterface::reloadHistory()
{
    if (!ready_) {
        return;
    }

    // Не отправляем второй запрос истории параллельно первому.
    if (historyLoading_) {
        historyReloadPending_ = true;
        return;
    }

    historyNextOffset_ = 0;
    historyVersion_ = QUuid{};

    historyHasMore_ = true;
    historyReplace_ = true;

    requestHistoryPage();
}

void LedgerInterface::loadMoreHistory()
{
    if (!ready_ || historyLoading_ || !historyHasMore_) {
        return;
    }

    requestHistoryPage();
}

void LedgerInterface::requestHistoryPage()
{
    historyLoading_ = true;
    emit historyStateChanged();

    service_.requestOperations(
        historyNextOffset_,
        historyPageSize_,
        historyVersion_
    );
}

} // namespace interfaces
