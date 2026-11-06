import sys,glob,re
from PIL import Image
# cbm.py <carpeta> <salida> <arma_tramo> [paso=3] [cols=12]: tira de cuadros de un tramo
S,out,seg=sys.argv[1:4]; step=int(sys.argv[4]) if len(sys.argv)>4 else 3; cols=int(sys.argv[5]) if len(sys.argv)>5 else 12
fs=sorted(glob.glob(f"{S}/cb_{seg}_*.png"))[::step]
rows=(len(fs)+cols-1)//cols
W=Image.new("RGB",(cols*200,rows*340),"white")
from PIL import ImageDraw
d=ImageDraw.Draw(W)
for i,f in enumerate(fs):
    k=int(re.search(r"_(\d+)\.png",f).group(1))
    W.paste(Image.open(f).crop((476,130,676,470)),((i%cols)*200,(i//cols)*340))
    d.text(((i%cols)*200+4,(i//cols)*340+4),f"{k} {k/30:.2f}s",fill="black")
W.save(out)
