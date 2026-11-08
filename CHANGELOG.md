# Changelog

## 0.1.0 (first release, pre-release)

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
