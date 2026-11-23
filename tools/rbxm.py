import struct,lz4.block,sys
def chunks(b):
    i=32
    while i<len(b):
        name=b[i:i+4]; comp,uncomp=struct.unpack('<II',b[i+4:i+12]); i+=16
        data=b[i:i+(comp or uncomp)]; i+=comp or uncomp
        if comp: data=lz4.block.decompress(data,uncompressed_size=uncomp)
        yield name,data
        if name==b'END\x00': break
def rstr(d,o):
    n=struct.unpack('<I',d[o:o+4])[0]; return d[o+4:o+4+n],o+4+n
def untrans_f(d,n):  # interleaved float32 rotated
    out=[]
    for k in range(n):
        v=sum(d[j*n+k]<<(8*(3-j)) for j in range(4))
        v=(v>>1)|((v&1)<<31); out.append(struct.unpack('>f',struct.pack('>I',v))[0])
    return out
def parse(b):
    cls={};props={}
    for name,d in chunks(b):
        if name==b'INST':
            cid=struct.unpack('<I',d[:4])[0]; cn,o=rstr(d,4); cls[cid]=cn.decode()
        elif name==b'PROP':
            cid=struct.unpack('<I',d[:4])[0]; pn,o=rstr(d,4); t=d[o]; v=d[o+1:]
            props.setdefault(cls[cid],{})[pn.decode()]=(t,v)
    return cls,props
if __name__=='__main__':
    cls,props=parse(open(sys.argv[1],'rb').read())
    print(cls)
    for c,p in props.items():
        for k,(t,v) in p.items():
            if t==1 or t==0x1d: s,_=rstr(v,0); print(c,k,'str',s[:80])
            elif t==0x0e: print(c,k,'v3',untrans_f(v[:4],1),untrans_f(v[4:8],1),untrans_f(v[8:12],1))
            elif t in (0x10,0x11): print(c,k,'cf',v[:1],len(v))
            else: print(c,k,hex(t),len(v))
