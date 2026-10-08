#!/usr/bin/env python3
"""Yap / Spoken caret. Deterministic vector geometry + supersampled sRGB rendering.
Run: python3 icon/generate.py
Dependencies: Pillow, numpy. All writes are relative to this file, never to cwd.
"""
from pathlib import Path
import argparse
import math
import subprocess
import struct
import tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops, ImageCms

ROOT = Path(__file__).resolve().parent
S = 2
N = 1024 * S
ICC = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
Y, X = np.mgrid[0:N, 0:N].astype(np.float32) / S

class Shape:
    def __init__(self): self.points=[]; self.svg=[]; self.current=(0,0)
    def move(self,x,y): self.points.append((x,y)); self.current=(x,y); self.svg.append(f'M{x} {y}'); return self
    def line(self,x,y): self.points.append((x,y)); self.current=(x,y); self.svg.append(f'L{x} {y}'); return self
    def curve(self,a,b,c,d,x,y):
        p=self.current
        for t in np.linspace(0,1,65)[1:]:
            u=1-t
            self.points.append((u**3*p[0]+3*u*u*t*a+3*u*t*t*c+t**3*x,u**3*p[1]+3*u*u*t*b+3*u*t*t*d+t**3*y))
        self.current=(x,y); self.svg.append(f'C{a} {b} {c} {d} {x} {y}'); return self
    def close(self): self.svg.append('Z'); return self
    def mask(self):
        m=Image.new('L',(N,N)); ImageDraw.Draw(m).polygon([(round(x*S),round(y*S)) for x,y in self.points],fill=255); return m
    def path(self,fill): return f'<path d="{" ".join(self.svg)}" fill="{fill}"/>'

def bubble(revision=1):
    if revision >= 2:
        return (Shape().move(412,260).line(613,260)
           .curve(740,260,817,337,817,451).line(817,483)
           .curve(817,594,746,658,620,658).line(465,658)
           .curve(426,699,389,724,337,730)
           .curve(324,732,320,721,331,711)
           .curve(350,692,358,670,356,641)
           .curve(263,617,207,558,207,475).line(207,453)
           .curve(207,336,282,260,412,260).close())
    return (Shape().move(415,270).line(610,270)
       .curve(728,270,801,345,801,452).line(801,482)
       .curve(801,588,735,654,620,654).line(477,654)
       .curve(430,711,383,744,320,754)
       .curve(307,756,302,747,311,736)
       .curve(341,700,351,675,351,638)
       .curve(270,614,223,557,223,474).line(223,453)
       .curve(223,344,295,270,415,270).close())

def body_mask():
    angles=np.linspace(0,2*math.pi,2049)
    pts=[(512+412*math.copysign(abs(math.cos(t))**(2/4.4),math.cos(t)),512+412*math.copysign(abs(math.sin(t))**(2/4.4),math.sin(t))) for t in angles]
    m=Image.new('L',(N,N)); ImageDraw.Draw(m).polygon([(round(x*S),round(y*S)) for x,y in pts],fill=255); return m

def rounded_mask(rect,r):
    m=Image.new('L',(N,N)); ImageDraw.Draw(m).rounded_rectangle(tuple(round(v*S) for v in rect),radius=r*S,fill=255); return m

def gray(v):
    a=np.clip(np.broadcast_to(v,(N,N)),0,255).astype(np.uint8)
    return Image.fromarray(np.stack((a,a,a,np.full_like(a,255)),axis=-1),'RGBA')

def put(base,paint,mask):
    if not isinstance(paint,Image.Image): paint=Image.new('RGBA',(N,N),paint)
    paint=paint.copy(); paint.putalpha(mask); base.alpha_composite(paint)

def scaled(mask,factor): return mask.point(lambda v:round(v*factor))

def shift(mask,dx,dy):
    out=Image.new('L',mask.size); out.paste(mask,(round(dx*S),round(dy*S))); return out

def rim(mask,width):
    # Separable square erosion; avoids Pillow's quadratic rank-filter cost.
    radius=round(width*S); a=np.asarray(mask); eroded=a.copy()
    for axis in (0,1):
        pads=[(0,0),(0,0)]; pads[axis]=(radius,radius)
        p=np.pad(eroded,pads); out=np.full_like(a,255)
        for offset in range(2*radius+1):
            window=p[offset:offset+N,:] if axis==0 else p[:,offset:offset+N]
            np.minimum(out,window,out=out)
        eroded=out
    return Image.fromarray(a-eroded)

def save(im,path):
    path.parent.mkdir(parents=True,exist_ok=True)
    im.save(path,icc_profile=ICC)

def font(size,bold=False):
    p='/Library/Fonts/SF-Compact-Display-'+('Semibold' if bold else 'Regular')+'.otf'
    if not Path(p).exists(): p='/System/Library/Fonts/Supplemental/Arial.ttf'
    return ImageFont.truetype(p,size)

def render(revision,output_size=1024):
    base=Image.new('RGBA',(N,N)); body=body_mask(); speech=bubble(revision).mask()
    # A restrained physical shadow outside the compatibility tile.
    put(base,(0,0,0,255),scaled(shift(body,0,15).filter(ImageFilter.GaussianBlur(17*S)),.25))
    put(base,(0,0,0,255),scaled(shift(body,0,3).filter(ImageFilter.GaussianBlur(3*S)),.20))
    bg=46-21*(Y-100)/824 + 17*np.exp(-((X-390)/550)**2-((Y-155)/330)**2)
    if revision >= 2: bg=51-16*(Y-100)/824 + 10*np.exp(-((X-512)/550)**2-((Y-155)/330)**2)
    put(base,gray(bg),body)
    # All lighting is achromatic, with a vertical source, never a rainbow sheen.
    edge=rim(body,1.5)
    put(base,gray(138-65*(Y/1024)),scaled(edge,.80))
    inner=rim(body,3.5)
    put(base,(255,255,255,255),scaled(inner,.06))
    background=base.copy()
    base=Image.new('RGBA',(N,N))
    put(base,(0,0,0,255),scaled(shift(speech,0,16).filter(ImageFilter.GaussianBlur(14*S)),.45))
    put(base,(255,255,255,255),scaled(speech.filter(ImageFilter.GaussianBlur(30*S)),.08))
    glass=238-68*(Y-270)/485 + 18*np.exp(-((X-420)/340)**2-((Y-340)/180)**2)
    if revision >= 2: glass=219-33*(Y-260)/470 + 23*np.exp(-((X-512)/390)**2-((Y-290)/145)**2)
    if revision >= 3:
        glass += 10*np.exp(-((Y-575)/90)**2) - 10*np.exp(-((X-775)/135)**2-((Y-470)/180)**2)
    put(base,gray(glass),speech)
    # Broad transmitted light below, thin bright lip above.
    frost=ImageChops.multiply(rim(speech,11 if revision==1 else 5).filter(ImageFilter.GaussianBlur(3*S)),speech)
    put(base,gray(195+40*(Y/1024)),scaled(frost,.45))
    lip=rim(speech,2.0 if revision==1 else 1.5)
    put(base,gray(255-40*(Y-270)/485),scaled(lip,.92))
    if revision >= 3:
        # Narrow transmitted-light band, subordinate to the silhouette.
        transmitted=ImageChops.multiply(rim(speech,7),speech)
        light=np.clip((Y-460)/230,0,1)*.28
        alpha=Image.fromarray((np.asarray(transmitted)*light).astype(np.uint8))
        put(base,(250,250,250,255),alpha)
    bars=[(365,419,411,515),(467,375,513,559),(610,352,652,582)]
    if revision >= 2: bars=[(347,392,409,536),(469,416,531,512),(622,345,672,583)]
    if revision >= 3:
        bars=[(347,384,409,544),(469,416,531,512),(622,345,678,583)]
        if output_size<=32:
            bars=[(320,384,384,544),(448,416,512,512),(640,320,704,576)]
    for i,rect in enumerate(bars):
        m=rounded_mask(rect,(21 if revision==1 else 31) if i<2 else 12)
        # A subtle lower caustic keeps the apertures looking cut through glass.
        put(base,(255,255,255,255),scaled(shift(m,0,3).filter(ImageFilter.GaussianBlur(2*S)),.7))
        put(base,gray(48-15*(Y-352)/230),m)
    foreground=base.copy()
    combined=background.copy(); combined.alpha_composite(foreground)
    return combined,background,foreground,bars

def svg_doc(content):
    return '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'+content+'\n</svg>\n'

def export_layers(background,foreground,bars,revision):
    folder=ROOT/'layers'; folder.mkdir(exist_ok=True)
    # Composer uses full-bleed coordinates. Undo the 824/1024 compatibility inset.
    transform='translate(-124.27184466 -124.27184466) scale(1.2427184466)'
    (folder/'01-background.svg').write_text(svg_doc('<rect width="1024" height="1024" fill="#292929"/>'))
    (folder/'02-speech.svg').write_text(svg_doc(f'<g transform="{transform}">'+bubble(revision).path('#eeeeee')+'</g>'))
    wave=''; caret=''
    for i,(x0,y0,x1,y1) in enumerate(bars):
        rect=f'<rect x="{x0}" y="{y0}" width="{x1-x0}" height="{y1-y0}" rx="{(21 if revision==1 else 31) if i<2 else 12}" fill="#292929"/>'
        if i<2: wave+=rect
        else: caret+=rect
    (folder/'03-voice.svg').write_text(svg_doc(f'<g transform="{transform}">{wave}</g>'))
    (folder/'04-caret.svg').write_text(svg_doc(f'<g transform="{transform}">{caret}</g>'))
    save(background.resize((1024,1024),Image.Resampling.LANCZOS),folder/'background-rendered.png')
    save(foreground.resize((1024,1024),Image.Resampling.LANCZOS),folder/'foreground-rendered.png')

def standin(kind,size):
    n=384; im=Image.new('RGBA',(n,n)); d=ImageDraw.Draw(im)
    colors={'files':('#a6daef','#dceff7'),'notes':('#f5c95f','#fff8df'),'compass':('#67bbdf','#e2f7fc')}
    c,_=colors[kind]; d.rounded_rectangle((38,38,346,346),radius=76,fill=c)
    if kind=='files':
        d.rounded_rectangle((103,134,285,265),radius=21,fill='#eef9fc')
        d.rounded_rectangle((103,109,187,161),radius=15,fill='#eef9fc')
    if kind=='notes':
        d.rounded_rectangle((107,97,277,290),radius=13,fill='#fffbed')
        for y in (155,195,235): d.rounded_rectangle((130,y,252,y+9),radius=4,fill='#c0bbaa')
    if kind=='compass':
        d.ellipse((86,86,298,298),fill='#edf8fc',outline='#ffffff',width=5)
        d.polygon([(230,122),(211,211),(154,262),(173,173)],fill='#39728e')
        d.polygon([(230,122),(211,211),(173,173)],fill='#ec6b63')
    return im.resize((size,size),Image.Resampling.LANCZOS)

def preview(icons,revision):
    # Both 1024 px examples are literal 1024 raster pixels in the PNG.
    w,h=1744,2540
    board=Image.new('RGBA',(w,h),'#eeefef'); d=ImageDraw.Draw(board)
    for row,dark in enumerate((False,True)):
        y0=row*1120; bg='#1b1d20' if dark else '#eeefef'; ink='#f0f1f2' if dark else '#25282b'; muted='#95999e' if dark else '#73777a'
        d.rectangle((0,y0,w,y0+1120),fill=bg)
        d.text((42,y0+25),'yap',font=font(35,True),fill=ink)
        d.text((127,y0+37),f'SPOKEN CARET  /  {"DARK" if dark else "LIGHT"}  /  REVISION {revision:02}',font=font(15),fill=muted)
        for size,x in [(1024,18),(256,1078),(64,1380),(32,1500),(16,1608)]:
            y=y0+68+(1024-size)//2
            board.alpha_composite(icons[size],(x,y))
            d.text((x+size/2,y+size+13),str(size)+' px',font=font(16),fill=muted,anchor='mt')
        # Magnified nearest-neighbor samples reveal actual pixel behavior.
        for size,x in [(32,1160),(16,1432)]:
            board.alpha_composite(icons[size].resize((192,192),Image.Resampling.NEAREST),(x,y0+790))
            d.text((x+96,y0+995),f'{size} px · pixel inspection',font=font(15),fill=muted,anchor='mt')
    d.rectangle((0,2240,w,h),fill='#c1c9ce')
    d.text((42,2270),'Dock context',font=font(22,True),fill='#30383d')
    d.text((42,2305),'Yap with three simple stand-ins',font=font(16),fill='#58636b')
    d.rounded_rectangle((638,2260,1178,2475),radius=43,fill='#dce1e4',outline='#edf0f1',width=2)
    for i,kind in enumerate(('files','compass','yap','notes')):
        x=652+i*129; item=icons[128] if kind=='yap' else standin(kind,128)
        board.alpha_composite(item,(x,2292))
        d.text((x+64,2426),{'files':'Files','compass':'Browser','yap':'Yap','notes':'Notes'}[kind],font=font(14),fill='#505960',anchor='mt')
    d.ellipse((968,2450,972,2454),fill='#505960')
    save(board.convert('RGB'),ROOT/'preview.png')


def correct_legacy_alpha():
    """Work around iconutil's ic04/ic05 straight-alpha encoding on this Mac.

    Probe first: on systems without the bug the iconutil output is left alone.
    Retain its ICNS container; repair only legacy ARGB chunks with premultiplied
    bytes. Eight modern PNG representations are unchanged. 8-bit premultiplication
    necessarily introduces sub-one-level compositing quantization at soft edges.
    """
    replacements={}
    with tempfile.TemporaryDirectory(prefix='.icon-check-',dir=ROOT) as td:
        decoded=Path(td)/'decoded.iconset'
        subprocess.run(['/usr/bin/iconutil','-c','iconset',str(ROOT/'AppIcon.icns'),'-o',str(decoded)],check=True)
        for size,kind in ((16,b'ic04'),(32,b'ic05')):
            name=f'icon_{size}x{size}.png'
            a=np.asarray(Image.open(ROOT/'AppIcon.iconset'/name).convert('RGBA')).astype(np.float32)
            b=np.asarray(Image.open(decoded/name).convert('RGBA')).astype(np.float32)
            error=np.abs((a[:,:,:3]-b[:,:,:3])*a[:,:,3:4]/255).max()
            if error<=1: continue
            rgba=a.astype(np.uint16)
            rgba[:,:,:3]=(rgba[:,:,:3]*rgba[:,:,3:4]+127)//255
            raw=rgba[:,:,[3,0,1,2]].transpose(2,0,1).astype(np.uint8).tobytes()
            # Valid literal runs in Apple's planar ARGB byte-run encoding.
            replacements[kind]=b'ARGB'+b''.join(bytes([len(raw[i:i+128])-1])+raw[i:i+128] for i in range(0,len(raw),128))
    if replacements:
        data=(ROOT/'AppIcon.icns').read_bytes(); offset=8; chunks=[]
        while offset<len(data):
            kind,length=struct.unpack_from('>4sI',data,offset)
            payload=replacements.get(kind,data[offset+8:offset+length])
            chunks.append(struct.pack('>4sI',kind,len(payload)+8)+payload)
            offset+=length
        body=b''.join(chunks)
        (ROOT/'AppIcon.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
        print('Corrected legacy 16/32 px alpha after iconutil packaging.')


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--revision',type=int,default=3,choices=(1,2,3)); args=ap.parse_args()
    master,background,foreground,bars=render(args.revision)
    icons={size:master.resize((size,size),Image.Resampling.LANCZOS) for size in (16,32,64,128,256,512,1024)}
    if args.revision>=3:
        small=render(args.revision,16)[0]
        for size in (16,32): icons[size]=small.resize((size,size),Image.Resampling.LANCZOS)
    save(icons[1024],ROOT/'icon-1024.png')
    folder=ROOT/'AppIcon.iconset'; folder.mkdir(exist_ok=True)
    for point in (16,32,128,256,512):
        for scale in (1,2):
            suffix='@2x' if scale==2 else ''
            save(icons[point*scale],folder/f'icon_{point}x{point}{suffix}.png')
    export_layers(background,foreground,bars,args.revision)
    preview(icons,args.revision)
    hist=ROOT/'iterations'; hist.mkdir(exist_ok=True)
    save(icons[1024],hist/f'icon-{args.revision:02}.png')
    save(Image.open(ROOT/'preview.png'),hist/f'preview-{args.revision:02}.png')
    subprocess.run(['/usr/bin/iconutil','-c','icns',str(folder),'-o',str(ROOT/'AppIcon.icns')],check=True)
    correct_legacy_alpha()
    print(f'Revision {args.revision}: wrote master, SVG layers, 10 iconset PNGs, ICNS, and preview to {ROOT}')

if __name__=='__main__': main()
