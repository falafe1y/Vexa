#include "OperationService.h"

#include "Database.h"
#include "Ledger.h"
#include "Money.h"
#include "Operation.h"

namespace services {

QUuid OperationService::income(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date)
{
    const auto& account = ledger_.account(accountId);
    const auto& category = ledger_.category(categoryId);

    return save(core::model::Operation::income(
        QUuid::createUuid(),
        date,
        account,
        category,
        core::model::Money::fromMinorUnits(
            amountMinor,
            account.currency()
        )
    ));
}

QUuid OperationService::expense(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date)
{
    const auto& account = ledger_.account(accountId);
    const auto& category = ledger_.category(categoryId);

    return save(core::model::Operation::expense(
        QUuid::createUuid(),
        date,
        account,
        category,
        core::model::Money::fromMinorUnits(
            amountMinor,
            account.currency()
        )
    ));
}

QUuid OperationService::transfer(
    const QUuid& fromAccountId,
    const QUuid& toAccountId,
    qint64 sentAmountMinor,
    QDate date)
{
    const auto& from = ledger_.account(fromAccountId);
    const auto& to = ledger_.account(toAccountId);

    return save(core::model::Operation::transfer(
        QUuid::createUuid(),
        date,
        from,
        to,
        core::model::Money::fromMinorUnits(
            sentAmountMinor,
            from.currency()
        )
    ));
}

QUuid OperationService::save(
    const core::model::Operation& operation)
{
    auto candidate = ledger_;

    // Проверка связей, архивных состояний и расчета остатков.
    candidate.addOperation(operation);

    database_.saveOperation(operation);

    ledger_.swap(candidate);

    return operation.id();
}

} // namespace services
