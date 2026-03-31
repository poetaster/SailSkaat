import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.WebView 1.0
import Sailfish.WebEngine 1.0

Page {
    id: page

    // The effective value will be restricted by ApplicationWindow.allowedOrientations
    allowedOrientations: Orientation.All
    SilicaFlickable {
        anchors.fill: parent
        /*
        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("About.qml"))

            }
            MenuItem {
                text: qsTr("Back")
                onClicked:
                    if (webview.canGoBack)
                        webview.goBack()

            }
            MenuItem {
                text: qsTr("Player")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("PlayerPage.qml"))
            }
            MenuItem {
                text: qsTr("Download")
                onClicked: {
                    notification.notify("Download starting...")
                    py.download_url(webview.url.toString(),musicPath)
                }
            }
        }
        PushUpMenu {
            MenuItem {
                text: qsTr("Forward")
                onClicked:
                    if (webview.canGoForward)
                        webview.goForward()
            }
        }
        */
        WebView {
            id: webview
            anchors.fill: parent
            /* This will probably be required from 4.4 on. */
            Component.onCompleted: {
                WebEngineSettings.setPreference("security.disable_cors_checks", true, WebEngineSettings.BoolPref)
                WebEngineSettings.setPreference("security.fileuri.strict_origin_policy", false, WebEngineSettings.BoolPref)
            }

            //url: Qt.resolvedUrl("https://www.poetaster.de/skaat/index.html")
            url: Qt.resolvedUrl("../html/index.html")

            onViewInitialized: {
                //webview.loadFrameScript(Qt.resolvedUrl("../html/framescript.js"));
                //webview.addMessageListener("webview:action");
                //webview.runJavaScript("return latlon('" + lat + "','" + lon + "')");
            }
            on_PageOrientationChanged: {
                /*if ( data.topic != lon ) {
                        webview.runJavaScript("return latlon('" + lat + "','" + lon + "')");
                }*/

            }

            onRecvAsyncMessage: {
                //popup.notify(message)
                //webview.runJavaScript("return latlon('" + lat + "','" + lon + "')");
                /*
                switch (message) {
                case "embed:contentOrientationChanged":
                    break
                case "webview:action":
                    if ( data.topic != lon ) {
                        webview.runJavaScript("return latlon('" + lat + "','" + lon + "')");
                        if (debug) console.debug(data.topic)
                        if (debug) console.debug(data.also)
                        if (debug) console.debug(data.src)
                    }
                    break
                }
                */
            }
        }
    }
}
