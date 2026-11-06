import sys,re,collections
rows=collections.defaultdict(list)
for l in open(sys.argv[1],encoding="utf8",errors="ignore"):
    m=re.match(r"(\S+) (\d+) ([\d.]+)s (\S+)\s+(.*)\| max=([\d.]+)",l)
    if not m: continue
    parts=dict(re.findall(r"(\w+)=([\d.]+)",m.group(5)))
    rows[m.group(1)].append((int(m.group(2)),float(m.group(3)),m.group(4),float(m.group(6)),parts))
for sc,r in rows.items():
    print("==",sc)
    prev=None
    for i,(k,t,st,mx,p) in enumerate(r):
        if st!=prev:
            win=[x[3] for x in r[i:i+20]]
            print(f"  {t:.2f}s k={k} -> {st}   pico {max(win):.1f} m/s, dura {sum(1 for x in win if x>0.6)/30:.2f}s"); prev=st
        nb=[x[3] for x in r[max(0,i-3):i]+r[i+1:i+4]]
        med=sorted(nb)[len(nb)//2] if nb else 0
        if mx>1.2 and mx>2.2*med:
            top=max(p,key=lambda q:float(p[q]))
            print(f"     SALTO {t:.2f}s k={k} {st} max={mx:.1f} ({top}) vecinos~{med:.1f}")
