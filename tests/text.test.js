// Text from outside the plugin, made safe to show on one line (Text.js).
// Run from the plugin root: gjs tests/text.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Text = load("Text.js");
const line = Text.line;

eq("a plain name is left as it is", line("WH-1000XM6"), "WH-1000XM6");
eq("spaces are made plain and trimmed", line("  Acme \t  Studio\n\n 2x2  "), "Acme Studio 2x2");
// What a nearby device or a driver could put in a name to rewrite the terminal
// or the card (an escape sequence, a bell, a line feed that fakes a second line)
eq("control characters never get through", line("Acme\u0000\u001b[31m Studio\u007f\u009b"), "Acme [31m Studio");
eq("a bell and a line feed do not fake another line", line("Headset\u0007\nOK: done"), "Headset OK: done");
eq("invisible and reordering characters are dropped", line("Acme‮odutS​﻿ Pro"), "Acme odutS Pro");
eq("a name that is only invisible is nothing", [line("\u0000\u0001"), line("​‮"), line("   "), line("")], ["", "", "", ""]);

eq("40 characters at most when no limit is given", [line("x".repeat(100)), line("y".repeat(40)).length, line("z".repeat(41)).length], ["x".repeat(40), 40, 40]);
eq("the limit can be given", [line("x".repeat(100), 10), line("abc", 10), line("abc", 2)], ["x".repeat(10), "abc", "ab"]);
eq("a limit that is not a positive number is the default", [line("x".repeat(60), 0), line("x".repeat(60), -3), line("x".repeat(60), "9"), line("x".repeat(60), NaN), line("x".repeat(60), undefined)], new Array(5).fill("x".repeat(40)));
eq("the default is the one constant", line("w".repeat(99)).length, Text.MAX_NAME);
eq("a cut never ends on a space", line("a".repeat(39) + " bbb"), "a".repeat(39));
eq("an emoji is never split in two", line("a".repeat(39) + "\u{1F3A7}\u{1F3A7}"), "a".repeat(39) + "\u{1F3A7}");
eq("accents and other scripts are kept", [line("Casque Bluetooth é"), line("ヘッドホン"), line("наушники")], ["Casque Bluetooth é", "ヘッドホン", "наушники"]);

eq("what is not a text is nothing", [line(undefined), line(null), line(5), line({}), line(["a"]), line(true)], new Array(6).fill(""));
eq("the same line, whatever called it", line("  Acme\u0000 X "), "Acme X");

done();
