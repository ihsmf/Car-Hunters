"""Собирает BilliardHunters.rbxlx из src/ (аналог rojo build): python3 build_rbxlx.py"""
from xml.sax.saxutils import escape
import itertools
ref = itertools.count()

def item(cls, name, children="", source=None):
    src = f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>' if source is not None else ""
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties><string name="Name">{escape(name)}</string>{src}</Properties>{children}</Item>'

def script(path, cls, name):
    return item(cls, name, source=open(path, encoding="utf-8").read())

shared = item("Folder", "Shared", script("src/shared/Config.luau", "ModuleScript", "Config"))
server = item("Folder", "Server", script("src/server/Main.server.luau", "Script", "Main") + script("src/server/Map.luau", "ModuleScript", "Map"))
client = item("Folder", "Client", script("src/client/UI.client.luau", "LocalScript", "UI") + script("src/client/Balls.client.luau", "LocalScript", "Balls"))
xml = ('<roblox version="4">'
       + item("ReplicatedStorage", "ReplicatedStorage", shared)
       + item("ServerScriptService", "ServerScriptService", server)
       + item("StarterPlayer", "StarterPlayer", item("StarterPlayerScripts", "StarterPlayerScripts", client))
       + '</roblox>')
open("BilliardHunters.rbxlx", "w", encoding="utf-8").write(xml)
print("BilliardHunters.rbxlx ready")
