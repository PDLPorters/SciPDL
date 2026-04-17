# SciPDL — Notes for Claude

This file is loaded automatically by Claude Code in this repo. Karl maintains SciPDL across multiple machines via Dropbox sync, so project-specific preferences live here (in addition to per-machine memory in `~/.claude/projects/`).

## What this project is

SciPDL is a drag-and-drop macOS installer (.dmg) for PDL (Perl Data Language). It bundles Perl, PDL, PGPLOT, GSL, CFITSIO, FFTW, Astro::FITS, and friends into `/Applications/PDL` so users get a complete scientific computing environment with one drag.

See `ARCHITECTURE.md` for:
- Full component stack with versions and what each piece provides
- The six layers of static linking hacks (gfortran wrapper, post-link bundle swaps, PGPLOT patches, Alien bypasses, code signing & notarisation)
- Build environment requirements (Homebrew, gfortran/gcc paths, Apple Developer signing, etc.)
- Guide for verifying test output in build logs (what successful tests look like for each component, false-failure indicators to ignore, real failure indicators to act on)
- **Verifying static linking with `otool -L` after a successful build** (passing tests aren't enough — bundles can sneak in dynamic deps on libgfortran/libquadmath/Homebrew libs that won't be on user machines). Always run these checks after a build before declaring success.

## Working preferences

### Work in the main repo folder

Do NOT use Claude Code worktrees. Edit, build, and commit directly from `/Users/karl/GIT/SciPDL/` (or wherever the repo is checked out on the current machine). Karl finds the worktree indirection confusing.

### Snapshot working builds before version bumps

Before bumping the PDL version (e.g. 2.095 → 2.096), first create a snapshot of the current working build in a versioned subfolder:

1. Create a `v<old-version>/` folder (e.g. `v2.095/`)
2. Copy in: `README.md`, `README_dmg.rtfd/`, `build_scipdl.sh`, `go_dmg`, plus any of `gfortran-static` and `patches/` that were modified for this version
3. Then proceed with the version bump in the main repo files

Existing examples: `v2.088/`, `v2.093/`, `v2.095/`. This preserves the working build for each release without requiring git archaeology. The earlier v2.088 and v2.093 snapshots only have the four core files because `gfortran-static` and `patches/` happened to be unchanged for those releases. The v2.095 snapshot includes `gfortran-static` and `patches/` because both changed (`-static-libquadmath` added to the wrapper, FFTW3 patch fixed). Rule of thumb: if it changed for this release, snapshot it.

### Always consult the PDL Changes file before a version bump

PDL has frequent breaking changes — modules get split into separate distributions, APIs get renamed, build system assumptions shift. Before bumping `VERSION_PDL` in `build_scipdl.sh`, fetch and review:

**https://raw.githubusercontent.com/PDLPorters/pdl/master/Changes**

Read every entry between the current version and the target version. Watch especially for:
- Modules split out into separate CPAN distributions (e.g. `PDL::Minuit`, `PDL::Slatec`, `PDL::GSL`, `PDL::Complex` were all extracted from PDL core in v2.096) — these need new build sections following the PDL::FFTW3/PDL::Minuit pattern
- Renamed functions or removed APIs
- New minimum dependency versions (Perl, GSL, etc.)
- Build system restructuring (e.g. v2.096's move to standard Perl distro layout broke the Slatec/Minuit post-link hacks that referenced `Libtmp/Slatec` and `Libtmp/Minuit` paths)

For large jumps (e.g. 2.093 → 2.104), upgrade in stages — one or two minor versions at a time — so failures are easier to diagnose. Karl prefers this stepwise approach over big-bang upgrades.

### ⚠ v2.096 is the big restructuring — expect significant work

When upgrading past v2.095 to v2.096, brace for a major rebuild of the script. v2.096 split many things out of PDL core into separate CPAN distributions, and reorganised the source tree to standard Perl layout (`lib/`). Things that will break:

- **`PDL::Slatec`** — split out. The post-link hack in `build_scipdl.sh` that re-links `Libtmp/Slatec/Slatec.bundle` won't find that path anymore. Need to add a separate Slatec build section like we did for Minuit (it's Fortran, so static linking via gfortran wrapper).
- **`PDL::GSL`** — split out. Currently we install GSL the C library and PDL picks it up; in 2.096+ we need a separate `cpan -i PDL::GSL` or curl/build section.
- **`PDL::GSLSF::*`** — merged into single `PDL::GSL::SF`. Anything depending on the old namespace will break.
- **`PDL::Complex`** — split out into separate distro.
- **`PDL::Graphics::TriD`**, **`PDL::IO::Browser`**, **`PDL::IO::IDL`**, **`PDL::IO::Dicom`**, **`PDL::IO::GD`**, **`PDL::IO::HDF`**, **`PDL::Fit`**, **`PDL::Opt::Simplex`**, **`PDL::Perldl2`**, **`PDL::Graphics::Limits`**, **`PDL::Transform::Proj4`** — all separate distros now. Decide which are needed for the "kitchen sink".
- **`PDL::Graphics::State`** — moved to the PGPLOT distro.
- **`CallExt`**, `PDL::PP::Dump`, `PDL::Graphics2D` — removed entirely.
- **GSL >= 2.0 required** (we're already on 2.8, so this is fine).

Expected workflow for the v2.096 upgrade: snapshot v2.095 first (per the rule above), then add a `cpan -i` or curl/build/post-link section for each split-out module that's part of the SciPDL "kitchen sink". Test each one in isolation (small shell script following the Minuit pattern) before integrating into the main build script.

## Build environment quirks

- Build script must be run from the repo root (uses `$PWD` as `$HERE`).
- Anaconda must be deactivated (`conda deactivate`) — script refuses to run if `$CONDA_PREFIX` is set.
- Karl has `PERL5DB` and `PERL5LIB` set in his shell profile for his own perl development; the build script `unset`s these to avoid interference.
- The build script supports `--clean` (interactive prompt) and `--force-clean` (no prompt, for scripted runs) to nuke `/Applications/PDL` and `~/Downloads/build` before starting.

### Running from non-TTY environments (e.g. Claude Code's Bash tool)

Without a controlling terminal, Perl's `lib/perl5db.t` test hangs (it tries to open `/dev/tty`). The build script replaces this test with a skip stub before `make test` to work around this. Doesn't affect interactive terminal builds.

## Where to find things

- `ARCHITECTURE.md` — full build system documentation, component stack, static linking hacks, test verification guide
- `build_scipdl.sh` — master build script
- `go_dmg` — DMG packaging script (signs and notarises)
- `gfortran-static` — wrapper that statically links libgfortran/libgcc/libquadmath
- `patches/` — source patches applied during the build
