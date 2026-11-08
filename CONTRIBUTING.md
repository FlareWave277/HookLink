# Contributing to HookLink

HookLink builds The Legend of Zelda: Ocarina of Time (Nintendo Switch 2 Edition) for iPhone from the player's own copy, with [nxnative](https://github.com/seedds/nxnative) as its engine. This page covers what to send, how to build and test it, and the rules that keep the project safe.

## The rule with no exceptions

**No game files, keys, or anything made from them go into this repository, an issue or a pull request.** That includes:

- the `.nup`, `romfs`, `exefs`, `.nso`, `.nca`, `.nsp`, `.xci` files and any keys;
- `RomFS.img`, the `build/` folder and everything in it (extracted files, shader libraries, pipeline archives);
- the IPA (`HookLink-OcarinaOfTime.ipa`), and any `.mtl4a`, `.metallib` or `.img` file;
- edited game files, such as the resolution file (`Bootup.Nin_Ounce_NVN2.pack.zs`): HookLink makes it on each player's Mac from their own game;
- saves and anything copied off a phone.

**The one exception: pipeline lists** (`HookLink-pipelines-<date>.txt`, from **Share my pipeline list**). They hold shader identifiers and drawing settings only, the same kind of list nxnative ships in its own code, and they're how the game learns to prepare more areas for everyone. Share them through the *Share my pipeline list* issue form.

Don't open an issue or a pull request asking where to get the game or keys, or for someone else's files. Screenshots, videos and the game's `log.txt` are fine and often needed; the log holds no game data.

`.gitignore` blocks most of these. Still check `git status` before every commit. If you're not sure whether a file is game data, leave it out.

## Ways to help

| What | |
|---|---|
| Test on another iPhone | Only an iPhone 18 Pro Max has been tested. An iPhone 17 report is very useful, even when everything works. |
| Play further | Report areas, cutscenes and items that misbehave, with where you were. |
| Report a problem | Include your HookLink version, iPhone model, iOS version, where you were, and the game's `log.txt` if you can get it. |
| Send a fix | Fork, fix, test, open a pull request. Small, focused changes are easiest to review. |
| Improve the docs | Clearer steps in the README or here are welcome. |

## Before you open an issue or a pull request

- Try the newest release first.
- Search the open issues; add your details to an existing one instead of opening another.
- English, please.
- One topic per issue or pull request.
- Say which HookLink version and iPhone you used.

## Development setup

You need a Mac with Apple silicon, Xcode 27.2 with the iOS platform, Homebrew, about 80 GB free, and your own supported dump (`0400486024DEC000`, `v131072`).

```bash
git clone <your fork of HookLink>
cd HookLink
swift build                # the app
scripts/make_app.sh        # dist/HookLink.app and dist/HookLink.zip
```

To run the app against an nxnative checkout of your own instead of the one it downloads:

```bash
HOOKLINK_ENGINE=/path/to/nxnative swift run
```

or set the engine folder in HookLink → Settings.

## Layout

| Path | What |
|---|---|
| `Sources/HookLink/` | The Mac app (SwiftUI): the steps, the build runner, the phone copy |
| `Resources/presets/` | The settings baked into the iPhone app (`iphone.env`) and its entitlements |
| `Resources/tools/hl_resolution.py` | Makes the iPhone resolution file from the player's own game files |
| `Resources/engine.json` | Where the app downloads the engine from (repository and branch) |
| `scripts/` | Packaging (`make_app.sh`) and the icon |

Engine changes (graphics, pipelines, memory, game patches) belong in the nxnative branch HookLink uses, and where they help every game, upstream in nxnative itself.

## Testing a change

- **App changes:** `swift build`, then walk through every step with your own dump and phone.
- **Settings or engine changes:** build, install, and play at least Kokiri Forest, Hyrule Field and Castle Town. Report frame times from the game's log before and after, and say how warm the phone was.
- **A change must not trade one area for another:** if it helps one area, check it doesn't hurt the others.

## Commits and pull requests

- Branch from `main` and name the branch for the change: `fix/...`, `app/...`, `docs/...`.
- One topic per pull request.
- Write the title as a short sentence saying what changed. The body says why, and how you tested it (iPhone, iOS, area, fps before and after).
- No build output, dumps or generated files. Check `git status`.

## Licensing

HookLink is under the MIT License. By sending a change you agree to license it under those terms. Only send code you can license that way, and never decompiled game code or anything generated from a dump.

## Where to talk

- Issues: on this repository.
- Discord: https://discord.gg/bSrN5kEScg

Thanks for testing, reporting and sending fixes.
