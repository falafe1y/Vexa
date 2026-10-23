#include "DatabaseProtection.h"
#include "../services/ContentUriIo.h"
#include <QCoreApplication>
#include <QProcess>
#include <QFileInfo>
#include <QDir>
#include <QtConcurrent>

DatabaseProtection::DatabaseProtection(QString path, QObject* parent)
    : QObject(parent), path_(std::move(path)), store_(nativeDatabaseKeyStore()) {
    workspaceRoot_ = QFileInfo(path_).absolutePath() + "/.vexa-portable";
    // The application owns the installation lock before constructing this object.
    PortableBackup::cleanAbandoned(workspaceRoot_);
    autoFile_ = QFileInfo(path_).absolutePath() + QStringLiteral("/auto-backup.json");
    QString error;
    if (!AutoBackup::load(autoFile_, autoState_, error)) autoError_ = error;
    QString secretError;
    autoSupported_ = AutoBackup::Target::supported() && AutoBackup::Secret::available(secretError);
    QByteArray secret;
    bool found = false;
    autoPasswordSet_ = autoSupported_ && AutoBackup::Secret::read(secret, found, secretError) && found;
    secret.fill('\0');
    autoTimer_.setInterval(10 * 60 * 1000);
    connect(&autoTimer_, &QTimer::timeout, this, &DatabaseProtection::autoBackupCheck);
    autoTimer_.start();
}
DatabaseProtection::~DatabaseProtection() { worker_.waitForFinished(); backupWorker_.waitForFinished(); }
bool DatabaseProtection::supported() const {
#if defined(Q_OS_WIN) || defined(Q_OS_ANDROID)
    return true;
#else
    return false;
#endif
}
void DatabaseProtection::setAdmitted(bool admitted) {
    admitted_ = admitted;
    if (!admitted) { ++generation_; preview_.reset(); passwordRequired_ = false; backupError_.clear(); emit backupChanged(); }
}
void DatabaseProtection::releaseSession() {
    ready_ = false; access_ = {};
    emit changed();
}
void DatabaseProtection::storageFailed(const QString& error) {
    ready_ = false; error_ = error; emit changed();
}
void DatabaseProtection::prepare() {
    if (!admitted_ || busy_ || ready_ || restartRequired_) return;
    launch(false);
}
void DatabaseProtection::requestChange(bool encrypted) {
    if (!admitted_ || !ready_ || busy_ || !supported() || encrypted == access_.encrypted()) return;
    // Withdraw readiness immediately, before yielding to the UI event loop.
    ready_ = false; busy_ = true; error_.clear(); emit changed();
    emit maintenanceRequested(encrypted);
}
void DatabaseProtection::beginChange(bool encrypted) {
    // The request was admitted before teardown. A later app lock cannot cancel file maintenance.
    launch(true, encrypted);
}
void DatabaseProtection::beginRestore() {
    if (!restoring_) return;
    auto candidate = std::move(restoring_);
    launch(true, false, std::move(candidate));
}
void DatabaseProtection::launch(bool conversion, bool encrypted, std::shared_ptr<PortableBackup::Prepared> restore) {
    busy_ = true; error_.clear(); emit changed();
    disconnect(&worker_, nullptr, this, nullptr);
    connect(&worker_, &QFutureWatcher<DatabaseOutcome>::finished, this, [this, conversion] {
        const auto result = worker_.result();
        busy_ = false;
        if (!result.ok) {
            ready_ = false;
            error_ = result.error;
            if (!result.recoveryPath.isEmpty()) error_ += QStringLiteral(" Копия для восстановления: %1").arg(result.recoveryPath);
        } else if (conversion) {
            access_ = result.access;
            restartRequired_ = true;
            emit changed();
            restart();
            return;
        } else if (admitted_) {
            access_ = result.access; ready_ = true;
        }
        emit changed();
        if (ready_ && admitted_) {
            emit available();
            // A little later, so that startup is not slowed down by a copy
            QTimer::singleShot(3000, this, [this] { autoBackupCheck(); });
        }
    });
    const auto path = path_; const auto store = store_;
    const bool recovery = recovery_;
    worker_.setFuture(QtConcurrent::run([path, store, conversion, encrypted, restore, recovery] {
        if (restore) return recovery ? DatabaseEncryption::recover(path, restore->access, *store)
                                    : DatabaseEncryption::restore(path, restore->access, *store);
        if (conversion) return DatabaseEncryption::convert(path, encrypted, *store);
        DatabaseEncryption::cleanAbandoned(path);
        return DatabaseEncryption::open(path, *store);
    }));
}
void DatabaseProtection::finishBackup(bool exporting, const QString& path, quint64 generation, const QUrl& destination) {
    auto result = backupWorker_.result();
    disconnect(&backupWorker_, nullptr, this, nullptr);
    backupWorker_.setFuture(QFuture<PortableBackup::Result>());
    busy_ = false;
    const bool current = generation == generation_ && admitted_;
    // The backup is saved only while the session that started the export is still open
    QUrl saved = destination;
    if (exporting && result.ok && current && ContentUriIo::isContentUri(destination)) {
        if (ContentUriIo::saveToDownloads(path, backupName_, saved, result.error)) {
            ContentUriIo::deleteDocument(destination); // The empty document the picker made
        } else {
            result.ok = false;
        }
    }
    backupDirectory_.reset();
    if (current) {
        backupError_ = result.error;
        if (result.ok && !exporting) { preview_ = result.prepared; previewAge_.start(); passwordRequired_ = false; }
        emit backupChanged();
        if (result.ok && exporting) {
            const QString name = ContentUriIo::isContentUri(saved) ? ContentUriIo::displayName(saved) : path;
            emit backupExported(name.isEmpty() ? saved.toString() : name);
        }
    }
    emit changed();
    if (generation != generation_ && admitted_ && !ready_) prepare();
}
void DatabaseProtection::exportBackup(const QUrl& destination, const QString& password, bool plaintext) {
    if (!admitted_ || !ready_ || busy_) return;
    backupError_.clear();
    if (!plaintext && !PortableBackup::validPassword(password)) {
        backupError_ = QStringLiteral("Пароль копии должен содержать от 12 до 1024 символов."); emit backupChanged(); return;
    }
    const QString suffix = plaintext ? QStringLiteral(".sqlite3") : QStringLiteral(".vexabackup");
    QUrl target = destination;
    QString path = destination.toLocalFile();
    if (ContentUriIo::isContentUri(destination)) {
        // A picked document cannot be written on Android, so the backup goes to Downloads under the picked name.
        // The picker does not add the suffix, so it is added to the name here.
        QString error;
        backupName_ = ContentUriIo::displayName(destination);
        if (backupName_.isEmpty()) { backupError_ = QStringLiteral("Не удалось узнать имя выбранного файла"); emit backupChanged(); return; }
        if (!backupName_.endsWith(suffix, Qt::CaseInsensitive)) backupName_ += suffix;
        // A picked document has no path on Android: the backup is written to a temporary folder and copied over later
        backupDirectory_ = ContentUriIo::temporaryDirectory(error);
        if (!backupDirectory_) { backupError_ = error; emit backupChanged(); return; }
        path = backupDirectory_->filePath(QStringLiteral("backup"));
    }
    if (path.isEmpty()) { backupError_ = QStringLiteral("Выберите место сохранения копии."); emit backupChanged(); return; }
    if (QFileInfo(path).suffix().isEmpty()) path += suffix;
    busy_ = true; emit changed(); emit backupChanged();
    const auto generation = generation_; const auto source = access_; const auto root = workspaceRoot_;
    const auto version = QCoreApplication::applicationVersion();
    disconnect(&backupWorker_, nullptr, this, nullptr);
    connect(&backupWorker_, &QFutureWatcher<PortableBackup::Result>::finished, this,
            [this, path, generation, target] { finishBackup(true, path, generation, target); });
    backupWorker_.setFuture(QtConcurrent::run([source, path, root, password, plaintext, version] {
        return PortableBackup::exportFile(source, path, root, password, plaintext, version);
    }));
}
void DatabaseProtection::inspectBackup(const QUrl& source, const QString& password) {
    if (!admitted_ || busy_ || restartRequired_ || (!ready_ && error_.isEmpty())) return;
    preview_.reset(); backupError_.clear(); passwordRequired_ = false;
    // A picked copy is read through a temporary file, which exists until the import has been prepared
    const auto copy = std::make_shared<ContentUriIo::LocalCopy>(source);
    if (!copy->error().isEmpty()) { backupError_ = copy->error(); emit backupChanged(); return; }
    const auto path = copy->path();
    if (QFileInfo(path).canonicalFilePath() == QFileInfo(path_).canonicalFilePath()) {
        backupError_ = QStringLiteral("Выберите копию, а не рабочую базу."); emit backupChanged(); return;
    }
    if (!PortableBackup::needsPassword(path, passwordRequired_, backupError_)
        || (passwordRequired_ && password.isEmpty())) { emit backupChanged(); return; }
    busy_ = true; emit changed(); emit backupChanged();
    const auto generation = generation_; const auto root = workspaceRoot_; const auto keys = store_; const auto validator = schemaValidator_;
    disconnect(&backupWorker_, nullptr, this, nullptr);
    connect(&backupWorker_, &QFutureWatcher<PortableBackup::Result>::finished, this,
            [this, generation] { finishBackup(false, {}, generation, {}); });
    backupWorker_.setFuture(QtConcurrent::run([copy, root, password, keys, validator] {
        return PortableBackup::prepareImport(copy->path(), root, password, *keys, validator);
    }));
}
QString DatabaseProtection::sourceName(const QUrl& source) const {
    // A picked document on Android has an address made of provider ids: its name comes from the provider
    return ContentUriIo::isContentUri(source) ? ContentUriIo::displayName(source) : QFileInfo(source.toLocalFile()).fileName();
}
void DatabaseProtection::discardBackup() {
    if (busy_) return;
    preview_.reset(); passwordRequired_ = false; backupError_.clear(); emit backupChanged();
}
void DatabaseProtection::restoreBackup() {
    if (!admitted_ || busy_ || restartRequired_ || !preview_ || (!ready_ && error_.isEmpty())) return;
    if (!previewAge_.isValid() || previewAge_.elapsed() >= 10 * 60 * 1000) {
        preview_.reset(); backupError_ = QStringLiteral("Проверка копии устарела. Выберите файл и проверьте его заново."); emit backupChanged(); return;
    }
    restoring_ = std::move(preview_);
    recovery_ = !ready_;
    ready_ = false; busy_ = true; error_.clear(); emit changed(); emit backupChanged();
    emit restoreRequested();
}
void DatabaseProtection::restart() {
    if (!restartRequired_ || busy_) return;
    // Quit first so the next process can acquire the installation ownership lock.
    QCoreApplication::exit(42);
}

QString DatabaseProtection::autoBackupLast() const
{
    return autoState_.lastBackup.isValid() ? autoState_.lastBackup.toString(QStringLiteral("dd.MM.yyyy HH:mm")) : QString();
}

void DatabaseProtection::saveAutoState()
{
    QString error;
    if (!AutoBackup::save(autoFile_, autoState_, error)) autoError_ = error;
    emit autoBackupChanged();
}

void DatabaseProtection::setAutoBackupEnabled(bool enabled)
{
    autoError_.clear();
    if (!autoSupported_) {
        autoError_ = QStringLiteral("Автокопии на этой платформе недоступны.");
        emit autoBackupChanged();
        return;
    }
    if (enabled) {
        if (autoState_.folder.isEmpty()) { autoError_ = QStringLiteral("Сначала выберите папку для автокопий."); emit autoBackupChanged(); return; }
        if (!autoPasswordSet_) { autoError_ = QStringLiteral("Сначала задайте пароль автокопий."); emit autoBackupChanged(); return; }
        QString error;
        if (!AutoBackup::Target::grant(autoState_.folder, error)) { autoError_ = error; emit autoBackupChanged(); return; }
    }
    autoState_.enabled = enabled;
    autoState_.lastError.clear();
    saveAutoState();
    // Enabling makes a copy at once when none has been made yet
    if (enabled) QTimer::singleShot(0, this, [this] { autoBackupCheck(); });
}

void DatabaseProtection::chooseAutoBackupFolder(const QUrl& folder)
{
    autoError_.clear();
    // Windows gives a local path; Android gives a document-tree URI, which is kept as text
    const QString path = folder.scheme() == QStringLiteral("content") ? folder.toString() : folder.toLocalFile();
    if (path.isEmpty()) { autoError_ = QStringLiteral("Выберите папку."); emit autoBackupChanged(); return; }
    QString error;
    if (!AutoBackup::Target::grant(path, error)) { autoError_ = error; emit autoBackupChanged(); return; }
    if (path != autoState_.folder) {
        // A new folder has no copies, so the next copy is made in it at once
        autoState_.folder = path;
        autoState_.lastBackup = QDateTime();
        autoState_.lastAttempt = QDateTime();
        autoState_.lastError.clear();
    }
    saveAutoState();
    if (autoState_.enabled) QTimer::singleShot(0, this, [this] { autoBackupCheck(); });
}

void DatabaseProtection::setAutoBackupPassword(const QString& password)
{
    autoError_.clear();
    if (!PortableBackup::validPassword(password)) {
        autoError_ = QStringLiteral("Пароль автокопий должен содержать от 12 до 1024 символов.");
        emit autoBackupChanged();
        return;
    }
    QString error;
    if (!AutoBackup::Secret::write(password.toUtf8(), error)) { autoError_ = error; emit autoBackupChanged(); return; }
    autoPasswordSet_ = true;
    emit autoBackupChanged();
}

void DatabaseProtection::autoBackupCheck()
{
    if (!autoSupported_ || !admitted_ || !ready_ || busy_ || restartRequired_) return;
    if (!AutoBackup::isDue(autoState_, QDateTime::currentDateTime(), autoPasswordSet_)) return;
    QByteArray secret;
    bool found = false;
    QString readError;
    if (!AutoBackup::Secret::read(secret, found, readError)) {
        finishAutoBackup(PortableBackup::Result{false, readError, {}});
        return;
    }
    if (!found) {
        autoPasswordSet_ = false;
        autoError_ = QStringLiteral("Пароль автокопий не найден. Задайте его заново.");
        emit autoBackupChanged();
        return;
    }
    const auto password = QString::fromUtf8(secret);
    secret.fill('\0');
    busy_ = true; emit changed(); emit autoBackupChanged();
    const auto source = access_; const auto root = workspaceRoot_; const auto folder = autoState_.folder;
    const auto name = AutoBackup::fileName(QDateTime::currentDateTime());
    const auto version = QCoreApplication::applicationVersion();
    disconnect(&backupWorker_, nullptr, this, nullptr);
    connect(&backupWorker_, &QFutureWatcher<PortableBackup::Result>::finished, this, [this] {
        busy_ = false;
        finishAutoBackup(backupWorker_.result());
    });
    backupWorker_.setFuture(QtConcurrent::run([source, root, password, folder, name, version] {
        PortableBackup::Result result;
        if (!QDir().mkpath(root)) { result.error = QStringLiteral("Не удалось подготовить папку для копии."); return result; }
        QTemporaryDir staging(root + QStringLiteral("/auto-XXXXXX"));
        if (!staging.isValid()) { result.error = QStringLiteral("Не удалось подготовить копию."); return result; }
        const auto local = staging.filePath(QStringLiteral("copy.vexabackup"));
        result = PortableBackup::exportFile(source, local, root, password, false, version);
        if (!result.ok) return result;
        QString error;
        if (!AutoBackup::Target::write(folder, local, name, error)) {
            result.ok = false;
            result.error = error;
            return result;
        }
        // Only copies made by this feature are removed, and failing to remove one does not fail the copy
        QString listError;
        const auto copies = AutoBackup::Target::list(folder, listError);
        for (const auto& old : AutoBackup::expired(copies.keys(), AutoBackup::KeepCopies)) {
            QString removeError;
            AutoBackup::Target::remove(copies.value(old), removeError);
        }
        return result;
    }));
}

void DatabaseProtection::finishAutoBackup(const PortableBackup::Result& result)
{
    const auto now = QDateTime::currentDateTime();
    autoState_.lastAttempt = now;
    if (result.ok) {
        autoState_.lastBackup = now;
        autoState_.lastError.clear();
    } else {
        // A failed attempt is retried after an hour; the message stays visible in settings
        autoState_.lastError = result.error;
    }
    saveAutoState();
    emit changed();
}
