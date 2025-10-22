#pragma once

#include <QObject>
#include <QStringList>

struct AudioFile
{
    QString path;
    QString filename;
    QString displayName;
};

class AudioFileManager : public QObject
{
    Q_OBJECT

public:
    explicit AudioFileManager(QObject *parent = nullptr);

    Q_INVOKABLE void loadFilesFromDirectory(const QString &dirPath);
    Q_INVOKABLE QStringList getAudioFiles() const;
    Q_INVOKABLE QString getFilePath(int index) const;

    QList<AudioFile> files() const { return m_files; }

signals:
    void filesLoaded(const QStringList &files);
    void error(const QString &errorMessage);

private:
    QList<AudioFile> m_files;
    QString m_currentDirectory;

    bool isAudioFile(const QString &filename) const;
};
