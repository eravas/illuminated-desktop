import QtQuick
// The flip control: the card's top-right corner is cut away (MaterialFace `cut`) and folded
// over as a flap showing the other face's colour, shaded as a fold, with a rounded tip and
// sharp crease ends (DESIGN.md §8). The hit area is at least 24 × 24 px (44 with large targets).
Item {
    id: root
    objectName: "card-dog-ear"
    property color colour
    property color edgeColour
    property real size: 18
    property real minimumTarget: 24
    signal turned()
    width: Math.max(minimumTarget, size * 1.5); height: width
    Canvas {
        id: fold
        anchors { top: parent.top; right: parent.right }
        width: root.size + 3; height: root.size + 3
        onPaint: {
            const ctx = getContext("2d"), e = root.size, r = e * 0.28;
            ctx.reset();
            function flap() { ctx.beginPath(); ctx.moveTo(3, 0); ctx.lineTo(e + 3, e); ctx.lineTo(3 + r, e); ctx.quadraticCurveTo(3, e, 3, e - r); ctx.closePath(); }
            ctx.save(); ctx.translate(1, 1.5); flap(); ctx.fillStyle = "rgba(0,0,0,0.25)"; ctx.fill(); ctx.restore();
            flap();
            const g = ctx.createLinearGradient(3 + e / 2, e / 2, 3, e);
            g.addColorStop(0, Qt.lighter(root.colour, 1.16)); g.addColorStop(0.55, root.colour); g.addColorStop(1, Qt.darker(root.colour, 1.12));
            ctx.fillStyle = g; ctx.fill();
            ctx.strokeStyle = root.edgeColour; ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(3, 0); ctx.lineTo(e + 3, e); ctx.stroke();
        }
        Connections { target: root; function onColourChanged() { fold.requestPaint(); } function onEdgeColourChanged() { fold.requestPaint(); } function onSizeChanged() { fold.requestPaint(); } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.turned() }
}
