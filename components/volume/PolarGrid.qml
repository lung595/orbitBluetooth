import QtQuick

// The scope's own screen behind the picture (PolarScope): a faint glow,
// guide rings and the L / R lines, like an Ozone-style goniometer.
// Painted once per size or color change, never per frame
Canvas {
    id: gridCanvas

    // The scope (PolarScope.qml): its geometry, ink and grid switch
    required property var scope

    visible: scope.grid
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: requestPaint()
    Connections {
        target: scope
        function onInkColorChanged() {
            gridCanvas.requestPaint();
        }
        function onOuterChanged() {
            gridCanvas.requestPaint();
        }
        function onDeviceColorChanged() {
            gridCanvas.requestPaint();
        }
    }
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (!scope.grid)
            return;
        const c = scope.inkColor;
        const ink = a => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
        const R = scope.outer - scope.stroke * 2;
        // A faint glow where the sound rises from, like a lit phosphor screen
        const d = scope.deviceColor;
        const glow = ctx.createRadialGradient(scope.cx, scope.cy, 0, scope.cx, scope.cy, scope.outer * 1.15);
        glow.addColorStop(0, "rgba(" + Math.round(d.r * 255) + "," + Math.round(d.g * 255) + "," + Math.round(d.b * 255) + ",0.13)");
        glow.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = glow;
        ctx.fillRect(0, 0, width, height);
        ctx.lineWidth = 1;
        // Rings at a quarter, half and three quarters, dashed
        ctx.setLineDash([2, 4]);
        ctx.strokeStyle = ink(0.09);
        for (const f of [0.25, 0.5, 0.75]) {
            ctx.beginPath();
            ctx.arc(scope.cx, scope.cy, R * f, Math.PI, Math.PI * 2);
            ctx.stroke();
        }
        // Mono up the middle, hard left and right at ±45° (as on a goniometer)
        ctx.setLineDash([]);
        for (const deg of [225, 270, 315]) {
            const a = deg * Math.PI / 180;
            ctx.beginPath();
            ctx.moveTo(scope.cx, scope.cy);
            ctx.lineTo(scope.cx + Math.cos(a) * R, scope.cy + Math.sin(a) * R);
            ctx.strokeStyle = ink(deg === 270 ? 0.12 : 0.08);
            ctx.stroke();
        }
        ctx.fillStyle = ink(0.32);
        ctx.font = "600 " + Math.max(9, Math.round(scope.outer * 0.075)) + "px sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        for (const [deg, t] of [[225, "L"], [315, "R"]]) {
            const a = deg * Math.PI / 180;
            ctx.fillText(t, scope.cx + Math.cos(a) * (R * 0.62), scope.cy + Math.sin(a) * (R * 0.62) - 9);
        }
    }
}
