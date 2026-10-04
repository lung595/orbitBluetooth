// What the graph adds to what plays: the codec's bit rate, the delay the
// output reports and the quantum (Codecs.js, AudioGraph.js).
// Run from the plugin root: gjs tests/audiograph.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Codecs = load("Codecs.js", ["name", "profile", "bitrate"]);
const Graph = load("AudioGraph.js", ["parseDump", "parseTop", "latencyText", "quantumText"]);

// --- Codecs: names, profiles, bit rates ------------------------------------------
eq("codec names", [Codecs.name("ldac"), Codecs.name("aptx_hd"), Codecs.name("msbc"), Codecs.name("newcodec"), Codecs.name("")], ["LDAC", "aptX HD", "mSBC", "NEWCODEC", ""]);
eq("profiles are written as people write them", ["a2dp-sink", "headset-head-unit", "bap-sink", "asha", "odd-one", ""].map(Codecs.profile), ["A2DP", "HSP/HFP", "LE Audio", "LE Audio", "odd-one", ""]);

eq("LDAC fixed qualities, 96 kHz family", [0, 1, 2].map(q => Codecs.bitrate("ldac", 96000, 2, q)), ["990 kbps", "660 kbps", "330 kbps"]);
eq("LDAC fixed qualities, 44.1 kHz family", [0, 1, 2].map(q => Codecs.bitrate("ldac", 88200, 2, q)), ["909 kbps", "606 kbps", "303 kbps"]);
eq("LDAC adaptive is a range, not a number", Codecs.bitrate("ldac", 96000, 2, -1), "Adaptive, 330 to 990 kbps");
eq("LDAC with no quality read says nothing", [Codecs.bitrate("ldac", 96000, 2, undefined), Codecs.bitrate("ldac", 96000, 2, 7)], ["", ""]);
eq("aptX is four to one, always", [Codecs.bitrate("aptx", 44100, 2, undefined), Codecs.bitrate("aptx", 48000, 2, undefined), Codecs.bitrate("aptx_hd", 48000, 2, undefined), Codecs.bitrate("aptx_hd", 44100, 2, undefined)], ["352 kbps", "384 kbps", "576 kbps", "529 kbps"]);
eq("SBC, AAC and the rest vary: never a guess", ["sbc", "sbc_xq", "aac", "lc3", "aptx_adaptive", "", "faststream"].map(k => Codecs.bitrate(k, 48000, 2, undefined)), ["", "", "", "", "", "", ""]);
eq("no rate, no bit rate", Codecs.bitrate("aptx", 0, 2, undefined), "");

// --- pw-dump: latency and LDAC quality, sinks only ---------------------------------
const node = (name, cls, params) => ({ id: 1, type: "PipeWire:Interface:Node", info: { props: { "node.name": name, "media.class": cls }, params: params } });
const dump = JSON.stringify([
    { id: 0, type: "PipeWire:Interface:Core", info: {} },
    node("bluez_output.AA_BB_CC_DD_EE_FF.1", "Audio/Sink", {
        "Latency": [{ direction: "Input", minQuantum: 0, maxQuantum: 0, minRate: 0, maxRate: 0, minNs: 606387499, maxNs: 606387499 }],
        "Props": [{ volume: 1.0, mute: false }, { latencyOffsetNsec: 0 }, { quality: -1 }]
    }),
    node("alsa_output.usb-X.HiFi__Line1__sink", "Audio/Sink", {
        "Latency": [{ direction: "Input", minQuantum: 1.0, maxQuantum: 1.0, minRate: 1024, maxRate: 1024, minNs: 0, maxNs: 0 }, { direction: "Output", minQuantum: 0, maxQuantum: 0, minRate: 0, maxRate: 0, minNs: 0, maxNs: 0 }],
        "Props": [{ volume: 1.0 }]
    }),
    node("bluez_output.11_22_33_44_55_66.1", "Audio/Sink", { "Latency": [{ direction: "Input", minNs: 0, maxNs: 0 }], "Props": [{ quality: 0 }] }),
    node("bluez_input.AA_BB_CC_DD_EE_FF", "Audio/Source", { "Latency": [{ direction: "Input", minNs: 5e8, maxNs: 5e8 }] }),
    { id: 9, type: "PipeWire:Interface:Metadata", info: null },
    null
]);
const parsed = Graph.parseDump(dump);
eq("only sinks are kept", Object.keys(parsed), ["bluez_output.AA_BB_CC_DD_EE_FF.1", "alsa_output.usb-X.HiFi__Line1__sink", "bluez_output.11_22_33_44_55_66.1"]);
eq("the reported delay and the LDAC setting", parsed["bluez_output.AA_BB_CC_DD_EE_FF.1"], { latencyMs: 606.387499, quality: -1 });
eq("a wired output reports no delay in time: nothing is made up", parsed["alsa_output.usb-X.HiFi__Line1__sink"], {});
eq("a delay of zero is not a delay", parsed["bluez_output.11_22_33_44_55_66.1"], { quality: 0 });
eq("not JSON, or not a list, gives nothing", [Graph.parseDump("oops"), Graph.parseDump("{}"), Graph.parseDump("")], [{}, {}, {}]);

// --- pw-top: the quantum of the nodes that run ---------------------------------------
const header = "S   ID  QUANT   RATE    WAIT    BUSY   W/Q   B/Q  ERR FORMAT           NAME ";
const top = [
    header,
    "I   30      0      0   0.0us   0.0us  ???   ???     0                  Dummy-Driver",
    "S  144      0      0    ---     ---   ---   ---     0                  bluez_output.AA_BB_CC_DD_EE_FF.1",
    header,
    "I   30      0      0   0.0us   0.0us  ???   ???     0                  Dummy-Driver",
    "R  144   1024  96000 739.3us   2.1us  0.07  0.00    0    F32P 2 96000 bluez_output.AA_BB_CC_DD_EE_FF.1",
    "R  112      0      0   3.2us   2.5us  0.00  0.00    0    F32P 2 96000  + orbit_pc_AA_BB_CC_DD_EE_FF",
    "R  186   4800  48000   5.3us  24.7us  0.00  0.00    0    S16LE 2 48000  = Player",
    "S   50      0      0    ---     ---   ---   ---     0                  alsa_output.usb-X.HiFi__Line1__sink",
    ""
].join("\n");
eq("the last block counts, running nodes with a quantum only", Graph.parseTop(top), {
    "bluez_output.AA_BB_CC_DD_EE_FF.1": { quantum: 1024, quantumRate: 96000 },
    "Player": { quantum: 4800, quantumRate: 48000 }
});
eq("nothing running, nothing said", [Graph.parseTop(header + "\nS  144      0      0    ---     ---   ---   ---     0                  x"), Graph.parseTop(""), Graph.parseTop(undefined)], [{}, {}, {}]);

// --- The text ------------------------------------------------------------------------
eq("latency is short and rounded", [Graph.latencyText(606.387), Graph.latencyText(5.33), Graph.latencyText(12.5), Graph.latencyText(0), Graph.latencyText(undefined)], ["606 ms", "5.3 ms", "13 ms", "", ""]);
eq("quantum in samples and milliseconds", [Graph.quantumText(1024, 192000), Graph.quantumText(256, 48000), Graph.quantumText(0, 48000), Graph.quantumText(1024, 0), Graph.quantumText(undefined, undefined)], ["1024 samples (5.3 ms)", "256 samples (5.3 ms)", "", "", ""]);

done();
