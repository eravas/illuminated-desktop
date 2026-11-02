.pragma library
// Card families: which component draws a card kind. A kind is "<family>:<id>" or a bare
// built-in service kind. To add a family: add its prefix here and a Component with the same
// name in CardsLayer's `families` map; every family's card takes the same properties (kind,
// aspectRatio, naturalRotation, selected, interactive, selectedByUser) as ArtifactCard.
var FAMILIES = ["skin"];   // prefixed families; anything else is "service"

function family(kind) {
    var i = (kind || "").indexOf(":");
    if (i > 0) { var f = kind.slice(0, i); if (FAMILIES.indexOf(f) >= 0) return f; }
    return "service";
}
