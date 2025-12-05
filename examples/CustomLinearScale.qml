// SPDX-FileCopyrightText: Copyright (c) 2024 Refeyn Ltd and other QuickGraphLib contributors
// SPDX-License-Identifier: MIT

import QtQuick
import QuickGraphLib as QuickGraphLib
import QuickGraphLib.GraphItems as QGLGraphItems
import QuickGraphLib.PreFabs as QGLPreFabs

/*!
    \qmltype CustomLinearScale
    \brief Example showing custom tick formatting for large numbers with binned image data
*/

QGLPreFabs.XYAxes {
    id: root

    property int bins: 256
    property real maxValue: 100000000  // 100M
    property real binToValue: maxValue / bins  // Each bin = ~390,625 units

    // Generate 256x256 sample data
    property var imageData: {
        var data = [];
        for (var y = 0; y < bins; y++) {
            var row = [];
            for (var x = 0; x < bins; x++) {
                // Example: radial gradient pattern from center
                var dx = x - bins / 2;
                var dy = y - bins / 2;
                var distance = Math.sqrt(dx * dx + dy * dy);
                var value = Math.cos(distance / 20) * Math.sin(x / 30) * Math.cos(y / 30);
                row.push(value);
            }
            data.push(row);
        }
        return data;
    }

    // Set the view rect to match the bins
    viewRect: Qt.rect(0, 0, bins, bins)

    // Ticks positioned in bin coordinates (0-256 scale)
    // But will be displayed as 0, 20M, 40M, 60M, 80M, 100M
    xAxis.ticks: QuickGraphLib.Helpers.linspace(0, bins, 6)
    yAxis.ticks: QuickGraphLib.Helpers.linspace(0, bins, 6)

    grid.xTicks: xAxis.ticks
    grid.yTicks: yAxis.ticks

    // Custom tick formatter - converts bin position to millions
    xAxis.tickDelegate: QuickGraphLib.TickLabel {
        color: root.xAxis.tickLabelColor
        decimalPoints: 0
        direction: root.xAxis.direction
        font: root.xAxis.tickLabelFont

        text: {
            // Convert bin number to actual value (0-100M)
            var actualValue = value * root.binToValue;
            if (actualValue === 0) {
                return "0";
            } else {
                return (actualValue / 1000000).toFixed(0) + "M";
            }
        }
    }

    yAxis.tickDelegate: QuickGraphLib.TickLabel {
        color: root.yAxis.tickLabelColor
        decimalPoints: 0
        direction: root.yAxis.direction
        font: root.yAxis.tickLabelFont

        text: {
            // Convert bin number to actual value (0-100M)
            var actualValue = value * root.binToValue;
            if (actualValue === 0) {
                return "0";
            } else {
                return (actualValue / 1000000).toFixed(0) + "M";
            }
        }
    }

    // Add the ColorMesh to display the 256x256 image
    QGLGraphItems.ColorMesh {
        dataTransform: root.dataTransform
        source: root.imageData
        colormap: QuickGraphLib.ColorMaps.Viridis
        extents: Qt.rect(0, bins, bins, -bins)
    }
}
