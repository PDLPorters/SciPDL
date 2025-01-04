#!/bin/bash

### This is for MacOS Monterey both arm64 and intel ###

# This is a bash script. Builds SciPDL v2.084.

# Build SciPDL from the sources. Note right now this is only likely to work on Karl's Mac.
# Note run this from the git directory

# Note this depends on my 'gfortran' script being in the PATH which does static linking (and this is a symlink 
# to gfortran-static)

set -e # Stop on error

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

if true
then 

curl -OL https://www.cpan.org/src/5.0/perl-5.38.2.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PGPLOT-2.29.tar.gz 
curl -OL https://ftp.gnu.org/gnu/gsl/gsl-2.7.1.tar.gz
curl -OL https://github.com/HEASARC/cfitsio/archive/refs/tags/cfitsio4_4_0_20240228.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/P/PR/PRATZLAFF/Astro-FITS-CFITSIO-1.18.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-2.088.tar.gz
curl -OL https://www.fftw.org/fftw-3.3.10.tar.gz
curl -OL https://cpan.metacpan.org/authors/id/E/ET/ETJ/PDL-FFTW3-0.19.tar.gz
curl -OL https://www.dropbox.com/s/ib3q8pcgepyiwg9/pgplot531.tar.gz

cp $HERE/patches/pgplot2.patch .
cp $HERE/patches/pdl-fftw3-0.18.patch .
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

tar xvfz perl-5.38.2.tar.gz
cd perl-5.38.2
./Configure -de -Dcc=gcc -Dprefix=/Applications/PDL
make
# All tests OK!
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

cpan -i ETJ/ExtUtils-F77-1.26.tar.gz

echo  +++++++++++++++++++++++++++++ Install perl-PGPLOT  +++++++++++++++++++++++++++++

cpan -i Devel::CheckLib

export PGPLOT_DEV=/NULL # Suppress interactive tests

tar xvf PGPLOT-2.29.tar.gz
cd PGPLOT-2.29
perl Makefile.PL
make
# Now super ugly hack to make the bundle static!
gfortran -bundle -undefined dynamic_lookup -L/usr/local/lib -fstack-protector-strong  \
   -Wl,-no_compact_unwind PGPLOT.o  -o blib/arch/auto/PGPLOT/PGPLOT.bundle  \
   -L/Applications/PDL/pgplot -lcpgplot -lpgplot -static-libgfortran -static-libgcc \
   /opt/local/lib/libX11.a /opt/local/lib/libxcb.a /opt/local/lib/libXdmcp.a /opt/local/lib/libXau.a /opt/local/lib/libpng.a  -lz
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

tar xvf gsl-2.7.1.tar.gz
cd gsl-2.7.1 
# This works around what appears to be an optimisation bug in ARM64 gcc 12.1
CFLAGS='-g -O' ./configure --disable-shared prefix=/Applications/PDL
make
make check
make install
cd ..

echo  +++++++++++++++++++++++++++++ Install cfitsio  +++++++++++++++++++++++++++++

# Noting cpan -i Alien::CFITSIO does not seem to work on my M1 Monterey machine, missing SSL stuff?

tar xvf cfitsio4_4_0_20240228.tar.gz
cd cfitsio-cfitsio4_4_0_20240228/   
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

tar xvf Astro-FITS-CFITSIO-1.18.tar.gz 
cd Astro-FITS-CFITSIO-1.18
patch -i ../AstroFitsIO.patch
# Note adding of -lcurl and lib/incl dirs
perl Makefile.PL LIBS="-Wl,-no_compact_unwind -L/Applications/PDL/lib -lcfitsio -lcurl -lm" INC="-I/Applications/PDL/include"
make
make test
make install
cd ..

cpan -i GSB/Astro-FITS-Header-3.09.tar.gz


echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ++++++++++++++++++++++++++++ Install PDL!!! ++++++++++++++++++++++++++++
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
# Note cpan -i ETJ/PDL-2.084.tar.gz also works but do it this way so I can look at the leftovers
# from the build easily

tar xvfz PDL-2.088.tar.gz     
cd PDL-2.088
perl Makefile.PL
make


# Fix up static gfortran linking for modules that use fortran libs
# Note 'gfortran' is my static script

cd Libtmp/Slatec
 gfortran $EXTRAFLAGS  -mmacosx-version-min=12.7 -bundle -undefined dynamic_lookup  -fstack-protector-strong  Slatec.o barf.o pp-*.o slatec/*.o -o ../../blib/arch/auto/PDL/Slatec/Slatec.bundle  -lm

cd ../../Libtmp/Minuit 
 gfortran $EXTRAFLAGS -mmacosx-version-min=12.7 -bundle -undefined dynamic_lookup  -fstack-protector-strong  Minuit.o FCN.o pp-*.o minuitlib/*.o   -o ../../blib/arch/auto/PDL/Minuit/Minuit.bundle  -lm
cd ../..


make test
make install
cd ..


echo  +++++++++++++++++++++++++++++ Install libfftw  +++++++++++++++++++++++++++++

#cpan -i Alien::FFTW3 # does not work as can't seem to install IO:: modules

tar xvf  fftw-3.3.10.tar.gz
cd fftw-3.3.10
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

tar xvf PDL-FFTW3-0.19.tar.gz
cd PDL-FFTW3-0.19
# Patch the Makefile.PL to find the libs in the right place
patch -i ../pdl-fftw3-0.18.patch
perl Makefile.PL
make
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


