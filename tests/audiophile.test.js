// What plays: connection, codec, rate and depth read from `pactl` (Audiophile.js).
// Run from the plugin root: gjs tests/audiophile.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Audiophile = load("Audiophile.js", ["INFOS", "connectionOf", "factsOf", "parse", "kilohertz", "chainOf", "textOf", "line", "rows"]);

const sinks = JSON.stringify([
    { name: "alsa_output.usb-X.HiFi__Line1__sink", sample_specification: "s32le 2ch 192000Hz", properties: { "device.bus": "usb", "device.api": "alsa", "api.alsa.path": "hw:Gen" } },
    { name: "alsa_output.pci-0000_01_00.1.hdmi-stereo", sample_specification: "s32le 2ch 48000Hz", properties: { "device.bus": "pci", "device.api": "alsa", "api.alsa.path": "hdmi:0" } },
    { name: "alsa_output.pci-0000_0d_00.6.iec958-stereo", sample_specification: "s16le 2ch 44100Hz", properties: { "device.bus": "pci", "device.api": "alsa", "api.alsa.path": "iec958:1" } },
    { name: "alsa_output.pci-0000_0d_00.6.analog-stereo", sample_specification: "s24le 2ch 96000Hz", properties: { "device.bus": "pci", "device.api": "alsa", "api.alsa.path": "hw:Generic" } },
    { name: "bluez_output.AA_BB_CC_DD_EE_FF.1", sample_specification: "float32le 2ch 96000Hz", properties: { "api.bluez5.codec": "ldac", "device.api": "bluez5" } },
    { name: "bluez_output.11_22_33_44_55_66.1", sample_specification: "s16le 2ch 48000Hz", properties: { "api.bluez5.codec": "sbc_xq" } }
]);
const facts = Audiophile.parse(sinks);
eq("how each output is connected", Object.values(facts).map(f => f.connection), ["USB", "HDMI", "S/PDIF", "Analog", "Bluetooth", "Bluetooth"]);
eq("USB card: rate and depth from the sink", [facts["alsa_output.usb-X.HiFi__Line1__sink"].rate, facts["alsa_output.usb-X.HiFi__Line1__sink"].bits], [192000, 32]);
eq("float sink format still reads its number", Audiophile.parse(sinks)["bluez_output.AA_BB_CC_DD_EE_FF.1"].rate, 96000);
eq("Bluetooth bits come from the codec, not the sink", [facts["bluez_output.AA_BB_CC_DD_EE_FF.1"].bits, facts["bluez_output.11_22_33_44_55_66.1"].bits], [24, 16]);
eq("codec names are written as people write them", [facts["bluez_output.AA_BB_CC_DD_EE_FF.1"].codec, facts["bluez_output.11_22_33_44_55_66.1"].codec], ["LDAC", "SBC-XQ"]);
eq("a wired output has no codec", facts["alsa_output.usb-X.HiFi__Line1__sink"].codec, "");
eq("not JSON gives nothing", [Audiophile.parse("oops"), Audiophile.parse("{}"), Audiophile.parse("")], [{}, {}, {}]);
eq("an unknown output is not named", Audiophile.connectionOf("x", {}), "");
eq("kilohertz are short", [Audiophile.kilohertz(48000), Audiophile.kilohertz(44100), Audiophile.kilohertz(0)], ["48 kHz", "44.1 kHz", ""]);

const bt = facts["bluez_output.AA_BB_CC_DD_EE_FF.1"];
const card = { connection: true, codec: true, rate: true, bits: true };
eq("the card's line", Audiophile.line(bt, card, null), "Bluetooth · LDAC · 96 kHz · 24 bit");
eq("a fact left off the line", Audiophile.line(bt, { rate: true }, null), "96 kHz");
eq("nothing chosen, no line", Audiophile.line(bt, {}, null), "");
eq("a wired output skips the missing codec", Audiophile.line(facts["alsa_output.usb-X.HiFi__Line1__sink"], card, null), "USB · 192 kHz · 32 bit");
eq("resampling is signalled", Audiophile.chainOf({ rate: 48000 }, { rate: 96000 }), "Resampled 48 kHz to 96 kHz");
eq("same rate, nothing to signal", [Audiophile.chainOf({ rate: 48000 }, { rate: 48000 }), Audiophile.chainOf(null, { rate: 48000 })], ["", ""]);
eq("detail rows keep the order and the labels", Audiophile.rows(bt, { codec: true, channels: true, chain: true }, { rate: 48000 }), [
    { label: "Codec", text: "LDAC" }, { label: "Channels", text: "Stereo" }, { label: "PC to device", text: "Resampled 48 kHz to 96 kHz" }]);
eq("no facts, no line", [Audiophile.line(null, card, null), Audiophile.rows(null, card, null)], ["", []]);

done();
