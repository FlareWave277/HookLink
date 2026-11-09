<p align="center"><img src="docs/icon.png" width="128" alt="HookLink icon"></p>

<h1 align="center">HookLink</h1>

<p align="center"><b>The Legend of Zelda: Ocarina of Time (Nintendo Switch 2 Edition) on your iPhone, natively, built on your Mac from your own copy of the game.</b></p>

<p align="center">
<a href="#project-status">Status</a> · <a href="#how-to-build">How to build</a> · <a href="#installing-and-copying-the-game">Install</a> · <a href="#updating">Updating</a> · <a href="#what-hookLink-tunes-for-the-iphone">What it tunes</a> · <a href="#if-something-goes-wrong">Problems</a> · <a href="#want-to-help">Help</a> · <a href="#credits">Credits</a> · <a href="#license">License</a>
</p>

Discord: https://discord.gg/bSrN5kEScg

HookLink is a Mac app that turns your own dump of Ocarina of Time into an iPhone app. It runs [nxnative](https://github.com/seedds/nxnative), which translates the game's code and its graphics to Apple's Metal, with changes made and tested for this one game on the iPhone: faster pipeline loading, memory fixes, real-time game speed below 60 fps, and a resolution tuned for the phone. No emulator is involved.

> [!IMPORTANT]
> This repository does not contain the game, keys or a built app, and it does not explain how to get them. You need your own copy. Everything HookLink makes (the IPA, the game files on your phone, the shader caches and your saves) comes from your game and stays on your Mac and your phone. **Never share those files.**

## Project status

**Experimental.** Tested on one iPhone (iPhone 18 Pro Max, iOS 27.2), built on one Mac.

| What | Status |
|---|---|
| Kokiri Forest, Hyrule Field, Castle Town | ✅ Plays |
| Sound, touch controls, controllers, saves | ✅ Works |
| 60 fps | ⚠️ Most areas; Hyrule Field dips in the 40s–50s when the phone is warm |
| Stutter the first time you enter an area | ⚠️ Happens once; the next start prepares that area |
| First start after installing | ⚠️ Long "Preparing shaders" screen, a few minutes, once |
| iPhone 17 family (A19) | ❓ Should work, not tested yet |
| Older iPhones | ❌ Not supported (memory and graphics) |

## How to build

### With the HookLink app (the easy way)

1. Download **HookLink.zip** from the [Releases](../../releases) page and unzip it.
2. Open **HookLink.app**. The first time, macOS says it can't check it for malware (it isn't from the App Store or notarized): open **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, then open HookLink again.
3. Follow the steps in the window:
   1. **Check your Mac**: HookLink finds what's missing and installs most of it for you.
   2. **Choose your game**: drop your `.nup` file in.
   3. **Choose your iPhone** model.
   4. **Build**: a few hours the first time. You can keep using your Mac.
   5. **Install** the IPA with your sideloading tool.
   6. **Copy game files**: plug in your iPhone and click one button (or use Finder, if the cable copy keeps stopping).
   7. **Play.**

### How long it takes

| Step | First time | Later builds |
|---|---|---|
| Check your Mac and install tools | 5–20 min (plus Xcode's own download, if you need it) | Seconds |
| Build, step 1–3 (unpack, rewrite, split shaders) | ~10 min | ~5 min |
| Build, step 4 (iOS shaders) | ~1 h 10 min. Part of it shows no percentage for 10+ minutes while it checks the shader cache: that's normal | Minutes, unless an update changes the shaders |
| Build, step 5 (app and GPU pipeline archive) | ~45 min | Minutes |
| Build, step 6 (pack the IPA) | ~5 min | ~5 min |
| Copy game files to the phone | 10–25 min | Not needed again |
| First start of the game ("Preparing shaders") | A few minutes, once | Seconds |

### What you need

- A Mac with Apple silicon, macOS 26.6 or later.
- [Xcode 27.2](https://developer.apple.com/download/all/?q=Xcode%2027.2), opened once, with the iOS platform (Xcode → Settings → Components).
- [Homebrew](https://brew.sh).
- About **80 GB free** while building. The build folder keeps about 70 GB afterwards so later builds are fast; see [Disk space](#disk-space).
- Your game: program `0400486024DEC000`, update `v131072`, as a `.nup`. Other versions don't work.
- An iPhone 18 Pro / Pro Max (tested) or an iPhone 17 model (untested), with **Developer Mode** on, and a cable.
- A sideloading tool such as iLoader, Sideloadly or AltStore.

### From the command line

HookLink runs nxnative's packing script with its own settings. With nxnative (HookLink's branch) checked out:

```bash
DM_ENTITLEMENTS="$PWD/../HookLink/Resources/presets/entitlements.plist" \
python3 -I scripts/build_ipa_from_nsp.py "/path/to/your-game.nup" \
  --platform ios --romfs separate --allow-damaged --gpu g19p \
  --env-file ../HookLink/Resources/presets/iphone.env \
  -o ~/HookLink/HookLink-OcarinaOfTime.ipa
```

Use `--gpu g18p` for an iPhone 17 model.

## Installing and copying the game

The IPA holds the app, its shaders and its GPU pipeline archive (about 5 GB). The game's own files (about 24 GB) are copied to the phone separately, once:

1. Install the IPA with your sideloading tool. Turn on **Increased Memory Limit** if it offers it.
2. Don't open the game yet.
3. In HookLink, **Copy game files**: set **Auto-Lock → Never** on the phone, plug it in, unlock it, tap **Trust**, then click the button. HookLink copies the game files and the iPhone resolution file made from your game, then checks them.
4. Open the game.

**If the cable copy keeps stopping**, click **Copy with Finder instead**. HookLink shows the file in Finder; drag it onto the game in your iPhone's **Files** tab in Finder, wait for Finder to finish, then click **Finder is done: check and finish**. HookLink checks the game files arrived whole and does the rest.

## Your saves

Your saves live only on your iPhone, inside the game. HookLink can keep copies on your Mac:

- **Play → Back up my saves** copies them to `Documents/HookLink Save Backups/<date>` on the Mac.
- HookLink also backs them up **by itself before copying game files** to the phone.
- **Play → Restore a backup…** puts a backup back on the phone (close the game first). What's on the phone is backed up first, and every file is checked after copying.

**Never delete the game from your phone to reinstall it:** that deletes its saves. Install the new version over the old one instead, and back up first to be safe.

## Updating

HookLink checks for updates every time you open it (and from **HookLink → Check for Updates…**):

- **A game update** (performance and fixes): click **Update and rebuild**, then build again. Small updates rebuild in minutes; updates that change the shaders take a few hours. Install the new IPA over the old one: your saves, game files and resolution file stay on the phone, so there's nothing to copy again.
- **A new HookLink version**: download it from the Releases page and replace the old app.

## What HookLink tunes for the iPhone

- **Pipelines:** a draw waiting for its pipeline no longer repeats failed archive searches every frame. Each pipeline the game asks for is listed for the next start, which builds them all behind the loading screen.
- **First starts:** the app ships with a list of the pipelines recorded while playing Kokiri Forest, Hyrule Field, Castle Town and Hyrule Castle, so those areas are prepared before the game starts instead of stuttering. Players' shared lists extend it with every update.
- **GPU:** nxnative's latest work for this game: occlusion tests that let hidden grass be skipped, faster mesh-shader loads (the foliage), no 2 ms GPU wait each frame, faster shader math, and the mist without dark specks.
- **Mesh shaders:** the foliage, shadow and enemy shaders are prepared before the game starts and saved, instead of freezing the game the first time each one is drawn.
- **Frame pacing:** the thread that sends each frame to the GPU always runs in iOS's top class, so the busy areas run on the fast cores.
- **Memory:** freed render targets' memory is reused for the next one, and textures of scenes you've left are retired when memory runs short (fixes the freeze after the talk with Saria).
- **Game speed:** the game moves at real speed even when a frame runs long, without dropping to 30 fps.
- **Resolution:** the handheld dynamic resolution ranges from 1080×608 down to 640×360 on the phone, made from your own game files.
- **Controls:** a glass look on every on-screen layout, and a Mobile layout with a floating stick, glass buttons and a D-pad (from the [kid-with-sword fork](https://github.com/ednofedulo/kid-with-sword-remake-detached-20261108) of nxnative).
- **Wide view:** an optional launcher setting that fills an iPhone screen with a wider view and no black bars (from nxnative pull request 1460 by vladbondarenko97).
- **Settings:** thread priorities, no 30 fps hold, no 30 fps thermal cap.

## Disk space

HookLink keeps its build folder (the folder you chose, about 70 GB) so later builds take minutes instead of hours.

| Safe to delete | Don't delete (costs a long rebuild) |
|---|---|
| Old IPAs you no longer need | `build/shader` (the shader cache: over an hour to rebuild) |
| `copy-to-phone` (only a link to your game files, no extra space) | `build/ipa` (holds the GPU pipeline archive: about 45 minutes to rebuild) |
| | `build/extract` (your game, unpacked) |

To remove HookLink completely, delete the app, the build folder, and `~/Library/Application Support/HookLink`.

## If something goes wrong

| Problem | What to do |
|---|---|
| HookLink says the game isn't supported | Check it's the Switch 2 Edition with update v131072, as a `.nup` |
| The build seems stuck | Look at the progress card's timer and its last line: some steps go quiet for 10+ minutes. Stopped for over an hour? Click **Show details** |
| The game file copy stops part way | Set Auto-Lock to Never and keep the phone unlocked; if it still stops, use **Copy with Finder instead** |
| The build stops | Click **Show details** and look at the last lines. Free disk space and Xcode 27.2 are the usual causes |
| "No iPhone found" | Use a cable, unlock the phone, tap Trust, turn on Developer Mode |
| "The game is not installed on this iPhone" | Install the IPA first, then click **Find my iPhone** again |
| The game closes at start | Copy the game files again from HookLink; make sure Increased Memory Limit is on |
| Stutter the first time somewhere | Normal: the next start prepares that area |
| The first session after installing runs slowly | Close the game fully (swipe it away) and open it again: the next start runs at full speed |
| "The build needs Xcode 27.2's Metal compiler" | Install Xcode 27.2 and select it (`sudo xcode-select -s /Applications/Xcode.app`), then build again |

Still stuck? Click **Get game log** on HookLink's last step, then [open an issue](../../issues) or ask on [Discord](https://discord.gg/bSrN5kEScg) with your iPhone model, iOS version, where you were in the game and what happened. A screenshot or video helps. **Never attach game files.**

## Want to help?

- **Test on another iPhone**, especially an iPhone 17 model, and report how it runs.
- **Play further** than anyone has, and report what breaks.
- **Share your pipeline list**: in HookLink, **Play → Share my pipeline list**. Lists from different players are merged into the next update, so everyone's game prepares more of the world ahead of time and stutters less.
- **Send a fix**: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

- **[nxnative](https://github.com/seedds/nxnative)** by seedds and its contributors: the engine HookLink runs, which translates the game to native code and Metal.
- **gunvalk**: found that the game's frame step ignores the frame's time (zortos293/Lichii PR #216), the basis of the real-speed fix.
- **[HookShot](https://github.com/NotRexed/Hookshot)** by NotRexed: inspired HookLink's name.

## License

HookLink is free software under the [MIT License](LICENSE). It builds on nxnative, also MIT; its notice is kept in [NOTICE.md](NOTICE.md).

HookLink is an unofficial fan project, not affiliated with or endorsed by Nintendo. The Legend of Zelda and Ocarina of Time are trademarks of Nintendo.
