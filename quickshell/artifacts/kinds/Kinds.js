.pragma library
// What each built-in card kind is and does. Behaviour lives here and in the kind's adapter
// (kinds/<Adapter>.qml), not in config: config.toml names cards (title, short), points them at
// a sheet and asks for confirmation; it cannot turn a slider into a toggle.
//   orientation   landscape | portrait
//   interaction   level (drag/scroll adjusts, click mutes) | toggle (click switches) |
//                 flip (click turns the card) | session (power actions)
//   alternatives  session menus: the entries on the card's back (Sleep: Lock, Log Out)
//   adapter       the component in kinds/ that binds the card to its service
var KINDS = {
    volume:        {orientation: "landscape", interaction: "level",   adapter: "LevelKind"},
    microphone:    {orientation: "portrait",  interaction: "level",   adapter: "LevelKind"},
    brightness:    {orientation: "landscape", interaction: "level",   adapter: "LevelKind"},
    outputs:       {orientation: "portrait",  interaction: "flip",    adapter: "InfoKind"},
    battery:       {orientation: "portrait",  interaction: "flip",    adapter: "BatteryKind"},
    profile:       {orientation: "portrait",  interaction: "toggle",  adapter: "ProfileKind"},
    wifi:          {orientation: "portrait",  interaction: "toggle",  adapter: "NetworkKind"},
    bluetooth:     {orientation: "portrait",  interaction: "toggle",  adapter: "BluetoothKind"},
    media:         {orientation: "portrait",  interaction: "flip",    adapter: "InfoKind"},
    notifications: {orientation: "portrait",  interaction: "flip",    adapter: "InfoKind"},
    dnd:           {orientation: "portrait",  interaction: "toggle",  adapter: "InfoKind"},
    lock:          {orientation: "portrait",  interaction: "session", adapter: "SessionKind"},
    suspend:       {orientation: "portrait",  interaction: "session", adapter: "SessionKind", alternatives: ["lock", "logout"]},
    poweroff:      {orientation: "portrait",  interaction: "session", adapter: "SessionKind"},
    reboot:        {orientation: "portrait",  interaction: "session", adapter: "SessionKind"},
    logout:        {orientation: "portrait",  interaction: "session", adapter: "SessionKind"}
};
function meta(kind) {
    var m = KINDS[kind];
    return m ? {orientation: m.orientation, interaction: m.interaction, adapter: m.adapter, alternatives: m.alternatives || []} : null;
}
function landscape(kind) { var m = KINDS[kind]; return !!m && m.orientation === "landscape"; }
