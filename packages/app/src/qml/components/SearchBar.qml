import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 56
    color: themeManager.colorBackground
    radius: 8
    border.width: 2
    border.color: themeManager.colorDominant

    Behavior on border.color {
        ColorAnimation { duration: 300 }
    }

    signal search(string query)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        TextInput {
            id: searchInput
            Layout.fillWidth: true
            color: themeManager.colorText
            font.pixelSize: 16
            selectionColor: themeManager.colorDominant

            Text {
                text: "Search tracks, artists..."
                color: themeManager.colorTextSecondary
                font.pixelSize: 16
                visible: !parent.text
            }

            Keys.onReturnPressed: root.search(text)
        }

        Button {
            text: "🔍"
            onClicked: root.search(searchInput.text)
        }
    }
}
