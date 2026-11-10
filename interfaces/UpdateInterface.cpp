#include "UpdateInterface.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QUrl>

namespace interfaces {

UpdateInterface::UpdateInterface(services::UpdateService& service, QObject* parent)
    : QObject(parent), service_(service)
{
    connect(&service_, &services::UpdateService::stateChanged,
            this, &UpdateInterface::stateChanged);
}

bool UpdateInterface::checking() const noexcept { return service_.checking(); }
bool UpdateInterface::updateAvailable() const noexcept { return service_.updateAvailable(); }
QString UpdateInterface::currentVersion() const { return QCoreApplication::applicationVersion(); }
QString UpdateInterface::latestVersion() const { return service_.latestVersion(); }
QString UpdateInterface::errorMessage() const { return service_.errorMessage(); }
void UpdateInterface::checkForUpdates() { service_.checkForUpdates(); }

void UpdateInterface::openReleasePage() const
{
    if (!service_.updateAvailable())
        return;
    QDesktopServices::openUrl(QUrl(QStringLiteral("https://github.com/falafe1y/Vexa/releases/latest")));
}

} // namespace interfaces
