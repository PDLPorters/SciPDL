# Building and releasing SciPDL

This is the human-friendly walkthrough for building SciPDL end-to-end on a fresh Mac and producing a signed/notarised `.dmg` ready for release. Aimed at maintainers and the curious.

For *what's bundled* and *why the build is structured the way it is*, see [`ARCHITECTURE.md`](ARCHITECTURE.md). For day-to-day Claude Code working notes, see [`CLAUDE.md`](CLAUDE.md).

---

## 1. Prerequisites

### A working Homebrew

The build relies heavily on Homebrew for static libraries (libpng, libX11, libxcb, etc.) and tooling (cmake, gfortran). Install Homebrew first if you don't have it: <https://brew.sh>.

### Homebrew packages

```bash
brew install \
    libpng \
    libx11 \
    libxcb \
    xquartz \
    cmake \
    gnuplot
```

Notes:
- **`libpng`, `libx11`, `libxcb`** — needed for PGPLOT's static linking. The build script reads `/opt/homebrew/lib/libpng.a`, `/opt/homebrew/lib/libX11.a` etc. directly.
- **`xquartz`** — required at *runtime* for users to display PGPLOT graphics, and needed during the build so PGPLOT can find X11 headers.
- **`cmake`** — used by libjpeg-turbo's build system.
- **`gnuplot`** — only needed at *build* time so `Alien::Gnuplot` finds a working system gnuplot rather than downloading its own (broken on macOS) gnuplot 5.4. End users install their own gnuplot if they want to use `PDL::Graphics::Gnuplot`.

**For DMG packaging (only if you're producing a distributable installer):** you need `create-dmg`, which is NOT covered by Homebrew here — clone it from <https://github.com/create-dmg/create-dmg> and edit the `CREATE_DMG=` line in `go_dmg` to point at your clone. See the "create-dmg" sub-section below for details.

### gcc and gfortran (NOT from Homebrew)

The build needs **real GCC** (not Apple's clang, which is what `/usr/bin/gcc` is on macOS) and **gfortran**. The currently-tested setup uses the standalone macOS installers from François-Xavier Coudert:

- **<https://github.com/fxcoudert/gfortran-for-macOS/releases>** — pick the latest release matching your macOS / architecture. This installs both `gcc` and `gfortran` (real GCC 14.x) under `/usr/local/gfortran/` with symlinks at `/usr/local/bin/gcc` and `/usr/local/bin/gfortran`.

The `gfortran-static` wrapper in this repo expects `/usr/local/bin/gfortran`. If you install elsewhere, edit that script.

> *Note:* Homebrew also offers `brew install gcc` (which provides `gcc-14`, `gfortran-14`, etc.) but **the SciPDL build has not been tested against the Homebrew GCC** as of v2.104. If you go that route you'll likely need to update `gfortran-static` to point at the Homebrew paths (`/opt/homebrew/bin/gcc-14`, `/opt/homebrew/bin/gfortran-14`) and check that the link line conventions still work. Patches welcome.

### create-dmg (only if you're producing a distributable DMG)

`go_dmg` uses [create-dmg](https://github.com/create-dmg/create-dmg) — a shell script that builds fancy disk images with custom backgrounds, icon positions, and an Applications folder symlink. Currently `go_dmg` hard-codes a path to a local checkout (the maintainer's lives at `~/Dropbox/Software/SciPDL-Own-Perl/create-dmg`, which is `create-dmg 1.2.0`).

**The tested setup:** clone the upstream repo and point `go_dmg` at it.

```bash
git clone https://github.com/create-dmg/create-dmg ~/path/to/create-dmg
# Then edit the CREATE_DMG= line near the top of go_dmg to point at ~/path/to/create-dmg
```

**You could try the Homebrew version instead:**

```bash
brew install create-dmg
```

Homebrew's `create-dmg` is currently version `1.2.3` (vs the maintainer's `1.2.0`) — same upstream project, slightly newer. In principle changing the `CREATE_DMG=` line in `go_dmg` to something like `CREATE_DMG=$(dirname $(which create-dmg))` should work. **This path is untested** with the SciPDL flow as of v2.104. Patches welcome.

### NO Anaconda in the active environment

The build script **refuses to run** if `$CONDA_PREFIX` is set, because Anaconda's Python aggressively rewrites paths and breaks the build in subtle ways. Before each build:

```bash
conda deactivate
```

Make sure your `~/.bashrc` / `~/.zshrc` does NOT auto-activate the base conda environment. Look for and remove (or comment out) anything like:

```bash
# >>> conda initialize >>>
# ...
conda activate base   # <-- remove or comment out this kind of line
# <<< conda initialize <<<
```

You can keep `conda` itself installed and available, just don't have it active by default.

### Apple Developer ID (ONLY if you're producing a DMG for distribution)

You can build SciPDL into `/Applications/PDL/` and use it locally on your own machine without any of this — just skip ahead to "Building the SciPDL tree" and stop after that section. The signing, notarisation, and DMG steps are only needed if you want to produce a one-click installer DMG to give to other people. For personal use, the build output in `/Applications/PDL/` works directly: `source /Applications/PDL/setup_bash` and you're good.

If you DO want to produce a distributable DMG, you need an active **Apple Developer Program** membership ($99/year) and a **Developer ID Application** certificate.

1. Generate a CSR via Keychain Access → Certificate Assistant → Request a Certificate from a CA. Fill in your email and name; tick "Saved to disk"; choose 2048-bit RSA.
2. Go to <https://developer.apple.com/account/resources/certificates/list>, click "+", choose **Developer ID Application**, profile type **G2 Sub-CA (Xcode 11.4.1 or later)**. Upload the CSR. Download the resulting `.cer` and double-click to install.
3. Install the **G2 intermediate certificates** in your keychain (Apple does NOT bundle them with the leaf cert):

   ```bash
   curl -O https://www.apple.com/certificateauthority/AppleRootCA-G2.cer
   curl -O https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
   open AppleRootCA-G2.cer
   open DeveloperIDG2CA.cer
   ```

4. Verify:

   ```bash
   security find-identity -p codesigning -v
   ```

   Should show one valid identity:

   ```
   1) <hash> "Developer ID Application: Your Name (TEAMID)"
        1 valid identities found
   ```

5. Set up **notarytool credentials**. Generate an app-specific password at <https://appleid.apple.com> (Sign-In and Security → App-Specific Passwords → Generate). Then:

   ```bash
   xcrun notarytool store-credentials AC_PASSWORD \
       --apple-id your-apple-id@example.com \
       --team-id YOURTEAMID \
       --password xxxx-xxxx-xxxx-xxxx
   ```

   The label `AC_PASSWORD` must match what `go_dmg` looks up.

---

## 2. Building the SciPDL tree

Clone the repo (anywhere convenient) and run the build script from its root:

```bash
cd /path/to/SciPDL
./build_scipdl.sh --force-clean > build_log.txt 2>&1
```

What this does:

- **Wipes** `/Applications/PDL` and `~/Downloads/build` (the `--force-clean` flag — `--clean` would prompt).
- **Downloads** all sources (Perl, PDL, PGPLOT, GSL, CFITSIO, FFTW, libgd, libjpeg-turbo, ~20 PDL family modules) into `~/Downloads/build/`.
- **Compiles and installs** everything into `/Applications/PDL/`. Statically links Fortran libraries via the `gfortran-static` wrapper, manually re-links several `.bundle` files for static-only dependencies.
- **Runs tests** for each component.
- Takes about **30 minutes** on a current Apple Silicon Mac.

Output: `/Applications/PDL/` contains a complete self-contained PDL distribution. The `build_log.txt` file is around 75 000 lines and is your record of what happened.

### Sanity checks

```bash
# Confirm PDL works
/Applications/PDL/bin/perl -MPDL -E 'say "PDL ", PDL->VERSION; say pdl([1,2,3])'

# Count test results in the log
grep -c "Result: PASS" build_log.txt   # expect ~180
grep -c "Result: FAIL" build_log.txt   # expect 0

# Spot-check static linking — these should show only /usr/lib/libSystem and /usr/lib/libz at most
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PDL/Slatec/Slatec.bundle
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PDL/Minuit/Minuit.bundle
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PGPLOT/PGPLOT.bundle
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PDL/IO/GD/GD.bundle
```

### Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Script exits immediately with anaconda message | `$CONDA_PREFIX` is set | `conda deactivate` |
| Script exits with worktree error | running from a Claude Code worktree | `cd` to the actual repo checkout |
| `lib/perl5db.t` test hangs forever | non-TTY environment | the script should already replace this test with a stub; if not, you're running an out-of-date script |
| `PDL::Graphics::Gnuplot` test crashes | Alien::Gnuplot downloaded its own broken gnuplot | `brew install gnuplot` and re-run |
| Random module fails with "Can't locate Foo.pm" | a missed transitive dep | `cpan -i Foo` then re-run from clean |

See `ARCHITECTURE.md` for details on what passing tests look like and how to spot real failures vs. cosmetic noise.

---

## 3. Building the DMG (optional — for distribution)

> **Skip this and the following sections if you only want SciPDL for personal use.** Your build is already complete — the previous step's `/Applications/PDL/` is fully functional. `source /Applications/PDL/setup_bash` in any terminal and you're done. The DMG steps below are just for producing a signed installer to share with others.

Once `/Applications/PDL/` is good, build the signed/notarised `.dmg`:

```bash
./go_dmg
```

This script:

1. Tarballs `/Applications/PDL/` into a `.tar.gz` (for archival without signature complexities).
2. Recursively code-signs every executable and `.bundle` in the staging tree with your Developer ID Application certificate.
3. Adds a special entitlement to the `perl` binary so users can `cpan -i` modules that load shared libraries.
4. Builds the `.dmg` via `create-dmg` with a custom background and Applications-folder symlink.
5. Submits the `.dmg` to Apple's notary service (uses the `AC_PASSWORD` keychain credential), waits for approval (typically a few minutes).
6. Staples the notarisation ticket to the `.dmg` so Gatekeeper can verify offline.

Output: `~/Downloads/SciPDL-vX.YYY.dmg`, signed and notarised. Takes about 5 minutes.

---

## 4. Testing the DMG

Before publishing the release:

1. **Install on a clean Mac** if you have one available — drag the `PDL` folder from the mounted DMG to `/Applications/`. Open Terminal, `source /Applications/PDL/setup_bash`, run `pdl`, plot something. Confirm Gatekeeper doesn't grumble.
2. If no clean Mac, at least verify on your build machine that the DMG mounts cleanly and that running the bundled `pdl` starts the shell without errors.

---

## 5. Releasing on GitHub

1. Bump the `version=` line in `go_dmg` if you haven't already (probably already done as part of the version bump).
2. Tag and push:

   ```bash
   git tag -a vX.YYY -m "SciPDL vX.YYY"
   git push origin vX.YYY
   ```

3. Create the release at `https://github.com/PDLPorters/SciPDL/releases/new?tag=vX.YYY`. Upload the `.dmg`. Paste release notes (see previous releases for the format).

---

## 6. After the release

- Test the published DMG by downloading it via the public URL on a different Mac (verifies Gatekeeper accepts the notarised version).
- Reply to any open issues that reference modules or features the release addresses.
- If the bundle has new components, double-check the version tables in `README.md` and the in-DMG `README_dmg.rtfd` are up to date.

---

## Where to look when things go wrong

- **Build log:** the `build_log.txt` (or whatever you named it). 75 000 lines, but `grep -A5 "Result: FAIL"` will find any actual failure quickly.
- **`ARCHITECTURE.md`** — documents the static-linking hacks, the CPAN workarounds, and what passing tests look like for each component.
- **`CLAUDE.md`** — has working notes including the various traps encountered during PDL upgrades, EUMM gotchas, and the Apple G2 cert renewal trap.
- **`v2.X/` snapshot folders** — preserved copies of the build script that worked for each prior release, in case you need to compare.

---

## Acknowledgements

SciPDL is maintained by Karl Glazebrook. The build infrastructure has been refined over many years of releases (going back to PDL 2.020-something) and by collective experience of PDL users and developers, especially in the v2.096 split-out era. See `ARCHITECTURE.md` for the technical lineage.
