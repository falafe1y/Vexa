#include "DatabaseKeyStore.h"
#include "AndroidVault.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincred.h>
#endif

namespace {
// Android keeps the database key as a record sealed by Android Keystore, beside the database file.
const QString AndroidKeyRecord = QStringLiteral("vexa-database-key-v1.bin");
class NativeKeyStore final : public DatabaseKeyStore {
public:
    QByteArray existing(QString& error) override {
#ifdef Q_OS_WIN
        PCREDENTIALW credential = nullptr;
        if (!CredReadW(L"Vexa/database-encryption/v1", CRED_TYPE_GENERIC, 0, &credential)) {
            if (GetLastError() != ERROR_NOT_FOUND) error = QStringLiteral("Не удалось прочитать ключ базы из Диспетчера учётных данных Windows.");
            return {};
        }
        QByteArray value(reinterpret_cast<const char*>(credential->CredentialBlob), credential->CredentialBlobSize);
        SecureZeroMemory(credential->CredentialBlob, credential->CredentialBlobSize); CredFree(credential);
        if (value.size() != 32) { error = QStringLiteral("Сохранённый ключ базы повреждён."); value.fill('\0'); return {}; }
        return value;
#elif defined(Q_OS_ANDROID)
        QByteArray value;
        bool found = false;
        if (!AndroidVault::read(AndroidKeyRecord, value, found, error) || !found) return {};
        if (value.size() != 32) { error = QStringLiteral("Сохранённый ключ базы повреждён."); value.fill('\0'); return {}; }
        return value;
#else
        error = QStringLiteral("Хранилище ключа базы реализовано для Windows и Android."); return {};
#endif
    }
    bool save(const QByteArray& key, QString& error) override {
#ifdef Q_OS_WIN
        CREDENTIALW credential{};
        credential.Type = CRED_TYPE_GENERIC;
        credential.TargetName = const_cast<wchar_t*>(L"Vexa/database-encryption/v1");
        credential.UserName = const_cast<wchar_t*>(L"Vexa");
        credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
        credential.CredentialBlobSize = DWORD(key.size());
        credential.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char*>(key.constData()));
        if (CredWriteW(&credential, 0)) return true;
#elif defined(Q_OS_ANDROID)
        if (AndroidVault::write(AndroidKeyRecord, key, error)) return true;
        if (!error.isEmpty()) return false;
#else
        Q_UNUSED(key);
#endif
        error = QStringLiteral("Не удалось сохранить ключ базы в системном хранилище."); return false;
    }
};
}

std::shared_ptr<DatabaseKeyStore> nativeDatabaseKeyStore() { return std::make_shared<NativeKeyStore>(); }
