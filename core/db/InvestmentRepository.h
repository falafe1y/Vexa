#pragma once
#include "Database.h"
#include "../model/investments/InvestmentInstrument.h"
#include "../model/investments/InvestmentOperation.h"
#include "../model/investments/InvestmentPosition.h"
#include "../model/investments/InvestmentQuote.h"
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVector>
#include <optional>

// Investments: instruments, positions, quotes, broker operations and charges,
// and the history of each position (states and cost basis) written with them.
class InvestmentRepository
{
public:
    explicit InvestmentRepository(Database& database);

    QVector<InvestmentInstrument> loadInvestmentInstruments();
    QVector<InvestmentPosition> loadInvestmentPositions();
    QVector<InvestmentQuote> loadInvestmentQuotes();
    bool insertInvestmentInstrument(const InvestmentInstrument& instrument);
    bool updateInvestmentInstrument(const InvestmentInstrument& instrument);
    bool archiveInvestmentInstrument(const QString& id);
    bool insertInvestmentPosition(const InvestmentPosition& position);
    bool updateInvestmentPosition(const InvestmentPosition& position);
    bool deleteInvestmentPosition(const QString& id);
    bool archiveInvestmentPosition(const QString& id);
    bool saveInvestmentQuote(const InvestmentQuote& quote);
    QVector<InvestmentOperation> loadInvestmentOperations();
    bool hasInvestmentOperations(const QString& positionId) const;
    bool saveInvestmentBundle(const InvestmentInstrument& instrument,
        const InvestmentPosition& position, const std::optional<InvestmentQuote>& quote,
        bool editing, const std::optional<InvestmentOperation>& operation = {},
        const std::optional<qint64>& openingCostMinor = {}, bool clearCostBasis = false,
        const QVector<InvestmentOperation>& charges = {});
    bool bookInvestmentOperation(const InvestmentOperation& operation,
        const InvestmentPosition& expected, const InvestmentPosition& updated, bool close,
        const std::optional<InvestmentQuote>& quote = {}, const QVector<InvestmentOperation>& charges = {});
    bool insertAccountCharge(const InvestmentOperation& operation);
    QVariant investmentCostBasis(const QString& positionId) const;
    bool appendPositionState(const QString& id, const QString& event);
    bool completePositionEvent(const InvestmentOperation& operation, const QVariant& previousBasis,
                               qint64 beforeQuantity, qint64 afterQuantity);
    QVariantList loadPositionHistory(const QString& positionId);
    QVariantList loadAllPositionHistory();
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
