#include "OperationService.h"

#include "Database.h"
#include "Ledger.h"
#include "Money.h"
#include "Operation.h"
#include <stdexcept>

namespace services {
namespace {

void validateDescription(const QString& description)
{
    if (description.toUcs4().size() > 50) {
        throw std::invalid_argument("Описание должно содержать не больше 50 символов");
    }
}

} // namespace

QUuid OperationService::income(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date,
    const QString& description)
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
        ),
        description
    ));
}

QUuid OperationService::expense(
    const QUuid& accountId,
    const QUuid& categoryId,
    qint64 amountMinor,
    QDate date,
    const QString& description)
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
        ),
        description
    ));
}

QUuid OperationService::transfer(
    const QUuid& fromAccountId,
    const QUuid& toAccountId,
    qint64 sentAmountMinor,
    QDate date,
    const QString& description)
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
        ),
        description
    ));
}

QUuid OperationService::update(const QUuid& id, int type,
    const QUuid& accountId, const QUuid& secondaryId,
    qint64 amountMinor, QDate date, const QString& description)
{
    const auto& account = ledger_.account(accountId);
    const auto amount = core::model::Money::fromMinorUnits(amountMinor, account.currency());
    core::model::Operation updated = [&]() {
        if (type == 0) return core::model::Operation::income(
            id, date, account, ledger_.category(secondaryId), amount, description);
        if (type == 1) return core::model::Operation::expense(
            id, date, account, ledger_.category(secondaryId), amount, description);
        if (type == 2) return core::model::Operation::transfer(
            id, date, account, ledger_.account(secondaryId), amount, description);
        throw std::invalid_argument("Invalid operation type");
    }();

    validateDescription(description);
    ledger_.validateOperationUpdate(updated);
    database_.saveOperation(updated);
    ledger_.applyOperationUpdate(updated);
    return id;
}

QUuid OperationService::remove(const QUuid& id)
{
    auto candidate = ledger_;

    candidate.removeOperation(id);

    database_.removeOperation(id);

    ledger_.swap(candidate);

    return id;
}

QUuid OperationService::save(
    const core::model::Operation& operation)
{
    validateDescription(operation.description());

    auto candidate = ledger_;

    // Проверка связей, архивных состояний и расчета остатков.
    candidate.addOperation(operation);

    database_.saveOperation(operation);

    ledger_.swap(candidate);

    return operation.id();
}

} // namespace services
