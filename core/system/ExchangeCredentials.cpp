#include "ExchangeCredentials.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QStandardPaths>
#include <QProcess>
#include "AndroidVault.h"
#ifdef Q_OS_WIN
#include <windows.h>
#include <wincrypt.h>
#endif
namespace {
QString path(const QString& id) {
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/exchange-secrets";
    QDir().mkpath(directory);
    return directory + "/" + id + ".bin";
}
#ifdef Q_OS_ANDROID
// Account ids are hex-encoded so that no id can change the file name.
QString vaultName(const QString& id) {
    return QStringLiteral("exchange-") + QString::fromLatin1(id.toUtf8().toHex()) + QStringLiteral(".bin");
}
#endif
#if !defined(Q_OS_WIN) && !defined(Q_OS_ANDROID)
QByteArray secretTool(const QStringList& arguments, const QByteArray& input = {}, bool* succeeded = nullptr) {
    const QString program = QStandardPaths::findExecutable("secret-tool");
    if (program.isEmpty()) { if (succeeded) *succeeded = false; return {}; }
    QProcess process;
    process.start(program, arguments);
    if (!process.waitForStarted(1000)) { if (succeeded) *succeeded = false; return {}; }
    if (!input.isEmpty()) process.write(input);
    process.closeWriteChannel();
    if (!process.waitForFinished(2000)) { process.kill(); process.waitForFinished(500); if (succeeded) *succeeded = false; return {}; }
    if (succeeded) *succeeded = process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
    return process.readAllStandardOutput().trimmed();
}
#endif
}
QPair<QString, QString> ExchangeCredentials::load(const QString& id) {
    QByteArray bytes;
#ifdef Q_OS_WIN
    QFile file(path(id));
    if (!file.open(QIODevice::ReadOnly)) return {};
    QByteArray encrypted = file.readAll();
    DATA_BLOB source{static_cast<DWORD>(encrypted.size()), reinterpret_cast<BYTE*>(encrypted.data())}, output{};
    if (!CryptUnprotectData(&source, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) return {};
    bytes = QByteArray(reinterpret_cast<char*>(output.pbData), static_cast<int>(output.cbData));
    SecureZeroMemory(output.pbData, output.cbData); LocalFree(output.pbData);
#elif defined(Q_OS_ANDROID)
    bool found = false;
    QString error;
    if (!AndroidVault::read(vaultName(id), bytes, found, error) || !found) {
        qWarning().noquote() << "Bybit key record for" << id << "not loaded:" << (error.isEmpty() ? QStringLiteral("no record") : error);
        return {};
    }
#else
    bytes = secretTool({"lookup", "application", "vexa", "exchange", "Bybit", "account", id});
#endif
    const auto object = QJsonDocument::fromJson(bytes).object(); bytes.fill('\0');
    if (object.isEmpty()) qWarning().noquote() << "Bybit key record for" << id << "is empty or unreadable";
    return {object.value("key").toString(), object.value("secret").toString()};
}
bool ExchangeCredentials::save(const QString& id, const QString& apiKey, const QString& secret) {
    QByteArray bytes = QJsonDocument(QJsonObject{{"key", apiKey}, {"secret", secret}}).toJson(QJsonDocument::Compact);
    bool succeeded = false;
#ifdef Q_OS_WIN
    DATA_BLOB source{static_cast<DWORD>(bytes.size()), reinterpret_cast<BYTE*>(bytes.data())}, output{};
    if (CryptProtectData(&source, L"Vexa Bybit", nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) {
        QSaveFile file(path(id));
        succeeded = file.open(QIODevice::WriteOnly)
            && file.write(reinterpret_cast<char*>(output.pbData), output.cbData) == output.cbData && file.commit();
        file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        SecureZeroMemory(output.pbData, output.cbData); LocalFree(output.pbData);
    }
#elif defined(Q_OS_ANDROID)
    QString error;
    succeeded = AndroidVault::write(vaultName(id), bytes, error);
#else
    secretTool({"store", "--label=Vexa Bybit", "application", "vexa", "exchange", "Bybit", "account", id}, bytes, &succeeded);
#endif
    if (!succeeded) qWarning().noquote() << "Bybit key record for" << id << "could not be saved";
    bytes.fill('\0'); return succeeded;
}
void ExchangeCredentials::remove(const QString& id) {
#ifdef Q_OS_WIN
    QFile::remove(path(id));
#elif defined(Q_OS_ANDROID)
    AndroidVault::remove(vaultName(id));
#else
    secretTool({"clear", "application", "vexa", "exchange", "Bybit", "account", id});
#endif
}
