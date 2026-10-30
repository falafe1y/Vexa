#pragma once
#include "Database.h"
#include "../model/accounts/DepositSettings.h"
#include "../model/money/Currency.h"
#include "../model/transactions/BankCategoryRule.h"
#include "../model/transactions/BankRecipientRule.h"
#include "../model/transactions/Transaction.h"
#include <QDate>
#include <QMap>
#include <QSet>
#include <QString>
#include <QVariantList>
#include <QVector>
#include <array>

// The operations journal: listing, the summary, adding, transfers, editing, replacing and removing
// operations, bank statement import with its rules and links, and the operations created on their
// dates from recurring schedules and deposit interest.
class TransactionRepository
{
public:
    struct Summary
    {
        std::array<qint64, kCurrencyCount> balance{};
        std::array<qint64, kCurrencyCount> income{};
        std::array<qint64, kCurrencyCount> expense{};
    };

    struct RecurringOccurrence
    {
        QDate date;
        Transaction transaction;
    };

    struct DepositInterestOccurrence
    {
        QDate date;
        Transaction transaction;
    };

    explicit TransactionRepository(Database& database);

    QVector<Transaction> loadTransactions();
    Summary loadSummary();
    bool insertTransaction(const Transaction& transaction);
    bool insertTransfer(
        const Transaction& outgoing,
        const Transaction& incoming
        );
    bool insertTransactions(const QVector<Transaction>& transactions,
                            const QVector<BankCategoryRule>& rules = {},
                            const QVector<BankRecipientRule>& recipientRules = {},
                            const QMap<QString, QString>& bankLinks = {},
                            const QSet<QString>& replacedBankTransactions = {});
    bool updateTransaction(const Transaction& transaction);
    bool replaceTransaction(
        const QString& currentId,
        const Transaction& replacement
        );
    bool replaceTransactionWithTransfer(
        const QString& currentId,
        const Transaction& outgoing,
        const Transaction& incoming
        );
    bool deleteTransaction(const QString& id);
    bool deleteHistoryRows(const QVariantList& rows);
    bool materializeRecurringOccurrences(
        const QString& recurringId,
        const QVector<RecurringOccurrence>& occurrences,
        const QDate& generatedThrough,
        int* insertedCount = nullptr
        );
    bool materializeDepositInterest(
        const DepositSettings& settings,
        const QVector<DepositInterestOccurrence>& occurrences,
        const QDate& generatedThrough,
        int* insertedCount = nullptr
        );
    QString lastError() const;

private:
    void setLastError(const QString& error);

    Database& db_;
    QSqlDatabase& database_;
    QString lastError_;
};
