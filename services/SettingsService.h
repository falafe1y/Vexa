#pragma once

#include <QString>
#include <QSettings>

namespace services {

class SettingsService final
{
public:
    SettingsService();

    [[nodiscard]] const QString& baseCurrencyCode() const noexcept;
    void setBaseCurrencyCode(const QString& code);

private:
    QString baseCurrencyCode_;
    QSettings settings_;
};

} // namespace services
