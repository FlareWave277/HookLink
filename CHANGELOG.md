# Changelog

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
