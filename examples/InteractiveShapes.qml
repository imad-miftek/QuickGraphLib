// SPDX-FileCopyrightText: Copyright (c) 2024 Refeyn Ltd and other QuickGraphLib contributors
// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes as QQS
import QuickGraphLib as QuickGraphLib
import QuickGraphLib.GraphItems as QGLGraphItems
import QuickGraphLib.PreFabs as QGLPreFabs

QGLPreFabs.XYAxes {
    id: axes

    title: "Interactive Shapes"
    viewRect: Qt.rect(-5, -5, 10, 10)
    xLabel: "X Position"
    yLabel: "Y Position"

    // Model to hold all shapes (rectangles and ellipses)
    ListModel {
        id: shapesModel
    }

    // Helper function to get selected shape index
    function getSelectedIndex() {
        for (let i = 0; i < shapesModel.count; i++) {
            if (shapesModel.get(i).selected) {
                return i
            }
        }
        return -1
    }

    // Interactive Rectangle Component
    Component {
        id: rectangleComponent

        Item {
            id: interactiveRect

            property int index: 0
            property real dataX: 0
            property real dataY: 0
            property real dataWidth: 2
            property real dataHeight: 2
            property real rotation: 0
            property bool selected: false

            property rect dataRect: Qt.rect(dataX, dataY, dataWidth, dataHeight)

            // Sync changes back to model
            onDataRectChanged: {
                shapesModel.setProperty(index, "dataX", dataRect.x)
                shapesModel.setProperty(index, "dataY", dataRect.y)
                shapesModel.setProperty(index, "dataWidth", dataRect.width)
                shapesModel.setProperty(index, "dataHeight", dataRect.height)
            }
            onRotationChanged: {
                shapesModel.setProperty(index, "rotation", rotation)
            }
            onSelectedChanged: {
                // Deselect all other shapes
                if (selected) {
                    for (let i = 0; i < shapesModel.count; i++) {
                        if (i !== index) {
                            shapesModel.setProperty(i, "selected", false)
                        }
                    }
                }
                shapesModel.setProperty(index, "selected", selected)
            }

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
                color: "transparent"
                border.color: "black"
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
                // Force binding update by explicitly depending on rectContainer position and rotation
                property point rotatedCorner: {
                    // Explicitly reference rectContainer.x, y, and rotation to force binding updates
                    let _ = rectContainer.x + rectContainer.y + interactiveRect.rotation;
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
            width: 8
            height: 8
            radius: 4
            color: rotationMouseArea.containsMouse || rotationMouseArea.pressed ? "#ffcc00" : "yellow"
            border.color: "black"
            border.width: 1
            z: 100

            property real handleDistance: 30
            // Get top-center in interactiveRect coordinates
            // Force binding update by explicitly depending on rectContainer position and rotation
            property point topCenter: {
                let _ = rectContainer.x + rectContainer.y + interactiveRect.rotation;
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
            width: 1
            height: rotationHandle.handleDistance - rotationHandle.radius
            color: "black"
            antialiasing: true
            z: 99

            // Force binding update by explicitly depending on rectContainer position and rotation
            property point topCenter: {
                let _ = rectContainer.x + rectContainer.y + interactiveRect.rotation;
                return rectContainer.mapToItem(interactiveRect, rectContainer.width / 2, 0);
            }

            x: topCenter.x - width / 2
            y: topCenter.y
            rotation: interactiveRect.rotation - 180
            transformOrigin: Item.Top
        }

        }
    }

    // Interactive Ellipse Component (similar to rectangle but with elliptical shape)
    Component {
        id: ellipseComponent

        Item {
            id: interactiveEllipse

            property int index: 0
            property real dataX: 0
            property real dataY: 0
            property real dataWidth: 2
            property real dataHeight: 2
            property real rotation: 0
            property bool selected: false

            property rect dataRect: Qt.rect(dataX, dataY, dataWidth, dataHeight)

            // Sync changes back to model
            onDataRectChanged: {
                shapesModel.setProperty(index, "dataX", dataRect.x)
                shapesModel.setProperty(index, "dataY", dataRect.y)
                shapesModel.setProperty(index, "dataWidth", dataRect.width)
                shapesModel.setProperty(index, "dataHeight", dataRect.height)
            }
            onRotationChanged: {
                shapesModel.setProperty(index, "rotation", rotation)
            }
            onSelectedChanged: {
                // Deselect all other shapes
                if (selected) {
                    for (let i = 0; i < shapesModel.count; i++) {
                        if (i !== index) {
                            shapesModel.setProperty(i, "selected", false)
                        }
                    }
                }
                shapesModel.setProperty(index, "selected", selected)
            }

            // Helper function to get rotated corner position in global coordinates
            function getRotatedCorner(localX, localY) {
                return ellipseContainer.mapToItem(null, localX, localY);
            }

            // Ellipse shape (rotatable container)
            Item {
                id: ellipseContainer
                property point topLeft: axes.dataTransform.map(Qt.point(interactiveEllipse.dataRect.x, interactiveEllipse.dataRect.y + interactiveEllipse.dataRect.height))
                property point bottomRight: axes.dataTransform.map(Qt.point(interactiveEllipse.dataRect.x + interactiveEllipse.dataRect.width, interactiveEllipse.dataRect.y))
                property point center: Qt.point((topLeft.x + bottomRight.x) / 2, (topLeft.y + bottomRight.y) / 2)

                x: center.x - width / 2
                y: center.y - height / 2
                width: Math.abs(bottomRight.x - topLeft.x)
                height: Math.abs(bottomRight.y - topLeft.y)
                rotation: interactiveEllipse.rotation
                transformOrigin: Item.Center

                // Ellipse using QtQuick.Shapes
                QQS.Shape {
                    anchors.fill: parent

                    QQS.ShapePath {
                        strokeColor: "black"
                        strokeWidth: interactiveEllipse.selected ? 2 : 1.5
                        fillColor: "transparent"
                        capStyle: QQS.ShapePath.RoundCap

                        // Draw ellipse using two 180-degree arcs
                        PathMove {
                            x: ellipseContainer.width / 2 + ellipseContainer.width / 2
                            y: ellipseContainer.height / 2
                        }
                        PathArc {
                            x: ellipseContainer.width / 2 - ellipseContainer.width / 2
                            y: ellipseContainer.height / 2
                            radiusX: ellipseContainer.width / 2
                            radiusY: ellipseContainer.height / 2
                            useLargeArc: false
                        }
                        PathArc {
                            x: ellipseContainer.width / 2 + ellipseContainer.width / 2
                            y: ellipseContainer.height / 2
                            radiusX: ellipseContainer.width / 2
                            radiusY: ellipseContainer.height / 2
                            useLargeArc: false
                        }
                    }
                }

                // Mouse area INSIDE the rotated container
                MouseArea {
                    id: ellipseMouseArea
                    anchors.fill: parent
                    property point startDragDataPoint: Qt.point(0, 0)
                    property rect startDragRect: Qt.rect(0, 0, 0, 0)

                    cursorShape: interactiveEllipse.selected ? Qt.SizeAllCursor : Qt.PointingHandCursor
                    hoverEnabled: true

                    onPressed: mouse => {
                        interactiveEllipse.selected = true;
                        let screenPos = mapToItem(null, mouse.x, mouse.y);
                        startDragDataPoint = axes.dataTransform.inverted().map(screenPos);
                        startDragRect = interactiveEllipse.dataRect;
                    }

                    onPositionChanged: mouse => {
                        if (pressed && interactiveEllipse.selected) {
                            let screenPos = mapToItem(null, mouse.x, mouse.y);
                            let currentDataPoint = axes.dataTransform.inverted().map(screenPos);
                            let dx = currentDataPoint.x - startDragDataPoint.x;
                            let dy = currentDataPoint.y - startDragDataPoint.y;

                            interactiveEllipse.dataRect = Qt.rect(startDragRect.x + dx, startDragRect.y + dy, startDragRect.width, startDragRect.height);
                        }
                    }
                }
            }

            // Resize handles (same as rectangle)
            Repeater {
                model: interactiveEllipse.selected ? 4 : 0

                Rectangle {
                    required property int index
                    width: 8
                    height: 8
                    radius: 0
                    color: handleMouseArea.containsMouse || handleMouseArea.pressed ? "#ffcc00" : "yellow"
                    border.color: "black"
                    border.width: 1
                    z: 100

                    property point localCorner: {
                        if (index === 0)
                            return Qt.point(0, 0);
                        if (index === 1)
                            return Qt.point(ellipseContainer.width, 0);
                        if (index === 2)
                            return Qt.point(ellipseContainer.width, ellipseContainer.height);
                        return Qt.point(0, ellipseContainer.height);
                    }

                    property point rotatedCorner: {
                        let _ = ellipseContainer.x + ellipseContainer.y + interactiveEllipse.rotation;
                        return ellipseContainer.mapToItem(interactiveEllipse, localCorner.x, localCorner.y);
                    }

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
                            startDragRect = interactiveEllipse.dataRect;
                            startRotation = interactiveEllipse.rotation;

                            if (index === 0) {
                                startCornerData = Qt.point(startDragRect.x, startDragRect.y + startDragRect.height);
                            } else if (index === 1) {
                                startCornerData = Qt.point(startDragRect.x + startDragRect.width, startDragRect.y + startDragRect.height);
                            } else if (index === 2) {
                                startCornerData = Qt.point(startDragRect.x + startDragRect.width, startDragRect.y);
                            } else {
                                startCornerData = Qt.point(startDragRect.x, startDragRect.y);
                            }

                            let posInInteractiveEllipse = mapToItem(interactiveEllipse, mouse.x, mouse.y);
                            let posInAxes = interactiveEllipse.mapToItem(axes, posInInteractiveEllipse.x, posInInteractiveEllipse.y);
                            startDragDataPoint = axes.dataTransform.inverted().map(posInAxes);
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                let posInInteractiveEllipse = mapToItem(interactiveEllipse, mouse.x, mouse.y);
                                let currentPoint = interactiveEllipse.mapToItem(axes, posInInteractiveEllipse.x, posInInteractiveEllipse.y);
                                let currentDataPoint = axes.dataTransform.inverted().map(currentPoint);

                                let deltaX = currentDataPoint.x - startDragDataPoint.x;
                                let deltaY = currentDataPoint.y - startDragDataPoint.y;

                                let newCornerX = startCornerData.x + deltaX;
                                let newCornerY = startCornerData.y + deltaY;

                                let newRect = Qt.rect(0, 0, 0, 0);

                                if (index === 0) {
                                    let anchorX = startDragRect.x + startDragRect.width;
                                    let anchorY = startDragRect.y;
                                    newRect.x = Math.min(newCornerX, anchorX);
                                    newRect.y = Math.min(newCornerY, anchorY);
                                    newRect.width = Math.abs(anchorX - newCornerX);
                                    newRect.height = Math.abs(newCornerY - anchorY);
                                } else if (index === 1) {
                                    let anchorX = startDragRect.x;
                                    let anchorY = startDragRect.y;
                                    newRect.x = Math.min(newCornerX, anchorX);
                                    newRect.y = Math.min(newCornerY, anchorY);
                                    newRect.width = Math.abs(newCornerX - anchorX);
                                    newRect.height = Math.abs(newCornerY - anchorY);
                                } else if (index === 2) {
                                    let anchorX = startDragRect.x;
                                    let anchorY = startDragRect.y + startDragRect.height;
                                    newRect.x = Math.min(newCornerX, anchorX);
                                    newRect.y = Math.min(newCornerY, anchorY);
                                    newRect.width = Math.abs(newCornerX - anchorX);
                                    newRect.height = Math.abs(anchorY - newCornerY);
                                } else {
                                    let anchorX = startDragRect.x + startDragRect.width;
                                    let anchorY = startDragRect.y + startDragRect.height;
                                    newRect.x = Math.min(newCornerX, anchorX);
                                    newRect.y = Math.min(newCornerY, anchorY);
                                    newRect.width = Math.abs(anchorX - newCornerX);
                                    newRect.height = Math.abs(anchorY - newCornerY);
                                }

                                if (newRect.width > 0.1 && newRect.height > 0.1) {
                                    interactiveEllipse.dataRect = newRect;
                                }
                            }
                        }
                    }
                }
            }

            // Rotation handle
            Rectangle {
                id: ellipseRotationHandle
                visible: interactiveEllipse.selected
                width: 8
                height: 8
                radius: 4
                color: ellipseRotationMouseArea.containsMouse || ellipseRotationMouseArea.pressed ? "#ffcc00" : "yellow"
                border.color: "black"
                border.width: 1
                z: 100

                property real handleDistance: 30
                property point topCenter: {
                    let _ = ellipseContainer.x + ellipseContainer.y + interactiveEllipse.rotation;
                    return ellipseContainer.mapToItem(interactiveEllipse, ellipseContainer.width / 2, 0);
                }
                property real perpendicularAngle: interactiveEllipse.rotation - 90
                property real angleRad: perpendicularAngle * Math.PI / 180

                x: topCenter.x + handleDistance * Math.cos(angleRad) - width / 2
                y: topCenter.y + handleDistance * Math.sin(angleRad) - height / 2

                MouseArea {
                    id: ellipseRotationMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    hoverEnabled: true

                    property point startDragPoint: Qt.point(0, 0)
                    property real startRotation: 0

                    onPressed: mouse => {
                        startDragPoint = mapToItem(interactiveEllipse, mouse.x, mouse.y);
                        startRotation = interactiveEllipse.rotation;
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            let currentPoint = mapToItem(interactiveEllipse, mouse.x, mouse.y);
                            let center = ellipseContainer.mapToItem(interactiveEllipse, ellipseContainer.width / 2, ellipseContainer.height / 2);

                            let dx = currentPoint.x - center.x;
                            let dy = currentPoint.y - center.y;
                            let angle = Math.atan2(dy, dx) * 180 / Math.PI;

                            let startDx = startDragPoint.x - center.x;
                            let startDy = startDragPoint.y - center.y;
                            let startAngle = Math.atan2(startDy, startDx) * 180 / Math.PI;

                            interactiveEllipse.rotation = startRotation + (angle - startAngle);
                        }
                    }
                }
            }

            // Connection line from ellipse to rotation handle
            Rectangle {
                visible: interactiveEllipse.selected
                width: 1
                height: ellipseRotationHandle.handleDistance - ellipseRotationHandle.radius
                color: "black"
                antialiasing: true
                z: 99

                property point topCenter: {
                    let _ = ellipseContainer.x + ellipseContainer.y + interactiveEllipse.rotation;
                    return ellipseContainer.mapToItem(interactiveEllipse, ellipseContainer.width / 2, 0);
                }

                x: topCenter.x - width / 2
                y: topCenter.y
                rotation: interactiveEllipse.rotation - 180
                transformOrigin: Item.Top
            }
        }
    }

    // Repeater to create shapes from model
    Repeater {
        model: shapesModel
        delegate: Loader {
            required property int index
            required property string shapeType
            required property real dataX
            required property real dataY
            required property real dataWidth
            required property real dataHeight
            required property real rotation
            required property bool selected

            sourceComponent: shapeType === "ellipse" ? ellipseComponent : rectangleComponent

            onLoaded: {
                item.index = Qt.binding(() => index)
                item.dataX = Qt.binding(() => dataX)
                item.dataY = Qt.binding(() => dataY)
                item.dataWidth = Qt.binding(() => dataWidth)
                item.dataHeight = Qt.binding(() => dataHeight)
                item.rotation = Qt.binding(() => rotation)
                item.selected = Qt.binding(() => selected)
            }
        }
    }

    // Context menu MouseArea
    MouseArea {
        id: contextMenuArea
        anchors.fill: parent
        z: -2
        acceptedButtons: Qt.RightButton | Qt.LeftButton

        property point lastClickPos: Qt.point(0, 0)

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // Deselect all shapes when clicking on background
                for (let i = 0; i < shapesModel.count; i++) {
                    shapesModel.setProperty(i, "selected", false)
                }
            }
        }

        onPressAndHold: mouse => {
            lastClickPos = Qt.point(mouse.x, mouse.y)
            contextMenu.popup()
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                lastClickPos = Qt.point(mouse.x, mouse.y)
                contextMenu.popup()
            }
        }
    }

    // Context menu
    Menu {
        id: contextMenu

        MenuItem {
            text: "Add Rectangle"
            onTriggered: {
                // Get the mouse position in data coordinates
                let dataPos = axes.dataTransform.inverted().map(contextMenuArea.lastClickPos)

                // Add a new 2x2 rectangle centered at clicked position
                shapesModel.append({
                    "shapeType": "rectangle",
                    "dataX": dataPos.x - 1,
                    "dataY": dataPos.y - 1,
                    "dataWidth": 2,
                    "dataHeight": 2,
                    "rotation": 0,
                    "selected": true
                })

                // Deselect all other shapes
                for (let i = 0; i < shapesModel.count - 1; i++) {
                    shapesModel.setProperty(i, "selected", false)
                }
            }
        }

        MenuItem {
            text: "Add Ellipse"
            onTriggered: {
                // Get the mouse position in data coordinates
                let dataPos = axes.dataTransform.inverted().map(contextMenuArea.lastClickPos)

                // Add a new 2x2 ellipse centered at clicked position
                shapesModel.append({
                    "shapeType": "ellipse",
                    "dataX": dataPos.x - 1,
                    "dataY": dataPos.y - 1,
                    "dataWidth": 2,
                    "dataHeight": 2,
                    "rotation": 0,
                    "selected": true
                })

                // Deselect all other shapes
                for (let i = 0; i < shapesModel.count - 1; i++) {
                    shapesModel.setProperty(i, "selected", false)
                }
            }
        }

        MenuSeparator {
            visible: axes.getSelectedIndex() >= 0
        }

        MenuItem {
            text: "Delete Shape"
            visible: axes.getSelectedIndex() >= 0
            onTriggered: {
                let selectedIndex = axes.getSelectedIndex()
                if (selectedIndex >= 0) {
                    shapesModel.remove(selectedIndex)
                }
            }
        }
    }

    // Instructions
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        text: "• Right-click: Add Rectangle/Ellipse or Delete\n• Click shape to select\n• Drag to move\n• Drag corners to resize\n• Drag circle to rotate\n• Click outside to deselect"
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
