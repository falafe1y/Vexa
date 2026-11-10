#include "UpdateService.h"

#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QVersionNumber>

namespace services {
namespace {
constexpr auto releasesApi = "https://api.github.com/repos/falafe1y/Vexa/releases/latest";

QString normalizedVersion(QString version)
{
    if (version.startsWith(QLatin1Char('v'), Qt::CaseInsensitive))
        version.remove(0, 1);
    return version;
}
}

UpdateService::UpdateService(QObject* parent) : QObject(parent) {}

void UpdateService::checkForUpdates()
{
    if (checking_)
        return;

    checking_ = true;
    errorMessage_.clear();
    emit stateChanged();

    QNetworkRequest request{QUrl{QString::fromLatin1(releasesApi)}};
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("User-Agent", "Vexa-Desktop");
    request.setTransferTimeout(10000);

    auto* reply = network_.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        checking_ = false;
        const auto finishWithError = [this](const QString& reason) {
            updateAvailable_ = false;
            latestVersion_.clear();
            errorMessage_ = reason;
            emit stateChanged();
        };

        if (reply->error() != QNetworkReply::NoError) {
            finishWithError(reply->errorString());
            reply->deleteLater();
            return;
        }

        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(reply->readAll(), &parseError);
        reply->deleteLater();
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            finishWithError(QStringLiteral("Некорректный ответ GitHub"));
            return;
        }

        const auto release = document.object();
        const QString tag = release.value(QStringLiteral("tag_name")).toString();
        const QString version = normalizedVersion(tag);
        const auto availableVersion = QVersionNumber::fromString(version);
        const auto installedVersion = QVersionNumber::fromString(
            QCoreApplication::applicationVersion());

        if (availableVersion.isNull() || installedVersion.isNull() ||
            availableVersion.toString() != version) {
            finishWithError(QStringLiteral("Некорректная версия выпуска"));
            return;
        }

        bool hasWindowsInstaller = false;
        const QString expectedAsset = QStringLiteral("Vexa-Setup-%1-win64.exe").arg(version);
        for (const auto& asset : release.value(QStringLiteral("assets")).toArray()) {
            if (asset.toObject().value(QStringLiteral("name")).toString() == expectedAsset &&
                !asset.toObject().value(QStringLiteral("browser_download_url")).toString().isEmpty()) {
                hasWindowsInstaller = true;
                break;
            }
        }

        latestVersion_ = version;
        updateAvailable_ = hasWindowsInstaller &&
            QVersionNumber::compare(availableVersion, installedVersion) > 0;
        errorMessage_.clear();
        emit stateChanged();
    });
}

} // namespace services
