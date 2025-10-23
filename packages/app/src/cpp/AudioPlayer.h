#pragma once

#include <QAudioOutput>
#include <QMediaPlayer>
#include <QObject>

class AudioPlayer : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool playing READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(qint64 position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)

public:
    explicit AudioPlayer(QObject *parent = nullptr);

    Q_INVOKABLE void play(const QString &url);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();

    bool isPlaying() const;
    qint64 position() const;
    qint64 duration() const;
    void setPosition(qint64 pos);

signals:
    void playingChanged();
    void positionChanged(qint64 position);
    void durationChanged(qint64 duration);
    void error(const QString &errorString);

private:
    QMediaPlayer *m_player;
    QAudioOutput *m_audioOutput;
};
