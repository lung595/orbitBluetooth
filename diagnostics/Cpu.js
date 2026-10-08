.pragma library

// The CPU line of a report. The shell is ONE process shared by DMS and every
// plugin, so no exact share per plugin exists (docs/notes-techniques.md 7.6):
// this is the whole shell over a short window, and the report says so.
// Nothing here runs by itself: the caller reads /proc/self/stat twice, only
// when a report is asked for, and hands the two texts to these functions.

// Linux counts process time in 1/100 s ticks (sysconf(_SC_CLK_TCK) is 100 on
// every kernel Fedora ships)
var TICKS_PER_SECOND = 100;

// User + system ticks from the text of /proc/self/stat, or -1. The process name
// (field 2) sits in parentheses and may hold spaces, so counting starts after
// the last ")": utime and stime are then the 12th and 13th words.
function ticksOf(stat) {
    if (typeof stat !== "string")
        return -1;
    var end = stat.lastIndexOf(")");
    if (end < 0)
        return -1;
    var words = stat.slice(end + 1).trim().split(/\s+/);
    var user = parseInt(words[11]);
    var system = parseInt(words[12]);
    return isFinite(user) && isFinite(system) && user >= 0 && system >= 0 ? user + system : -1;
}

// Percent of one core used between two readings taken windowMs apart, or -1
// when a reading is missing or the window is too short to mean anything.
function percent(ticksBefore, ticksAfter, windowMs) {
    if (ticksBefore < 0 || ticksAfter < ticksBefore || !(windowMs >= 200))
        return -1;
    return Math.round((ticksAfter - ticksBefore) / TICKS_PER_SECOND / (windowMs / 1000) * 1000) / 10;
}

// The report's line, worded so nobody reads it as the plugin's own share
function line(cpu) {
    if (!cpu || !(cpu.percent >= 0))
        return "not measured";
    return cpu.percent + "% of one core, whole shell (DMS and every plugin), over " + Math.round(cpu.windowMs / 100) / 10 + " s";
}
