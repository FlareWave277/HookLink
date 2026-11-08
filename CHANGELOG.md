# Changelog

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
