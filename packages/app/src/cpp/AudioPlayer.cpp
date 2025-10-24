#include "AudioPlayer.h"

AudioPlayer::AudioPlayer(QObject *parent)
    : QObject(parent)
    , m_player(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
{
    m_player->setAudioOutput(m_audioOutput);

    connect(m_player, &QMediaPlayer::playbackStateChanged, this, &AudioPlayer::playingChanged);
    connect(m_player, &QMediaPlayer::positionChanged, this, &AudioPlayer::positionChanged);
    connect(m_player, &QMediaPlayer::durationChanged, this, &AudioPlayer::durationChanged);
}

void AudioPlayer::play(const QString &url)
{
    m_player->setSource(QUrl(url));
    m_player->play();
}

void AudioPlayer::pause()
{
    m_player->pause();
}

void AudioPlayer::resume()
{
    m_player->play();
}

void AudioPlayer::stop()
{
    m_player->stop();
}

bool AudioPlayer::isPlaying() const
{
    return m_player->playbackState() == QMediaPlayer::PlayingState;
}

qint64 AudioPlayer::position() const
{
    return m_player->position();
}

qint64 AudioPlayer::duration() const
{
    return m_player->duration();
}

void AudioPlayer::setPosition(qint64 pos)
{
    m_player->setPosition(pos);
}
