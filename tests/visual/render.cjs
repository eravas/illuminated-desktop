#!/usr/bin/env node
// Renders the shell's material painters in Chromium through the QML Context2D stand-in and
// writes contact sheets to artifacts/v7/. Visual check only (no pixel assertions here; the
// numeric rules are in tests/materials.test.cjs). Fonts fall back where Pirata One is absent.
//   node tests/visual/render.cjs [outdir]
const path = require('node:path');
const fs = require('node:fs');
const {wrapped} = require('./load.cjs');
const root = path.resolve(__dirname, '../..');
const out = path.resolve(process.argv[2] || path.join(root, 'artifacts/v7'));
fs.mkdirSync(out, {recursive: true});
const q = f => path.join(root, 'quickshell', f);
const defaults = JSON.parse(fs.readFileSync(q('config/defaults.json'), 'utf8'));

const shared = new Map();   // one copy of every module, as in QML
const lib = [
  fs.readFileSync(path.join(__dirname, 'qml-context2d.js'), 'utf8'),
  wrapped(path.join(root, 'scripts/skin/Materials.js'), 'M', shared),
  wrapped(path.join(root, 'scripts/skin/painters/Selection.js'), 'Sel', shared),
  wrapped(q('materials/CardPaint.js'), 'CardPaint', shared),
  wrapped(q('materials/DeviceGeometry.js'), 'Geo', shared),
  wrapped(q('materials/DeviceArt.js'), 'DeviceArt', shared),
  wrapped(q('materials/ArtLayers.js'), 'ArtLayers', shared),
  wrapped(q('skin/Skin.js'), 'Skin', shared),
  wrapped(q('skin/Compose.js'), 'Compose', shared),
  wrapped(q('artifacts/CardModel.js'), 'CardModel', shared),
].join('\n');

const page = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;font:12px sans-serif;background:#888}
.sheet{display:flex;flex-wrap:wrap;gap:14px;padding:14px;align-items:flex-start}
.sheet[data-mode=light]{background:#9DB7A0}.sheet[data-mode=dark]{background:#1C2A2A;color:#ddd}
figure{margin:0;display:flex;flex-direction:column;gap:4px}figcaption{max-width:260px}
canvas{display:block}
</style><body><script>${lib}
const DEF = ${JSON.stringify({palettes: defaults.palettes, semantic: defaults.semantic})};
const BL = '"Pirata One", "UnifrakturCook", serif';
function colours(mode){const p=DEF.palettes[mode],o=DEF.palettes[mode==='light'?'dark':'light'];return Object.assign({},DEF.semantic,p,{edgeInverted:o.edge,silver:'#B9BEC4'});}
function fig(host,cv,cap){const f=document.createElement('figure');f.append(cv);const c=document.createElement('figcaption');c.textContent=cap;f.append(c);host.append(f);}
function canvas(w,h,D){const cv=document.createElement('canvas');cv.width=Math.round(w*D);cv.height=Math.round(h*D);cv.style.width=w+'px';cv.style.height=h+'px';return cv;}
function chin(ctx,W,H,D,label,value,ink){const k=Math.min(W,H)/D/154,mg=Math.max(4,Math.round(10*k))*D,ch=Math.round(H/D*(W>H?.2:.19))*D;
  ctx.fillStyle=ink;ctx.font=Math.round(17*k*D)+'px '+BL;ctx.textBaseline='middle';ctx.textAlign='left';const cy=H-ch+(ch-mg)/2;ctx.fillText(label,mg+5*k*D,cy);ctx.textAlign='right';ctx.fillText(value,W-mg-5*k*D,cy);}
function card(host,mode,pres,{landscape,label,value,front=true,art,cut=0,mark,cvd,numeral,D=1,cap}){
  const w=landscape?248:154,h=landscape?177:215.6,cv=canvas(w,h,D),ctx=qmlContext(cv),W=cv.width,H=cv.height,c=colours(mode);
  const surface=front?pres.surface:CardModel.back(pres.kind||'', pres.surface, c);
  const sp=CardPaint.spec(surface,{D,gc:Math.max(1,Math.round(D)),front,art:art||{rgb:'#808080',luminance:1},cut,mark,cvd,onFill:c.onFill});
  let num=null;const k=Math.min(W,H)/D/154,mg=Math.max(4,Math.round(10*k))*D,ch=Math.round(H/D*(W>H?.2:.19))*D;
  if(numeral)num={text:numeral,family:'Pirata One',size:Math.round(92*k*D),ink:c.ink,card:c.cardstock,art:{x:mg,y:mg,w:W-2*mg,h:H-ch-mg}};
  const t0=performance.now();CardPaint.paint(ctx,W,H,sp,num);const ms=performance.now()-t0;
  if(front&&label!==undefined)chin(ctx,W,H,D,label,value||'',surface.wash&&surface.wash.level>.85?c.onFill:surface.chinInk||surface.ink);
  fig(host,cv,(cap||label)+' · '+ms.toFixed(1)+' ms');}
function sheet(mode){const s=document.createElement('div');s.className='sheet';s.dataset.mode=mode;document.body.append(s);return s;}
window.renderCards=function(mode,D){
  const s=sheet(mode),c=colours(mode);
  for(const l of [.1,.3,.6,.9,1]){const p=CardModel.level('brightness',{available:true,level:l},c);card(s,mode,p,{landscape:true,label:'Light',value:Math.round(l*100)+'%',art:{rgb:'#808080',luminance:.4+.6*l},D,cap:'Light '+Math.round(l*100)+'% gold foil'});}
  card(s,mode,CardModel.level('volume',{available:true,level:.62},c),{landscape:true,label:'Sound',value:'62%',D});
  card(s,mode,CardModel.level('volume',{available:true,level:.62,muted:true},c),{landscape:true,label:'Sound',value:'Muted',D,cap:'Sound muted'});
  card(s,mode,CardModel.level('volume',{available:true,level:.62,muted:true},c),{landscape:true,label:'Sound',value:'Muted',D,cvd:'deutan',cap:'Sound muted, deutan hatch'});
  card(s,mode,CardModel.level('volume',{available:true,level:.62},c),{landscape:true,label:'Sound',value:'62%',D,mark:'line',cap:'Sound, level line (Legibility)'});
  card(s,mode,CardModel.level('brightness',{available:true,level:.48},c),{landscape:true,label:'Light',value:'48%',D,mark:'solid',cap:'Light, solid edge (Accessibility)'});
  card(s,mode,CardModel.battery({present:true,level:.76},c,false),{label:'Charge',value:'76%',cut:18*D,D,cap:'Charge 76% with dog-ear cut'});
  card(s,mode,CardModel.battery({present:true,level:.45,charging:true},c,false),{label:'Charge',value:'ϟ 45%',D,cap:'Charging 45%'});
  card(s,mode,CardModel.battery({present:true,level:.92,plugged:true},c,false),{label:'Charge',value:'92% • held',D,cap:'Held 92%'});
  card(s,mode,CardModel.battery({present:true,level:.09},c,true),{label:'',value:'',numeral:'9',D,cap:'Charge 9%, low-charge numeral'});
  for(const st of [1,2,3,4])card(s,mode,CardModel.network({enabled:true,connected:true,stage:st,name:'home'},c),{label:'Network',value:'home',D,cap:'Network stage '+st});
  card(s,mode,CardModel.network({enabled:true,connecting:true},c),{label:'Network',value:'…',D,cap:'Network connecting'});
  card(s,mode,CardModel.bluetooth({available:true,enabled:true,connected:0},c),{label:'Bluetooth',value:'On',D,cap:'Bluetooth idle (chin bleed)'});
  card(s,mode,CardModel.bluetooth({available:true,enabled:true,connected:1,name:'Headphones'},c),{label:'Bluetooth',value:'Headphones',D});
  card(s,mode,CardModel.power('suspend',c),{label:'Sleep',value:'☾',D});
  card(s,mode,CardModel.power('poweroff',c),{label:'Shut Down',value:'',D});
  card(s,mode,CardModel.power('reboot',c),{label:'Reboot',value:'',D});
  card(s,mode,Object.assign(CardModel.power('reboot',c),{kind:'reboot'}),{front:false,D,cap:'Reboot back (tonal bands)'});
  card(s,mode,Object.assign(CardModel.battery({present:true,level:.76,charging:true},c,false),{kind:'battery'}),{front:false,D,cap:'Charging back (tonal bands)'});
  card(s,mode,Object.assign(CardModel.network({enabled:true,connected:true,stage:3},c),{kind:'wifi'}),{front:false,D,cap:'Network back'});
  card(s,mode,CardModel.device({used:.59},c),{front:false,D,cap:'Device card, silver 59%'});
};
// Rail strip: vellum + wash + initials + a loupe over the active numeral; dock strip with loupe on an icon.
window.renderChrome=function(mode,D){
  const s=sheet(mode),M=window.M,p=DEF.palettes[mode],gc=Math.max(1,Math.round(D));
  const ink=p.ink,wt=M.washTone(p.paper,'#8A9F7B',ink,mode,'medium');
  const railW=64,railH=640,cv=canvas(railW+12,railH+12,D),ctx=qmlContext(cv),W=cv.width,H=cv.height;
  const img=ctx.createImageData(W,H);M.paintVellum(img.data,W,H,{x0:6*D,y0:6*D,w:railW*D,h:railH*D,D,gc,mode,base:p.paper,fray:mode==='dark'?'#120F0A':'#A6967B',edge:p.edge});
  M.paintWash(img.data,W,H,{x0:15*D,y0:15*D,w:(railW-18)*D,h:(railH-18)*D,D,gc,mode,tone:wt.tone,horizontal:false,radius:9*D});
  ctx.putImageData(img,0,0,0,0,img.width,img.height);
  // initials (painted into separate ImageData then composited by drawing order)
  const slots=[['launcher','plain'],['L','levels',.62],['C','connections',0,3],['B','battery',.72],['P','plain'],['clipboard','plain'],['N','plain'],['tray','plain']];
  let y=24;
  const sub=canvas(32,32,D),sc=qmlContext(sub);
  slots.forEach(([mark,kind,level,stage],n)=>{const w=sub.width;sc.setTransform(1,0,0,1,0,0);sc.clearRect(0,0,w,w);const im=sc.createImageData(w,w);
    Sel.paintInitial(im.data,w,w,{kind,level,stage,D,gc});sc.putImageData(im,0,0,0,0,im.width,im.height);M.drawInitialMark(sc,mark,w,D,'Pirata One');
    const data=sc.getImageData(0,0,w,w);const bx=Math.round((6+16)*D),by=Math.round((6+y)*D);
    const tgt=ctx.getImageData(bx,by,w,w);for(let i=0;i<data.data.length;i+=4){const a=data.data[i+3]/255;if(!a)continue;for(let k=0;k<3;k++)tgt.data[i+k]=Math.round(data.data[i+k]*a+tgt.data[i+k]*(1-a));tgt.data[i+3]=255;}
    ctx.putImageData(tgt,bx,by,0,0,tgt.width,tgt.height);y+= n===0?60:40; if(n===0){ctx.fillStyle=ink;ctx.font=Math.round(20*D)+'px '+BL;ctx.textAlign='center';ctx.textBaseline='middle';
      ['j','ij','iij','iv','v'].forEach((r,k)=>ctx.fillText(r,(6+32)*D,(6+y+k*30)*D));y+=160;}});
  // loupe over "iij" (index 2 → y offset)
  const L=54,lc=canvas(L,L+3,D),lx=qmlContext(lc),LW=lc.width,LH=lc.height;lx.fillStyle=ink;lx.font=Math.round(20*1.26*D)+'px '+BL;lx.textAlign='center';lx.textBaseline='middle';lx.fillText('iij',LW/2,LW/2);
  const li=lx.getImageData(0,0,LW,LH);Sel.paintLoupe(li.data,LW,LH,{band:6,dark:mode==='dark',D});lx.putImageData(li,0,0,0,0,li.width,li.height);
  fig(s,cv,'Rail · '+mode+' · wash '+wt.strength.toFixed(2));fig(s,lc,'Loupe');
  // dock
  const dw=560,dh=64,dv=canvas(dw+12,dh+12,D),dx=qmlContext(dv),DW=dv.width,DH=dv.height,di=dx.createImageData(DW,DH);
  M.paintVellum(di.data,DW,DH,{x0:6*D,y0:6*D,w:dw*D,h:dh*D,D,gc,mode,base:p.paper,fray:mode==='dark'?'#120F0A':'#A6967B',edge:p.edge,offX:80,offY:0});
  M.paintWash(di.data,DW,DH,{x0:15*D,y0:15*D,w:(dw-18)*D,h:(dh-18)*D,D,gc,mode,tone:wt.tone,horizontal:true,radius:9*D,offX:80});dx.putImageData(di,0,0,0,0,di.width,di.height);
  for(let k=0;k<7;k++){const x=(6+30+k*56)*D;dx.fillStyle=k===3?'#4a6':'#777';dx.fillRect(x-15*D,(6+10)*D,30*D,30*D);dx.fillStyle=ink;dx.font=Math.round(13*D)+'px '+BL;dx.textAlign='center';dx.fillText(['j','ij','viij','vij','','v','j'][k],x,(6+50)*D);}
  fig(s,dv,'Dock · '+mode);
  // initials large
  const big=document.createElement('div');big.style.cssText='display:flex;gap:8px;flex-wrap:wrap;max-width:420px';
  slots.forEach(([mark,kind,level,stage])=>{const z=canvas(32,32,4),zc=qmlContext(z),w=z.width,im=zc.createImageData(w,w);Sel.paintInitial(im.data,w,w,{kind,level,stage,D:4,gc:4});zc.putImageData(im,0,0,0,0,im.width,im.height);M.drawInitialMark(zc,mark,w,4,'Pirata One');z.style.width='96px';z.style.height='96px';big.append(z);});
  fig(s,big,'Initials at 3× (grain = 1 logical px)');
};
// The skin path, as SkinElement paints it: look → layers → compose → finish, for the default
// skin's rail at several shell states. Images resolve through window.__images ('skin/<path>').
function bakeElement(m,el,values,D,pxmm,gc){
  const scale=Skin.scaleFor(Skin.unitsOf(m,el),pxmm),margin=el.shadow===false?0:6,g=Compose.geometry(el.size,scale,margin,D);
  const cv=document.createElement('canvas');cv.width=g.W;cv.height=g.H;cv.style.width=(g.W/D)+'px';cv.style.height=(g.H/D)+'px';const ctx=qmlContext(cv);
  const layer=(ref,rect)=>{const r=rect||[0,0,el.size[0],el.size[1]];return ArtLayers.rasterise(ctx,g.W,g.H,D,ref.file,margin+r[0]*scale,margin+r[1]*scale,r[2]*scale,r[3]*scale,0,ref.rect);};
  const lk=Skin.look(el,values),regions=(el.regions||[]).filter(r=>Skin.test(r.visibleWhen,values)).map(r=>({id:r.id,rect:r.rect||null,look:Skin.look(r,values)}));
  const px=Compose.compose({manifest:m,g,look:lk,state:values,layer,regions,inks:m.inks});Compose.finish(px,g,gc,{dither:el.dither!==false,shadow:el.shadow!==false});
  const img=ctx.createImageData(g.W,g.H);ArtLayers.copyInto(img.data,px);ctx.putImageData(img,0,0,0,0,g.W,g.H);
  const an=el.anchor||[0,0];return {cv,g,ax:margin+an[0]*scale,ay:margin+an[1]*scale,alpha:Compose.alpha(px,g.W,g.H),scale,margin};
}
window.renderSkin=async function(mode,D,states,files,example){
  window.__images=window.__images||{};
  for(const [p,url] of Object.entries(files)){const i=new Image();i.src=url;await i.decode();window.__images['skin/'+p]=i;window.__images['example/../default/'+p]=i;}
  for(const [p,url] of Object.entries(example?window.__exampleFiles:{})){const i=new Image();i.src=url;await i.decode();window.__images['example/'+p]=i;}
  const m=example?Skin.merge(Skin.absolutise(window.__skin,'skin/'),Skin.absolutise(window.__example,'example/')):Skin.absolutise(window.__skin,'skin/'),s=sheet(mode),M=window.M,p=DEF.palettes[mode],gc=Math.max(1,Math.round(D)),k=1366/344,RW=64,RX=3;
  window.__hits=[];
  for(const st of states){
    const values=Object.assign({mode},st),H=700,cv=canvas(110,H,D),ctx=qmlContext(cv),W=cv.width,HH=cv.height;cv.style.width=W+'px';cv.style.height=HH+'px';
    const im=ctx.createImageData(W,HH);M.paintVellum(im.data,W,HH,{x0:RX*D,y0:8*D,w:RW*D,h:(H-16)*D,D,gc,mode,base:p.paper,fray:mode==='dark'?'#120F0A':'#A6967B',edge:p.edge});
    M.paintWash(im.data,W,HH,{x0:(RX+9)*D,y0:17*D,w:(RW-18)*D,h:(H-34)*D,D,gc,mode,tone:M.washTone(p.paper,'#8A9F7B',p.ink,mode,'medium').tone,horizontal:false,radius:9*D});
    ctx.putImageData(im,0,0,0,0,W,HH);const c2=cv.getContext('2d');
    const draw=(b,x,y)=>c2.drawImage(b.cv,Math.round((x-b.ax)*D),Math.round((y-b.ay)*D));
    let y=18;
    for(const it of m.rail.items){
      if(it.element){const el=m.elements[it.element];if(!Skin.test(el.visibleWhen,values))continue;const b=bakeElement(m,el,values,D,k,gc),h=b.g.h+4,cx=it.place==='center'?RX+RW/2:RX+RW-4;draw(b,cx,y+h/2);y+=h;}
      else if(it.system==='rule'){c2.fillStyle=p.edge;c2.fillRect((RX+18)*D,(y+6)*D,28*D,D);y+=13;}
      else if(it.system==='workspaces'){c2.fillStyle=p.ink;c2.font=(20*D)+'px serif';c2.textAlign='center';['j','ij','iij'].forEach((t,i)=>c2.fillText(t,(RX+RW/2)*D,(y+22+i*26)*D));y+=86;}
      else if(it.system==='clock'){c2.fillStyle=p.ink;c2.font=(21*D)+'px serif';c2.textAlign='center';c2.fillText('17:09',(RX+RW/2)*D,(H-120)*D);}
    }
    const foot=m.rail.items.find(i=>i.foot),fe=m.elements[foot.foot],fb=bakeElement(m,fe,values,D,k,gc);draw(fb,0,H);
    // Hits on the foot: the clip region, the sheet, outside.
    const clip=fe.regions.find(r=>r.id==='clip'),at=[clip.rect[0]+clip.rect[2]/2,clip.rect[1]+clip.rect[3]/2];
    const alphaAt=(kind,ux,uy,rid)=>{const q=Compose.toDevice(fb.g,[ux,uy]),x=Math.round(q[0]),yy=Math.round(q[1]);if(x<0||yy<0||x>=fb.g.W||yy>=fb.g.H)return false;return kind==='alpha'&&!rid?fb.alpha[yy*fb.g.W+x]>0:false;};
    const live={regions:fe.regions.filter(r=>r.triggers),hit:fe.hit};
    const tr=fe.regions.find(r=>r.id==='tray'),trayHit=tr?Skin.hit(live,tr.rect[0]+tr.rect[2]/2,tr.rect[1]+tr.rect[3]/2,alphaAt):'';
    window.__hits.push({clip:Skin.hit(live,at[0],at[1],alphaAt),tray:trayHit,sheet:Skin.hit(live,2,fe.size[1]-2,alphaAt),outside:Skin.hit(live,fe.size[0]-1,1,alphaAt)});
    fig(s,cv,'skin rail · '+JSON.stringify(st));
  }
};
window.renderDevices=async function(mode,D,locked,files){
  window.__images=window.__images||{};
  for(const [p,url] of Object.entries(files))if(!window.__images['skin/'+p]){const i=new Image();i.src=url;await i.decode();window.__images['skin/'+p]=i;}
  const ms=Skin.absolutise(window.__skin,'skin/'),imgs={};for(const kd in ms.devices)imgs[kd]={device:ms.devices[kd].image,envelope:ms.devices[kd].envelope};DeviceArt.setImages(imgs,{seal:ms.media.seal,cracked:ms.media.sealCracked});
  const s=sheet(mode),M=window.M,p=DEF.palettes[mode],gc=Math.max(1,Math.round(D)),rail=Geo.railGeometry(3,64),pxmm=Geo.PX_PER_MM['24'];
  for(const kind of Geo.KINDS){
    const dv=Geo.DEVICES[kind],bay=Geo.bay(dv,pxmm,rail,false),Hh=Math.max(300,bay+200),wrap=document.createElement('div');wrap.style.cssText='display:flex;gap:6px';
    for(const pose of locked?['mounted']:['unmounted','mounted']){
      const cv=canvas(96,Hh,D),ctx=qmlContext(cv),W=cv.width,H=cv.height;
      // rail stub behind
      const im=ctx.createImageData(W,H);M.paintVellum(im.data,W,H,{x0:3*D,y0:4*D,w:64*D,h:(Hh-8)*D,D,gc,mode,base:p.paper,fray:mode==='dark'?'#120F0A':'#A6967B',edge:p.edge});
      M.paintWash(im.data,W,H,{x0:12*D,y0:13*D,w:46*D,h:(Hh-26)*D,D,gc,mode,tone:M.washTone(p.paper,'#8A9F7B',p.ink,mode,'medium').tone,horizontal:false,radius:9*D});
      const back=im;const cy=Hh-110-(pose==='mounted'?bay/2:0);
      const dc=canvas(rail.maxX,Hh,D),dx=qmlContext(dc);
      const t0=performance.now();DeviceArt.bake(dx,{kind,pose,cy,pxmm,rail,compact:false,locked,D,gc,W:dc.width,H:dc.height,sealAt:[rail.maxX-16,cy]});const ms=performance.now()-t0;
      const d=dx.getImageData(0,0,dc.width,dc.height).data,a=pose==='unmounted'?.55:1;
      for(let y=0;y<dc.height;y++)for(let x=0;x<dc.width;x++){const i=(y*dc.width+x)*4,j=(y*W+x)*4,al=d[i+3]/255*a;if(!al)continue;for(let k=0;k<3;k++)back.data[j+k]=Math.round(d[i+k]*al+back.data[j+k]*(1-al));back.data[j+3]=255;}
      ctx.putImageData(back,0,0,0,0,back.width,back.height);ctx.fillStyle='#000';ctx.fillRect(0,0,1,H);
      const f=document.createElement('figure');f.append(cv);const c=document.createElement('figcaption');c.textContent=pose+' '+ms.toFixed(0)+'ms';f.append(c);wrap.append(f);
    }
    fig(s,wrap,dv.name+(locked?' · locked':''));
  }
};
</script></body>`;

(async () => {
  const {chromium} = require('playwright');
  const browser = await chromium.launch();
  const pg = await browser.newPage({viewport: {width: 1500, height: 900}, deviceScaleFactor: 1});
  const errors = [];
  pg.on('pageerror', e => errors.push(String(e)));
  pg.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await pg.setContent(page);
  const jobs = [['cards-light', 'renderCards', ['light', 1]], ['cards-dark', 'renderCards', ['dark', 1]], ['cards-hidpi', 'renderCards', ['light', 2]],
                ['chrome-light', 'renderChrome', ['light', 1]], ['chrome-dark', 'renderChrome', ['dark', 1]],
                ['devices-light', 'renderDevices', ['light', 1, false]], ['devices-locked', 'renderDevices', ['dark', 1, true]],
                ];
  // The default skin (quickshell/skins/default): its images for the skin and device sheets.
  const skinDir = q('skins/default'), skinFiles = {};
  const walk = d => fs.readdirSync(d, {withFileTypes: true}).forEach(e => { const f = path.join(d, e.name);
    if (e.isDirectory()) walk(f); else if (e.name.endsWith('.png')) skinFiles[path.relative(skinDir, f)] = 'data:image/png;base64,' + fs.readFileSync(f).toString('base64'); });
  walk(skinDir);
  await pg.evaluate(j => { window.__skin = j; }, JSON.parse(fs.readFileSync(path.join(skinDir, 'skin.json'), 'utf8')));
  jobs.forEach(j => { if (j[1] === 'renderDevices') j[2].push(skinFiles); });
  // The skin's material images installed as fields (what MaterialFields.qml does in the shell);
  // every sheet below renders on them.
  await pg.evaluate(async files => {
    const m = window.__skin.materials || {};
    for (const n in m) {
      const i = new Image(); i.src = files[m[n].image]; await i.decode();
      const c = document.createElement('canvas'); c.width = m[n].size[0]; c.height = m[n].size[1]; const x = c.getContext('2d'); x.drawImage(i, 0, 0);
      const d = x.getImageData(0, 0, c.width, c.height).data;
      if (n === 'ramps') M.setRamps(d, c.width, m[n].rows, m[n].lengths); else M.setField(n, c.width, c.height, d, {span: m[n].span});
    }
  }, skinFiles);

  jobs.push(['skin-light', 'renderSkin', ['light', 2, [{volume: .62, 'network.stage': 3, 'battery.present': true, 'battery.level': .7, 'battery.state': 'dis', 'notifications.unread': 2},
                                                       {volume: .2, 'network.stage': 0, 'network.connecting': true, 'battery.present': true, 'battery.level': .3, 'battery.state': 'chg', 'notifications.unread': 0},
                                                       {volume: .9, 'network.stage': 4, 'battery.present': true, 'battery.level': .95, 'battery.state': 'held', 'notifications.unread': 6}], skinFiles]],
            ['skin-dark', 'renderSkin', ['dark', 1, [{volume: .5, 'network.stage': 2, 'battery.present': false, 'notifications.unread': 1}], skinFiles]],
            ['skin-example', 'renderSkin', ['light', 2, [{volume: .4, 'network.stage': 2, 'battery.present': true, 'battery.level': .5, 'battery.state': 'dis', 'notifications.unread': 3}], skinFiles, true]]);
  // The example skin (quickshell/skins/example) over the default.
  const exDir = q('skins/example'), exFiles = {};
  const walkEx = d => fs.readdirSync(d, {withFileTypes: true}).forEach(e => { const f = path.join(d, e.name);
    if (e.isDirectory()) walkEx(f); else if (e.name.endsWith('.png')) exFiles[path.relative(exDir, f)] = 'data:image/png;base64,' + fs.readFileSync(f).toString('base64'); });
  walkEx(exDir);
  await pg.evaluate(([j, f]) => { window.__example = j; window.__exampleFiles = f; }, [JSON.parse(fs.readFileSync(path.join(exDir, 'skin.json'), 'utf8')), exFiles]);
  for (const [name, fn, args] of jobs) {
    await pg.evaluate(() => { document.querySelectorAll('.sheet').forEach(s => s.remove()); });
    try { await pg.evaluate(([f, a]) => window[f](...a), [fn, args]); if (fn === 'renderSkin') console.log('foot hits', JSON.stringify(await pg.evaluate(() => window.__hits))); } catch (e) { errors.push(name + ': ' + e.message); continue; }
    const el = await pg.$('.sheet');
    if (el) await el.screenshot({path: path.join(out, name + '.png')});
  }
  await browser.close();
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
  console.log('wrote', jobs.map(j => j[0] + '.png').join(' '), 'to', out);
})();
