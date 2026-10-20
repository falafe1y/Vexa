#pragma once
#include <QDateTime>
#include <QMap>
#include <QString>
#include <QStringList>

// Automatic copies of the database in the portable .vexabackup format.
// Times are device-local: the 24-hour interval is counted on the device clock, never in UTC.
namespace AutoBackup {
constexpr qint64 IntervalSeconds = 24 * 60 * 60;
constexpr qint64 RetryAfterSeconds = 60 * 60;
constexpr int KeepCopies = 7;

struct State {
    bool enabled = false;
    // A directory on Windows; a document-tree URI on Android
    QString folder;
    // Local time with its UTC offset; invalid until the first copy is made
    QDateTime lastBackup;
    QDateTime lastAttempt;
    QString lastError;
};

// A missing file is an empty state, not an error
bool load(const QString& file, State& state, QString& error);
bool save(const QString& file, const State& state, QString& error);

// Due when a copy has never been made, 24 hours have passed since the last copy, or an hour has passed since a failure
bool isDue(const State& state, const QDateTime& now, bool passwordSet);

// Name of a copy made at `when` (local time), for example vexa-auto-2026-10-20_09-30-00.vexabackup
QString fileName(const QDateTime& when);
bool isAutoName(const QString& name);

// Names to delete so that only the newest `keep` copies remain. Names not made by this feature are never returned.
QStringList expired(QStringList names, int keep);

// Where copies go. Windows writes into a directory; Android writes into a document tree granted by the user.
namespace Target {
// Creates `name` in `folder` with the contents of `localFile`
bool write(const QString& folder, const QString& localFile, const QString& name, QString& error);
// Copies made by this feature in `folder`, name -> identifier for remove()
QMap<QString, QString> list(const QString& folder, QString& error);
bool remove(const QString& identifier, QString& error);
// Keeps access to a folder chosen by the user across restarts (Android); a no-op elsewhere
bool grant(const QString& folder, QString& error);
bool supported();
}

// The password of automatic copies, kept in the system store like the database key
namespace Secret {
bool available(QString& error);
bool read(QByteArray& value, bool& found, QString& error);
bool write(const QByteArray& value, QString& error);
}
}
