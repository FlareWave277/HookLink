# Changelog

## 1.6

Wide view now shows more of the game, plus 14 engine fixes from nxnative. **This update has been built but not played on a phone yet**, so please share your game log (**Get game log**) if something looks or runs wrong.

**Fixed: Wide view stretched the picture.** In 1.5 and 1.5.1 the game rendered a wider picture, but its cameras still used a 16:9 view, so Wide view stretched the picture instead of showing more. The 1.5 notes said nothing was stretched, and the 1.5.1 notes didn't mention it; both were wrong. Now the camera uses your screen's shape: the view keeps its height and shows more at the sides. If things pop in or vanish at the left and right edges, or the HUD or menus look wrong, please send your log.

**From nxnative:**
- **Terrain:** ground tiles no longer vanish or show another tile's surface after you walk a while. This may be the cause of the flat single-colour shapes some players saw, but that isn't confirmed.
- **Death Mountain Trail:** the light-blue dashes over the rock at the cave entrance are gone.
- **GPU:** a faster check in the shaders that mark which memory each pass used (measured on an Apple M6, not an iPhone).
- **Memory and storage:** freed GPU memory is released sooner when the game pauses its drawing, textures are no longer read again when nothing changed them, and the game's files give disk space back (an iPad had stopped the game at 5 GB free).
- Fixes for textures that change size, for presenting frames, and the iOS build fix that 1.5 already carried.

**To update:** open HookLink and click **Update and rebuild** on the update banner, then install the new app over the old one. Your saves and game files stay on the phone. This update changes the shaders, so every shader is compiled again: the rebuild took about 2 hours of work on our Mac. Keep the Mac awake while it runs, because sleep pauses it. The first "Preparing shaders" on the phone takes a few minutes. If the first session after that feels slow, close the game fully and reopen it.

## 1.5.1

A small fix update for 1.5: the same engine, with its Wide view and Mobile controls corrected. **This update has been built but not played on a phone yet**, so please share your game log (**Get game log**) if something looks or runs wrong.

**Fixed: Wide view still showed black bars.** In 1.5 the game rendered the wider picture, but the display step still laid it out as 16:9, so the bars stayed even though the 1.5 notes said they were gone. The display step now gets the picture's real shape. Wide view works on screens from 1.8:1 to 2.6:1, which covers regular iPhones. The iPhone Duo's unfolded screen stays 16:9, with black bars.

**Fixed: Mobile buttons now show what they do.** The icons didn't match the game's actions. The layout is now Y sword, A action, B back, X jump, R shield and ZL Navi, and there's a new ZR button for the held item. This mapping hasn't been checked against every in-game action yet, so please tell us if a button still looks wrong.

**Fixed: Mobile now follows the colour theme.** Its buttons change with **Touch controls style** (Classic, Forest or Glass), like the other layouts.

**To update:** open HookLink and click **Update and rebuild** on the update banner, then install the new app over the old one. Your saves and game files stay on the phone. The shaders didn't change, so if you already built 1.5 none of them are compiled again and "Preparing shaders" on the phone stays short. The rebuild still checks them and packs the app, which took about 2 hours on our Mac.

## 1.5

New controls, a wide view for iPhones, and an engine update. **This update has been built but not played on a phone yet**, so please share your game log (**Get game log**) if something looks or runs wrong.

**New: a glass look for the on-screen controls.** All the layouts now use nearly clear buttons with a bright rim and a light-blue press. You can go back to the older look under **Touch controls style** in the game's launcher.

**New: Mobile control layout.** A choice next to 2D, 3D and Tap in the in-game menu: a floating left stick that appears where your thumb lands, the camera on the right half of the screen, round glass buttons with icons and letter chips, and a small D-pad above the stick. (From the kid-with-sword fork of nxnative.)

**New: Wide view (optional, off by default).** Turn on **Wide view** in the game's launcher and the game renders your screen's real shape: you see more at the sides, with no black bars and nothing stretched. It applies the next time the game starts. It draws about a fifth more pixels, so turn it off if your frame rate suffers. The HUD and movies stay in the middle 16:9 area, and a few cutscenes or effects may look off at the edges. (From nxnative pull request 1460 by vladbondarenko97.)

**New: your own app name and icon.** On the **Choose your iPhone** step, you can name the app and pick any PNG or JPEG as its icon. Leave them empty for the game's own.

**New: small game file updates.** On the **Play** step, HookLink compares the small files on your iPhone (such as the resolution file) with the current ones and sends only what changed. It runs by itself after a build when your iPhone is plugged in, and there's a button for it. Your 24 GB of game files and your saves aren't touched.

**iPhone Duo in the phone list.** It uses the same chip as the iPhone 18 Pro, so it shares that choice. It hasn't been tested on a Duo, and the Duo's unfolded screen still shows black bars.

**Changed: fewer waits on the GPU.** The game can now keep 32 batches of GPU work in flight instead of 8. On some runs in Hyrule Field it kept stopping to wait for a free slot and fell to about 20 fps. This is aimed at that slowdown, but its effect hasn't been measured on a phone yet.

**Also from nxnative:** the title movie's upscaling network takes about half the GPU time (measured on an M4 Pro Mac, not an iPhone), mesh-shader models no longer pick up ambient light from the wrong place, fixes for occlusion and memory reads, and faster handling of the pipeline archive.

**Known issues**
- Hyrule Field and other busy areas can drop into the 40s and 50s once the phone warms up, because iOS slows the CPU.
- Some surfaces can show as flat single-colour shapes with hard edges. We don't know the cause yet, and this update may or may not fix it. If you see it, please send your log.

**To update:** open HookLink and click **Update and rebuild** on the update banner, then install the new app over the old one. Your saves and game files stay on the phone. This update changes the shaders, so the rebuild is long (about 3 hours on an M-series Mac), and the first "Preparing shaders" on the phone takes a few minutes. If the first session after that feels slow, close the game fully and reopen it.

## 1.4

An engine update for smoother play in the busy areas, from a 31-minute run from Kokiri Forest to Castle Town on an iPhone 18 Pro Max.

**Fixed: freezes of 1–4 seconds the first time you reach new areas** (Hyrule Field, Castle Town).
The game draws its foliage, shadows and enemies with mesh shaders. The engine wasn't counting, saving or preparing those shaders, so each new one was built at the moment it was first drawn, freezing the game. They are now prepared during "Preparing shaders", saved, and loaded from the save on later starts. The built-in list covers Kokiri Forest, Hyrule Field, Castle Town and Hyrule Castle. (From nxnative, by seedds and nanotchec, with rows from several players; one more row from our own test.)

**Improved: Hyrule Field and the road to the castle dropping to 35–55 fps.**
iOS decides which CPU cores each thread runs on from its class. The thread that sends each frame to the GPU was in a lower class, which tells iOS its work can wait, so iOS kept it on the phone's slower efficiency cores, at about 1.6 GHz instead of 3.7. Hyrule Field draws about 4× as much per frame as Kokiri Forest, so it fell behind even though the GPU had time to spare. That thread now always runs in the top class. The cause is confirmed in the logs; how close this brings Hyrule Field to 60 fps hasn't been measured on a phone yet, so please share your log if it still drops.

**Changed: memory for the game's render targets.**
Tested on the phone: about 4 GB to spare in Hyrule Field, more than 1.3. The shared memory layout for render targets (from an nxnative pull request) is replaced by nxnative's own render-target recycling. nxnative found the old layout can corrupt the picture. The new one reuses a freed target's memory for the next one that fits, so dynamic resolution changes no longer pile up memory.

**Also from nxnative:** dynamic resolution climbs back to full size based on the measured load, the bundled pipeline archive is mapped instead of read into memory, and fixes for paused threads and exclusive memory access.

**To update:** open HookLink and click **Update and rebuild** on the update banner, then install the new app over the old one. Your saves and game files stay on the phone. This update changes the shaders, so the rebuild takes longer than usual (about an hour on an M-series Mac), and the first "Preparing shaders" on the phone takes a few minutes. If the first session after that feels slow, close the game fully and reopen it.

## 1.3

- **Save backups:** **Back up my saves** and **Restore a backup…** on the Play step. Backups go to `Documents/HookLink Save Backups` on your Mac. HookLink backs up your saves by itself before copying game files, and before restoring. A restore copies one file at a time and checks each one.
- **Clearer errors:** a wrong Xcode / Metal compiler, a full disk or a missing tool now says what to do in plain words.
- **Damaged dumps:** the build step lists the damaged textures it found.
- **Tips:** if the first session after installing feels slow, close the game fully and reopen it. Never delete the game to reinstall (that deletes its saves).

## 1.2

- **Engine download that can't get stuck:** the download shows its progress, and if it receives nothing for a minute HookLink stops it and tries again (up to 3 times), instead of waiting forever.
- **Version panel** at the bottom of the sidebar, always visible: your HookLink version and engine version (commit and date), whether each is up to date, when HookLink last checked, and a **Check now** button. An available update shows in orange and is clickable; a check that couldn't reach GitHub says so instead of looking up to date.

## 1.1

**Fixed: the game crashed on its first frame after "Preparing shaders", on every launch.**
The patch that keeps the game at real speed when frames run long has two jumps that skip to the game's own code while the frame pacing isn't decided yet, which is the case on the very first frames. Extra instructions added for the real-speed fix sat between those jumps and their target, so the jumps landed in the middle of the new code and the game crashed (an access at address 0x3c). The jumps are now computed from the code instead of fixed, a check stops the build if they ever don't line up, and a new test runs the patch on an ARM emulator for the first frames, 60 fps, slow frames, the 30 fps step and the pacing turned off.

**To update:** open HookLink and click **Update and rebuild** on the update banner, then install the new app over the old one. Your saves and game files stay on the phone.

## 1.0

The first version of HookLink, tested on one Mac and one iPhone 18 Pro Max (iOS 27.2).

**The app**
- Step-by-step builder: checks the Mac and installs missing tools, takes your own `.nup`, builds the iPhone app, guides the install, and copies the game files and the iPhone resolution file to the phone, then checks them.
- Progress card on every long task: overall and per-step bars, elapsed time, and the latest activity, so quiet steps don't look frozen.
- Copy with Finder instead, for when the cable copy keeps stopping.
- Get game log and Share my pipeline list, for bug reports and for improving everyone's first start.
- Update checks at every launch: engine updates with Update and rebuild, and new HookLink releases.

**The engine** (nxnative, HookLink branch)
- Built on nxnative's latest Ocarina of Time work (GPU, occlusion, mesh shaders, shader math, mist).
- Pipelines: failed archive searches aren't repeated every draw; a faster lookup for waiting builds; every pipeline the game asks for is prepared at the next start.
- A pipeline list for Kokiri Forest, Hyrule Field, Castle Town and Hyrule Castle, built in.
- Memory: render targets in one placement heap; idle textures of old scenes retired under memory pressure (the freeze after Saria).
- Real-time game speed below 60 fps, without a 30 fps hold.

**Known issues**
- Hyrule Field can dip into the 40s–50s fps when the phone is warm.
- The first start after installing prepares shaders for a few minutes.
- iPhone 17 models are untested.
- A damaged dump builds, but its damaged textures may look wrong.
