import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    header: BackgroundHeader {
        Label {
            text: qsTr("About")
            anchors.left: parent.left
            anchors.leftMargin: Theme.paddingLarge
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: Math.max(page.height, aboutCol.height + 2 * Theme.paddingLarge)

        Column {
            id: aboutCol
            x: Theme.horizontalPageMargin
            y: Theme.paddingLarge
            width: page.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge

            Label {
                text: "SailSkaat"
                font.pixelSize: Theme.fontSizeExtraLarge
            }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("A game of Skat for Sailfish OS. You sit against two bots, bid the auction, declare the game and play the tricks.")
            }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("The Skat rules engine is from the skaat project by Markus Kisch (MIT). Card components adapted from the sailfish-cards project (GPLv3).")
            }
            Button {
                text: qsTr("OK")
                onClicked: pageStack.pop()
            }
        }
    }
}
