pragma Singleton
import QtQuick

QtObject {
    function expandTilde(p) {
        return p;
    }
    // Same as DMS: decode, drop the scheme
    function strip(u) {
        return decodeURIComponent(String(u)).replace("file://", "");
    }
}
