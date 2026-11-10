#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QString>

namespace services {

class UpdateService final : public QObject
{
    Q_OBJECT

public:
    explicit UpdateService(QObject* parent = nullptr);

    bool checking() const noexcept { return checking_; }
    bool updateAvailable() const noexcept { return updateAvailable_; }
    const QString& latestVersion() const noexcept { return latestVersion_; }
    const QString& errorMessage() const noexcept { return errorMessage_; }

    void checkForUpdates();

signals:
    void stateChanged();

private:
    QNetworkAccessManager network_;
    bool checking_ = false;
    bool updateAvailable_ = false;
    QString latestVersion_;
    QString errorMessage_;
};

} // namespace services
