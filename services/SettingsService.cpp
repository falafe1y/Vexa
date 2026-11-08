#include "SettingsService.h"

#include "Currency.h"

#include <QSettings>

#include <stdexcept>

namespace services {

SettingsService::SettingsService()
{
    QSettings settings;
    const auto stored = settings.value(
        QStringLiteral("finance/baseCurrency"), QStringLiteral("RUB")
    ).toString();

    try {
        (void)core::model::Currency::fromCode(stored.toStdString());
        baseCurrencyCode_ = stored;
    } catch (const std::invalid_argument&) {
        baseCurrencyCode_ = QStringLiteral("RUB");
    }
}

const QString& SettingsService::baseCurrencyCode() const noexcept
{
    return baseCurrencyCode_;
}

void SettingsService::setBaseCurrencyCode(const QString& code)
{
    (void)core::model::Currency::fromCode(code.toStdString());

    if (code == baseCurrencyCode_) {
        return;
    }

    QSettings settings;
    settings.setValue(QStringLiteral("finance/baseCurrency"), code);
    settings.sync();

    if (settings.status() != QSettings::NoError) {
        throw std::runtime_error("Не удалось сохранить настройки");
    }

    baseCurrencyCode_ = code;
}

} // namespace services
