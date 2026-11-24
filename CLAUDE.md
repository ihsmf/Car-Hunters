# CUE HUNTERS

- The game is called **CUE HUNTERS** — always. Never "Billiard Hunters" or "Car Hunters" in anything visible.
- Source of truth: the Studio place `studio/CueHunters.rbxlx`. Edited scripts live in `studio/src/*.luau`;
  `python3 tools/studio.py pack` writes them back, regenerates the hall/landscape, bakes the uploaded Blender meshes
  (`tools/mesh_assets.json`) as MeshParts and builds `studio/CueHunters-Studio-Full.zip`.
- Blender models: `blender/build_models.py` (+ `blender/themes.py`); new meshes are uploaded with
  `python3 tools/meshassets.py 1221663569` (Open Cloud key saved in the environment), then pack again.
- Publish: `python3 tools/publish.py <universeId> <placeId>`.
