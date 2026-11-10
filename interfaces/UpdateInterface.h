#pragma once

#include "UpdateService.h"

#include <QObject>
#include <QString>

namespace interfaces {

class UpdateInterface final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool checking READ checking NOTIFY stateChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY stateChanged)
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)

public:
    explicit UpdateInterface(services::UpdateService& service, QObject* parent = nullptr);

    bool checking() const noexcept;
    bool updateAvailable() const noexcept;
    QString currentVersion() const;
    QString latestVersion() const;
    QString errorMessage() const;

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void openReleasePage() const;

signals:
    void stateChanged();

private:
    services::UpdateService& service_;
};

} // namespace interfaces
