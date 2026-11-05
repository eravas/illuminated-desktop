pragma Singleton
import QtQuick
import Quickshell
// The shell's lock screen, when features.lock has loaded it (lock.qml registers itself):
// lockNow(), secure (the compositor confirmed the lock), abandon(). SessionState locks through it
// in-process; `illuminated lock` stays for keybinds and idle daemons.
Singleton {
    property var screen: null
    readonly property bool available: screen !== null
}
