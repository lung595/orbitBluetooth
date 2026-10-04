import QtQuick

// The colour of a device's picture: the average of its saturated pixels,
// read once from a 12 x 12 downscale (mid-tones count most, grey and
// near-black or near-white pixels barely count). `found` stays transparent
// without a picture or when the picture has no colour to speak of. The
// pairing sheet lends it to a grey theme accent (PairingSkin.qml).
Canvas {
    id: probe

    property url source
    property color found: "transparent"

    width: 12
    height: 12
    opacity: 0

    onSourceChanged: {
        found = "transparent";
        if (source.toString() !== "")
            loadImage(source);
    }
    onImageLoaded: requestPaint()
    onPaint: {
        if (source.toString() === "" || !isImageLoaded(source))
            return;
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.drawImage(source, 0, 0, width, height);
        const px = ctx.getImageData(0, 0, width, height).data;
        let r = 0, g = 0, b = 0, total = 0;
        for (let i = 0; i < px.length; i += 4) {
            const c = Qt.rgba(px[i] / 255, px[i + 1] / 255, px[i + 2] / 255, 1);
            const w = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 2) * (px[i + 3] / 255);
            r += c.r * w;
            g += c.g * w;
            b += c.b * w;
            total += w;
        }
        found = total > 4 ? Qt.rgba(r / total, g / total, b / total, 1) : "transparent";
    }
}
