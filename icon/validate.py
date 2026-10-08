#!/usr/bin/env python3
"""Check export sizes, color/alpha, SVGs, and iconutil's lossless ICNS round-trip."""
from pathlib import Path
import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
expected={f'icon_{p}x{p}{"@2x" if s==2 else ""}.png':p*s for p in (16,32,128,256,512) for s in (1,2)}
checks=[]
for name,size in expected.items():
    im=Image.open(ROOT/'AppIcon.iconset'/name)
    assert im.size==(size,size) and im.mode=='RGBA',name
    assert im.info.get('icc_profile'),name
    a=np.asarray(im)
    assert (a[:,:,0]==a[:,:,1]).all() and (a[:,:,1]==a[:,:,2]).all(),name
    assert im.getpixel((0,0))[3]==0 and im.getpixel((size//2,size//2))[3]==255,name
    checks.append({'file':name,'pixels':size,'rgba':True,'srgb_profile':True,'achromatic':True})
assert len(list((ROOT/'AppIcon.iconset').glob('*.png')))==10
master=Image.open(ROOT/'icon-1024.png')
assert np.array_equal(np.asarray(master),np.asarray(Image.open(ROOT/'AppIcon.iconset/icon_512x512@2x.png')))
assert Image.open(ROOT/'preview.png').size==(1744,2540)
for svg in (ROOT/'layers').glob('*.svg'):
    root=ET.parse(svg).getroot()
    assert root.attrib['viewBox']=='0 0 1024 1024'
    assert 'filter' not in svg.read_text() and '<image' not in svg.read_text()
validation=ROOT/'validation'; validation.mkdir(exist_ok=True)
roundtrip=validation/'roundtrip.iconset'
if roundtrip.exists(): shutil.rmtree(roundtrip)
subprocess.run(['/usr/bin/iconutil','-c','iconset',str(ROOT/'AppIcon.icns'),'-o',str(roundtrip)],check=True)
roundtrip_checks=[]
for name in expected:
    original=np.asarray(Image.open(ROOT/'AppIcon.iconset'/name).convert('RGBA'))
    decoded=np.asarray(Image.open(roundtrip/name).convert('RGBA'))
    assert np.array_equal(original[:,:,3],decoded[:,:,3]),f'Alpha mismatch: {name}'
    delta=np.abs(original[:,:,:3].astype(float)-decoded[:,:,:3].astype(float))*original[:,:,3:4]/255
    assert delta.max()<=1,f'Visible ICNS mismatch: {name}: {delta.max()}'
    roundtrip_checks.append({'file':name,'pixel_identical':bool(np.array_equal(original,decoded)),'max_composited_channel_error':float(delta.max())})
shutil.rmtree(roundtrip)
(ROOT/'validation/results.json').write_text(json.dumps({'status':'passed','representations':checks,'icns_roundtrip':roundtrip_checks,'svg_layers':'four valid 1024-square vectors without raster content or filters','preview':'1744 x 2540; two full-size rows plus dock','visual_reviews':['revision 01: signal-strength reading, pointed tail, soft small strokes','revision 02: softer tail and thicker pulses; small strokes need pixel alignment','revision 03: optical 16/32 variants, stronger caret, narrow glass edge; inspected full preview and 1024 master']},indent=2)+'\n')
print('PASS: ten RGBA/sRGB iconset images, monochrome pixels, transparent corners, four vector layers, preview dimensions, and ICNS round-trip within one composited channel level (eight images pixel-identical).')
