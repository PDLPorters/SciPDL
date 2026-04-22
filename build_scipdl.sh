#!/bin/bash

### This is for MacOS Monterey both arm64 and intel ###

# This is a bash script. Builds SciPDL v2.084.

# Build SciPDL from the sources. Note right now this is only likely to work on Karl's Mac.
# Note run this from the git directory

# Note this depends on my 'gfortran' script being in the PATH which does static linking (and this is a symlink 
# to gfortran-static)

set -e # Stop on error

# Refuse to run from inside a Claude Code worktree.
# The worktree contains a SNAPSHOT of the script taken when the worktree
# was created - it won't have any subsequent edits to build_scipdl.sh,
# patches/, gfortran-static, etc. Always run from the main repo checkout.
if [[ "$PWD" == */.claude/worktrees/* ]]; then
    echo "ERROR: refusing to run from inside a Claude Code worktree:"
    echo "  $PWD"
    echo ""
    echo "Worktrees contain a snapshot of files from when the worktree was"
    echo "created and will not reflect subsequent edits. Run this script"
    echo "from the main repo checkout instead:"
    echo "  cd \$(git rev-parse --show-superproject-working-tree 2>/dev/null \\"
    echo "        || git rev-parse --show-toplevel | sed 's|/.claude/worktrees/.*||')"
    echo "  ./build_scipdl.sh $@"
    exit 1
fi

# Option to nuke previous build artifacts before starting
# --clean prompts for confirmation in interactive terminals
# --force-clean skips the prompt (for scripted/automated builds)
if [[ "$1" == "--clean" || "$1" == "--force-clean" ]]; then
    if [[ "$1" == "--clean" && -t 0 ]]; then
        echo "WARNING: This will permanently delete:"
        echo "  /Applications/PDL"
        echo "  $HOME/Downloads/build"
        echo ""
        read -p "Type YES to confirm: " confirm
        if [[ "$confirm" != "YES" ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
    echo "Removing /Applications/PDL and ~/Downloads/build..."
    rm -fr /Applications/PDL ~/Downloads/build
    echo "Clean complete."
fi

# Clean environment of user Perl settings that can interfere with the build
unset PERL5DB
unset PERL5LIB

# Helper: build and install one or more CPAN modules from local tarballs
# in ~/Downloads/build. We do this manually (tar / Makefile.PL / make /
# test / install) rather than 'cpan -i' because:
#   1. cpan's default mirror only keeps the latest version of each distro
#      (404s on older versions when given an AUTHOR/Dist-X.Y.tar.gz path)
#   2. cpan doesn't accept local file paths (mangles them into bogus URLs)
# Usage:
#     install_local_tarballs PDL-GSL-2.096 PDL-Complex-2.011 ...
install_local_tarballs() {
    local saved_pwd=$PWD
    for name in "$@"; do
        echo "----- install_local_tarballs: $name -----"
        cd $HOME/Downloads/build
        tar xvf $name.tar.gz
        cd $name
        perl Makefile.PL
        make
        make test
        make install
        cd $HOME/Downloads/build
    done
    cd $saved_pwd
}

# Refuse to run if anaconda is present and activated
if [[ -n "$CONDA_PREFIX" && -d "$CONDA_PREFIX" ]]; then
    echo "Anaconda is activated. CONDA_PREFIX: $CONDA_PREFIX"
    echo "Please use 'conda deactivate' and try again. Believe me having Anaconda in your"
    echo "path is a big bag of hurt for this build."
    exit 1
fi

HERE=$PWD

# Add GIT directory to PATH to allow pick up of misc scripts.
PATH=$HERE:$PATH
export PATH

cp gfortran-static gfortran

# Where to build everything
mkdir ~/Downloads/build
cd ~/Downloads/build

echo +++++++++++++++++++++++++++++ Fetch Sources  +++++++++++++++++++++++++++++

VERSION_PDL=2.104
VERSION_PERL=5.42.2
VERSION_PGPLOT=2.35
VERSION_EXTUTILS_F77=1.26
VERSION_GSL=2.8
VERSION_CFITSIO=4.6.3
VERSION_ASTRO_FITSIO=1.18
VERSION_ASTRO_FITS_HEADER=3.09
VERSION_FFTW=3.3.11
VERSION_PDL_FFTW3=0.203
VERSION_PDL_MINUIT=0.002
VERSION_PDL_SLATEC=2.098

# The following PDL:: family modules were split out of PDL core in v2.096.
# Versions are pinned to specific releases (current latest as of the
# release date of whatever VERSION_PDL is set to) for reproducible builds.
# When bumping PDL, bump these alongside it - some have version-coupling
# with PDL internals (see PDL::GSL and PDL::FFTW3 comments below).
VERSION_PDL_GSL=2.103  # 2.103 fixes test using $x->inplace->transpose, now an error in PDL 2.104+
VERSION_PDL_COMPLEX=2.011
VERSION_PDL_FIT=2.100
VERSION_PDL_GRAPHICS_LIMITS=0.03
VERSION_PDL_IO_DICOM=2.098
VERSION_PDL_IO_BROWSER=0.001
VERSION_PDL_TRANSFORM_PROJ4=2.099  # 2.099 fixes test failures with PROJ 9.8+
VERSION_PDL_IO_IDL=2.098
VERSION_PDL_OPT_SIMPLEX=2.097
VERSION_PDL_NDBIN=0.029

# Additional PDL modules requested in issue #4 (mohawk2's list).
VERSION_PDL_GRAPHICS_SIMPLE=1.016
VERSION_PDL_GRAPHICS_COLORSPACE=0.206
VERSION_PDL_TRANSFORM_COLOR=1.010
VERSION_PDL_GRAPHICS_GNUPLOT=2.032

# PDL::IO::GD needs libgd which we build ourselves statically (no Homebrew
# static .a available). VERSION_LIBGD is the C library; VERSION_PDL_IO_GD
# is the Perl binding.
VERSION_LIBGD=2.3.3
VERSION_PDL_IO_GD=2.103

if true
then 

curl -OL https://www.cpan.org/src/5.0/perl-$VERSION_PERL.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PGPLOT-$VERSION_PGPLOT.tar.gz 
curl -OL https://ftp.gnu.org/gnu/gsl/gsl-$VERSION_GSL.tar.gz
curl -OL https://heasarc.gsfc.nasa.gov/FTP/software/fitsio/c/cfitsio-$VERSION_CFITSIO.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/P/PR/PRATZLAFF/Astro-FITS-CFITSIO-$VERSION_ASTRO_FITSIO.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-$VERSION_PDL.tar.gz
curl -OL https://www.fftw.org/fftw-$VERSION_FFTW.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-FFTW3-$VERSION_PDL_FFTW3.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Minuit-$VERSION_PDL_MINUIT.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Slatec-$VERSION_PDL_SLATEC.tar.gz
# Pinned split-out PDL:: modules. We fetch from cpan.metacpan.org directly
# rather than relying on cpan -i because cpan's default mirror only keeps
# the latest version of each distro.
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-GSL-$VERSION_PDL_GSL.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Complex-$VERSION_PDL_COMPLEX.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Fit-$VERSION_PDL_FIT.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Graphics-Limits-$VERSION_PDL_GRAPHICS_LIMITS.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-IO-Dicom-$VERSION_PDL_IO_DICOM.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-IO-Browser-$VERSION_PDL_IO_BROWSER.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Transform-Proj4-$VERSION_PDL_TRANSFORM_PROJ4.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-IO-IDL-$VERSION_PDL_IO_IDL.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Opt-Simplex-$VERSION_PDL_OPT_SIMPLEX.tar.gz
# Issue #4 wishlist additions
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Graphics-Simple-$VERSION_PDL_GRAPHICS_SIMPLE.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Graphics-ColorSpace-$VERSION_PDL_GRAPHICS_COLORSPACE.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Transform-Color-$VERSION_PDL_TRANSFORM_COLOR.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-Graphics-Gnuplot-$VERSION_PDL_GRAPHICS_GNUPLOT.tar.gz
# libgd C library and PDL::IO::GD binding (built/installed in their own sections below)
curl -OL https://github.com/libgd/libgd/releases/download/gd-$VERSION_LIBGD/libgd-$VERSION_LIBGD.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-IO-GD-$VERSION_PDL_IO_GD.tar.gz
# Dropbox now returns an HTML preview page for the bare URL; the ?dl=1
# query parameter forces an actual file download.
curl -L -o pgplot531.tar.gz 'https://www.dropbox.com/s/ib3q8pcgepyiwg9/pgplot531.tar.gz?dl=1'

cp $HERE/patches/pgplot2.patch .
cp $HERE/patches/pdl-fftw3.patch .
cp $HERE/patches/AstroFitsIO.patch .

fi

echo -+++++++++++++++++++++++++++++ Initial Setup  +++++++++++++++++++++++++++++


# Do specific things for x86_64 vs ARM64 for my particular computer setup
  
myarch=`uname -m`
if [[ "$myarch" == "x86_64" ]]
then
   echo --- Detected x86_64 ---
fi
if [[ "$myarch" == "arm64" ]]
then
   echo --- Detected arm64 ---
fi

# Just in case

# Set up directories
mkdir /Applications/PDL
cp $HERE/setup_* /Applications/PDL

source /Applications/PDL/setup_bash

if false 
then  # Skip a bunch of code
echo Hello
fi ### End of the code skip


# Ensure cpan does not prompt if not configured.
export PERL_MM_USE_DEFAULT=1

echo +++++++++++++++++++++++++++++ build perl  +++++++++++++++++++++++++++++

tar xvfz perl-$VERSION_PERL.tar.gz
cd perl-$VERSION_PERL
./Configure -de -Dcc=gcc -Dprefix=/Applications/PDL
make
# Replace perl5db.t with a stub - it hangs in non-TTY environments (no controlling terminal)
# The test harness manifest expects this file, so we can't just delete it.
chmod u+w lib/perl5db.t
echo 'print "1..0 # Skip: bypassed in SciPDL build (non-TTY environment)\n";' > lib/perl5db.t
make test
make install
cd ..

# Update the PATH

echo +++++++++++++++++++++++++++++ Install pgplot  +++++++++++++++++++++++++++++

tar xvfz pgplot531.tar.gz
cd pgplotsrc
patch -p 1 -i ../pgplot2.patch
SRC=$PWD
mkdir /Applications/PDL/pgplot
cd  /Applications/PDL/pgplot
cp $SRC/drivers.list .
$SRC/makemake $SRC/ darwin gfortran_gcc_BigSur_static
make
make clean
cd $SRC/..
rm -fr pgplotsrc 



echo  +++++++++++++++++++++++++++++ Install ExtUtils::F77 +++++++++++++++++++++++++++++

cpan -i ETJ/ExtUtils-F77-$VERSION_EXTUTILS_F77.tar.gz

echo  +++++++++++++++++++++++++++++ Install perl-PGPLOT  +++++++++++++++++++++++++++++

cpan -i Devel::CheckLib

export PGPLOT_DEV=/NULL # Suppress interactive tests

tar xvf PGPLOT-$VERSION_PGPLOT.tar.gz
cd PGPLOT-$VERSION_PGPLOT
perl Makefile.PL
make
# Now super ugly hack to make the bundle static!
gfortran -bundle -undefined dynamic_lookup -L/usr/local/lib -fstack-protector-strong  \
   -Wl,-no_compact_unwind PGPLOT.o  -o blib/arch/auto/PGPLOT/PGPLOT.bundle  \
   -L/Applications/PDL/pgplot -lcpgplot -lpgplot -static-libgfortran -static-libgcc \
   /opt/homebrew/lib/libX11.a /opt/homebrew/lib/libxcb.a /opt/homebrew/lib/libXdmcp.a /opt/homebrew/lib/libXau.a /opt/homebrew/lib/libpng.a  -lz
make
make test
make install
cd ..



echo  +++++++++++++++++++++++++++++ Install misc perl modules  +++++++++++++++++++++++++++++


cpan -i Parse::RecDescent Inline Devel::CheckLib Convert::UU File::Map Test2::V0 \
 Module::Compile Test::Deep Test::Exception List::MoreUtils Pod::Parser 
 
cpan -iT Term::ReadLine::Perl Term::ReadKey   # -T suppresses the interactive test


echo  +++++++++++++++++++++++++++++ Install GSL +++++++++++++++++++++++++++++

# Note I can't get Alien to work as it needs Net:SSLeay that won't install correctly
# cpan -i Alien::GSL 

tar xvf gsl-$VERSION_GSL.tar.gz
cd gsl-$VERSION_GSL 
# This works around what appears to be an optimisation bug in ARM64 gcc 12.1
CFLAGS='-g -O' ./configure --disable-shared prefix=/Applications/PDL
make
make check
make install
cd ..

echo  +++++++++++++++++++++++++++++ Install cfitsio  +++++++++++++++++++++++++++++

# Noting cpan -i Alien::CFITSIO does not seem to work on my M1 Monterey machine, missing SSL stuff?

tar xvf cfitsio-$VERSION_CFITSIO.tar.gz
cd cfitsio-$VERSION_CFITSIO/   
./configure prefix=/Applications/PDL CC=gcc
make
# Run test progs
make install
make testprog
echo ---------- Testing ---------- 
./testprog > foo.out # CC test
# Should be same:
diff foo.out testprog.out 
echo ----------------------------
rm /Applications/PDL/lib/libcfitsio*dylib
cd ..


echo  +++++++++++++++++++++++++++++ Install Astro::FITS modules  +++++++++++++++++++++++++++++

# Can't use CPAN as it wants to do Alien::CFITSIO

tar xvf Astro-FITS-CFITSIO-$VERSION_ASTRO_FITSIO.tar.gz 
cd Astro-FITS-CFITSIO-$VERSION_ASTRO_FITSIO
patch -i ../AstroFitsIO.patch
# Note adding of -lcurl and lib/incl dirs
perl Makefile.PL LIBS="-Wl,-no_compact_unwind -L/Applications/PDL/lib -lcfitsio -lcurl -lm" INC="-I/Applications/PDL/include"
make
make test
make install
cd ..

cpan -i GSB/Astro-FITS-Header-$VERSION_ASTRO_FITS_HEADER.tar.gz


echo  +++++++++++++++++++++++++++++ Install libgd  +++++++++++++++++++++++++++++

# libgd for PDL::IO::GD. Built static + PNG-only (the only image format
# needed by PDL::IO::GD's tests; jpeg/tiff/freetype/etc. would all need
# their own static libs which Homebrew doesn't provide).
#
# Note libgd.a alone is incomplete - it has unresolved libpng symbols.
# We link in /opt/homebrew/lib/libpng.a manually when re-linking PDL::IO::GD's
# bundle below (same pattern as PGPLOT/Slatec/Minuit static re-links).
tar xvf libgd-$VERSION_LIBGD.tar.gz
cd libgd-$VERSION_LIBGD
./configure \
  --enable-static --disable-shared \
  --with-png=/opt/homebrew --with-zlib \
  --without-jpeg --without-tiff --without-webp --without-freetype \
  --without-fontconfig --without-raqm --without-x \
  --prefix=/Applications/PDL
make
make install
cd ..


echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ++++++++++++++++++++++++++++ Install PDL!!! ++++++++++++++++++++++++++++
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
# Note cpan -i ETJ/PDL-2.084.tar.gz also works but do it this way so I can look at the leftovers
# from the build easily

tar xvfz PDL-$VERSION_PDL.tar.gz     
cd PDL-$VERSION_PDL
perl Makefile.PL
make


# Run the PDL test and install

make test
make install

cd ..


echo  +++++++++++++++++++++++++++++ Install libfftw  +++++++++++++++++++++++++++++

#cpan -i Alien::FFTW3 # does not work as can't seem to install IO:: modules

tar xvf  fftw-$VERSION_FFTW.tar.gz
cd fftw-$VERSION_FFTW
# Install double precision library
# Note need to set F77 explicitly for some weird reason
./configure prefix=/Applications/PDL
make
make check
make install
# Install single precision library
./configure --enable-float prefix=/Applications/PDL
make
make check
make install
cd ..

echo  +++++++++++++++++++++++++++++ Install PDL::FFTW3  +++++++++++++++++++++++++++++

#cpan -i PDL::FFTW3 # Does not seem to work

tar xvf PDL-FFTW3-$VERSION_PDL_FFTW3.tar.gz
cd PDL-FFTW3-$VERSION_PDL_FFTW3
# Patch the Makefile.PL to find the libs in the right place
patch -i ../pdl-fftw3.patch
perl Makefile.PL
make
make test
make install
cd ..


echo  +++++++++++++++++++++++++++++ Install PDL::Minuit  +++++++++++++++++++++++++++++

# Was part of PDL core in <2.094, now a separate distribution.
# Fortran library, so we need to manually re-link the bundle for static linking
# (gfortran wrapper handles -static-libgfortran -static-libgcc -static-libquadmath)

tar xvf PDL-Minuit-$VERSION_PDL_MINUIT.tar.gz
cd PDL-Minuit-$VERSION_PDL_MINUIT
perl Makefile.PL
make
# Manual static re-link of the Minuit bundle
gfortran -mmacosx-version-min=12.7 -bundle -undefined dynamic_lookup -fstack-protector-strong \
   Minuit.o FCN.o minuitlib/*.o \
   -o blib/arch/auto/PDL/Minuit/Minuit.bundle -lm
make test
make install
cd ..


echo  +++++++++++++++++++++++++++++ Install PDL::Slatec  +++++++++++++++++++++++++++++

# Was part of PDL core in <2.096, now a separate distribution.
# Fortran library, so we need to manually re-link the bundle for static linking
# (gfortran wrapper handles -static-libgfortran -static-libgcc -static-libquadmath)

tar xvf PDL-Slatec-$VERSION_PDL_SLATEC.tar.gz
cd PDL-Slatec-$VERSION_PDL_SLATEC
perl Makefile.PL
make
# Manual static re-link of the Slatec bundle
gfortran -mmacosx-version-min=12.7 -bundle -undefined dynamic_lookup -fstack-protector-strong \
   Slatec.o barf.o pp-*.o slatec/*.o \
   -o blib/arch/auto/PDL/Slatec/Slatec.bundle -lm
make test
make install
cd ..


echo "+++++++++++++++++++++++++++++ Install split-out PDL modules (kitchen sink) +++++++++++++++++++++++++++++"

# These were part of PDL core in <2.096 but split into separate distros.
# We pin to specific tarball versions rather than using module names, so
# that CPAN doesn't transitively upgrade PDL itself (newer releases of
# these distros bump the minimum required PDL version). All link statically
# against the GSL we built; PDL::Transform::Proj4 ships its own libproj/
# libsqlite3 via Alien::proj/Alien::sqlite (installed under /Applications/PDL).
#
# NOTE: the following were also split out but are NOT included because
# their underlying C libraries are awkward to bundle:
#   - PDL::IO::HDF       requires hdf5 (awkward static build, not
#                        previously shipped, value debatable now that
#                        most science uses HDF5/NetCDF)
#   - PDL::Graphics::TriD requires OpenGL/freeglut (Apple-deprecated
#                        OpenGL framework, slated for eventual removal)
# (PDL::IO::GD IS bundled now - libgd is built statically above and the
# binding is installed in its own section after the split-out modules.)
# Alien::proj is needed by PDL::Transform::Proj4 (it builds and ships a
# private libproj.dylib under /Applications/PDL). Install via cpan since
# it's a regular CPAN module that doesn't trigger a PDL upgrade.
cpan -i Alien::proj

install_local_tarballs \
    PDL-GSL-$VERSION_PDL_GSL \
    PDL-Complex-$VERSION_PDL_COMPLEX \
    PDL-Fit-$VERSION_PDL_FIT \
    PDL-Graphics-Limits-$VERSION_PDL_GRAPHICS_LIMITS \
    PDL-IO-Dicom-$VERSION_PDL_IO_DICOM \
    PDL-IO-Browser-$VERSION_PDL_IO_BROWSER \
    PDL-Transform-Proj4-$VERSION_PDL_TRANSFORM_PROJ4 \
    PDL-IO-IDL-$VERSION_PDL_IO_IDL \
    PDL-Opt-Simplex-$VERSION_PDL_OPT_SIMPLEX


echo "+++++++++++++++++++++++++++++ Install user-requested modules (issue #5) +++++++++++++++++++++++++++++"

# Pure-Perl/XS modules requested for the kitchen sink (GitHub issue #5).
# These pull in many dependencies but install cleanly via cpan.
# NOTE: Devel::Carp was also requested but is broken on modern Perl
#       (uses 'defined(@array)' removed in Perl 5.22, originally released 1998).
#       Core 'Carp' provides similar functionality.
# PDL::NDBin gets installed via cpan (not the local tarball helper) because
# it has several pure-Perl prereqs (Math::Round, Class::Load, Log::Any,
# Params::Validate, UUID::Tiny) that need CPAN's transitive resolution.
# Latest NDBin (0.029) only requires PDL >= 2.088 so this won't trigger
# a PDL upgrade.
cpan -i DateTime String::Scanf Devel::Size List::Uniq LWP::UserAgent \
        Test::Number::Delta Parallel::ForkManager PDL::NDBin


echo "+++++++++++++++++++++++++++++ Install PDL graphics/colour extras (issue #4) +++++++++++++++++++++++++++++"

# Pure-Perl modules from mohawk2's wishlist on issue #4. Note PDL::Graphics::Gnuplot
# also requires the gnuplot binary at runtime; we install only the Perl module
# here (users can install gnuplot themselves via Homebrew if they want).
# Pre-install Perl prereqs of PDL::Graphics::Gnuplot via cpan so that
# install_local_tarballs (which doesn't do prereq resolution) finds them.
#   - Alien::Gnuplot: locates the gnuplot binary at runtime
#   - IPC::Run, Safe::Isa: required by PDL::Graphics::Gnuplot
cpan -i Alien::Gnuplot IPC::Run Safe::Isa
install_local_tarballs \
    PDL-Graphics-Simple-$VERSION_PDL_GRAPHICS_SIMPLE \
    PDL-Graphics-ColorSpace-$VERSION_PDL_GRAPHICS_COLORSPACE \
    PDL-Transform-Color-$VERSION_PDL_TRANSFORM_COLOR \
    PDL-Graphics-Gnuplot-$VERSION_PDL_GRAPHICS_GNUPLOT


echo "+++++++++++++++++++++++++++++ Install PDL::IO::GD (uses bundled libgd) +++++++++++++++++++++++++++++"

# PDL::IO::GD needs the libgd we built above. Its Makefile.PL respects
# GD_LIBS/GD_INC env vars to find an out-of-tree libgd. After the normal
# 'make', we manually re-link the GD.bundle to add /opt/homebrew/lib/libpng.a
# directly - libgd.a depends on libpng symbols but EUMM's LIBS-parsing
# silently strips absolute .a paths so we can't get -lpng on the link line
# via Makefile.PL. Same pattern as the PGPLOT/Slatec/Minuit re-links.
tar xvf PDL-IO-GD-$VERSION_PDL_IO_GD.tar.gz
cd PDL-IO-GD-$VERSION_PDL_IO_GD
GD_LIBS=/Applications/PDL/lib GD_INC=/Applications/PDL/include perl Makefile.PL
make
# Manual re-link of the GD bundle to pull in libpng statically.
gcc -mmacosx-version-min=12.7 -bundle -undefined dynamic_lookup -fstack-protector-strong \
   GD.o \
   -o blib/arch/auto/PDL/IO/GD/GD.bundle \
   /Applications/PDL/lib/libgd.a /opt/homebrew/lib/libpng.a -lz -lm
make test
make install
cd ..


echo  -+++++++++++++++++++++++++++++ Installing utilites  +++++++++++++++++++++++++++++

# I am told ditto is better for copying app folders
ditto "$HERE/Apps/pdl [here].app" "/Applications/PDL/pdl [here].app"
ditto "$HERE/Apps/pdl [home].app" "/Applications/PDL/pdl [home].app"

cp $HERE/go_pdl /Applications/PDL

echo  +++++++++++++++++++++++++++++ Installing final perl modules  +++++++++++++++++++++++++++++

# For some reason this sometimes randomly fails unless put at the end!
cpan -i Inline::C

echo  +++++++++++++++++++++++++++++ Done! +++++++++++++++++++++++++++++


