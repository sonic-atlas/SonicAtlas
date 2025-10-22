#include "AudioFileManager.h"
#include <QDebug>
#include <QDir>
#include <QFileInfo>

AudioFileManager::AudioFileManager(QObject *parent)
    : QObject(parent)
{}

bool AudioFileManager::isAudioFile(const QString &filename) const
{
    QStringList audioExtensions = {"mp3", "flac", "wav", "m4a", "aac", "ogg", "opus"};
    QString ext = QFileInfo(filename).suffix().toLower();
    return audioExtensions.contains(ext);
}

void AudioFileManager::loadFilesFromDirectory(const QString &dirPath)
{
    m_files.clear();
    m_currentDirectory = dirPath;

    QDir dir(dirPath);
    if (!dir.exists()) {
        emit error("Directory does not exist: " + dirPath);
        return;
    }

    QStringList audioFiles;
    for (const QString &filename : dir.entryList(QDir::Files)) {
        if (isAudioFile(filename)) {
            AudioFile file;
            file.path = dir.absoluteFilePath(filename);
            file.filename = filename;
            file.displayName = QFileInfo(filename).baseName();

            m_files.append(file);
            audioFiles.append(file.displayName);
        }
    }

    if (audioFiles.isEmpty()) {
        emit error("No audio files found in: " + dirPath);
    }

    emit filesLoaded(audioFiles);
}

QStringList AudioFileManager::getAudioFiles() const
{
    QStringList names;
    for (const AudioFile &file : m_files) {
        names.append(file.displayName);
    }
    return names;
}

QString AudioFileManager::getFilePath(int index) const
{
    if (index >= 0 && index < m_files.size()) {
        return m_files.at(index).path;
    }
    return "";
}
