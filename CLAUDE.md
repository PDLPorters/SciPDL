# SciPDL — Notes for Claude

This file is loaded automatically by Claude Code in this repo. Karl maintains SciPDL across multiple machines via Dropbox sync, so project-specific preferences live here (in addition to per-machine memory in `~/.claude/projects/`).

## What this project is

SciPDL is a drag-and-drop macOS installer (.dmg) for PDL (Perl Data Language). It bundles its own Perl, PDL, PGPLOT, GSL, CFITSIO, FFTW, Astro::FITS, and many split-out PDL modules into `/Applications/PDL` so users get a complete scientific computing environment with one drag.

Current state (as of v2.104, April 2026): tracks the latest PDL release. Builds on macOS 15 Sequoia for Apple Silicon only (Intel retired). Signed and notarised with Karl's Apple Developer ID.

See `ARCHITECTURE.md` for:
- Full component stack with versions and what each piece provides
- The full set of static linking hacks (gfortran wrapper, post-link bundle re-links, PGPLOT patches, Alien bypasses, code signing & notarisation)
- Build environment requirements (Homebrew, gfortran/gcc paths, Apple Developer signing, etc.)
- Guide for verifying test output in build logs
- **Verifying static linking with `otool -L` after a successful build** — passing tests aren't enough. Always run these checks after a build before declaring success.

## Working preferences

### Work in the main repo folder — NEVER the worktree

Do NOT use Claude Code worktrees. Edit, build, and commit directly from `/Users/karl/GIT/SciPDL/` (or wherever the repo is checked out on the current machine).

**The trap:** Claude Code may start the session in a worktree at `.claude/worktrees/<name>/`. The worktree's working directory persists across `Bash` tool calls and silently drifts back to the worktree even after you `cd` to the main repo. If you use relative paths (`./build_scipdl.sh`, `cp gfortran-static .`, `git status`, etc.) you'll silently hit STALE copies of files snapshotted when the worktree was created — not your live edits.

**Defences in place:**
- `build_scipdl.sh` itself refuses to run if `$PWD` contains `/.claude/worktrees/`. If you see this error, `cd /Users/karl/GIT/SciPDL` first.
- This file (CLAUDE.md) is loaded into every session as a reminder.

**What to actually do (this WILL happen, repeatedly):**
- **Always start every Bash command with `cd /Users/karl/GIT/SciPDL && …`** OR use absolute paths everywhere.
- For `git` operations, prefer `git -C /Users/karl/GIT/SciPDL <cmd>` over relying on cwd.
- When launching long-running builds, use absolute paths for both the script AND the log file: `/Users/karl/GIT/SciPDL/build_scipdl.sh --force-clean > /Users/karl/GIT/SciPDL/build_2.X.log 2>&1`
- If you find yourself writing `./<filename>` and you're unsure, run `pwd` first.
- The cwd has drifted at least 5+ times in this session despite explicit `cd` commands. Be paranoid.

### Snapshot working builds before version bumps

Before bumping the PDL version (e.g. 2.104 → 2.105), first create a snapshot of the current working build in a versioned subfolder:

1. Create a `v<old-version>/` folder (e.g. `v2.104/`)
2. Copy in: `README.md`, `README_dmg.rtfd/`, `build_scipdl.sh`, `go_dmg`, plus any of `gfortran-static` and `patches/` that were modified for this version
3. Then proceed with the version bump in the main repo files

Existing examples: `v2.088/`, `v2.093/`, `v2.095/` through `v2.103/`. Rule of thumb: if it changed for this release, snapshot it.

### Always consult the PDL Changes file before a version bump

PDL has frequent breaking changes — modules get split into separate distributions, APIs get renamed, build system assumptions shift. Before bumping `VERSION_PDL` in `build_scipdl.sh`, fetch and review:

**https://raw.githubusercontent.com/PDLPorters/pdl/master/Changes**

Read every entry between the current version and the target version. Watch especially for:
- Modules split out into separate CPAN distributions
- Renamed functions or removed APIs (e.g. `Ufunc::diffover` → `numdiff` in 2.099, `$pdl->inplace->transpose` became an error in 2.104)
- New minimum dependency versions (Perl, GSL, etc.)
- Build system restructuring

For large jumps (e.g. 2.093 → 2.104), upgrade in stages — one or two minor versions at a time — so failures are easier to diagnose. Karl prefers this stepwise approach over big-bang upgrades.

### Module ↔ PDL version coupling

Some modules need specific PDL versions and vice versa. Known coupling:

- **`PDL::FFTW3 0.201+` requires PDL 2.097+** (single-precision real FFTs return zeros otherwise — the workaround was removed in 0.201). When bumping PDL past 2.097, also bump PDL::FFTW3 to 0.203+.
- **`PDL::GSL 2.103+` is required for PDL 2.104+** (older PDL::GSL test uses `$x->inplace->transpose` which became an error in 2.104; 2.103 fixed the test).
- **`PDL::Transform::Proj4 2.099+`** has a numerical fix needed for PROJ 9.8+ (which Alien::proj installs).

Always check the Changes file of any module before bumping it independently of PDL.

## CPAN gotchas (the abandoned tool strikes again)

The `cpan` shell tool has been effectively abandoned for serious work in favour of `cpanm` / `cpm` / `Carton`. SciPDL still uses `cpan` for historical reasons but several traps emerge — see issue #6 for migration plans.

**Trap 1: CPAN auto-upgrades PDL behind your back.** When you run `cpan -i PDL::GSL::SF` (or similar split-out PDL modules), CPAN sees PDL listed as a build_requires and decides to "satisfy" it by installing the LATEST PDL — even if you've just carefully built a specific PDL version. This silently overwrites your `/Applications/PDL/.../PDL.pm` with whatever's current on CPAN.

**Workaround used in `build_scipdl.sh`:** the `install_local_tarballs` shell function downloads pinned tarball versions ourselves (via curl) and runs `tar / perl Makefile.PL / make / make test / make install` manually, bypassing CPAN's prereq resolution entirely. Used for all PDL family modules (GSL, Complex, Fit, Slatec, etc.).

**Trap 2: `cpan` mangles local file paths.** `cpan -i /local/path/foo.tar.gz` interprets the path as a partial CPAN distribution identifier and constructs bogus URLs like `https://cpan.org/authors/id/U/Users/karl/...`. Use the manual unpack/build/install pattern instead.

**Trap 3: `cpan -M <mirror>` is documented but doesn't reliably work.** The flag exists in the manpage but in this version of cpan it doesn't override the mirror. Default mirror (`cpan.org`) only keeps the latest version of each distro; older versions are on `cpan.metacpan.org` or BackPAN.

**Trap 4: CPAN's default mirror drops old versions.** `cpan -i ETJ/PDL-GSL-2.096.tar.gz` 404s if PDL-GSL has had a newer release. Solution: fetch from `cpan.metacpan.org` directly (which keeps everything), or use BackPAN.

**Trap 5: ExtUtils::MakeMaker silently strips absolute `.a` paths from LIBS.** If you do `perl Makefile.PL LIBS="-L/foo -lbar /path/to/lib.a"`, EUMM's parser identifies the `.a` path as "not a real library" and removes it. No warning. The link line ends up with unresolved symbols. Solution: manually re-link the resulting `.bundle` file with explicit static archives (the established Slatec/Minuit/PGPLOT pattern).

## External resource gotchas

- **Dropbox URLs need `?dl=1` to actually download.** The bare share URL serves an HTML preview page. The `pgplot531.tar.gz` URL in `build_scipdl.sh` uses `?dl=1`. If a Dropbox-hosted dependency mysteriously becomes a 470-byte HTML page, this is why.
- **Apple Developer cert G2 chain transition.** When renewing certs after a lapse, Apple's portal now only issues G2-chain certs. If your keychain has only the legacy intermediate CA, signing will fail with `unable to build chain to self-signed root`. Fix: download Apple Root CA - G2 (https://www.apple.com/certificateauthority/AppleRootCA-G2.cer) and Developer ID - G2 (https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer) and `open` them to install. Apple does not bundle intermediates with the leaf cert download.

## Build environment quirks

- Build script must be run from the repo root (uses `$PWD` as `$HERE`).
- Anaconda must be deactivated (`conda deactivate`) — script refuses to run if `$CONDA_PREFIX` is set.
- Karl has `PERL5DB` and `PERL5LIB` set in his shell profile for his own perl development; the build script `unset`s these to avoid interference.
- The build script supports `--clean` (interactive prompt) and `--force-clean` (no prompt, for scripted runs) to nuke `/Applications/PDL` and `~/Downloads/build` before starting.

### Running from non-TTY environments (e.g. Claude Code's Bash tool)

Without a controlling terminal, Perl's `lib/perl5db.t` test hangs (it tries to open `/dev/tty`). The build script replaces this test with a skip stub before `make test` to work around this. Doesn't affect interactive terminal builds.

When launching builds via Claude's Bash tool with `run_in_background=true`, the script process can sometimes get killed unexpectedly (orphaning the make-test sub-processes that keep running with PPID 1). Cause not fully diagnosed but likely related to the tool's signal handling. Mitigation: use absolute paths and avoid `kill` cleanup commands near a fresh `run_in_background` launch.

## Currently bundled modules (as of v2.104)

### C libraries (built from source, statically linked)
- Perl 5.42.2 (own private install)
- PGPLOT 5.3.1 + Perl PGPLOT 2.35
- GSL 2.8
- CFITSIO 4.6.3
- FFTW 3.3.11 (built twice: double + single precision)
- libgd 2.3.3 (PNG + JPEG only — no TIFF/WebP/FreeType)
- libjpeg-turbo 3.1.4.1 (so libgd can do JPEG)

### Core PDL family
- PDL 2.104
- PDL::FFTW3 0.203
- PDL::Minuit 0.002 (Fortran, manual re-link)
- PDL::Slatec 2.098 (Fortran, manual re-link)

### Split-out modules (post-2.096) — pinned versions, manual install via `install_local_tarballs`
- PDL::GSL 2.103
- PDL::Complex 2.011
- PDL::Fit 2.100
- PDL::Graphics::Limits 0.03
- PDL::IO::Dicom 2.098
- PDL::IO::Browser 0.001
- PDL::Transform::Proj4 2.099
- PDL::IO::IDL 2.098
- PDL::Opt::Simplex 2.097

### Issue #4 wishlist (mohawk2's list)
- PDL::Graphics::Simple 1.016 (modern auto-detecting plot frontend)
- PDL::Graphics::ColorSpace 0.206
- PDL::Transform::Color 1.010
- PDL::Graphics::Gnuplot 2.032 (**runtime requires `gnuplot` binary** — user installs separately, e.g. via Homebrew)
- PDL::IO::GD 2.103 (PNG + JPEG; not TIFF/WebP/TTF)

### Issue #5 user-requested modules (pure Perl/XS via cpan -i)
- DateTime, String::Scanf, Devel::Size, List::Uniq
- LWP::UserAgent, Test::Number::Delta, Parallel::ForkManager
- PDL::NDBin

### Deliberately NOT bundled
- **PDL::IO::HDF** — needs HDF4 (libhdf), awkward static build, value debatable now most science uses HDF5/NetCDF
- **PDL::Graphics::TriD** — needs OpenGL/freeglut. Apple deprecated OpenGL years ago, slated for eventual removal
- **PDL::Perldl2** — alternative shell, was silently failing to install in pre-2.096 builds anyway, deferred
- **`gnuplot` binary itself** — runtime dep of PDL::Graphics::Gnuplot but bundling it would mean compiling gnuplot statically with all its terminal backends, separate project
- **JPEG TTF text rendering in libgd** (`gdImageStringTTF`) — would need static FreeType + HarfBuzz + ICU, not worth it for one rarely-used function

## The libgd/libjpeg-turbo pattern (for future image format additions)

PDL::IO::GD's API exposes PNG, JPEG, GIF, WBMP, Gd/Gd2 file formats. Of these, GIF/WBMP/Gd/Gd2 are built-in to libgd; PNG and JPEG need external libs. Our build:

1. Builds **libjpeg-turbo** statically into `/Applications/PDL/lib/libjpeg.a` via cmake (Homebrew only ships libjpeg as dylib)
2. Builds **libgd** statically with `--with-png=/opt/homebrew --with-jpeg=/Applications/PDL` (uses our static libjpeg + Homebrew's static libpng) but `--without-tiff --without-webp --without-freetype` etc.
3. Builds **PDL::IO::GD** with `GD_LIBS=/Applications/PDL/lib GD_INC=/Applications/PDL/include` env vars
4. **Manually re-links the GD.bundle** to add `/opt/homebrew/lib/libpng.a` and `/Applications/PDL/lib/libjpeg.a` directly (bypassing EUMM's LIBS-stripping)

To add e.g. WebP support in the future: add libwebp static build (cmake), add `--with-webp=...` to libgd configure, append `libwebp.a` to the GD.bundle re-link line. Same pattern.

## Where to find things

- `ARCHITECTURE.md` — full build system documentation, component stack, static linking hacks, test verification guide
- `build_scipdl.sh` — master build script (refuses to run from worktree)
- `go_dmg` — DMG packaging script (signs and notarises)
- `gfortran-static` — wrapper that statically links libgfortran/libgcc/libquadmath
- `patches/` — source patches applied during the build (only PGPLOT and FFTW3 currently — minor)
- `v2.X/` — snapshots of past working builds (per the snapshot rule above)
