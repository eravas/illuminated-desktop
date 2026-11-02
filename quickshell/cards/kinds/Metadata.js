.pragma library
// Built-in behavior; labels, sheets and confirmation come from config.
var values = {
  "volume": {
    "orientation": "landscape",
    "interaction": "level"
  },
  "microphone": {
    "interaction": "level"
  },
  "outputs": {},
  "brightness": {
    "orientation": "landscape",
    "interaction": "level"
  },
  "battery": {},
  "profile": {
    "interaction": "toggle"
  },
  "wifi": {
    "interaction": "toggle"
  },
  "bluetooth": {
    "interaction": "toggle"
  },
  "media": {},
  "notifications": {},
  "dnd": {
    "interaction": "toggle"
  },
  "lock": {
    "interaction": "session"
  },
  "suspend": {
    "interaction": "session",
    "alternatives": [
      "lock",
      "logout"
    ]
  },
  "poweroff": {
    "interaction": "session"
  },
  "reboot": {
    "interaction": "session"
  },
  "logout": {
    "interaction": "session"
  }
};
function spec(kind) {
    return Object.prototype.hasOwnProperty.call(values, kind)
        ? Object.assign({orientation: "portrait", interaction: "flip", alternatives: []}, values[kind]) : {};
}
