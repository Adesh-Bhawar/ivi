/*
 * Copyright (C) 2016 The Qt Company Ltd.
 * Copyright (C) 2016, 2017 Mentor Graphics Development (Deutschland) GmbH
 * Copyright (c) 2017, 2018, 2019 TOYOTA MOTOR CORPORATION
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2

Item {
    id: root

    // Orientation helper
    property bool isLandscape: Screen.width > Screen.height

    // Icon width per cell — in landscape shrink to fit the shorter bar
    property int iconSize: isLandscape ? 110 : 160

    ListModel {
        id: applicationModel
        ListElement {
            appid: 'launcher'
            name: 'launcher'
            application: 'launcher@0.1'
        }
        ListElement {
            appid: 'mediaplayer'
            name: 'MediaPlayer'
            application: 'mediaplayer@0.1'
        }
        ListElement {
            appid: 'hvac'
            name: 'HVAC'
            application: 'hvac@0.1'
        }
        ListElement {
            appid: 'navigation'
            name: 'Navigation'
            application: 'navigation@0.1'
        }
    }

    property int pid: -1

    Flickable {
        id: flickable
        anchors.fill: parent
        clip: true

        // Scroll horizontally in landscape, vertically in portrait
        flickableDirection: root.isLandscape
                            ? Flickable.HorizontalFlick
                            : Flickable.VerticalFlick

        // Content size drives scrollability
        contentWidth: root.isLandscape
                      ? applicationModel.count * root.iconSize
                      : width
        contentHeight: root.isLandscape
                       ? height
                       : applicationModel.count * root.iconSize

        RowLayout {
            id: iconRow
            // Always lay icons out horizontally; in portrait they just stack
            // wider than the bar so portrait still fills the row correctly
            width: root.isLandscape
                   ? applicationModel.count * root.iconSize
                   : flickable.width
            height: flickable.height
            spacing: 0

            Repeater {
                model: applicationModel
                delegate: ShortcutIcon {
                    Layout.preferredWidth: root.isLandscape
                                           ? root.iconSize
                                           : flickable.width / applicationModel.count
                    Layout.preferredHeight: flickable.height
                    name: model.name
                    active: model.name === launcher.current
                    onClicked: {
                        console.log("Activating: " + model.appid)
                        homescreenHandler.tapShortcut(model.appid)
                    }
                }
            }
        }
    }
}
