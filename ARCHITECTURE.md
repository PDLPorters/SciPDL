# SciPDL Build Architecture

## What SciPDL Is

SciPDL is a drag-and-drop macOS installer (.dmg) for PDL (Perl Data Language). It bundles a complete scientific computing stack into `/Applications/PDL` — its own Perl, numerical libraries, plotting, and FITS I/O — so users install by dragging a folder. This repo is the build/packaging infrastructure, not PDL source itself.

The core problem: scientists need PDL to "just work" on macOS without compiling dependencies. No package manager, no Xcode, no Homebrew required (except an X11 server for PGPLOT graphics). Every hack in this repo exists because an upstream project assumes shared libraries or system paths.

## Component Stack (v2.093)

| Component | Version | Purpose |
|---|---|---|
| Perl | 5.40.0 | Private install (not system perl) |
| PDL | 2.093 | Perl Data Language |
| PGPLOT | 5.3.1 + Perl 2.35 | Fortran plotting library + Perl bindings |
| GSL | 2.8 | GNU Scientific Library |
| CFITSIO | 4.5.0 | FITS file I/O (astronomy) |
| Astro::FITS::CFITSIO | 1.18 | Perl CFITSIO bindings |
| Astro::FITS::Header | 3.09 | FITS header handling |
| FFTW | 3.3.10 + PDL::FFTW3 0.20 | Fast Fourier Transforms (built twice: double and single precision) |
| ExtUtils::F77 | 1.26 | Fortran linking support for Perl |

## Repo File Map

| File/Dir | Purpose |
|---|---|
| `build_scipdl.sh` | Master build script — downloads and compiles everything from source |
| `go_dmg` | Packages built install into signed/notarised .dmg |
| `gfortran-static` | 2-line wrapper that shadows gfortran to force static linking |
| `setup_bash` / `setup_csh` | User PATH setup scripts (go into distribution) |
| `go_pdl` | Launcher for interactive PDL sessions |
| `entitlements.plist` | Gives perl binary `com.apple.security.cs.disable-library-validation` |
| `Apps/` | AppleScript apps "pdl [here]" and "pdl [home]" for Finder launching |
| `patches/` | Source patches for pgplot, FFTW3 bindings, Astro::FITS |
| `DMG-Background.png` | Background image for the .dmg window |
| `README_dmg.rtfd` | RTF README bundled inside the .dmg |
| `v2.088/` | Older version of builder scripts |

## The Static Linking Hack Stack

### 1. The gfortran Trojan Horse (`gfortran-static`)

A 2-line script that wraps the real gfortran:
```bash
/usr/local/bin/gfortran -static-libgfortran -static-libgcc $@
```
At build_scipdl.sh:29 it's copied to a file named `gfortran` and prepended to `$PATH`. Every Fortran compilation in the entire build tree silently gets static linking — no upstream Makefiles need modification.

### 2. PGPLOT Perl Module Post-Link Swap (build_scipdl.sh:144–147)

Comment in source: `# Now super ugly hack to make the bundle static!`

After `perl Makefile.PL && make` produces PGPLOT.bundle with dynamic linking, the bundle is manually re-linked by hand, bypassing the Perl Makefile entirely. Links static `.a` archives of X11, XCB, Xdmcp, Xau, and libpng by absolute Homebrew path:
```bash
gfortran -bundle -undefined dynamic_lookup ... \
   -L/Applications/PDL/pgplot -lcpgplot -lpgplot -static-libgfortran -static-libgcc \
   /opt/homebrew/lib/libX11.a /opt/homebrew/lib/libxcb.a \
   /opt/homebrew/lib/libXdmcp.a /opt/homebrew/lib/libXau.a \
   /opt/homebrew/lib/libpng.a -lz
```
Then `make` is called again so the install step picks up the swapped bundle.

### 3. PDL Slatec/Minuit Re-link (build_scipdl.sh:232–236)

Same post-link trick for PDL's Fortran numerical library modules. After PDL's normal `make`, cd into the build tree subdirectories and manually re-link `Slatec.bundle` and `Minuit.bundle`, listing every `.o` file explicitly to override whatever the Perl build system produced.

### 4. PGPLOT Source Patches (`patches/pgplot2.patch`)

Multiple hacks stacked in one patch file:

- **Hardcoded default dir**: `/usr/local/pgplot/` → `/Applications/PDL/pgplot/` in Fortran source (`grgfil.f`)
- **X11 server fallback**: Adds `/Applications/PDL/pgplot` as extra search path for `pgxwin_server` in the X11 driver
- **libpng API fix**: `png_ptr->jmpbuf` → `png_jmpbuf(png_ptr)` for modern libpng 1.6 (the original code's comment reads "not really sure what I'm doing here...")
- **Static libpng in makemake**: Replaces `-lpng` with `/opt/homebrew/lib/libpng.a`
- **Header dependency removal**: Comments out pndriv.o header deps that don't exist in build dir
- **Driver list curation**: Disables GIF, HPGL, Tektronix terminal drivers; enables PNG
- **Custom compiler config**: New `gfortran_gcc_BigSur_static.conf` that hardcodes all Homebrew static library paths for X11/png

### 5. Alien Bypass Patches

Perl's "Alien" system for finding external C libraries doesn't work in this self-contained build context. Both patches gut it:

**`patches/AstroFitsIO.patch`** — Rips out `Alien::Base::Wrapper` and `Alien::CFITSIO` entirely, replaces with plain `ExtUtils::MakeMaker`. Library paths are passed manually on the `perl Makefile.PL` command line in build_scipdl.sh.

**`patches/pdl-fftw3-0.20.patch`** — Disables both the Alien detection AND the pkg-config fallback (`elsif (0) { # KG don't run this test`), then hardcodes:
```perl
$libs = "-Wl,-no_compact_unwind -L/Applications/PDL/lib -lfftw3 -lfftw3f";
```
Note FFTW is built twice — once for double precision (`libfftw3`) and once with `--enable-float` for single precision (`libfftw3f`). Both are linked here so PDL::FFTW3 can offer FFTs in either precision.

### 6. Code Signing & Notarisation (`go_dmg`)

After all the static linking, Apple's Gatekeeper still needs satisfying:
1. `find` locates every executable and `.bundle` file in the distribution
2. `codesign -f` force-signs them all with Developer ID (even ones already signed during compilation)
3. The `perl` binary gets a special entitlement (`disable-library-validation`) so users can still `cpan install` modules that load unsigned shared libraries
4. DMG is built with `create-dmg`, signed, and notarised through Apple's servers
5. A `.tar.gz` is also created for archiving without signature complexities

## Build Environment Requirements

- **Must deactivate Anaconda** before building (script checks `$CONDA_PREFIX` and refuses)
- Builds in `~/Downloads/build`
- Homebrew static libraries at `/opt/homebrew/lib/` (X11, png, xcb, etc.)
- `/usr/local/bin/gfortran` (HPC/Homebrew gfortran)
- `/usr/local/bin/gcc` (HPC gcc, not Apple clang)
- Apple Developer account for code signing
- `create-dmg` tool from `~/Dropbox/Software/SciPDL-Own-Perl/create-dmg`
- `PERL_MM_USE_DEFAULT=1` suppresses CPAN prompts
- GSL compiled with `-g -O` (not `-O2`) to work around an ARM64 gcc optimisation bug
- cfitsio dylibs are deleted after install to force static linking

## Architecture Support

Build script detects `uname -m` for x86_64 vs arm64 (Apple Silicon). Builds natively for whichever arch the build machine is running.

## Verifying a Build

A successful run of `build_scipdl.sh` produces ~45,000 lines of output. The build runs `set -e` so it will stop on any command failure, but tests need manual verification too. Here's what to check in the build log.

### Quick health check

```bash
# Should find zero real failures:
grep "Result: FAIL" build.log

# Count passes — expect 30+ across all components:
grep -c "Result: PASS" build.log

# The final line should be:
# +++++++++++++++++++++++++++++ Done! +++++++++++++++++++++++++++++
tail -10 build.log
```

### Per-component test signatures

**Perl** (`make test`) — The largest test run. Look for:
```
All tests successful.
Elapsed: NNN sec
u=...  s=...  cu=...  cs=...  scripts=2646  tests=1185744
```
~1.18 million individual tests across ~2,646 scripts. Some tests will show `skipped` (e.g. dtrace, threads) — that is normal.

**PGPLOT Perl module** — 16 test files (t1.t through t12.t plus others). Look for:
```
All tests successful.
Files=16, Tests=16 ... Result: PASS
```
Two tests (`t/lut.t`, `t/pdl-graphics.t`) will show `skipped: No PDL` — this is expected because PDL isn't installed yet at this build stage. Tests run against `/NULL` device (`PGPLOT_DEV=/NULL`).

**GSL** (`make check`) — Autotools-style testing, ~40+ submodules. Each prints:
```
PASS: test
Testsuite summary for gsl 2.8
# TOTAL: 1
# PASS:  1
# FAIL:  0
```
Verify no submodule has `# FAIL:` with a non-zero value.

**CFITSIO** — The most minimal test. The build runs `./testprog > foo.out` then `diff foo.out testprog.out`. A successful test produces only:
```
---------- Testing ----------
----------------------------
```
No output between those lines means the diff was empty (pass). Any text between them is a failure.

**FFTW** (`make check`) — Runs twice (double precision, then single precision with `--enable-float`). Each run produces autotools test output similar to GSL. Look for `# FAIL: 0` in both runs.

**Astro::FITS::CFITSIO** — Standard Perl test:
```
All tests successful.
Result: PASS
```

**PDL** (`make test`) — The main event. Tests run per-subdirectory across the PDL source tree. Key test suites to look for:

| Subdirectory | Tests | What it covers |
|---|---|---|
| NiceSlice | 137 | Syntactic sugar |
| Demos | 7 | Demo scripts |
| Limits | 119 | Data range handling |
| IO/FITS | 123 | FITS file I/O |
| IO/FlexRaw | 66 | Raw binary I/O (incl. Fortran) |
| IO/Pnm | 54 | Image file I/O |
| Image2D | 55 | 2D image processing |
| Complex | 156 | Complex number support |
| Slatec | 58 | Numerical library bindings |
| Minuit | 5 | Minimisation library |
| Transform | 68 | Coordinate transforms |
| **Core** (t/*.t) | **2,348** | **Main PDL test suite — 45 files** |

The core PDL test summary looks like:
```
All tests successful.
Test Summary Report
-------------------
t/pdl_from_string.t  (Wstat: 0 Tests: 144 Failed: 0)
  TODO passed:   60-62
t/primitive-random.t (Wstat: 0 Tests: 3 Failed: 0)
  TODO passed:   1
Files=45, Tests=2348, NN wallclock secs
Result: PASS
```
`TODO passed` entries are good news — tests expected to fail that actually passed. `Failed: 0` is the critical field.

**PDL::FFTW3** — 2 test files, 178 tests. `t/threads.t` will be skipped (Perl built without threads). Look for:
```
All tests successful.
Files=2, Tests=178 ... Result: PASS
```

**Inline::C** — Final CPAN module installed. Has its own test suite:
```
All tests successful.
Result: PASS
```

### Things that look like failures but aren't

- **`TODO passed`** in Test Summary Reports — tests marked "expected to fail" that actually passed. Good news.
- **`skipped`** tests — tests that correctly detect missing prerequisites (no X11 display, no threads, no PDL yet) and skip. Normal.
- **`Warning: IDL file is v9`** during PDL IO tests — harmless warning about reading an IDL save file.
- **`# XFAIL: 0`** in GSL/FFTW output — "expected failures" counter, should be 0.
- **`Ignoring record of unknown type 19`** during PDL IO tests — harmless.
- **CPAN messages like `'YAML' not installed, will not store persistent state`** — cosmetic, not a problem.

### Genuine failure indicators

- `Result: FAIL` anywhere
- `Failed: N` with N > 0 in Test Summary Reports (excluding TODO)
- Non-empty output between CFITSIO's `---------- Testing ----------` markers
- `# FAIL:` with non-zero value in GSL/FFTW test summaries
- Build script stopping before reaching `+++++++++++++++++++++++++++++ Done! +++++++++++++++++++++++++++++`

### Verify static linking with `otool -L`

A passing test suite is necessary but not sufficient — the build can succeed and tests can pass while leaving dynamic dependencies on libraries that won't be available on end users' machines (e.g. `libgfortran.5.dylib`, `libquadmath.0.dylib`, Homebrew libpng/libX11). After a successful build, **always check the key bundles for unwanted dynamic dependencies**.

```bash
# The Fortran-heavy bundles — these are the highest-risk for libgfortran/libquadmath leakage
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PDL/Minuit/Minuit.bundle
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PDL/Slatec/Slatec.bundle  # if present
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PGPLOT/PGPLOT.bundle

# FFTW bundle (C, but links against /Applications/PDL/lib — should be fine)
otool -L /Applications/PDL/lib/perl5/site_perl/*/darwin-2level/auto/PDL/FFTW3/FFTW3.bundle

# The pgplot library itself
otool -L /Applications/PDL/pgplot/libpgplot.*

# pgxwin_server — the X11 helper executable
otool -L /Applications/PDL/pgplot/pgxwin_server
```

**What you want to see** — only macOS system libraries:
- `/usr/lib/libSystem.B.dylib` (the C runtime — required and unavoidable)
- `/usr/lib/libz.1.dylib` (system zlib — fine)
- `/usr/lib/libc++.1.dylib` (system C++ runtime — fine)
- `/System/Library/Frameworks/...` (Apple frameworks — fine)

**Red flags** — anything that won't be on a clean macOS install:
- `@rpath/libgfortran.*.dylib` — the gfortran wrapper isn't being applied. Check `gfortran` script is in PATH first.
- `@rpath/libquadmath.*.dylib` — `-static-libquadmath` not being applied. Check the wrapper has it.
- `/opt/homebrew/lib/libX11.dylib` (or any Homebrew path) — should be linked from the static `.a` archives, not the dynamic `.dylib`.
- `/opt/homebrew/lib/libpng.dylib` — same as above.
- `/usr/local/lib/...` — anything from Homebrew's older path.
- `@rpath/...` for non-system libs — implies relocation that won't work on user machines.

If any red flags appear, the bundle needs to be re-linked manually with the static archives (see "PGPLOT Perl Module Post-Link Swap" and "PDL Slatec/Minuit Re-link" sections above for the pattern).
