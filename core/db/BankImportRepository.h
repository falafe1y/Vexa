#pragma once
#include "Database.h"
#include "../model/transactions/BankCategoryRule.h"
#include "../model/transactions/BankRecipientRule.h"

#include <QMap>
#include <QString>
#include <QVector>

// What bank statement import remembers: CSV profiles of banks, the category and
// recipient rules, the links from statement rows to the operations they created.
class BankImportRepository
{
public:
    struct BankCsvProfileRecord
    {
        QString id;
        QString name;
        QString configurationJson;
    };

    explicit BankImportRepository(Database& database);

    QVector<BankCsvProfileRecord> loadBankCsvProfiles();
    bool saveBankCsvProfile(
        const QString& id,
        const QString& name,
        const QString& configurationJson
        );
    bool deleteBankCsvProfile(const QString& id);
    QVector<BankCategoryRule> loadBankCategoryRules(QString* error = nullptr) const;
    bool deleteBankCategoryRule(const QString& pattern, const QString& matchMode,
                                CategoryType type);
    QVector<BankRecipientRule> loadBankRecipientRules(QString* error = nullptr) const;
    bool deleteBankRecipientRule(const QString& pattern, const QString& field, const QString& mode, CategoryType type);
    QMap<QString, QString> loadBankImportLinks(QString* error = nullptr) const;
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
