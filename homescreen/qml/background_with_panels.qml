import QtQuick 2.13
import QtQuick.Window 2.13
import QtQuick.Layouts 1.15

Window {
    id: background
    width: Screen.width
    height: Screen.height
    flags: Qt.FramelessWindowHint
    visible: true

    Grid {
         rows: 3
         spacing: 0

         Rectangle {
         width: Screen.width
         height: 216
         color: "#33363a"

         Timer {
             id:notificationTimer
             interval: 3000
             running: false
             repeat: true
             onTriggered: notificationItem.visible = false
         }

         Item {
             id: notificationItem
             x: 0
             y: 0
             z: 1
             width: 1280
             height: 100
             opacity: 0.8
             visible: false

             Rectangle {
                 width: parent.width
                 height: parent.height
                 anchors.fill: parent
                 color: "gray"
                 Image {
                     id: notificationIcon
                     width: 70
                     height: 70
                     anchors.left: parent.left
                     anchors.leftMargin: 20
                     anchors.verticalCenter: parent.verticalCenter
                     source: ""
                 }

                 Text {
                     id: notificationtext
                     font.pixelSize: 25
                     anchors.left: notificationIcon.right
                     anchors.leftMargin: 5
                     anchors.verticalCenter: parent.verticalCenter
                     color: "white"
                     text: qsTr("")
                 }
             }
         }

         Connections {
             target: homescreenHandler
             onShowNotification: {
                 notificationIcon.source = icon_path
                 notificationtext.text = text
                 notificationItem.visible = true
                 notificationTimer.restart()
             }
         }

         Image {
             anchors.fill: parent
             source: 'qrc:/images/TopSection_NoText_NoIcons-01.svg'
             //fillMode: Image.PreserveAspectCrop
             fillMode: Image.Stretch

         RowLayout {
             anchors.fill: parent
             spacing: 0
             ShortcutArea {
                 id: shortcutArea
                 Layout.fillWidth: true
                 Layout.fillHeight: true
                 Layout.preferredWidth: 775
             }
             StatusArea {
                 id: statusArea
                 Layout.fillWidth: true
                 Layout.fillHeight: true
                 Layout.preferredWidth: 291
             }
             }
         }

        }

        Rectangle {
             width: Screen.width
             height: Screen.height - (2 * 216)
         Image {
             anchors.fill: parent
             source: 'qrc:/images/AGL_HMI_Blue_Background_NoCar-01.png'
         }

        }

        Rectangle {
         width: Screen.width
         height: 216
         color: "#33363a"

         MediaArea {
         }

         Timer {
             id:informationTimer
             interval: 3000
             running: false
             repeat: true
             onTriggered: {
                 bottomInformation.visible = false
             }
         }

         Item {
             id: bottomInformation
             width: parent.width
             height: 216
             anchors.bottom: parent.bottom
             visible: false
             Text {
                 id: bottomText
                 anchors.centerIn: parent
                 font.pixelSize: 25
                 font.letterSpacing: 5
                 horizontalAlignment: Text.AlignHCenter
                 color: "white"
                 text: ""
                 z:1
             }
         }

         Connections {
             target: homescreenHandler
             onShowInformation: {
                 bottomText.text = info
                 bottomInformation.visible = true
                 informationTimer.restart()
             }
         }

	}
    }
}
