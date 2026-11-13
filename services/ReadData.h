#pragma once

#include "Account.h"
#include "Category.h"

#include <QDate>
#include <QMetaType>
#include <QString>
#include <QUuid>
#include <QtTypes>

#include <vector>

namespace services {

struct AccountData
{
    QUuid id;
    QString name;

    core::model::AccountType type =
        core::model::AccountType::Cash;

    QString currencyCode;
    int decimalPlaces = 0;

    qint64 openingBalanceMinor = 0;
    qint64 balanceMinor = 0;
    qint64 creditLimitMinor = 0;
    qint64 debtMinor = 0;
    qint64 availableBalanceMinor = 0;
};

struct CategoryData
{
    QUuid id;
    QString name;

    core::model::CategoryType type =
        core::model::CategoryType::Income;
};

enum class OperationType
{
    Income,
    Expense,
    Transfer
};

struct OperationData
{
    QUuid id;
    QDate date;

    OperationType type = OperationType::Income;

    // Для перевода это счет отправителя.
    QUuid accountId;
    QString accountName;

    QUuid categoryId;
    QString categoryName;

    // Для перевода это отправленная сумма.
    qint64 amountMinor = 0;
    QString currencyCode;
    int decimalPlaces = 0;

    // Заполняются только для перевода.
    QUuid toAccountId;
    QString toAccountName;

    qint64 receivedAmountMinor = 0;
    QString receivedCurrencyCode;
    int receivedDecimalPlaces = 0;

    QString description;
};

using AccountList = std::vector<AccountData>;
using CategoryList = std::vector<CategoryData>;
using OperationList = std::vector<OperationData>;

struct OperationPage
{
    OperationList items;

    qint64 offset = 0;
    qint64 limit = 0;
    qint64 totalCount = 0;
    qint64 nextOffset = 0;

    bool hasMore = false;

    QUuid version;
    bool resetRequired = false;
};

} // namespace services

Q_DECLARE_METATYPE(services::AccountData)
Q_DECLARE_METATYPE(services::CategoryData)
Q_DECLARE_METATYPE(services::OperationData)

Q_DECLARE_METATYPE(services::AccountList)
Q_DECLARE_METATYPE(services::CategoryList)
Q_DECLARE_METATYPE(services::OperationList)

Q_DECLARE_METATYPE(services::OperationPage)