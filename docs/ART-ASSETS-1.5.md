# Art and animation assets · 1.5 work in progress

## Current character artwork

The lesson, command bridge, reward reveal and gallery display the approved KVESMOS illustrations. The production widget is CharacterMoment. Seven full figures come from docs/design-handoff/01_approved/characters/*_sheet.png. Run python tool/export_crew_illustrations.py to rebuild their lossless transparent WebP files. Orbi and Pixie use their existing project drawings. Event poses for the crew use the existing illustrated expression set. Speech cues follow LearningAudio.playback. No joint atlas is bundled.

## Prototype history

The sections below document earlier assets and measurements. The joint-renderer prototypes were retired after visual review. Their gallery captures do not represent the current app.

- assets/kvesmos/scenes/painted_bridge.webp — original generated hand-painted starship interior, 315788 bytes at first export. Built-in ImageGen, source exec-adeb2c5a-d4d7-4f50-ac43-fb75ac5bfda5.png.
- assets/kvesmos/rigs/miko.webp — eight-part atlas based on the approved Miko reference. Built-in ImageGen, source exec-d5d8e225-f197-4118-b7e0-86befc0e23dc.png.
- assets/kvesmos/rigs/orbi.webp — eight-part atlas based on the approved Orbi reference. Built-in ImageGen, source exec-72aeddab-a698-49bb-9a13-4a4e81f4829a.png.
- assets/kvesmos/rigs/pixie.webp — independent floating anatomy: body with face variants, hands, two antennae and treasure satchel. Built-in ImageGen, source exec-b4463259-c0c4-4bc9-817b-916d26b54756.png.
- The referenced character artwork was supplied by the project. Generated derivatives are original project assets; no external stock character was substituted. Further art acceptance by the owner is pending.

Preparation tool — tool/prepare_cutout_atlas.py. It splits eight cells, removes edge-connected matte while preserving enclosed light material, trims empty margins and packs 256px cells in a lossless WebP. Runtime composes head, torso, arms and legs with independent joint transforms. Head variants supply blink and mouth changes. This is a cutout prototype, not phoneme lip sync.

## Final generation prompts

Bridge — hand-painted 2D exploration starship, matte gouache and paper grain, arch window onto indigo space and teal planet, asymmetric cyan mechanical consoles, worn navy and brass, empty foreground deck, natural light. No writing, UI, characters or plastic gloss.

Miko — same blue-haired navigator, blue eyes, goggles, yellow scarf, navy/cream outfit and cyan gloves. Four columns and two rows of separate parts: neutral head, blink head, talking head, torso, left arm, right arm, left leg, right leg. Transparent background, consistent camera, no labels.

Orbi — same round cream robot, black face, cyan eyes, blue orbit hat and gold star. Same eight-part layout, matte textured shading and coherent front three-quarter camera. Transparent background, no detached particles.

Pixie — preserve the approved rainbow cyan teardrop creature, large blue eyes, purple/gold satchel. Four columns, two rows: neutral body, blink body, talking body, detached satchel, left hand/arm, right hand/arm, large antenna, small antenna. No humanoid torso or legs; matte gouache, transparent gutters, no text.

Original part sheets are retained in docs/design-handoff/04_sources/v15/miko-parts.png, orbi-parts.png and pixie-parts.png. Runtime atlases and the bridge illustration are stored under assets/kvesmos/rigs and scenes; the application never fetches these assets from the network. Regenerate the atlases with python tool/prepare_cutout_atlas.py SOURCE OUTPUT. Build-time preparation requires Pillow, NumPy and SciPy; there is no added Flutter runtime dependency.

## Evaluated external sources

Kenney Space Kit https://kenney.nl/assets/space-kit declares CC0 and provides 3D props. Quaternius Universal Animation Library https://quaternius.com/packs/universalanimationlibrary.html declares CC0 and humanoid FBX/GLB motion. Neither pack is integrated: they do not supply a matching skeleton for approved KVESMOS characters. No third-party license obligations are introduced by these evaluations.

OpenGameArt interior pages were found, but direct retrieval failed. No unverified downloads were integrated.

## Scope and evidence

Gallery route /animation-gallery, with a debug link from CrewPage. All nine characters are selectable. Legacy characters are explicitly labelled until prepared. Readiness per character/action is in ANIMATION-READINESS.csv.

First Android video exposed a translucent white cell matte. The preparation step was corrected; the fixed native preview passed and was visually reviewed. A subsequent change adds distinct shoulder gestures for all fourteen states, finite celebrations and playback-bound speech in learning surfaces. That revision requires refreshed gallery evidence. Eight addressed tests pass: the existing five home/learning tests, including both themes, 320dp and 200% text, and three lifecycle/playback regression tests. Analyzer has no issues.

Still pending: complete unique motions for all states and all nine heroes, animated environment layers, a full lesson-to-reward video, measured frame timings and physical-device review. No claim of 60fps or completed Art & Animation Revolution.

Pixie has a separate non-humanoid renderer with antenna sway, hand gestures, floating body and delayed satchel motion. Chest reveals use it through LearningCharacter. This is the third prototype, pending native art review. Six other heroes still have legacy pose rendering.

## Cosmetic repair found during the vertical slice

The original 165px concept crop frame_common.png showed an opaque square and a neighboring-item fragment in the reward reveal. Original asset retained. Item cos_frame_common_v1 now references assets/kvesmos/cosmetics/beginner-orbit.webp, a 768px transparent restoration. IDs, rarity, drop tables and existing owned/equipped records are unchanged. The new resource is bundled offline. Source: docs/design-handoff/04_sources/v15/beginner-orbit.png; built-in ImageGen exec-b2240e26-d92a-49a9-8a87-1ead2a068474.png.

Final prompt — faithfully restore approved cream/royal-blue orbit frame, top blue faceted diamond, golden star at lower right, tiny gold marks. Preserve silhouette and colors; matte painted detail, complete centered frame, no neighboring pieces. Remove all background both outside and inside the ring; genuine RGBA transparency, no halo or text. Art review pending.

## Android evidence, 2026-11-25

Full UI cycle passed in 02:35: bridge, both home themes, galaxy, introduction, incorrect answer with retry, lesson completion, chest opening and one persisted item. Video: build/releases/KVESMOS-painted-learning-cycle/cycle-en.mp4. The XP assertion confirms opening did not add XP. That capture precedes the final button/header placement and transparent frame restoration.

All 42 action previews across Orbi/Miko/Pixie passed in 01:52. Mid-action screenshots and continuous native video: build/releases/KVESMOS-jointed-gallery/cycle-en.mp4. Source log .tools/v15-gallery-native.log. Debug/emulator timings, 6321 frames after warm-up: build p95 4.629ms, raster p95 18.803ms. These are diagnostic measurements, not proof of sustained release 60fps. A sample taken during the debug lesson showed PSS 398543KB / RSS 506516KB; this includes the full test application, not isolated atlas cost.

Windows emulator access violation was reproducible with software GPU backends. The complete cycle and gallery passed with -gpu host -feature -Vulkan on this machine; Impeller remained enabled. Physical-device and lower-end performance acceptance remain open.
