#include "AutoBackup.h"
#include "../security/AndroidVault.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrl>
#include <algorithm>

#ifdef Q_OS_ANDROID
#include "../services/ContentUriIo.h"
#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>
#endif

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincred.h>
#endif

namespace {
const QString NamePrefix = QStringLiteral("vexa-auto-");
const QString NameSuffix = QStringLiteral(".vexabackup");
const QString NameTimeFormat = QStringLiteral("yyyy-MM-dd_HH-mm-ss");
const QRegularExpression NamePattern(QStringLiteral("^vexa-auto-\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}\\.vexabackup$"));
#ifdef Q_OS_ANDROID
const char* FolderClass = "org/qtproject/example/vexa/BackupFolder";
const QString PasswordRecord = QStringLiteral("auto-backup-password-v1.bin");
#endif
#ifdef Q_OS_WIN
const wchar_t* PasswordTarget = L"Vexa/auto-backup-password/v1";
#endif
}

namespace AutoBackup {
bool load(const QString& file, State& state, QString& error)
{
    state = State{};
    if (!QFileInfo::exists(file)) return true;
    QFile device(file);
    if (!device.open(QIODevice::ReadOnly)) { error = device.errorString(); return false; }
    const auto object = QJsonDocument::fromJson(device.readAll()).object();
    if (object.isEmpty()) { error = QStringLiteral("Настройки автокопий повреждены."); return false; }
    state.enabled = object.value(QStringLiteral("enabled")).toBool();
    state.folder = object.value(QStringLiteral("folder")).toString();
    state.lastBackup = QDateTime::fromString(object.value(QStringLiteral("lastBackup")).toString(), Qt::ISODateWithMs);
    state.lastAttempt = QDateTime::fromString(object.value(QStringLiteral("lastAttempt")).toString(), Qt::ISODateWithMs);
    state.lastError = object.value(QStringLiteral("lastError")).toString();
    return true;
}

bool save(const QString& file, const State& state, QString& error)
{
    QJsonObject object{
        {QStringLiteral("enabled"), state.enabled},
        {QStringLiteral("folder"), state.folder},
        {QStringLiteral("lastError"), state.lastError},
    };
    // Local time keeps its UTC offset, so the interval is measured on the device clock
    if (state.lastBackup.isValid()) object.insert(QStringLiteral("lastBackup"), state.lastBackup.toString(Qt::ISODateWithMs));
    if (state.lastAttempt.isValid()) object.insert(QStringLiteral("lastAttempt"), state.lastAttempt.toString(Qt::ISODateWithMs));
    QSaveFile device(file);
    if (!device.open(QIODevice::WriteOnly) || device.write(QJsonDocument(object).toJson(QJsonDocument::Compact)) < 0
        || !device.commit()) {
        error = QStringLiteral("Не удалось сохранить настройки автокопий.");
        return false;
    }
    return true;
}

bool isDue(const State& state, const QDateTime& now, bool passwordSet)
{
    if (!state.enabled || state.folder.isEmpty() || !passwordSet) return false;
    if (state.lastAttempt.isValid() && !state.lastError.isEmpty() && state.lastAttempt.secsTo(now) < RetryAfterSeconds) return false;
    return !state.lastBackup.isValid() || state.lastBackup.secsTo(now) >= IntervalSeconds;
}

QString fileName(const QDateTime& when)
{
    return NamePrefix + when.toString(NameTimeFormat) + NameSuffix;
}

bool isAutoName(const QString& name)
{
    return NamePattern.match(name).hasMatch();
}

QStringList expired(QStringList names, int keep)
{
    QStringList copies;
    for (const auto& name : names) if (isAutoName(name)) copies.append(name);
    // The date and time in the name sort chronologically
    std::sort(copies.begin(), copies.end());
    const int count = std::max(0, int(copies.size()) - std::max(0, keep));
    return copies.mid(0, count);
}

namespace Target {
bool supported()
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_WIN) || defined(Q_OS_LINUX)
    return true;
#else
    return false;
#endif
}

bool write(const QString& folder, const QString& localFile, const QString& name, QString& error)
{
#ifdef Q_OS_ANDROID
    // A document is created inside the granted tree, then filled from the local copy
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    const auto created = QJniObject::callStaticObjectMethod(FolderClass, "create",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
        context.object(), QJniObject::fromString(folder).object<jstring>(), QJniObject::fromString(name).object<jstring>());
    QJniEnvironment env;
    if (env.checkAndClearExceptions() || !created.isValid()) {
        error = QStringLiteral("Не удалось создать файл автокопии в выбранной папке.");
        return false;
    }
    const QString documentUri = created.toString();
    if (!ContentUriIo::copyFileTo(localFile, QUrl(documentUri), error)) {
        QString ignored;
        remove(documentUri, ignored);
        return false;
    }
    return true;
#else
    const QDir directory(folder);
    if (!QDir().mkpath(folder)) { error = QStringLiteral("Не удалось создать папку автокопий."); return false; }
    const auto target = directory.filePath(name);
    if (QFileInfo::exists(target)) { error = QStringLiteral("Файл автокопии уже существует."); return false; }
    // Copy under a temporary name first, so an interrupted copy never looks like a finished one
    const auto partial = target + QStringLiteral(".partial");
    QFile::remove(partial);
    if (!QFile::copy(localFile, partial) || !QFile::rename(partial, target)) {
        QFile::remove(partial);
        error = QStringLiteral("Не удалось записать автокопию в выбранную папку.");
        return false;
    }
    return true;
#endif
}

QMap<QString, QString> list(const QString& folder, QString& error)
{
    QMap<QString, QString> copies;
#ifdef Q_OS_ANDROID
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    const auto names = QJniObject::callStaticObjectMethod(FolderClass, "list",
        "(Landroid/content/Context;Ljava/lang/String;)Ljava/lang/String;",
        context.object(), QJniObject::fromString(folder).object<jstring>());
    QJniEnvironment env;
    if (env.checkAndClearExceptions() || !names.isValid()) {
        error = QStringLiteral("Папка автокопий недоступна. Выберите её заново.");
        return copies;
    }
    for (const auto& line : names.toString().split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const auto fields = line.split(QLatin1Char('\t'));
        if (fields.size() == 2 && isAutoName(fields.at(0))) copies.insert(fields.at(0), fields.at(1));
    }
#else
    const QDir directory(folder);
    for (const auto& name : directory.entryList({NamePrefix + QStringLiteral("*")}, QDir::Files)) {
        if (isAutoName(name)) copies.insert(name, directory.filePath(name));
    }
    Q_UNUSED(error);
#endif
    return copies;
}

bool remove(const QString& identifier, QString& error)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    const bool deleted = QJniObject::callStaticMethod<jboolean>(FolderClass, "delete",
        "(Landroid/content/Context;Ljava/lang/String;)Z", context.object(), QJniObject::fromString(identifier).object<jstring>());
    QJniEnvironment env;
    if (env.checkAndClearExceptions() || !deleted) {
        error = QStringLiteral("Не удалось удалить старую автокопию.");
        return false;
    }
    return true;
#else
    if (QFile::remove(identifier)) return true;
    error = QStringLiteral("Не удалось удалить старую автокопию.");
    return false;
#endif
}

bool grant(const QString& folder, QString& error)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    const bool granted = QJniObject::callStaticMethod<jboolean>(FolderClass, "takePermission",
        "(Landroid/content/Context;Ljava/lang/String;)Z", context.object(), QJniObject::fromString(folder).object<jstring>());
    QJniEnvironment env;
    if (env.checkAndClearExceptions() || !granted) {
        error = QStringLiteral("Нет доступа к выбранной папке. Выберите её заново.");
        return false;
    }
    return true;
#else
    Q_UNUSED(folder); Q_UNUSED(error);
    return true;
#endif
}
}

namespace Secret {
bool available(QString& error)
{
#ifdef Q_OS_ANDROID
    return AndroidVault::available(error);
#elif defined(Q_OS_WIN)
    return true;
#else
    error = QStringLiteral("Хранилище пароля автокопий доступно на Windows и Android.");
    return false;
#endif
}

bool read(QByteArray& value, bool& found, QString& error)
{
    value.clear();
    found = false;
#ifdef Q_OS_ANDROID
    return AndroidVault::read(PasswordRecord, value, found, error);
#elif defined(Q_OS_WIN)
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(PasswordTarget, CRED_TYPE_GENERIC, 0, &credential)) {
        if (GetLastError() == ERROR_NOT_FOUND) return true;
        error = QStringLiteral("Не удалось прочитать пароль автокопий из Диспетчера учётных данных.");
        return false;
    }
    value = QByteArray(reinterpret_cast<const char*>(credential->CredentialBlob), credential->CredentialBlobSize);
    SecureZeroMemory(credential->CredentialBlob, credential->CredentialBlobSize);
    CredFree(credential);
    found = true;
    return true;
#else
    Q_UNUSED(value); Q_UNUSED(found);
    error = QStringLiteral("Хранилище пароля автокопий доступно на Windows и Android.");
    return false;
#endif
}

bool write(const QByteArray& value, QString& error)
{
#ifdef Q_OS_ANDROID
    return AndroidVault::write(PasswordRecord, value, error);
#elif defined(Q_OS_WIN)
    CREDENTIALW credential{};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = const_cast<wchar_t*>(PasswordTarget);
    credential.UserName = const_cast<wchar_t*>(L"Vexa");
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    credential.CredentialBlobSize = DWORD(value.size());
    credential.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char*>(value.constData()));
    if (CredWriteW(&credential, 0)) return true;
    error = QStringLiteral("Не удалось сохранить пароль автокопий в Диспетчере учётных данных.");
    return false;
#else
    Q_UNUSED(value);
    error = QStringLiteral("Хранилище пароля автокопий доступно на Windows и Android.");
    return false;
#endif
}
}
}
