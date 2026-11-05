const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const policy = {};
vm.createContext(policy);
vm.runInContext(fs.readFileSync('quickshell/artifacts/Geometry.js', 'utf8'), policy);
const kinds = {};   // card orientation: artifacts/kinds/Kinds.js, as CardsLayer reads it
vm.createContext(kinds);
vm.runInContext(fs.readFileSync('quickshell/artifacts/kinds/Kinds.js', 'utf8').replace('.pragma library', ''), kinds);
// Hands always travel in from the left (v7); `left`/`top` are the rail and permanent dock.
for (const [width,height] of [[320,240],[360,640],[720,480],[1280,720],[1366,768],[1920,1080],[3440,1440]]) {
  test(`rotated separated cards, lane and accessible pagination ${width}x${height}`, () => {
    for (let count=1; count<=12; count++) for (const lane of [0,height/2,height]) for (const [left,top] of [[0,0],[72,0],[72,38]]) {
      let seen=[];
      const first=policy.dealLeft(width,height,lane,count,0,left,top);
      for(let page=0;page<first.pages;page++) {
        const layout=policy.dealLeft(width,height,lane,count,page,left,top);
        const pager=layout.pages>1?44:0;
        const boxes=layout.cards.map(c => {
          const b=policy.bounds(c.width,c.angle); seen.push(c.index);
          assert(Math.abs(c.height/c.width-1.4)<1e-9);
          assert(Math.abs(c.y+c.height/2-layout.lane)<1e-9);
          assert(c.offscreenX+c.width<=0);
          const x=c.x+c.width/2-b.width/2, y=c.y+c.height/2-b.height/2;
          assert(x>=left && x+b.width<=width, `x ${count} ${page}`);
          assert(y-6>=top && y+b.height<=height-pager, `y ${count} ${page}`);
          return {x,w:b.width};
        }).sort((a,b)=>a.x-b.x);
        for(let i=1;i<boxes.length;i++) assert(boxes[i].x>boxes[i-1].x+boxes[i-1].w,'cards must not collide');
      }
      assert.deepEqual(seen,Array.from({length:count},(_,i)=>i));
    }
  });
}
test('launcher spread unfurls flat in place, beside the rail and under the dock',()=>{
 for(const [w,h] of [[320,240],[1280,720],[1366,768],[1920,1080]]) {
   const o={width:820,height:600,left:72,top:72};
   const zero=policy.spread(w,h,0,o), half=policy.spread(w,h,.5,o), open=policy.spread(w,h,1,o);
   assert.equal(zero.reveal,0); assert.equal(open.reveal,open.width);
   assert(half.reveal>0 && half.reveal<open.width);
   assert.equal(zero.x,open.x); assert.equal(half.y,open.y);          // no travel: the reveal is the only motion
   assert(open.x>=72 && open.x+open.width<=w); assert(open.y>=72 && open.y+open.height<=h);
   assert(Math.abs((open.x-72)-(w-open.x-open.width))<=1);            // centred in the free area
 }
});
test('specialized landscape cards remain separated in a hand',()=>{
 for(const [w,h] of [[320,240],[640,360],[1280,720],[1366,768]]) for(const kinds of [[{landscape:true},{},{}],[{landscape:true},{}]]){
  const first=policy.dealLeft(w,h,h/2,kinds,0,72,0);
  for(let page=0;page<first.pages;page++){
   const d=policy.dealLeft(w,h,h/2,kinds,page,72,0);
   const boxes=d.cards.map(c=>{assert(Math.abs(c.width/c.height-(kinds[c.index].landscape?1.4:5/7))<1e-9);const b=policy.bounds(c.width,c.angle,c.ratio);assert(Math.abs(c.y+c.height/2-d.lane)<1e-9);return {left:c.x+c.width/2-b.width/2,right:c.x+c.width/2+b.width/2};}).sort((a,b)=>a.left-b.left);
   for(let i=1;i<boxes.length;i++)assert(boxes[i].left>boxes[i-1].right);
  }
 }
});
test('every default group fits on one page at 1280x720 and 1366x768',()=>{
 // Mirrors CardsLayer.qml: groups from the packaged defaults, orientation from the kinds table.
 const defaults=JSON.parse(fs.readFileSync('quickshell/config/defaults.json','utf8'));
 const deck=defaults.deck, left=72;
 const options={cardWidth:deck.width,landscapeWidth:deck.landscapeWidth,gap:Math.max(deck.gap,deck.selectionLift+8),margin:deck.margin,rotation:4,lift:deck.selectionLift};   // reading.options.rotation "full" (the Default preset)
 const groups=Object.entries(defaults.groups).filter(([,g])=>g.cards.length);
 assert(groups.length>=5);
 for(const [w,h] of [[1280,720],[1366,768]]) for(const [name,group] of groups){
  const items=group.cards.map(kind=>({landscape:kinds.landscape(kind)}));
  for(const lane of [0,h/2,h]) for(const top of [0,72]){
   const d=policy.dealLeft(w,h,lane,items,0,left,top,options);
   assert.equal(d.pages,1,`${name} paginates at ${w}x${h}`);
   assert.equal(d.cards.length,items.length,name);
   for(const c of d.cards){
    const b=policy.bounds(c.width,c.angle,c.ratio), cy=c.y+c.height/2;
    assert(cy-b.height/2-options.lift>=top && cy+b.height/2<=h-options.margin,`${name} card ${c.index} leaves the screen at ${w}x${h}`);
   }
  }
 }
});

test('grid-aligned decks: no tilt and whole-pixel positions', () => {
  for (const [w, h] of [[1280, 720], [1366, 768], [1920, 1080]]) for (const count of [1, 2, 3]) {
    const items = Array.from({length: count}, (_, i) => ({landscape: i === 0}));
    const d = policy.dealLeft(w, h, h / 2 + 0.37, items, 0, 72, 38, {cardWidth: 154, landscapeWidth: 248, gap: 24, margin: 16, rotation: 4, aligned: true, lift: 6});
    for (const c of d.cards) {
      assert.equal(c.angle, 0);
      assert.equal(c.x, Math.round(c.x));
      assert.equal(c.y, Math.round(c.y));
    }
  }
});

test('hands dealt from the rail: a row right of the rail, on the dealing initial, inside the screen', () => {
  const defaults = JSON.parse(fs.readFileSync('quickshell/config/defaults.json', 'utf8'));
  const deck = defaults.deck, opts = {cardWidth: deck.width, landscapeWidth: deck.landscapeWidth, gap: 24, margin: deck.margin, rotation: 4, lift: deck.selectionLift};
  for (const [w, h] of [[1280, 720], [1366, 768], [1920, 1080], [2560, 1440]]) for (const name of defaults.rail.hands) {
    const items = defaults.groups[name].cards.map(k => ({landscape: kinds.landscape(k)}));
    for (const y of [0, h / 2, h]) for (const top of [0, 72]) {
      const d = policy.dealLeft(w, h, y, items, 0, 72, top, opts);
      assert.equal(d.pages, 1, `${name} paginates at ${w}x${h}`);
      let prev = -Infinity;
      for (const c of d.cards) {
        const b = policy.bounds(c.width, c.angle, c.ratio), cx = c.x + c.width / 2, cy = c.y + c.height / 2;
        assert(cx - b.width / 2 >= 72, `${name} overlaps the rail`);
        assert(cx + b.width / 2 <= w, `${name} leaves the screen right`);
        assert(cy - b.height / 2 - opts.lift >= top && cy + b.height / 2 <= h, `${name} leaves the screen vertically at ${w}x${h}`);
        assert(cx > prev, 'left to right'); prev = cx;
        assert(c.offscreenX + c.width <= 0, 'starts offscreen left');
      }
    }
  }
  const aligned = policy.dealLeft(1366, 768, 300, [{}, {}, {}], 0, 72, 0, {...opts, aligned: true});
  for (const c of aligned.cards) { assert.equal(c.angle, 0); assert.equal(c.x, Math.round(c.x)); }
});
