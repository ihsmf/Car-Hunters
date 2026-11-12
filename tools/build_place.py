"""Inject src/**/*.lua into base/CarHunters_original.rbxlx -> CarHunters.rbxlx.
Path = Explorer path. New files: *.server.lua -> Script, *.client.lua -> LocalScript, else ModuleScript."""
import os, sys, uuid, xml.etree.ElementTree as ET
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
base = os.path.join(ROOT, 'base', 'CarHunters_original.rbxlx')
out = os.path.join(ROOT, 'CarHunters.rbxlx')
tree = ET.parse(base); doc = tree.getroot()

def props(it): return it.find('Properties')
def name(it):
    for p in props(it):
        if p.get('name') == 'Name': return p.text
def child(parent, n):
    for c in parent.findall('Item'):
        if name(c) == n: return c
def new_item(parent, cls, n):
    it = ET.SubElement(parent, 'Item', {'class': cls, 'referent': 'RBX' + uuid.uuid4().hex.upper()})
    pr = ET.SubElement(it, 'Properties')
    s = ET.SubElement(pr, 'string', {'name': 'Name'}); s.text = n
    return it

count = {'replaced': 0, 'added': 0}
src = os.path.join(ROOT, 'src')
for dp, _, fs in os.walk(src):
    for f in sorted(fs):
        if not f.endswith('.lua'): continue
        rel = os.path.relpath(os.path.join(dp, f), src).replace(os.sep, '/')
        parts = rel[:-4].split('/')
        leaf = parts[-1]; cls = 'ModuleScript'
        if leaf.endswith('.server'): leaf, cls = leaf[:-7], 'Script'
        elif leaf.endswith('.client'): leaf, cls = leaf[:-7], 'LocalScript'
        node = doc
        for p in parts[:-1]:
            nxt = child(node, p)
            if nxt is None: nxt = new_item(node, 'Folder', p)
            node = nxt
        it = child(node, leaf)
        if it is None:
            it = new_item(node, cls, leaf); count['added'] += 1
        else:
            count['replaced'] += 1
        srcp = None
        for p in props(it):
            if p.get('name') == 'Source': srcp = p
        if srcp is None: srcp = ET.SubElement(props(it), 'ProtectedString', {'name': 'Source'})
        srcp.text = open(os.path.join(dp, f), encoding='utf-8').read()
# drop stale empty car placeholders (models are installed by CarModelTool.ApplyImported)
rs = [c for c in doc.findall('Item') if c.get('class') == 'ReplicatedStorage'][0]
cm = child(rs, 'CarModels')
if cm is not None:
    for c in list(cm.findall('Item')):
        if c.get('class') == 'Model' and not c.findall('Item'):
            cm.remove(c)
tree.write(out, encoding='utf-8', xml_declaration=False)
print('built', out, count)
# embed downloaded 3D models (tools/fetch_assets.py) with lune, so nothing is downloaded at runtime
import shutil, subprocess
rbxm = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'rbxm')
lune = shutil.which('lune') or os.path.expanduser('~/.cargo/bin/lune')
if os.path.isdir(rbxm) and any(f.endswith('.rbxm') for f in os.listdir(rbxm)):
    if os.path.exists(lune):
        subprocess.run([lune, 'run', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'bake_models.luau'), out, rbxm], check=True)
    else:
        print('! lune not found (cargo install lune --locked): 3D models were NOT embedded')
