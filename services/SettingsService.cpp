#include "SettingsService.h"
#include "Currency.h"

#include <QDir>
#include <QStandardPaths>

#include <stdexcept>

namespace services {

SettingsService::SettingsService()
    : settings_(
        QDir(
            QStandardPaths::writableLocation(
                QStandardPaths::AppDataLocation
            )
        ).filePath(QStringLiteral("settings.ini")),
        QSettings::IniFormat
    )
{
    const auto stored = settings_.value(
        QStringLiteral("finance/baseCurrency"),
        QStringLiteral("RUB")
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

    settings_.setValue(QStringLiteral("finance/baseCurrency"), code);
    settings_.sync();

    if (settings_.status() != QSettings::NoError) {
        throw std::runtime_error("Не удалось сохранить настройки");
    }

    baseCurrencyCode_ = code;
}

} // namespace services
