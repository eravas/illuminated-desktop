// Browser stand-in for QML's Context2D: exposes only the QML API surface, so code that
// renders here also runs in a QML Canvas. Anything outside the subset throws.
// https://doc.qt.io/qt-6/qml-qtquick-context2d.html
var Qt = {OddEvenFill: 0, WindingFill: 1};
function qmlContext(canvas) {
  const real = canvas.getContext('2d', {willReadFrequently: true});
  let rule = Qt.WindingFill;
  const props = new Set(['fillStyle', 'font', 'globalAlpha', 'globalCompositeOperation', 'lineCap', 'lineDashOffset', 'lineJoin', 'lineWidth',
    'miterLimit', 'shadowBlur', 'shadowColor', 'shadowOffsetX', 'shadowOffsetY', 'strokeStyle', 'textAlign', 'textBaseline']);
  const passthrough = new Set(['arc', 'arcTo', 'beginPath', 'bezierCurveTo', 'clearRect', 'closePath', 'createImageData', 'createLinearGradient',
    'createRadialGradient', 'fillRect', 'fillText', 'getImageData', 'isPointInPath', 'lineTo', 'measureText', 'moveTo',
    'quadraticCurveTo', 'rect', 'resetTransform', 'restore', 'rotate', 'save', 'scale', 'setLineDash', 'getLineDash', 'setTransform',
    'strokeRect', 'strokeText', 'transform', 'translate']);
  const custom = {
    fill(...a) { if (a.length) throw Error('QML Context2D.fill() takes no arguments; set fillRule'); real.fill(rule === Qt.OddEvenFill ? 'evenodd' : 'nonzero'); },
    stroke(...a) { if (a.length) throw Error('QML Context2D.stroke() takes no arguments (no Path2D)'); real.stroke(); },
    clip(...a) { if (a.length) throw Error('QML Context2D.clip() takes no arguments'); real.clip(rule === Qt.OddEvenFill ? 'evenodd' : 'nonzero'); },
    roundedRect(x, y, w, h, xr, yr) { real.roundRect(x, y, w, h, Math.min(xr, w / 2, h / 2)); },
    ellipse(x, y, w, h) { real.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2); },
    createConicalGradient(x, y, angle) { return real.createConicGradient(-angle, x, y); },
    // QML takes a loaded image's URL (Canvas.loadImage); here URLs resolve through window.__images.
    drawImage(img, ...a) { const src = typeof img === 'string' ? (window.__images || {})[img] : img; if (!src) throw Error('image not loaded: ' + img); real.drawImage(src, ...a); },
    reset() { real.reset(); rule = Qt.WindingFill; },
    // Qt 6.12's Canvas drew nothing for the three-argument form (v7 runtime report); require the dirty rect.
    putImageData(img, x, y, dx, dy, w, h) { if (arguments.length !== 7) throw Error('use putImageData(img, x, y, 0, 0, w, h): QML ignores the 3-argument form'); real.putImageData(img, x, y, dx, dy, w, h); },
  };
  return new Proxy({}, {
    get(_, k) {
      if (k === 'fillRule') return rule;
      if (k === 'canvas') return canvas;
      if (k in custom) return custom[k];
      if (passthrough.has(k)) return real[k].bind(real);
      if (props.has(k)) return real[k];
      throw Error('not in the QML Context2D API: ' + String(k));
    },
    set(_, k, v) {
      if (k === 'fillRule') { rule = v; return true; }
      if (props.has(k)) { real[k] = v; return true; }
      throw Error('not a QML Context2D property: ' + String(k));
    }
  });
}
