#pragma once
#include "BankCsvOperation.h"

#include <QChar>
#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVector>

// How to read the statements of one bank: the columns of the date, amount, recipient and so on
struct BankCsvProfile
{
    QString id;
    QString name;
    QString accountId;
    QString incomeCategoryId;
    QString expenseCategoryId;
    QString encoding = QStringLiteral("auto");
    QString delimiter = QStringLiteral("auto");
    QString dateFormat = QStringLiteral("auto");
    QString amountMode = QStringLiteral("signed");
    int headerRow = 0;
    int dateColumn = -1;
    int amountColumn = -1;
    int incomeColumn = -1;
    int expenseColumn = -1;
    int descriptionColumn = -1;
    int recipientColumn = -1;
    int recipientIdColumn = -1;
    int idColumn = -1;
    int categoryColumn = -1;
    int directionColumn = -1;
    int currencyColumn = -1;
    bool positiveMeansIncome = true;

    QJsonObject toJson() const;
    static BankCsvProfile fromJson(const QJsonObject& object);
};

// The operations read from a statement and the rows that could not be read
struct BankCsvParseResult
{
    QVector<BankCsvOperation> operations;
    QStringList errors;
    int rejected = 0;
    QChar delimiter;
    QString encoding;
};
