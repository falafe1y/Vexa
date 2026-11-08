#pragma once

#include "Account.h"
#include "Category.h"

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

using AccountList = std::vector<AccountData>;
using CategoryList = std::vector<CategoryData>;

} // namespace services

Q_DECLARE_METATYPE(services::AccountData)
Q_DECLARE_METATYPE(services::CategoryData)

Q_DECLARE_METATYPE(services::AccountList)
Q_DECLARE_METATYPE(services::CategoryList)