# Art and animation assets · 1.5 work in progress

## Integrated project assets

- assets/kvesmos/scenes/painted_bridge.webp — original generated hand-painted starship interior, 315788 bytes at first export. Built-in ImageGen, source exec-adeb2c5a-d4d7-4f50-ac43-fb75ac5bfda5.png.
- assets/kvesmos/rigs/miko.webp — eight-part atlas based on the approved Miko reference. Built-in ImageGen, source exec-d5d8e225-f197-4118-b7e0-86befc0e23dc.png.
- assets/kvesmos/rigs/orbi.webp — eight-part atlas based on the approved Orbi reference. Built-in ImageGen, source exec-72aeddab-a698-49bb-9a13-4a4e81f4829a.png.
- The referenced character artwork was supplied by the project. Generated derivatives are original project assets; no external stock character was substituted. Further art acceptance by the owner is pending.

Preparation tool — tool/prepare_cutout_atlas.py. It splits eight cells, removes edge-connected matte while preserving enclosed light material, trims empty margins and packs 256px cells in a lossless WebP. Runtime composes head, torso, arms and legs with independent joint transforms. Head variants supply blink and mouth changes. This is a cutout prototype, not phoneme lip sync.

## Final generation prompts

Bridge — hand-painted 2D exploration starship, matte gouache and paper grain, arch window onto indigo space and teal planet, asymmetric cyan mechanical consoles, worn navy and brass, empty foreground deck, natural light. No writing, UI, characters or plastic gloss.

Miko — same blue-haired navigator, blue eyes, goggles, yellow scarf, navy/cream outfit and cyan gloves. Four columns and two rows of separate parts: neutral head, blink head, talking head, torso, left arm, right arm, left leg, right leg. Transparent background, consistent camera, no labels.

Orbi — same round cream robot, black face, cyan eyes, blue orbit hat and gold star. Same eight-part layout, matte textured shading and coherent front three-quarter camera. Transparent background, no detached particles.

Original part sheets are retained in docs/design-handoff/04_sources/v15/miko-parts.png and orbi-parts.png. Runtime atlases and the bridge illustration are stored under assets/kvesmos/rigs and scenes; the application never fetches these assets from the network. Regenerate the atlases with python tool/prepare_cutout_atlas.py SOURCE OUTPUT. Build-time preparation requires Pillow, NumPy and SciPy; there is no added Flutter runtime dependency.

## Evaluated external sources

Kenney Space Kit https://kenney.nl/assets/space-kit declares CC0 and provides 3D props. Quaternius Universal Animation Library https://quaternius.com/packs/universalanimationlibrary.html declares CC0 and humanoid FBX/GLB motion. Neither pack is integrated: they do not supply a matching skeleton for approved KVESMOS characters. No third-party license obligations are introduced by these evaluations.

OpenGameArt interior pages were found, but direct retrieval failed. No unverified downloads were integrated.

## Scope and evidence

Gallery route /animation-gallery, with a debug link from CrewPage. All nine characters are selectable. Legacy characters are explicitly labelled until prepared. Readiness per character/action is in ANIMATION-READINESS.csv.

First Android video exposed a translucent white cell matte. The preparation step was corrected; the fixed native preview passed and was visually reviewed. A subsequent change adds distinct shoulder gestures for all fourteen states, finite celebrations and playback-bound speech in learning surfaces. That revision requires refreshed gallery evidence. Eight addressed tests pass: the existing five home/learning tests, including both themes, 320dp and 200% text, and three lifecycle/playback regression tests. Analyzer has no issues.

Still pending: complete unique motions for all states and all nine heroes, animated environment layers, a full lesson-to-reward video, measured frame timings and physical-device review. No claim of 60fps or completed Art & Animation Revolution.
