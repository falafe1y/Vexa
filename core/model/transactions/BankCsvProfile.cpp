#include "BankCsvProfile.h"

#include <QJsonValue>

QJsonObject BankCsvProfile::toJson() const
{
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("name"), name},
        {QStringLiteral("accountId"), accountId},
        {QStringLiteral("incomeCategoryId"), incomeCategoryId},
        {QStringLiteral("expenseCategoryId"), expenseCategoryId},
        {QStringLiteral("encoding"), encoding},
        {QStringLiteral("delimiter"), delimiter},
        {QStringLiteral("dateFormat"), dateFormat},
        {QStringLiteral("amountMode"), amountMode},
        {QStringLiteral("headerRow"), headerRow},
        {QStringLiteral("dateColumn"), dateColumn},
        {QStringLiteral("amountColumn"), amountColumn},
        {QStringLiteral("incomeColumn"), incomeColumn},
        {QStringLiteral("expenseColumn"), expenseColumn},
        {QStringLiteral("descriptionColumn"), descriptionColumn},
        {QStringLiteral("recipientColumn"), recipientColumn},
        {QStringLiteral("recipientIdColumn"), recipientIdColumn},
        {QStringLiteral("idColumn"), idColumn},
        {QStringLiteral("categoryColumn"), categoryColumn},
        {QStringLiteral("directionColumn"), directionColumn},
        {QStringLiteral("currencyColumn"), currencyColumn},
        {QStringLiteral("positiveMeansIncome"), positiveMeansIncome}
    };
}

BankCsvProfile BankCsvProfile::fromJson(const QJsonObject& object)
{
    BankCsvProfile profile;
    profile.id = object.value(QStringLiteral("id")).toString();
    profile.name = object.value(QStringLiteral("name")).toString();
    profile.accountId = object.value(QStringLiteral("accountId")).toString();
    profile.incomeCategoryId = object.value(
        QStringLiteral("incomeCategoryId")).toString();
    profile.expenseCategoryId = object.value(
        QStringLiteral("expenseCategoryId")).toString();
    profile.encoding = object.value(QStringLiteral("encoding"))
        .toString(QStringLiteral("auto"));
    profile.delimiter = object.value(QStringLiteral("delimiter"))
        .toString(QStringLiteral("auto"));
    profile.dateFormat = object.value(QStringLiteral("dateFormat"))
        .toString(QStringLiteral("auto"));
    profile.amountMode = object.value(QStringLiteral("amountMode"))
        .toString(QStringLiteral("signed"));
    profile.headerRow = object.value(QStringLiteral("headerRow")).toInt();
    profile.dateColumn = object.value(QStringLiteral("dateColumn")).toInt(-1);
    profile.amountColumn = object.value(QStringLiteral("amountColumn")).toInt(-1);
    profile.incomeColumn = object.value(QStringLiteral("incomeColumn")).toInt(-1);
    profile.expenseColumn = object.value(QStringLiteral("expenseColumn")).toInt(-1);
    profile.recipientColumn = object.value(QStringLiteral("recipientColumn")).toInt(-1);
    profile.recipientIdColumn = object.value(QStringLiteral("recipientIdColumn")).toInt(-1);
    profile.descriptionColumn = object.value(
        QStringLiteral("descriptionColumn")).toInt(-1);
    profile.idColumn = object.value(QStringLiteral("idColumn")).toInt(-1);
    profile.categoryColumn = object.value(
        QStringLiteral("categoryColumn")).toInt(-1);
    profile.directionColumn = object.value(
        QStringLiteral("directionColumn")).toInt(-1);
    profile.currencyColumn = object.value(
        QStringLiteral("currencyColumn")).toInt(-1);
    profile.positiveMeansIncome = object.value(
        QStringLiteral("positiveMeansIncome")).toBool(true);
    return profile;
}
