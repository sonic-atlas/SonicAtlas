import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle {
        color: themeManager.colorBackground
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Cover Art (Placeholder)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 300
            height: 300
            color: themeManager.colorDominant
            radius: 12

            Text {
                anchors.centerIn: parent
                text: "🎵"
                font.pixelSize: 120
                color: themeManager.colorText
            }
        }

        // Track Info
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: currentTrackTitle
                font.pixelSize: 28
                font.bold: true
                color: themeManager.colorText
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "Local File"
                font.pixelSize: 16
                color: themeManager.colorTextSecondary
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }

        // Player Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "⏮"
                font.pixelSize: 24
                onClicked: previousTrack()
            }

            Button {
                text: audioPlayer.playing ? "⏸" : "▶"
                font.pixelSize: 24
                highlighted: true
                onClicked: audioPlayer.playing ? audioPlayer.pause() : audioPlayer.resume()
            }

            Button {
                text: "⏭"
                font.pixelSize: 24
                onClicked: nextTrack()
            }
        }

        // Progress Bar
        Slider {
            Layout.fillWidth: true
            from: 0
            to: audioPlayer.duration > 0 ? audioPlayer.duration : 100
            value: audioPlayer.position
            onMoved: audioPlayer.setPosition(value)
        }

        // Time Display
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: formatTime(audioPlayer.position)
                color: themeManager.colorTextSecondary
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            Text {
                text: formatTime(audioPlayer.duration)
                color: themeManager.colorTextSecondary
                font.pixelSize: 12
            }
        }

        Item { Layout.fillHeight: true }
    }

    property string currentTrackTitle: "No track"
    property int currentTrackIndex: 0

    function formatTime(milliseconds) {
        let total = Math.floor(milliseconds / 1000)
        let mins = Math.floor(total / 60)
        let secs = total % 60
        return (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    function playTrack(index) {
        currentTrackIndex = index
        let filePath = audioFileManager.getFilePath(index)
        if (filePath) {
            let files = audioFileManager.getAudioFiles()
            currentTrackTitle = files[index]
            audioPlayer.play("file://" + filePath)
        }
    }

    function nextTrack() {
        let files = audioFileManager.getAudioFiles()
        if (currentTrackIndex < files.length - 1) {
            playTrack(currentTrackIndex + 1)
        }
    }

    function previousTrack() {
        if (currentTrackIndex > 0) {
            playTrack(currentTrackIndex - 1)
        }
    }
}
