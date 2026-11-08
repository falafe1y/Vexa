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
        throw std::invalid_argument(
            "Не выбрана запись или указан неверный идентификатор"
        );
    }

    return id;
}

QDate readDate(const QString& input)
{
    const QString text = input.trimmed();

    const QDate date = QDate::fromString(
        text,
        Qt::ISODate
    );

    if (!date.isValid()
        || date.toString(Qt::ISODate) != text) {
        throw std::invalid_argument(
            "Укажите дату в формате ГГГГ-ММ-ДД"
        );
    }

    return date;
}

bool containsOnlyDigits(const QString& text)
{
    if (text.isEmpty()) {
        return false;
    }

    for (const QChar ch : text) {
        if (ch < QLatin1Char('0')
            || ch > QLatin1Char('9')) {
            return false;
        }
    }

    return true;
}

qint64 readMinorUnits(
    const QString& input,
    int decimalPlaces)
{
    QString text = input.trimmed();

    if (text.isEmpty()) {
        throw std::invalid_argument(
            "Введите сумму"
        );
    }

    text.replace(
        QLatin1Char(','),
        QLatin1Char('.')
    );

    bool negative = false;

    if (text.startsWith(QLatin1Char('-'))
        || text.startsWith(QLatin1Char('+'))) {
        negative = text.startsWith(QLatin1Char('-'));
        text.remove(0, 1);
    }

    const QStringList parts = text.split(
        QLatin1Char('.')
    );

    if (parts.size() > 2
        || !containsOnlyDigits(parts.front())) {
        throw std::invalid_argument(
            "Неверная сумма. Пример: 1500,50"
        );
    }

    QString fraction;

    if (parts.size() == 2) {
        fraction = parts.at(1);

        if (!containsOnlyDigits(fraction)) {
            throw std::invalid_argument(
                "Неверная дробная часть суммы"
            );
        }
    }

    if (fraction.size() > decimalPlaces) {
        throw std::invalid_argument(
            "Слишком много знаков после запятой"
        );
    }

    fraction = fraction.leftJustified(
        decimalPlaces,
        QLatin1Char('0')
    );

    const QString digits = parts.front() + fraction;

    bool ok = false;

    const quint64 magnitude =
        digits.toULongLong(&ok);

    const quint64 maximum =
        static_cast<quint64>(
            std::numeric_limits<qint64>::max()
        );

    const quint64 allowed =
        negative ? maximum + 1 : maximum;

    if (!ok || magnitude > allowed) {
        throw std::overflow_error(
            "Слишком большая сумма"
        );
    }

    if (negative && magnitude == maximum + 1) {
        return std::numeric_limits<qint64>::min();
    }

    const auto result =
        static_cast<qint64>(magnitude);

    return negative ? -result : result;
}

} // namespace

bool LedgerInterface::executeUiCommand(
    const QString& commandName,
    const std::function<void()>& action)
{
    if (!ready_) {
        emit errorOccurred(
            QStringLiteral("База ещё не загружена")
        );

        return false;
    }

    if (commandPending_) {
        emit errorOccurred(
            QStringLiteral("Дождитесь завершения команды")
        );

        return false;
    }

    try {
        pendingCommand_ = commandName;
        commandPending_ = true;

        emit commandStateChanged();

        action();

        return true;
    } catch (const std::exception& error) {
        commandPending_ = false;
        pendingCommand_.clear();

        emit commandStateChanged();

        emit errorOccurred(
            QString::fromUtf8(error.what())
        );

        return false;
    }
}

qint64 LedgerInterface::readAccountAmount(
    const QString& accountId,
    const QString& amount) const
{
    const QUuid id = readId(accountId);

    const auto position =
        accountDecimalPlaces_.constFind(id);

    if (position == accountDecimalPlaces_.cend()) {
        throw std::invalid_argument(
            "Счёт недоступен. Обновите список счетов"
        );
    }

    const qint64 minorUnits = readMinorUnits(
        amount,
        position.value()
    );

    if (minorUnits <= 0) {
        throw std::invalid_argument(
            "Сумма операции должна быть больше нуля"
        );
    }

    return minorUnits;
}

bool LedgerInterface::createAccount(
    const QString& name,
    int type,
    const QString& currencyCode,
    const QString& openingBalance,
    const QString& creditLimit)
{
    return executeUiCommand(
        QStringLiteral("createAccount"),
        [&]() {
            if (type < 0 || type > 2) {
                throw std::invalid_argument(
                    "Неверный тип счёта"
                );
            }

            const auto currency =
                core::model::Currency::fromCode(
                    currencyCode.toStdString()
                );

            const qint64 openingMinor = readMinorUnits(
                openingBalance,
                currency.decimalPlaces()
            );

            const qint64 limitMinor = readMinorUnits(
                creditLimit,
                currency.decimalPlaces()
            );

            if (limitMinor < 0) {
                throw std::invalid_argument(
                    "Кредитный лимит не может быть отрицательным"
                );
            }

            service_.createAccount(
                name,
                static_cast<core::model::AccountType>(type),
                currencyCode,
                openingMinor,
                limitMinor
            );
        }
    );
}

bool LedgerInterface::createCategory(
    const QString& name,
    int type)
{
    return executeUiCommand(
        QStringLiteral("createCategory"),
        [&]() {
            if (type < 0 || type > 1) {
                throw std::invalid_argument(
                    "Неверный тип категории"
                );
            }

            service_.createCategory(
                name,
                static_cast<core::model::CategoryType>(type)
            );
        }
    );
}

bool LedgerInterface::addIncome(
    const QString& accountId,
    const QString& categoryId,
    const QString& amount,
    const QString& date)
{
    return executeUiCommand(
        QStringLiteral("income"),
        [&]() {
            service_.addIncome(
                readId(accountId),
                readId(categoryId),
                readAccountAmount(accountId, amount),
                readDate(date)
            );
        }
    );
}

bool LedgerInterface::addExpense(
    const QString& accountId,
    const QString& categoryId,
    const QString& amount,
    const QString& date)
{
    return executeUiCommand(
        QStringLiteral("expense"),
        [&]() {
            service_.addExpense(
                readId(accountId),
                readId(categoryId),
                readAccountAmount(accountId, amount),
                readDate(date)
            );
        }
    );
}

bool LedgerInterface::transfer(
    const QString& fromAccountId,
    const QString& toAccountId,
    const QString& amount,
    const QString& date)
{
    return executeUiCommand(
        QStringLiteral("transfer"),
        [&]() {
            service_.transfer(
                readId(fromAccountId),
                readId(toAccountId),
                readAccountAmount(fromAccountId, amount),
                readDate(date)
            );
        }
    );
}

bool LedgerInterface::removeAccount(const QString& id)
{
    return executeUiCommand(
        QStringLiteral("removeAccount"),
        [&]() {
            service_.removeAccount(readId(id));
        }
    );
}

bool LedgerInterface::removeCategory(const QString& id)
{
    return executeUiCommand(
        QStringLiteral("removeCategory"),
        [&]() {
            service_.removeCategory(readId(id));
        }
    );
}

bool LedgerInterface::removeOperation(const QString& id)
{
    return executeUiCommand(
        QStringLiteral("removeOperation"),
        [&]() {
            service_.removeOperation(readId(id));
        }
    );
}

} // namespace interfaces
