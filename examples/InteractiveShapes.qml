// SPDX-FileCopyrightText: Copyright (c) 2024 Refeyn Ltd and other QuickGraphLib contributors
// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes as QQS
import QuickGraphLib as QuickGraphLib
import QuickGraphLib.GraphItems as QGLGraphItems
import QuickGraphLib.PreFabs as QGLPreFabs

QGLPreFabs.XYAxes {
    id: axes

    title: "Interactive Rectangle"
    viewRect: Qt.rect(-5, -5, 10, 10)
    xLabel: "X Position"
    yLabel: "Y Position"

    // Interactive Rectangle Component
    Item {
        id: interactiveRect

        property bool selected: false
        property rect dataRect: Qt.rect(-2, 1, 3, 2)  // x, y, width, height in data coordinates
        property real rotation: 0  // rotation angle in degrees

        // Helper function to get rotated corner position in global coordinates
        function getRotatedCorner(localX, localY) {
            // Map from rectContainer's local coordinates to global coordinates
            // This automatically applies the rotation
            return rectContainer.mapToItem(null, localX, localY);
        }

        // Rectangle shape (rotatable container)
        Item {
            id: rectContainer
            property point topLeft: axes.dataTransform.map(Qt.point(interactiveRect.dataRect.x, interactiveRect.dataRect.y + interactiveRect.dataRect.height))
            property point bottomRight: axes.dataTransform.map(Qt.point(interactiveRect.dataRect.x + interactiveRect.dataRect.width, interactiveRect.dataRect.y))
            property point center: Qt.point((topLeft.x + bottomRight.x) / 2, (topLeft.y + bottomRight.y) / 2)

            x: center.x - width / 2  // Position top-left, not center
            y: center.y - height / 2
            width: Math.abs(bottomRight.x - topLeft.x)
            height: Math.abs(bottomRight.y - topLeft.y)
            rotation: interactiveRect.rotation
            transformOrigin: Item.Center  // Rotate around center

            Rectangle {
                id: visualRect
                anchors.fill: parent
                color: interactiveRect.selected ? "#4400ff00" : "#2200ff00"
                border.color: interactiveRect.selected ? "blue" : "#666666"
                border.width: interactiveRect.selected ? 2 : 1.5
                antialiasing: true
            }

            // Mouse area INSIDE the rotated container
            MouseArea {
                id: mainMouseArea
                anchors.fill: parent
                property point startDragDataPoint: Qt.point(0, 0)
                property rect startDragRect: Qt.rect(0, 0, 0, 0)

                cursorShape: interactiveRect.selected ? Qt.SizeAllCursor : Qt.PointingHandCursor
                hoverEnabled: true

                onPressed: mouse => {
                    interactiveRect.selected = true;
                    // Convert mouse position to screen coordinates, then to data coordinates
                    let screenPos = mapToItem(null, mouse.x, mouse.y);
                    startDragDataPoint = axes.dataTransform.inverted().map(screenPos);
                    startDragRect = interactiveRect.dataRect;
                }

                onPositionChanged: mouse => {
                    if (pressed && interactiveRect.selected) {
                        let screenPos = mapToItem(null, mouse.x, mouse.y);
                        let currentDataPoint = axes.dataTransform.inverted().map(screenPos);
                        let dx = currentDataPoint.x - startDragDataPoint.x;
                        let dy = currentDataPoint.y - startDragDataPoint.y;

                        interactiveRect.dataRect = Qt.rect(startDragRect.x + dx, startDragRect.y + dy, startDragRect.width, startDragRect.height);
                    }
                }
            }
        }

        // Click outside to deselect
        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: mouse => {
                // Check if click is outside the rectangle
                let clickPoint = axes.dataTransform.inverted().map(Qt.point(mouse.x, mouse.y));
                let rectBounds = interactiveRect.dataRect;

                if (clickPoint.x < rectBounds.x || clickPoint.x > rectBounds.x + rectBounds.width || clickPoint.y < rectBounds.y || clickPoint.y > rectBounds.y + rectBounds.height) {
                    interactiveRect.selected = false;
                }
                mouse.accepted = false;
            }
        }

        // Resize handles (only visible when selected)
        Repeater {
            model: interactiveRect.selected ? 4 : 0

            Rectangle {
                required property int index
                width: 8
                height: 8
                radius: 0
                color: handleMouseArea.containsMouse || handleMouseArea.pressed ? "#ffcc00" : "yellow"
                border.color: "black"
                border.width: 1
                z: 100

                // 0=TL, 1=TR, 2=BR, 3=BL - positions in rectContainer's local coordinates
                property point localCorner: {
                    if (index === 0)
                        return Qt.point(0, 0);
                    if (index === 1)
                        return Qt.point(rectContainer.width, 0);
                    if (index === 2)
                        return Qt.point(rectContainer.width, rectContainer.height);
                    return Qt.point(0, rectContainer.height);
                }

                // Map to interactiveRect coordinates (automatically accounts for rotation)
                // Force binding update by explicitly depending on rectContainer position
                property point rotatedCorner: {
                    // Explicitly reference rectContainer.x and y to force binding updates
                    let _ = rectContainer.x + rectContainer.y;
                    return rectContainer.mapToItem(interactiveRect, localCorner.x, localCorner.y);
                }

                // Position in interactiveRect coordinates - center the handle on the vertex
                x: rotatedCorner.x - width / 2
                y: rotatedCorner.y - height / 2

                MouseArea {
                    id: handleMouseArea
                    anchors.fill: parent
                    cursorShape: {
                        if (index === 0 || index === 2)
                            return Qt.SizeFDiagCursor;
                        return Qt.SizeBDiagCursor;
                    }
                    hoverEnabled: true

                    property point startDragDataPoint: Qt.point(0, 0)
                    property rect startDragRect: Qt.rect(0, 0, 0, 0)
                    property real startRotation: 0
                    property point startCornerData: Qt.point(0, 0)

                    onPressed: mouse => {
                        // Store the initial data rectangle
                        startDragRect = interactiveRect.dataRect;
                        startRotation = interactiveRect.rotation;

                        // Store the initial corner position in data space
                        if (index === 0) {
                            startCornerData = Qt.point(startDragRect.x, startDragRect.y + startDragRect.height);
                        } else if (index === 1) {
                            startCornerData = Qt.point(startDragRect.x + startDragRect.width, startDragRect.y + startDragRect.height);
                        } else if (index === 2) {
                            startCornerData = Qt.point(startDragRect.x + startDragRect.width, startDragRect.y);
                        } else {
                            startCornerData = Qt.point(startDragRect.x, startDragRect.y);
                        }

                        // Store the initial mouse position in data coordinates
                        let posInInteractiveRect = mapToItem(interactiveRect, mouse.x, mouse.y);
                        let posInAxes = interactiveRect.mapToItem(axes, posInInteractiveRect.x, posInInteractiveRect.y);
                        startDragDataPoint = axes.dataTransform.inverted().map(posInAxes);
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            // Get current mouse position in data coordinates
                            let posInInteractiveRect = mapToItem(interactiveRect, mouse.x, mouse.y);
                            let currentPoint = interactiveRect.mapToItem(axes, posInInteractiveRect.x, posInInteractiveRect.y);
                            let currentDataPoint = axes.dataTransform.inverted().map(currentPoint);

                            // Calculate the delta from initial click
                            let deltaX = currentDataPoint.x - startDragDataPoint.x;
                            let deltaY = currentDataPoint.y - startDragDataPoint.y;

                            // New corner position = original corner + delta
                            let newCornerX = startCornerData.x + deltaX;
                            let newCornerY = startCornerData.y + deltaY;

                            // Resize with opposite corner as anchor point
                            let newRect = Qt.rect(0, 0, 0, 0);

                            if (index === 0) {
                                // Top-left: opposite is bottom-right
                                let anchorX = startDragRect.x + startDragRect.width;
                                let anchorY = startDragRect.y;
                                newRect.x = Math.min(newCornerX, anchorX);
                                newRect.y = Math.min(newCornerY, anchorY);
                                newRect.width = Math.abs(anchorX - newCornerX);
                                newRect.height = Math.abs(newCornerY - anchorY);
                            } else if (index === 1) {
                                // Top-right: opposite is bottom-left
                                let anchorX = startDragRect.x;
                                let anchorY = startDragRect.y;
                                newRect.x = Math.min(newCornerX, anchorX);
                                newRect.y = Math.min(newCornerY, anchorY);
                                newRect.width = Math.abs(newCornerX - anchorX);
                                newRect.height = Math.abs(newCornerY - anchorY);
                            } else if (index === 2) {
                                // Bottom-right: opposite is top-left
                                let anchorX = startDragRect.x;
                                let anchorY = startDragRect.y + startDragRect.height;
                                newRect.x = Math.min(newCornerX, anchorX);
                                newRect.y = Math.min(newCornerY, anchorY);
                                newRect.width = Math.abs(newCornerX - anchorX);
                                newRect.height = Math.abs(anchorY - newCornerY);
                            } else {
                                // Bottom-left: opposite is top-right
                                let anchorX = startDragRect.x + startDragRect.width;
                                let anchorY = startDragRect.y + startDragRect.height;
                                newRect.x = Math.min(newCornerX, anchorX);
                                newRect.y = Math.min(newCornerY, anchorY);
                                newRect.width = Math.abs(anchorX - newCornerX);
                                newRect.height = Math.abs(anchorY - newCornerY);
                            }

                            // Prevent too-small dimensions
                            if (newRect.width > 0.1 && newRect.height > 0.1) {
                                interactiveRect.dataRect = newRect;
                            }
                        }
                    }
                }
            }
        }

        // Rotation handle (only visible when selected)
        Rectangle {
            id: rotationHandle
            visible: interactiveRect.selected
            width: 12
            height: 12
            radius: 6
            color: rotationMouseArea.containsMouse || rotationMouseArea.pressed ? "orange" : "white"
            border.color: "orange"
            border.width: 2
            z: 100

            property real handleDistance: 30
            // Get top-center in interactiveRect coordinates
            // Force binding update by explicitly depending on rectContainer position
            property point topCenter: {
                let _ = rectContainer.x + rectContainer.y;
                return rectContainer.mapToItem(interactiveRect, rectContainer.width / 2, 0);
            }
            property real perpendicularAngle: interactiveRect.rotation - 90
            property real angleRad: perpendicularAngle * Math.PI / 180

            x: topCenter.x + handleDistance * Math.cos(angleRad) - width / 2
            y: topCenter.y + handleDistance * Math.sin(angleRad) - height / 2

            MouseArea {
                id: rotationMouseArea
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                hoverEnabled: true

                property point startDragPoint: Qt.point(0, 0)
                property real startRotation: 0

                onPressed: mouse => {
                    // Convert to interactiveRect coordinates
                    startDragPoint = mapToItem(interactiveRect, mouse.x, mouse.y);
                    startRotation = interactiveRect.rotation;
                }

                onPositionChanged: mouse => {
                    if (pressed) {
                        // Convert to interactiveRect coordinates
                        let currentPoint = mapToItem(interactiveRect, mouse.x, mouse.y);
                        // Get center in interactiveRect coordinates
                        let center = rectContainer.mapToItem(interactiveRect, rectContainer.width / 2, rectContainer.height / 2);

                        // Calculate angle from center to current point
                        let dx = currentPoint.x - center.x;
                        let dy = currentPoint.y - center.y;
                        let angle = Math.atan2(dy, dx) * 180 / Math.PI;

                        // Calculate angle from center to start point
                        let startDx = startDragPoint.x - center.x;
                        let startDy = startDragPoint.y - center.y;
                        let startAngle = Math.atan2(startDy, startDx) * 180 / Math.PI;

                        // Update rotation
                        interactiveRect.rotation = startRotation + (angle - startAngle);
                    }
                }
            }
        }

        // Connection line from rectangle to rotation handle
        Rectangle {
            visible: interactiveRect.selected
            width: 2
            height: rotationHandle.handleDistance - rotationHandle.radius
            color: "orange"
            z: 99

            // Force binding update by explicitly depending on rectContainer position
            property point topCenter: {
                let _ = rectContainer.x + rectContainer.y;
                return rectContainer.mapToItem(interactiveRect, rectContainer.width / 2, 0);
            }

            x: topCenter.x - width / 2
            y: topCenter.y
            rotation: interactiveRect.rotation - 180
            transformOrigin: Item.Top
        }

        // Selection indicator text
        Text {
            // Force binding update by explicitly depending on rectContainer position
            property point center: {
                let _ = rectContainer.x + rectContainer.y;
                return rectContainer.mapToItem(interactiveRect, rectContainer.width / 2, rectContainer.height / 2);
            }

            visible: interactiveRect.selected
            text: "Selected\n" + "x: " + interactiveRect.dataRect.x.toFixed(2) + "\n" + "y: " + interactiveRect.dataRect.y.toFixed(2) + "\n" + "w: " + interactiveRect.dataRect.width.toFixed(2) + "\n" + "h: " + interactiveRect.dataRect.height.toFixed(2) + "\n" + "rot: " + interactiveRect.rotation.toFixed(1) + "°"
            color: "#0066ff"
            font.pixelSize: 12
            font.bold: true
            x: center.x - width / 2
            y: center.y - height / 2
            horizontalAlignment: Text.AlignHCenter

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "white"
                opacity: 0.8
                radius: 4
                z: -1
            }
        }
    }

    // Instructions
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        text: "• Click rectangle to select\n• Drag to move\n• Drag corners to resize\n• Drag orange handle to rotate\n• Click outside to deselect"
        color: "#333333"
        font.pixelSize: 12

        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            color: "white"
            opacity: 0.9
            radius: 4
            border.color: "#cccccc"
            border.width: 1
            z: -1
        }
    }
}
