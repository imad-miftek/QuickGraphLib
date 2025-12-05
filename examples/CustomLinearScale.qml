// SPDX-FileCopyrightText: Copyright (c) 2024 Refeyn Ltd and other QuickGraphLib contributors
// SPDX-License-Identifier: MIT

import QtQuick
import QuickGraphLib as QuickGraphLib
import QuickGraphLib.PreFabs as QGLPreFabs

/*!
    \qmltype CustomLinearScale
    \brief Example showing custom tick formatting for large numbers
*/

QGLPreFabs.XYAxes {
    id: root

    // Set the view rect to 0-100M on both axes (in actual values)
    viewRect: Qt.rect(0, 0, 100000000, 100000000)

    // Manually set ticks from 0 to 100M in steps of 20M
    xAxis.ticks: QuickGraphLib.Helpers.linspace(0, 100000000, 6) // [0, 20M, 40M, 60M, 80M, 100M]
    yAxis.ticks: QuickGraphLib.Helpers.linspace(0, 100000000, 6)

    grid.xTicks: xAxis.ticks
    grid.yTicks: yAxis.ticks

    // Custom tick formatter for millions
    xAxis.tickDelegate: QuickGraphLib.TickLabel {
        color: root.xAxis.tickLabelColor
        decimalPoints: 0
        direction: root.xAxis.direction
        font: root.xAxis.tickLabelFont

        // Override the text to show "M" suffix
        text: {
            if (value === 0) {
                return "0";
            } else {
                return (value / 1000000).toFixed(0) + "M";
            }
        }
    }

    yAxis.tickDelegate: QuickGraphLib.TickLabel {
        color: root.yAxis.tickLabelColor
        decimalPoints: 0
        direction: root.yAxis.direction
        font: root.yAxis.tickLabelFont

        text: {
            if (value === 0) {
                return "0";
            } else {
                return (value / 1000000).toFixed(0) + "M";
            }
        }
    }
}

