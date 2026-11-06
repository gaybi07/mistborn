import sys,glob,re
from PIL import Image,ImageDraw
# cbs.py <carpeta> <salida> <arma> tramo1,tramo2,... [paso]
S,out,wn,segs=sys.argv[1:5]; step=int(sys.argv[5]) if len(sys.argv)>5 else 4
segs=segs.split(","); TW,TH=150,255
rows=[sorted(glob.glob(f"{S}/cb_{wn}_{s}_*.png"))[::step] for s in segs]
cols=max(len(r) for r in rows)
W=Image.new("RGB",(cols*TW,len(segs)*TH),"white"); d=ImageDraw.Draw(W)
for i,r in enumerate(rows):
    for j,f in enumerate(r):
        W.paste(Image.open(f).crop((476,130,676,470)).resize((TW,TH)),(j*TW,i*TH))
        k=int(re.search(r"_(\d+)\.png",f).group(1))
        d.text((j*TW+2,i*TH+2),f"{segs[i]} {k/30:.1f}" if j==0 else f"{k/30:.1f}",fill="yellow")
W.save(out)
