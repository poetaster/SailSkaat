import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Column {
        anchors.centerIn: parent
        spacing: SiUnits.largeUnit

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 192
            height: 192
            source: Qt.resolvedUrl("harbour-sailskaat.png")
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("SailSkaat")
        }
    }
}
