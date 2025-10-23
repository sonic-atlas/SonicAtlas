import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 80
    color: themeManager.colorBackground
    border.width: 1
    border.color: Qt.darker(themeManager.colorBackground, 1.1)
    radius: 8

    required property string title
    required property string artist
    required property string album
    required property string coverUrl

    signal clicked()

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
        hoverEnabled: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Image {
                width: 60
                height: 60
                source: root.coverUrl
                fillMode: Image.PreserveAspectCrop
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.title
                    color: themeManager.colorText
                    font.bold: true
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                Text {
                    text: root.artist + " • " + root.album
                    color: themeManager.colorTextSecondary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "▶"
                color: themeManager.colorDominant
                font.pixelSize: 20
            }
        }

        onEntered: root.color = Qt.darker(themeManager.colorBackground, 1.05)
        onExited: root.color = themeManager.colorBackground
    }
}
