# SciPDL
This is a repository for releasing SciPDL distributions (easy install of PDL on MacOS).

The main purpose of this is to hold the releases, so please download a [release.](../../releases)

These are `.dmg` files that you double click to open and then do a drag and drop to install PDL.

I have included the source scripts that do all the building FWIW but these will probably only work on my Mac. But good luck if you want to play with this!

----

*Current version for PDL v2.093, Karl Glazebrook, 6/1/2025*

Welcome to SciPDL! SciPDL is a drag and drop installer for PDL on the Mac. SciPDL now includes its own version of perl in order to work across multiple versions of Mac OS X and a variety of environments (note old versions used the system perl which led to instability between OS updates).

SciPDL is a ‘kitchen sink’ type installer, you get everything you need in one bug bundle to start PDL work. If you prefer a more à la carte approach we suggest you build PDL yourself or use a package management system.

Everything in SciPDL lives within the folder:

![Applications-PDL](https://github.com/PDLPorters/SciPDL/assets/15331994/cc014f69-383a-43e4-804a-19c2b2c07831)


## Installation

Open the .dmg file and drag the ‘PDL’ folder to your Applications folder.

<img width="510" alt="Drag and Drop" src="https://github.com/PDLPorters/SciPDL/assets/15331994/ae59b053-685c-4935-8d8d-0f46c2af546f">

That's it! (And the entire point of SciPDL.)

*IMPORTANT*: an X11 server is also needed if you want PGPLOT graphics. One can use XQuartz or  MacPorts X11.
Since the X11 stuff in PDL is statically linked it should work with any X11 server. 
## Running SciPDL


*From the UNIX (Terminal) command line:*
If you are a bash or zsh user:

`source /Applications/PDL/setup_bash  # This can go in your .bashrc startup file
pdl`

If you are a csh user:

`source /Applications/PDL/setup_csh  # This can go in your .cshrc startup file
pdl`

Alternatively simply run

`/Applications/PDL/go_pdl`

to launch a PDL command line session 

# Convenience Apps

To launch pdl from the Finder (utility apps in PDL folder):

The app:

![pdl home](https://github.com/PDLPorters/SciPDL/assets/15331994/e6a7cd0e-1715-4e87-892e-09b5183339e0)

will launch a Terminal window in your home folder with PDL running.

The app:

￼![pdl here](https://github.com/PDLPorters/SciPDL/assets/15331994/4b6fc0f5-afc2-41c3-be68-c2565c3b8067)

will run PDL in the current Finder window folder. For this to work drag the app in to your Finder toolbar (right click on the tool bar and select ‘Customise toolbar’)

You will be asked if you wish to allow the app to run and whether to allow it to control Terminal. Say yes to both of these! 

You are also likely to get the error:

<img width="372" alt="Not Authorised" src="https://github.com/PDLPorters/SciPDL/assets/15331994/cb155d7f-fc8a-44f9-8416-296cdfa45c88">


If you do then click ‘Edit’ button in the dialog to open it in Script Editor and then just hit ‘Save’ in the menu. Then when you re-launch the app you should get a dialog to allow the app to do it’s thing.

(Note these are implemented via Applescripts, if you can't get them to work it is no big deal. Just run `pdl` from the command line.)


# Folder locations

Everything is installed in `/Applications/PDL`


After running the setup script one should be able to use `cpan -i` to install perl modules in the normal way (they get installed under `/Applications/PDL` with the perl).
  
The `pgplot` graphics library libpgplot is installed in `/Applications/PDL/pgplot`, libraries are in `/Applications/PDL/lib` and executables are in `/Applications/PDL/bin`. Usage from PDL should be transparent. You can also build and link your own C and Fortran programs against these `pgplot` libraries if you wish and it ought to work.

# Perl module versions

The current version numbers of the important stuff within SciPDL are:

```
VERSION_PDL=2.093
VERSION_PERL=5.40.0
VERSION_PGPLOT=2.35
VERSION_EXTUTILS_F77=1.26
VERSION_GSL=2.8
VERSION_CFITSIO=4.5.0
VERSION_ASTRO_FITSIO=1.18
VERSION_ASTRO_FITS_HEADER=3.09
VERSION_FFTW=3.3.10
VERSION_PDL_FFTW3=0.20
```

# Minor caveats

Because this is MacOS the code is all signed and notarised and has a hardened runtime. So it is quite locked down.

In the latest releases I have found a way to give the perl binary a library loading 'entitlement', so installing your own stuff on top of SciPDL (e.g. with `cpan -i`) will work. However see this [caveat.](../../issues/3)

# Github repository contents

The repo contains the various scripts and bits I use to build the DMG.

`build_scipdl.sh` is a shell script that builds SciPDL in /Applications/PDL on a Mac (well my Mac) from sources

`go_dmg` is a shell script that builds the DMG file and signs/notarises it

`gfortran-static` is a shell front end to `gfortran` that makes the buids static

`setup_bash` and `setup_csh` are the scripts that set up the user paths for SciPDL that go in the distrubution

`README_dmg.rtfd` is the RTF README file that goes in the DMG.

`DMG-Background.png` is the background image in the DMG

`Apps` folder contains the `pdl [here]` and `pdl [home]` Applescript apps that go in the distribution.

`go_pdl` is a shell script that launches an interactive PDL session that the above Applescripts use.

`patches/` is a folder containing various patches I need to build stuff for SciPDL.

There are also folders named, for example, `v2.088/` that contain older versions of the builder scripts used for previos releases.



