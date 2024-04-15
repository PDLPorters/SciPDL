# SciPDL
This is a repository for releasing SciPDL distributions (easy install of PDL on MacOS).

Right now this is just a placeholder repo for uploading and releasing the DMGs. I hope to add the code (a shell script) to build the DMG FWIW as soon as I have tidied it up.

----

*Karl Glazebrook, 15/4/2024*

Welcome to SciPDL! SciPDL is a drag and drop installer for PDL on the Mac. SciPDL now includes its own version of perl in order to work across multiple versions of Mac OS X and a variety of environments (note old versions used the system perl which led to instability between OS updates).

SciPDL is a ‘kitchen sink’ type installer, you get everything you need in one bug bundle to start PDL work. If you prefer a more à la carte approach we suggest you build PDL yourself or use a package management system.

Everything in SciPDL lives within the folder:

![Applications-PDL](https://github.com/PDLPorters/SciPDL/assets/15331994/cc014f69-383a-43e4-804a-19c2b2c07831)


## Installation

Open the .dmg file and drag the ‘PDL’ folder to your Applications folder.

<img width="510" alt="Drag and Drop" src="https://github.com/PDLPorters/SciPDL/assets/15331994/ae59b053-685c-4935-8d8d-0f46c2af546f">

That's it! (And the entire point of SciPDL.)

*IMPORTANT*: an X11 server is also needed if you want PGPLOT graphics. One can use XQuartz or  MacPorts X11.
Since the X11 stuff in PDL is statically linked it should work with any X11 server. If you don’t know what X11 is you probably shouldn’t be using PDL :-;


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



