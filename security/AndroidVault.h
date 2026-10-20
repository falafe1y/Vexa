#pragma once
#include <QByteArray>
#include <QString>

// Android only: secrets sealed by SecretVault.java with an AES-256 key held in Android Keystore. The sealed records
// are files in the application data directory, so the key stays bound to this device and the app installation.
// Elsewhere every call reports the vault as unavailable.
namespace AndroidVault {
// Probes Keystore access without creating a key.
bool available(QString& error);
// `found` is false when no record exists; that is not an error.
bool read(const QString& name, QByteArray& value, bool& found, QString& error);
bool write(const QString& name, const QByteArray& value, QString& error);
// A missing record is not an error.
void remove(const QString& name);
}
