import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Label {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: logo.top
        text: qsTr("SailSkaat")
    }
    Image {
        id: logo
        anchors.centerIn: parent
        anchors.top: label.bottom
        source:Qt.resolvedUrl("harbour-sailskaat.png")
        width:256
        height:256

    }

}
