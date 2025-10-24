import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1200
    height: 800
    visible: true
    title: "Sonic Atlas"

    color: themeManager.colorBackground

    PlayerPage {
        id: playerPage
        visible: false
    }

    SearchPage {
        id: searchPage
        visible: false
        onTrackSelected: (index) => playerPage.playTrack(index)
    }


    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: playerPage
    }

    // Footer navigation
    footer: Rectangle {
        height: 60
        color: themeManager.colorBackground
        border.color: themeManager.colorDominant
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Button {
                text: "Player"
                onClicked: stackView.replace(playerPage)
            }

            Button {
                text: "Files"
                onClicked: stackView.replace(searchPage)
            }

            Item { Layout.fillWidth: true }
        }
    }
}
