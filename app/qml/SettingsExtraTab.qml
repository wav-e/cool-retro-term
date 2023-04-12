/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/
import QtQuick 2.2
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1

import "Components"

ColumnLayout {


    GroupBox {
        title: qsTr("Blur")
        Layout.fillWidth: true



        GridLayout {
            anchors.fill: parent
            columns: 4


            CheckableSlider {
                Layout.columnSpan: 4
                name: qsTr("Blur blend")
                onNewValue: appSettings.blur = newValue
                value: appSettings.blur
            }


            Label {
                text: qsTr("Directions")
            }
            Slider {
                Layout.fillWidth: true
                Layout.columnSpan: 2

                stepSize: 1.0
                from: 1.0
                to: 64.0

                value: appSettings.blurDirections
                onValueChanged: appSettings.blurDirections = value
                }
            SizedLabel {
                text: appSettings.blurDirections
            }


            Label {
                text: qsTr("Radius")
            }
            Slider {
                Layout.fillWidth: true
                Layout.columnSpan: 2

                stepSize: 0.1
                from: 0.1
                to: 32.0

                value: appSettings.blurRadius
                onValueChanged: appSettings.blurRadius = value
                }
            SizedLabel {
                text: Math.round(appSettings.blurRadius*100)/100
            }


            Label {
                text: qsTr("Quality")
            }
            Slider {
                Layout.fillWidth: true
                Layout.columnSpan: 2

                stepSize: 1.0
                from: 1.0
                to: 12.0

                value: appSettings.blurQuality
                onValueChanged: appSettings.blurQuality = value
                }
            SizedLabel {
                text: appSettings.blurQuality
            }
        }
    }


    GroupBox {
        title: qsTr("Effects")
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent

            CheckableSlider {
                name: qsTr("Raster intensity")
                onNewValue: appSettings.rasterization_intensivity = newValue
                value: appSettings.rasterization_intensivity
            }
            CheckableSlider {
                name: qsTr("Grid")
                onNewValue: appSettings.grid = newValue
                value: appSettings.grid
            }
            ComboBox {
                editable: true
                model: ListModel {
                    id: model
                    ListElement { text: "Linux" }
                    ListElement { text: "macos" }
                    ListElement { text: "Ubuntu" }
                }
                onAccepted: {
                    if (find(editText) === -1){
                        model.append({text: editText})
                    }
                    
                }
                onCurrentIndexChanged: appSettings.colorSchemeStr = model.get(currentIndex).text
            }

        }
    }
}
