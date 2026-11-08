// A brief optical close-up of the cursor bubble. No library or downloaded texture.
(() => {
  'use strict';
  const root = document.documentElement;
  const title = document.querySelector('#title');
  const words = [...title.querySelectorAll('.intro-word')];
  const tape = document.querySelector('#tape');
  const replay = document.querySelector('#intro-replay');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const theme = matchMedia('(prefers-color-scheme: dark)');
  const storageKey = 'yap-intro-glass-v1';
  const duration = 2780;
  // A held frame is available only on local files / localhost for capture tools.
  const local = location.protocol === 'file:' || ['localhost', '127.0.0.1'].includes(location.hostname);
  const frame = local ? new URLSearchParams(location.search).get('intro-frame') : null;
  const review = frame !== null && Number.isFinite(Number(frame));
  const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  const mix = (a, b, t) => a + (b - a) * t;
  // Closed-form SwiftUI spring response, using Pill.swift's response/damping.
  function spring(t, response, damping) {
    if (t <= 0) return 0;
    const w = 2 * Math.PI / response, v = w * Math.sqrt(1 - damping * damping);
    return 1 - Math.exp(-damping * w * t) * (Math.cos(v * t) + damping * w / v * Math.sin(v * t));
  }
  let seen = false;
  try { seen = localStorage.getItem(storageKey) === '1'; } catch (_) {}
  let generation = 0, active = false, loading = false, interacted = false, raf = 0, deadline = 0;
  let canvas, gl, program, buffer, textures = [], u, layout, skip, started = 0, last = 0, slow = 0;
  const vertex = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';
  const fragment = `
precision highp float;
uniform vec2 viewport;
uniform float dpr,time,level,neck,redness;
uniform vec4 body,drop0,drop1,word0,word1,protectedRect;
uniform vec2 melt,inked;
uniform vec3 ink,pulse;
uniform sampler2D page,letters0,letters1;
float unite(float a,float b,float k){float h=max(k-abs(a-b),0.)/k;return min(a,b)-h*h*k*.25;}
float ellipse(vec2 p,vec4 b){vec2 q=(p-b.xy)/max(b.zw,vec2(.01));return (length(q)-1.)*min(b.z,b.w);}
float glyph(vec2 p,vec4 box,sampler2D tex){
  vec2 q=p-box.xy, limit=box.zw;
  vec2 uv=clamp(q/limit,0.,1.);
  return (dot(texture2D(tex,uv).rg,vec2(65280.,255.))-32768.)/32.+length(q-clamp(q,vec2(0.),limit));
}
vec3 distances(vec2 p){
  vec2 q=p;
  q.x+=sin((p.y-body.y)*.038+time*6.)*level*2.5;
  q.y+=sin((p.x-body.x)*.026-time*5.)*level*3.2;
  float a=ellipse(q,body);
  float b=inked.x>.99||drop0.z<.1?10000.:mix(ellipse(p,drop0),glyph(p,word0,letters0),melt.x);
  float c=inked.y>.99||drop1.z<.1?10000.:mix(ellipse(p,drop1),glyph(p,word1,letters1),melt.y);
  return vec3(a,b,c);
}
float surface(vec2 p){vec3 d=distances(p);return unite(unite(d.x,d.y,max(neck, .01)),d.z,max(neck, .01));}
vec3 behind(vec2 p){return texture2D(page,clamp(p/viewport,vec2(0.),vec2(1.))).rgb;}
void main(){
  vec2 p=vec2(gl_FragCoord.x/dpr,viewport.y-gl_FragCoord.y/dpr);
  if(p.x>protectedRect.x&&p.x<protectedRect.z&&p.y>protectedRect.y&&p.y<protectedRect.w)discard;
  float d=surface(p);
  if(d>28.)discard;
  vec3 ds=distances(p);
  float which=ds.y<ds.x&&ds.y<ds.z?1.:ds.z<ds.x?2.:0.;
  float morph=which==1.?melt.x:which==2.?melt.y:0.;
  if(morph>.985){
    vec4 box=which==1.?word0:word1;vec2 uv=(p-box.xy)/box.zw;
    float alpha=which==1.?texture2D(letters0,clamp(uv,0.,1.)).b:texture2D(letters1,clamp(uv,0.,1.)).b;
    gl_FragColor=vec4(ink,alpha);return;
  }
  vec2 gradient=vec2(surface(p+vec2(.65,0.))-surface(p-vec2(.65,0.)),surface(p+vec2(0.,.65))-surface(p-vec2(0.,.65)));
  vec2 n=gradient/max(length(gradient),.0001);
  if(d>0.){
    float shadow=exp(-max(surface(p-vec2(1.,6.)),0.)/5.)*.075*(1.-smoothstep(.55,.985,morph));
    float caustic=exp(-pow((d-5.)/2.8,2.))*max(dot(n,normalize(vec2(.5,.85))),0.)*.16*(1.-smoothstep(.55,.985,morph));
    gl_FragColor=vec4(mix(vec3(.10,.07,.05),vec3(1.),caustic/(shadow+caustic+.001)),max(shadow,caustic));return;
  }
  // Thick edge, almost empty centre: magnification and rim distortion sample
  // the actual page. No milky fill, broad softbox reflection or backdrop blur.
  float depth=-d;
  vec2 centre=which==1.?drop0.xy:which==2.?drop1.xy:body.xy;
  vec2 refract=(p-centre)*.17+n*10.*exp(-depth/9.);
  float fringe=.65*exp(-depth/6.);
  vec3 color;
  color.r=behind(p-refract-n*fringe).r;
  color.g=behind(p-refract).g;
  color.b=behind(p-refract+n*fringe).b;
  color=mix(color,vec3(1.),.008);
  float light=dot(n,normalize(vec2(-.55,-.83)));
  float rim=exp(-pow((depth-1.)/1.05,2.));
  float inner=exp(-pow((depth-4.)/1.9,2.));
  color*=1.-inner*.1;
  color=mix(color,vec3(1.),rim*(.38+.50*max(light,0.)));
  float highlight=exp(-pow((depth-6.)/2.0,2.))*pow(max(light,0.),16.);
  color=mix(color,vec3(1.),highlight*.65);
  float fill=which==1.?smoothstep(.45,.9,melt.x):which==2.?smoothstep(.45,.9,melt.y):redness;
  color=mix(color,which==0.?pulse:ink,fill);
  // The recording light is seen through the parent lens, not a glow behind it.
  float distanceToLight=length(p-(body.xy+vec2(-body.z*.48,0.)));
  float dot=1.-smoothstep(4.5+level*1.5,5.5+level*1.5,distanceToLight);
  float ring=1.-smoothstep(.5,1.4,abs(distanceToLight-(7.+level*7.)));
  if(which==0.)color=mix(color,pulse,(dot*.9+ring*(.12+.45*level))*(1.-redness));
  gl_FragColor=vec4(color,1.-smoothstep(-.8,0.,d));
}`;

  function remember() { seen = true; try { localStorage.setItem(storageKey, '1'); } catch (_) {} }
  function dispose() {
    if (gl) {
      textures.forEach(t => gl.deleteTexture(t));
      if (buffer) gl.deleteBuffer(buffer);
      if (program) gl.deleteProgram(program);
      if (!gl.isContextLost()) gl.getExtension('WEBGL_lose_context')?.loseContext();
    }
    textures = []; buffer = program = null;
    canvas?.remove(); canvas = gl = null;
  }
  function finish(reason) {
    generation++; active = loading = false;
    cancelAnimationFrame(raf); clearTimeout(deadline);
    root.classList.remove('intro-playing'); root.dataset.intro = reason;
    words.forEach(w => w.style.removeProperty('visibility'));
    skip?.remove(); skip = null; dispose();
    replay.textContent = 'replay intro';
  }
  function geometry() {
    const mobile = innerWidth <= 760;
    const lead = document.querySelector('.cover .lead').getBoundingClientRect();
    const install = document.querySelector('.cover .get').getBoundingClientRect();
    const caret = document.querySelector('.caret').getBoundingClientRect();
    const origin = mobile ? [innerWidth * .54, lead.top + 62] : [355, lead.top + 52];
    const target = [Math.max(12, Math.min(innerWidth - 12, caret.x + 1)), caret.bottom + 14 < innerHeight - 12 ? caret.bottom + 14 : caret.top - 12];
    if(caret.top<0||caret.top>innerHeight)target.splice(0,2,Math.min(innerWidth-18,title.getBoundingClientRect().right-8),title.getBoundingClientRect().bottom+12);
    return { mobile, origin, target, radii: mobile ? [126,50] : [230,70], words: words.map(w => w.getBoundingClientRect()),
      protected: [install.left-8,install.top-8,install.right+8,install.bottom+8] };
  }
  async function svgImage(content, width, height) {
    const image = new Image();
    image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="'+width+'" height="'+height+'"><foreignObject width="100%" height="100%">'+content+'</foreignObject></svg>');
    await image.decode(); return image;
  }
  async function snapshot() {
    const wrapper = document.createElement('div');
    wrapper.setAttribute('xmlns','http://www.w3.org/1999/xhtml');
    // Resolved styles work on file:// too, where reading stylesheet.cssRules
    // is forbidden. Freeze the measured layout rather than maintaining a second CSS.
    const properties = ['display','position','box-sizing','left','top','right','bottom','width','height','min-width','min-height','max-width','max-height','margin','padding','border-top','border-right','border-bottom','border-left','border-radius','background','color','font-family','font-size','font-weight','font-style','line-height','letter-spacing','text-align','text-indent','text-transform','text-decoration','white-space','word-break','overflow-wrap','overflow','flex','flex-direction','flex-wrap','align-items','align-self','justify-content','gap','order','transform','transform-origin','box-shadow','vertical-align','opacity','visibility'];
    const style = getComputedStyle(document.body);
    wrapper.style.cssText = 'width:'+innerWidth+'px;height:'+innerHeight+'px;overflow:hidden;background:'+style.backgroundColor+';color:'+style.color+';font:'+style.font+';-webkit-font-smoothing:antialiased;';
    const tokens = getComputedStyle(root);
    for(const key of tokens) if(key.startsWith('--')) wrapper.style.setProperty(key,tokens.getPropertyValue(key));
    for(const selector of ['.masthead','#tape','.transport']) {
      const source = document.querySelector(selector), clone = source.cloneNode(true);
      const originals = [source,...source.querySelectorAll('*')];
      [clone,...clone.querySelectorAll('*')].forEach((node,i)=>{
        const computed=getComputedStyle(originals[i]);
        node.style.cssText=properties.map(key=>key+':'+computed.getPropertyValue(key)).join(';');
      });
      if(selector==='#tape') [...clone.children].slice(3).forEach(e => e.remove());
      // The lens stays below the brand images. Avoid file-origin image tainting
      // and decoding unrelated screenshots just to render this brief opening.
      clone.querySelectorAll('img,canvas').forEach(e => e.style.visibility='hidden');
      clone.querySelectorAll('img').forEach(e => e.removeAttribute('src'));
      clone.querySelectorAll('.intro-word').forEach(e => e.style.visibility='hidden');
      wrapper.append(clone);
    }
    return svgImage(new XMLSerializer().serializeToString(wrapper),innerWidth,innerHeight);
  }
  // Squared Euclidean distance transform (Felzenszwalb/Huttenlocher). The two
  // signed fields let a drop continuously become letter geometry, not fade in.
  function distanceTransform(data, width, height) {
    const out = new Float32Array(data), max = Math.max(width,height);
    const f = new Float32Array(max), v = new Int32Array(max), z = new Float32Array(max+1), d = new Float32Array(max);
    function line(n) {
      let k=0;v[0]=0;z[0]=-Infinity;z[1]=Infinity;
      for(let q=1;q<n;q++) { let s;do { s=((f[q]+q*q)-(f[v[k]]+v[k]*v[k]))/(2*q-2*v[k]);if(s<=z[k])k--;else break; }while(k>=0);k++;v[k]=q;z[k]=s;z[k+1]=Infinity; }
      k=0;for(let q=0;q<n;q++){while(z[k+1]<q)k++;d[q]=(q-v[k])*(q-v[k])+f[v[k]];}
    }
    for(let x=0;x<width;x++){for(let y=0;y<height;y++)f[y]=out[y*width+x];line(height);for(let y=0;y<height;y++)out[y*width+x]=d[y];}
    for(let y=0;y<height;y++){for(let x=0;x<width;x++)f[x]=out[y*width+x];line(width);for(let x=0;x<width;x++)out[y*width+x]=d[x];}
    return out;
  }
  async function wordField(el, rect) {
    const cs=getComputedStyle(el), pad=32, width=Math.ceil(rect.width)+pad*2, height=Math.ceil(parseFloat(cs.lineHeight))+pad*2;
    // Inline span bounds include font ascenders outside the line box. Anchor the
    // raster to the heading's actual line top, otherwise it jumps 10 px on handover.
    const lineTop=title.getBoundingClientRect().top+rect.top-layout.words[0].top;
    const wrap=document.createElement('div');
    wrap.setAttribute('xmlns','http://www.w3.org/1999/xhtml');
    wrap.style.cssText='padding:32px;margin:0;color:#fff;white-space:nowrap;';
    for(const key of ['font-family','font-size','font-weight','line-height','letter-spacing'])wrap.style.setProperty(key,cs.getPropertyValue(key));
    wrap.textContent=el.textContent;
    const image=await svgImage(new XMLSerializer().serializeToString(wrap),width,height);
    const c=document.createElement('canvas');c.width=width;c.height=height;
    const ctx=c.getContext('2d',{willReadFrequently:true});ctx.drawImage(image,0,0);
    const pixels=ctx.getImageData(0,0,width,height), inside=new Float32Array(width*height),outside=new Float32Array(width*height);
    for(let i=0;i<inside.length;i++){const on=pixels.data[i*4+3]>127;inside[i]=on?0:1e9;outside[i]=on?1e9:0;}
    const a=distanceTransform(inside,width,height),b=distanceTransform(outside,width,height);
    for(let i=0;i<a.length;i++){const value=Math.round(Math.max(0,Math.min(65535,32768+32*(Math.sqrt(a[i])-Math.sqrt(b[i])))));pixels.data[i*4]=value>>8;pixels.data[i*4+1]=value&255;pixels.data[i*4+2]=pixels.data[i*4+3];pixels.data[i*4+3]=255;}
    ctx.putImageData(pixels,0,0);
    return {image:c,box:[rect.x-pad,lineTop-pad,width,height]};
  }
  function makeGL() {
    canvas=document.createElement('canvas');canvas.className='intro-canvas';canvas.setAttribute('aria-hidden','true');
    gl=canvas.getContext('webgl',{alpha:true,antialias:false,premultipliedAlpha:false,powerPreference:'low-power',failIfMajorPerformanceCaveat:true});
    if(!gl)throw new Error('no-webgl');
    canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();if(e.currentTarget===canvas&&(active||loading))finish('context-lost');});
    const compile=(kind,source)=>{const s=gl.createShader(kind);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)){gl.deleteShader(s);throw new Error('shader');}return s;};
    const vs=compile(gl.VERTEX_SHADER,vertex),fs=compile(gl.FRAGMENT_SHADER,fragment);
    program=gl.createProgram();gl.attachShader(program,vs);gl.attachShader(program,fs);gl.linkProgram(program);gl.deleteShader(vs);gl.deleteShader(fs);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw new Error('program');
    gl.useProgram(program);buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);
    const p=gl.getAttribLocation(program,'p');gl.enableVertexAttribArray(p);gl.vertexAttribPointer(p,2,gl.FLOAT,false,0,0);
    u=Object.fromEntries(['viewport','dpr','time','level','neck','redness','body','drop0','drop1','word0','word1','protectedRect','melt','inked','ink','pulse','page','letters0','letters1'].map(k=>[k,gl.getUniformLocation(program,k)]));
    const ratio=Math.min(devicePixelRatio,layout.mobile?1.5:1.75);
    canvas.width=Math.round(innerWidth*ratio);canvas.height=Math.round(innerHeight*ratio);gl.viewport(0,0,canvas.width,canvas.height);
    gl.uniform2f(u.viewport,innerWidth,innerHeight);gl.uniform1f(u.dpr,ratio);gl.uniform4fv(u.protectedRect,layout.protected);
    gl.uniform3f(u.ink,23/255,21/255,19/255);gl.uniform3f(u.pulse,1,theme.matches?69/255:59/255,theme.matches?58/255:48/255);
  }
  function upload(image, unit, name) {
    const tex=gl.createTexture();textures.push(tex);gl.activeTexture(gl.TEXTURE0+unit);gl.bindTexture(gl.TEXTURE_2D,tex);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.uniform1i(u[name],unit);
    if(gl.getError()!==gl.NO_ERROR)throw new Error('texture');
  }
  function draw(ms) {
    if(!active)return;
    const t=ms/1000,l=layout;
    // Four syllabic level changes, filtered by the app's .28/.86 spring.
    const level=.13+.7*spring(t-.06,.28,.86)-.55*spring(t-.24,.28,.86)+.72*spring(t-.42,.28,.86)-.65*spring(t-.62,.28,.86)+.54*spring(t-.81,.28,.86)-.69*spring(t-1.05,.28,.86);
    const contract=Math.min(1,spring(t-2.04,.35,.9));
    const grow=Math.min(1,spring(t,.3,.9));
    const volume=1-.27*smooth(.6,1.75,t);
    const body=[mix(l.origin[0],l.target[0],contract),mix(l.origin[1],l.target[1],contract),mix(l.radii[0]*volume*(1+level*.035)*grow,5,contract),mix(l.radii[1]*volume*(1-level*.025)*grow,5,contract)];
    gl.uniform4fv(u.body,body);gl.uniform1f(u.level,Math.max(0,level)*(1-contract));
    gl.uniform1f(u.time,t);gl.uniform1f(u.neck,34*(1-smooth(.85,1.35,t))+.01);
    gl.uniform1f(u.redness,smooth(2.18,2.45,t));
    const morph=[],done=[];
    l.words.forEach((r,i)=>{
      const delay=.42+i*.24;
      const pull=Math.min(1,spring(t-delay,.65,.86));
      const m=smooth(delay+.58,delay+1.2,t);
      const dest=[r.x+r.width/2,r.y+r.height/2];
      const origin=[l.origin[0]-l.radii[0]*.35+i*32,l.origin[1]-l.radii[1]*.45];
      const x=mix(origin[0],dest[0],pull),y=mix(origin[1],dest[1],pull);
      const radius=(l.mobile?27:36)*smooth(delay-.18,delay+.14,t);
      const spread=smooth(0,.42,m);
      gl.uniform4fv(u[i?'drop1':'drop0'],[x,y,Math.max(.01,mix(radius*(1+Math.sin(pull*Math.PI)*.32),r.width*.53,spread)),Math.max(.01,mix(radius*(1-Math.sin(pull*Math.PI)*.18),r.height*.43,spread))]);
      morph.push(m);done.push(m===1?1:0);words[i].style.visibility=m===1?'visible':'hidden';
    });
    gl.uniform2fv(u.melt,morph);gl.uniform2fv(u.inked,done);
    gl.clearColor(0,0,0,0);gl.clear(gl.COLOR_BUFFER_BIT);gl.drawArrays(gl.TRIANGLES,0,6);
    canvas.style.opacity=String(1-smooth(2.65,2.78,t));
    root.dataset.introTime=String(Math.round(ms));
    if(ms>=duration)finish('complete');
  }
  function tick(now) {
    if(!active)return;
    slow=last&&now-last>80?slow+1:Math.max(0,slow-1);last=now;
    if(slow>10){finish('slow-device');return;}
    draw(now-started);if(active)raf=requestAnimationFrame(tick);
  }
  async function start(manual=false) {
    finish('preparing');
    if(motion.matches){root.dataset.intro='reduced-motion';return;}
    if(navigator.connection?.saveData||(navigator.deviceMemory&&navigator.deviceMemory<=2)||navigator.hardwareConcurrency<=2){root.dataset.intro='low-power';return;}
    if(!manual&&(seen||interacted||location.hash||scrollY>0||tape.scrollLeft>0)){root.dataset.intro=seen?'seen':'reading';return;}
    if(manual&&(scrollY>0||tape.scrollLeft>0)){
      // Replay deliberately returns to the cover; automatic playback never does.
      window.scrollTo({top:0,behavior:'instant'});tape.scrollTo({left:0,behavior:'instant'});
      await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
    }
    interacted=false;loading=true;remember();delete root.dataset.introFailure;const token=++generation;
    // If fonts, SVG decoding or the GPU stall, normal HTML wins.
    deadline=setTimeout(()=>{if(token===generation)finish('timeout');},1800);
    try {
      await document.fonts.ready;
      if(token!==generation)return;
      layout=geometry();makeGL();
      const [page,...fields]=await Promise.all([snapshot(),...words.map((w,i)=>wordField(w,layout.words[i]))]);
      if(token!==generation)return;
      upload(page,0,'page');fields.forEach((f,i)=>{upload(f.image,i+1,i?'letters1':'letters0');gl.uniform4fv(u[i?'word1':'word0'],f.box);});
      clearTimeout(deadline);loading=false;active=true;last=slow=0;remember();
      document.body.append(canvas);root.classList.add('intro-playing');root.dataset.intro='playing';
      skip=document.createElement('button');skip.type='button';skip.className='intro-skip';skip.textContent='skip intro';skip.addEventListener('click',()=>finish('skipped'));document.body.append(skip);
      started=performance.now();draw(review?Math.max(0,Math.min(duration,Number(frame))):0);
      if(!review)raf=requestAnimationFrame(tick);
    }catch(error){if(token===generation){root.dataset.introFailure=error.message;finish('unavailable');}}
  }
  function cancel(event) {
    if(event.target===replay&&event.type!=='keydown')return;
    if(event.target===replay&&event.type==='keydown'&&(active||loading)&&['Enter',' '].includes(event.key))event.preventDefault();
    interacted=true;
    if(!seen&&!motion.matches)remember();
    if(active||loading)finish('skipped');
  }
  for(const type of ['pointerdown','click','touchstart','wheel'])document.addEventListener(type,cancel,{capture:true,passive:true});
  document.addEventListener('keydown',cancel,{capture:true});
  document.addEventListener('scroll',cancel,{capture:true,passive:true});
  addEventListener('resize',()=>{if(active||loading)finish('resized');});
  motion.addEventListener('change',()=>{replay.hidden=motion.matches;if(motion.matches)finish('reduced-motion');});
  theme.addEventListener('change',()=>{if(active||loading)finish('theme-changed');});
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&(active||loading))finish('hidden');});
  replay.hidden=motion.matches;
  replay.addEventListener('click',()=>start(true));
  if(review)window.yapIntro={seek:draw,loseContext:()=>gl?.getExtension('WEBGL_lose_context')?.loseContext()};
  // Content and install paint before enhancement. An early interaction cancels it.
  requestAnimationFrame(()=>requestAnimationFrame(()=>start(review)));
})();
