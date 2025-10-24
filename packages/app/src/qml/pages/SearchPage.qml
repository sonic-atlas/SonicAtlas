import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle {
        color: themeManager.colorBackground
    }

    signal trackSelected(int index)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Text {
            text: "Local Files"
            font.pixelSize: 24
            font.bold: true
            color: themeManager.colorText
        }

        // File List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            model: audioFileManager.getAudioFiles()

            delegate: Rectangle {
                width: parent.width
                height: 60
                color: themeManager.colorBackground
                border.color: themeManager.colorDominant
                border.width: 1
                radius: 8

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.trackSelected(index)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "♪"
                            color: themeManager.colorDominant
                            font.pixelSize: 20
                        }

                        Text {
                            text: modelData
                            color: themeManager.colorText
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "▶"
                            color: themeManager.colorDominant
                            font.pixelSize: 16
                        }
                    }

                    onEntered: parent.color = Qt.darker(themeManager.colorBackground, 1.1)
                    onExited: parent.color = themeManager.colorBackground
                }
            }
        }
    }
}
