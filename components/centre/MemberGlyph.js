.pragma library
.import "../device/DeviceCatalog.js" as Catalog
.import "../device/Glyphs.js" as Glyphs
.import "../together/Member.js" as Member
.import "WiredSign.js" as Sign

// The glyph a group member wears wherever the group is drawn (its row of icons,
// the volume radar's dials): a device's own, as its body wears it (the user's
// choice first), or the picture of a wired output's connection. `node` is the
// wired output's PipeWire node (null for a device), `device` the Bluetooth device.
function glyphOf(token, node, device, overrides) {
    if (Member.isWired(token))
        return Glyphs.wired(Sign.kindOf(token, node ? node.properties : null));
    return Catalog.resolve(device, overrides);
}
