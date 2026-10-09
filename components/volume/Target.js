.pragma library

// Which level the volume keys and `dms ipc call orbitBluetooth volume` move
// while a Listen together group plays (NAK-9): the member whose own level was
// touched last, else the group. Pure, tested in tests/target.test.js.

// The id of the member to move, or "" for the group. `touched` is the last
// member touched ("" once the group's level was); `members` the group's ids;
// `hasOwnLevel(id)` whether that member keeps a level of its own. A member
// that left, or has no level of its own (a wired output that follows the
// PC), falls back to the group so the keys never stop working.
function resolve(touched, members, hasOwnLevel) {
    if (!touched || (members || []).indexOf(touched) < 0)
        return "";
    return hasOwnLevel(touched) ? touched : "";
}
