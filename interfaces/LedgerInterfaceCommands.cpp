#include "LedgerInterface.h"
#include "Currency.h"

#include <QDate>
#include <QStringList>

#include <limits>
#include <stdexcept>

namespace interfaces {
namespace {

QUuid readId(const QString& text)
{
    const QUuid id{text.trimmed()};
    if (id.isNull()) {
        throw std::invalid_argument("Не выбрана запись или указан неверный идентификатор");
    }
    return id;
}

QDate readDate(const QString& input)
{
    const auto text = input.trimmed();
    const auto date = QDate::fromString(text, Qt::ISODate);
    if (!date.isValid() || date.toString(Qt::ISODate) != text) {
        throw std::invalid_argument("Укажите дату в формате ГГГГ-ММ-ДД");
    }
    return date;
}

bool onlyDigits(const QString& text)
{
    if (text.isEmpty()) return false;
    for (const QChar ch : text) {
        if (ch < QLatin1Char('0') || ch > QLatin1Char('9')) return false;
    }
    return true;
}

qint64 readMinorUnits(const QString& input, int decimals)
{
    auto text = input.trimmed();
    if (text.isEmpty()) throw std::invalid_argument("Введите сумму");
    text.replace(QLatin1Char(','), QLatin1Char('.'));
    // Незавершённый ввод «150,» трактуем как целое число 150.
    if (text.endsWith(QLatin1Char('.'))) text.chop(1);

    bool negative = false;
    if (text.startsWith(QLatin1Char('-')) || text.startsWith(QLatin1Char('+'))) {
        negative = text.startsWith(QLatin1Char('-'));
        text.remove(0, 1);
    }

    const auto parts = text.split(QLatin1Char('.'));
    if (parts.size() > 2 || !onlyDigits(parts.front())) {
        throw std::invalid_argument("Неверная сумма. Пример: 1500,50");
    }

    QString fraction;
    if (parts.size() == 2) {
        fraction = parts.at(1);
        if (!onlyDigits(fraction)) {
            throw std::invalid_argument("Неверная дробная часть суммы");
        }
    }
    if (fraction.size() > decimals) {
        throw std::invalid_argument("Слишком много знаков после запятой");
    }
    fraction = fraction.leftJustified(decimals, QLatin1Char('0'));

    bool ok = false;
    const quint64 magnitude = (parts.front() + fraction).toULongLong(&ok);
    const auto maximum = static_cast<quint64>(std::numeric_limits<qint64>::max());
    if (!ok || magnitude > (negative ? maximum + 1 : maximum)) {
        throw std::overflow_error("Слишком большая сумма");
    }
    if (negative && magnitude == maximum + 1) return std::numeric_limits<qint64>::min();
    const auto result = static_cast<qint64>(magnitude);
    return negative ? -result : result;
}

} // namespace

bool LedgerInterface::executeUiCommand(const QString& command,
                                     const std::function<void()>& action)
{
    if (!ready_) {
        emit errorOccurred(QStringLiteral("База еще не загружена"));
        return false;
    }
    if (commandPending_) {
        emit errorOccurred(QStringLiteral("Дождитесь завершения команды"));
        return false;
    }
    try {
        pendingCommand_ = command;
        commandPending_ = true;
        emit commandStateChanged();
        action();
        return true;
    } catch (const std::exception& error) {
        commandPending_ = false;
        pendingCommand_.clear();
        emit commandStateChanged();
        emit errorOccurred(QString::fromUtf8(error.what()));
        return false;
    }
}

qint64 LedgerInterface::readAccountAmount(const QString& accountId,
                                        const QString& amount) const
{
    const auto id = readId(accountId);
    const auto it = accountDecimalPlaces_.constFind(id);
    if (it == accountDecimalPlaces_.cend()) {
        throw std::invalid_argument("Счет недоступен. Обновите список счетов");
    }
    const auto result = readMinorUnits(amount, it.value());
    if (result <= 0) throw std::invalid_argument("Сумма операции должна быть больше нуля");
    return result;
}

bool LedgerInterface::createAccount(const QString& name, int type,
    const QString& currencyCode, const QString& openingBalance, const QString& creditLimit)
{
    return executeUiCommand(QStringLiteral("createAccount"), [&] {
        if (type < 0 || type > 2) throw std::invalid_argument("Неверный тип счета");
        const auto currency = core::model::Currency::fromCode(currencyCode.toStdString());
        const auto opening = readMinorUnits(openingBalance, currency.decimalPlaces());
        const auto limit = readMinorUnits(creditLimit, currency.decimalPlaces());
        if (limit < 0) throw std::invalid_argument("Кредитный лимит не может быть отрицательным");

        qint64 initialBalance = opening;
        if (type == static_cast<int>(core::model::AccountType::CreditCard)) {
            if (opening < 0 || opening > limit) {
                throw std::invalid_argument(
                    "Доступный остаток кредитки должен быть от 0 до кредитного лимита");
            }
            // Ядро хранит долг как отрицательный баланс, а на форме
            // пользователь вводит доступную сумму по кредитке.
            initialBalance = opening - limit;
        } else if (opening < 0) {
            throw std::invalid_argument("Начальный остаток не может быть отрицательным");
        }

        service_.createAccount(name, static_cast<core::model::AccountType>(type),
                               currencyCode, initialBalance, limit);
    });
}

bool LedgerInterface::createCategory(const QString& name, int type)
{
    return executeUiCommand(QStringLiteral("createCategory"), [&] {
        if (type < 0 || type > 1) throw std::invalid_argument("Неверный тип категории");
        service_.createCategory(name, static_cast<core::model::CategoryType>(type));
    });
}

bool LedgerInterface::updateAccount(const QString& id, const QString& name,
    int type, const QString& currencyCode, const QString& openingBalance,
    const QString& creditLimit)
{
    return executeUiCommand(QStringLiteral("updateAccount"), [&] {
        if (type < 0 || type > 2) throw std::invalid_argument("Invalid account type");
        const auto currency = core::model::Currency::fromCode(currencyCode.toStdString());
        const auto opening = readMinorUnits(openingBalance, currency.decimalPlaces());
        const auto limit = readMinorUnits(creditLimit, currency.decimalPlaces());
        if (opening < 0 || limit < 0) throw std::invalid_argument("Amount cannot be negative");
        if (type == 2 && opening > limit)
            throw std::invalid_argument("Available balance exceeds credit limit");
        const qint64 initial = type == 2 ? opening - limit : opening;
        service_.updateAccount(readId(id), name,
            static_cast<core::model::AccountType>(type), currencyCode, initial, limit);
    });
}

bool LedgerInterface::updateCategory(const QString& id, const QString& name, int type)
{
    return executeUiCommand(QStringLiteral("updateCategory"), [&] {
        if (type < 0 || type > 1) throw std::invalid_argument("Invalid category type");
        service_.updateCategory(readId(id), name,
            static_cast<core::model::CategoryType>(type));
    });
}

bool LedgerInterface::updateOperation(const QString& id, int type,
    const QString& accountId, const QString& secondaryId,
    const QString& amount, const QString& date)
{
    return executeUiCommand(QStringLiteral("updateOperation"), [&] {
        if (type < 0 || type > 2) throw std::invalid_argument("Invalid operation type");
        service_.updateOperation(readId(id), type, readId(accountId),
            readId(secondaryId), readAccountAmount(accountId, amount), readDate(date));
    });
}

bool LedgerInterface::addIncome(const QString& accountId, const QString& categoryId,
                                const QString& amount, const QString& date)
{
    return executeUiCommand(QStringLiteral("income"), [&] {
        service_.addIncome(readId(accountId), readId(categoryId),
                           readAccountAmount(accountId, amount), readDate(date));
    });
}

bool LedgerInterface::addExpense(const QString& accountId, const QString& categoryId,
                                 const QString& amount, const QString& date)
{
    return executeUiCommand(QStringLiteral("expense"), [&] {
        service_.addExpense(readId(accountId), readId(categoryId),
                            readAccountAmount(accountId, amount), readDate(date));
    });
}

bool LedgerInterface::transfer(const QString& fromId, const QString& toId,
                               const QString& amount, const QString& date)
{
    return executeUiCommand(QStringLiteral("transfer"), [&] {
        service_.transfer(readId(fromId), readId(toId),
                          readAccountAmount(fromId, amount), readDate(date));
    });
}

bool LedgerInterface::removeAccount(const QString& id)
{
    return executeUiCommand(QStringLiteral("removeAccount"), [&] { service_.removeAccount(readId(id)); });
}

bool LedgerInterface::removeCategory(const QString& id)
{
    return executeUiCommand(QStringLiteral("removeCategory"), [&] { service_.removeCategory(readId(id)); });
}

bool LedgerInterface::removeOperation(const QString& id)
{
    return executeUiCommand(QStringLiteral("removeOperation"), [&] { service_.removeOperation(readId(id)); });
}

} // namespace interfaces
