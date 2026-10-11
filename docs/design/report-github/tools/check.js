// Offscreen check of the report-github page (WebKitGTK through gjs): console errors, overlaps,
// overflow, clipped text, target sizes and contrast failures, for every width, mode and state.
// Usage: gjs tools/check.js "$PWD/index.html"
imports.gi.versions.Gtk = '4.0'; imports.gi.versions.WebKit = '6.0';
const { Gtk, WebKit, GLib, Gio } = imports.gi;
Gtk.init();
const loop = GLib.MainLoop.new(null, false);
const ucm = new WebKit.UserContentManager();
ucm.add_script(new WebKit.UserScript("window.__errs=[];window.addEventListener('error',e=>__errs.push(e.message));const ce=console.error;console.error=(...a)=>{__errs.push(a.join(' '));ce(...a)};", WebKit.UserContentInjectedFrames.TOP_FRAME, WebKit.UserScriptInjectionTime.START, null, null));
const wv = new WebKit.WebView({ user_content_manager: ucm });
const win = new Gtk.Window({ default_width: 1440, default_height: 1400, child: wv });
win.realize();
const CHECK = `(()=>{
const out={errs:__errs.slice(),bad:[],cases:0,geo:{}};
const sel='.old .ab,.old .gl,.txt b,.txt small,.cr,.seg,.hn b,.hn small,.gh,.note,h3,.ent';
const R=e=>e.getBoundingClientRect();
const hit=(a,b)=>a.left<b.right-.5&&b.left<a.right-.5&&a.top<b.bottom-.5&&b.top<a.bottom-.5;
for(const theme of ['stock','green','wall'])for(const mode of ['dark','light'])for(const w of [518,436,360])for(const st of ['live','hover','press','focus','busy','copied','copiedh','none','ghover','gfocus']){
 Object.assign(S,{theme,mode,w,st});render();out.cases++;const tag=[theme,mode,w,st].join('/');
 for(const box of [document.getElementById('panel'),...document.querySelectorAll('.cell')]){
  const B=R(box),els=[...box.querySelectorAll(sel)].filter(e=>e.offsetParent!==null);
  els.forEach((a,i)=>{const ra=R(a);
   if(ra.right>B.right+.5||ra.left<B.left-.5)out.bad.push(tag+' overflow '+a.className);
   if(a.scrollWidth>a.clientWidth+1&&!a.classList.contains('ent'))out.bad.push(tag+' clipped '+a.className);
   els.slice(i+1).forEach(b=>{if(!a.contains(b)&&!b.contains(a)&&hit(ra,R(b)))out.bad.push(tag+' overlap '+a.className+' x '+b.className);});});
  for(const c of box.querySelectorAll('.cr')){const r=R(c);if(!c.classList.contains('f-press')&&(r.height!==44||r.width!==112))out.bad.push(tag+' button size '+r.width+'x'+r.height);
   for(const s of c.querySelectorAll('span')){const q=R(s);if(q.left<r.left+12||q.right>r.right-12)out.bad.push(tag+' label past padding');}}
  for(const g of box.querySelectorAll('.gh'))if(g.offsetParent){const r=R(g);if(r.width!==44||r.height!==44)out.bad.push(tag+' gh size');}}
 if(document.getElementById('contrast').textContent.includes('FAIL'))out.bad.push(tag+' contrast');
 if(theme==='stock'&&mode==='dark'&&(st==='live'||st==='none')){const row=document.getElementById('row'),t=R(row.querySelector('.txt')),c=R(row.querySelector('.cr'));
  out.geo[w+'/'+st]={content:R(document.getElementById('content')).width,txt:[t.width,t.height],btn:[c.width,c.height],mark:(m=>[m.left-c.right,m.top-c.top,m.width])(R(row.querySelector('.gi'))),tipFits:(q=>q.left>=R(document.getElementById('content')).left&&q.right<=R(document.getElementById('content')).right&&q.bottom<=R(document.getElementById('panel')).bottom)(R(row.querySelector('.tip'))),sameLine:c.top<t.bottom,btnLeftMinusTxtLeft:c.left-t.left,gapY:c.top-t.bottom,note:st==='none'?[R(row.querySelector('.hn')).width,R(row.querySelector('.hn')).height]:null};}}
out.dash=/[\\u2013\\u2014]/.test(document.documentElement.outerHTML);
out.net=/https?:|src=|href=|@import|url\\(/.test(document.documentElement.outerHTML);
return JSON.stringify(out);})()`;
wv.connect('load-changed', (v, ev) => { if (ev !== WebKit.LoadEvent.FINISHED) return;
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => { wv.evaluate_javascript(CHECK, -1, null, null, null, (o, res) => {
    try { const r = wv.evaluate_javascript_finish(res); print(r.to_string()); } catch (e) { print('EVAL ERROR ' + e.message); }
    loop.quit(); }); return GLib.SOURCE_REMOVE; }); });
wv.load_uri(Gio.File.new_for_path(ARGV[0]).get_uri());
loop.run();
