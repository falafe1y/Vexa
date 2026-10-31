#include "AndroidVault.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QStandardPaths>

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QJniObject>
#endif

namespace {
const char* RecordMagic = "VEXA_VAULT_1\n";
#ifdef Q_OS_ANDROID
const char* VaultClass = "org/qtproject/example/vexa/SecretVault";

QString recordPath(const QString& name)
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)).filePath(name);
}

// Calls SecretVault.seal or SecretVault.open with Base64 text. A Java exception comes back as an invalid result.
bool invoke(const char* method, const QByteArray& input, QByteArray& output, QString& error)
{
    const auto argument = QJniObject::fromString(QString::fromLatin1(input));
    const auto result = QJniObject::callStaticObjectMethod(VaultClass, method,
                                                           "(Ljava/lang/String;)Ljava/lang/String;",
                                                           argument.object<jstring>());
    QJniEnvironment env;
    if (!result.isValid() || env.checkAndClearExceptions()) {
        error = QStringLiteral("Не удалось обработать данные в хранилище Android.");
        return false;
    }
    output = result.toString().toLatin1();
    return true;
}
#endif
}

namespace AndroidVault {
bool available(QString& error)
{
#ifdef Q_OS_ANDROID
    const bool ok = QJniObject::callStaticMethod<jboolean>(VaultClass, "available", "()Z");
    QJniEnvironment env;
    env.checkAndClearExceptions();
    if (ok) return true;
    error = QStringLiteral("Хранилище Android недоступно. Разблокируйте устройство и повторите попытку.");
    return false;
#else
    error = QStringLiteral("Хранилище Android доступно только на Android.");
    return false;
#endif
}

bool read(const QString& name, QByteArray& value, bool& found, QString& error)
{
    value.clear();
    found = false;
#ifdef Q_OS_ANDROID
    QFile file(recordPath(name));
    if (!file.exists()) return true;
    if (!file.open(QIODevice::ReadOnly)) { error = file.errorString(); return false; }
    const auto stored = file.readAll();
    file.close();
    const QByteArray magic(RecordMagic);
    if (!stored.startsWith(magic)) {
        error = QStringLiteral("Сохранённые данные повреждены.");
        return false;
    }
    QByteArray plainBase64;
    if (!invoke("open", stored.mid(magic.size()).trimmed(), plainBase64, error)) return false;
    value = QByteArray::fromBase64(plainBase64);
    plainBase64.fill('\0');
    found = true;
    return true;
#else
    Q_UNUSED(name);
    error = QStringLiteral("Хранилище Android доступно только на Android.");
    return false;
#endif
}

void remove(const QString& name)
{
#ifdef Q_OS_ANDROID
    QFile::remove(recordPath(name));
#else
    Q_UNUSED(name);
#endif
}

bool write(const QString& name, const QByteArray& value, QString& error)
{
#ifdef Q_OS_ANDROID
    QByteArray sealed;
    if (!invoke("seal", value.toBase64(), sealed, error)) return false;
    QSaveFile file(recordPath(name));
    const QByteArray magic(RecordMagic);
    if (!file.open(QIODevice::WriteOnly) || file.write(magic) != magic.size()
        || file.write(sealed) != sealed.size() || !file.commit()) {
        error = QStringLiteral("Не удалось сохранить данные в хранилище Android.");
        return false;
    }
    return true;
#else
    Q_UNUSED(name); Q_UNUSED(value);
    error = QStringLiteral("Хранилище Android доступно только на Android.");
    return false;
#endif
}
}
