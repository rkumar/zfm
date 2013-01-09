zfm
===

zsh file explorer/manager for fast navigation

This is a file navigator or explorer that attempts to make as many operations as possible on single keys so that a user can quickly navigate and execute commands. It is hoped that such paths will become second nature.

The first 9 files or dirs in any view are given hotkeys from 1-9. After that with each successive key the files are reduced. This actually makes file navigation very fast.

The "," key (lower case of "&lt;") is used to go up directory levels. There are many other shortcuts that allow for other usual operations to be done fast such as accessing favorite directories and files, and navigating deep structures quickly.

Paging of long listings is done using the SPACEBAR. If you have dirs with lots of files containing spaces, you may want to change the ZFM_PAGE_KEY to ENTER.

The motivation of yet another file manager is to automate as many file-related operations as I can: browsing, operating on multiple files, today's files, filtering file lists. I also use ``z``, ``v``, ``vifm``, and various other great utilities.

A Quick Session
---------------

You may either place all these files in your $HOME/bin folder (there are internal links to each other). Or place them somewhere in path and set a ZFM_DIR variable to that path.

In your shell, type "zfm.zsh"


If you like it, alias m or some other unused character to ~/bin/zfm.zsh in your shell and later in your .zshrc.

    alias m='~/bin/zfm.zsh'

Now type "m":

You should see a listing of your directory with 9 files hot-keyed with numbers and the rest with the first letter.
Press a hotkey. If it is a directory, you will automatically change into it. If its a file, you will get a menu of file options. (As of writing, now we automatically open the file using EDITOR). (MENU -> Options can be used to switch off default open behavior to get a menu).

Let's say you want to navigate to the "tmp" directory. 
Type "t". You will see "t" on the left of your prompt, and the list is filtered to "t*". 
In my case, "tmp" is the 2nd entry so i press 2. If i use this often I only need press "t2" to get to tmp. 
I could also press "tm" and if there is no other entry starting with "tm" we automatically go into "tmp".

You may also press "backspace" to erase the pattern one by one. Please note that the pattern accumulates. Usually a stray untrapped key results in the pattern being cleared completely. Otherwise, the "," (BACK key) will take you a level up and clear the pattern.

Press the ZFM_GOTO_KEY (currently "+" (plus sign)). You are prompted for a path. Type /usr/local/lib, pressing the tab after lo and li. Press ENTER to jump to that directory.

Press "?" to see what keys are available. This should work in menu's too.

Press the colon (":") and type an arbitrary shell command. You can type "q" or "quit" to quit, help or ? should show you some canned actions.

Currently "q" is never mapped to a file, it quits. This is a feature cum bug. I need to find another quit key and release the "q" so the "qt" guys don't sue me :)

*The Menu*

At present I have a menu triggered by pressing the backtick (lower tilde). This could change based on feedback or be configured. It allows seeing file listings, recursive listings, see just the directories in the current dir or jumping to recently used files etc. These views allow multiple selection of files so that actions can be executed on these files.

One example is "ft". After triggering the menu with MENU_KEY, "f" jumps to "File listing" and "t" shows a listing of files modified today.

If you are editing many files, rather than press "v" each time for your EDITOR (in the File Operations menu), select "a" for auto-open and enter your editor name. Now whenever a text file is selected your editor will open it. For other kinds of files, go to Menu => Options and provide the application for major file types.

Users of the autojump utility "z" (brew install z or see github rupa/z), can use MENU-k (backtick k) to see directories from their $HOME/.z database, type in a number to select, or press a couple of keys to drill down to the dir and press ENTER.

Users of vim can use MENU-l or MENU-v, files from your $HOME/.viminfo will be displayed and can be selected. "l" allows single file selection, "v" allows multiple file selection. These 2 features allow you to very quickly jump to dirs or files with a couple of keystrokes. Users of other utilities such as autojump can configure reading dirs from their database in zfmdirs.

If you wish to change the sort order of your listing, try MENU-s. To filter your listings to only files/dirs/links, recent files etc, try MENU-F.

There are some interfaces to ack and ag for viewing files containing some text. MENU-f and MENu-r give you the option to ack for this dir or recursively. File names can then be selected for viewing.

To search for a file in the current heirarchy, press "/"  and enter a pattern. You will see filename containing that pattern and can select one or more for viewing or running a command on.

To toggle various modes, use the TOGGLE_KEY (default =)  you can switch to "all files", "match from start of filename", "ignore case match", "approximate match" and various others.

###Edge Cases:###

While navigating a directory which has many files with numbers, you may be unable to access certain numbered files. There is a check for numbered files that clash with the numbered hotkey (M_SWITCH_OFF_DUPE_CHECK) that can be set. I have not used this by default just to reduce processing.

Some dirs such as Downloads may contain very long file names containing the same first 10 or 20 characters. In such case, drilling down is tedious. A quicker option is to have FULL_INDEXING. In this all files are indexed using 1-9, then a-zA-Z. However, this is not the default, since the user has to scan the list to see what the hotkey is. I have found that drilling down is much faster -- the first 2 characters of a file or dir often are all we need to get into a dir or get a file.

Other downloaded files may contain funny or unusual characters such as quotes or brackets that i ignore or use for other purposes. Let me know if this is an issue, or use FULL_INDEXING for these cases. Full indexing is available with the TOGGLE_KEY.

###Match from start or anywhere:###

The default when you type characters is to match from start. If you type "^" anywhere during the command, the match toggles between start and match anywhere in string. Once you start remembering file positions, it helps to always keep in the match-from-start position.

###Matching dot-files###

By default this is off. You can either go to the setting to change the option or if you type a dot at the beginning of a file name, I switch on GLOB_DOTS.

###Sorting and Filtering###

You can change the sort order of listings by pressing the ZFM_MENU_KEY (backtick). You can also filter the lists in the menu so you only see today's files or recent files etc whenever you visit a directory.

###Multiple Selection of files###

There are 2 ways of Multiple Selection. One is from the menu: select any file listing or recursive listing and choose the line numbers. Press ENTER when done and chose a command, or enter a command to execute. This way you may zip or move or delete or view multiple files.

The second way is from the file manager itself. There is a toggle key for SELECTION_MODE (currently @). After toggling selection on, any files selected will go into an array. When toggling off, a menu of operations for multiple files appears (zip, move, trash, or enter your own command).

The first method from the menu, allows you to select based on a query such as recent files, todays files,
files for an extension etc while keeping the file manager as-is. 

### Finding a file based on filename###

This is similar to the `find` command but uses zsh, to find a file given a string. Matches are displayed and can be filtered based on more keys, and files may be selected and edited. Currently, the location of this is MENU-c ("commands") -> "ffind". You can also use the slash "/" in the file lister.

###Searching based on file content###

I've interfaced with `ag` and `ack` to provide a list of files from which files may be selected.
MENU-f 9 (ack) searches current dir, MENU-r 9 (ack) searches recursively.

MENU-c (commands) ack and ag currently only show the output of ack and ag, they do not allow file selection.

###Miscellaneous###

There are other keys also mapped to some actions. Will document as i go. and these keys are not fixed yet.

e.g. navigate to a *sibling* directory. Press "[" (square bracket open) to see sibling directories. Select one to jump to it.  

The menu offers directories from the "*dirs*" command. I think this only works if you source the file, otherwise the new shell does not execute .zshrc and do contains a blank "dirs". This helps to jump to oft viewed directories.  

The menu option "filejump" shows files from your .viminfo file, so you can jump to recent files. If you use some other editor, the file zfmfiles can be configured to output recent files from some other source or database.

Provided an option for doing what "*cd OLD NEW*" does. It will offer parts of the current path, select one, and see the alternatives and select the other. Hopes to be faster than typing this on the command line. These things are required for jumping between large project structures.  Need to figure out what key to map it to, currently "]" (square bracket clase).  

Currently, I am using zsh v5.0.x (homebrew OSX Mountain Lion) inside iTerm and tmux.

##Supplying frequent/recent files and directories##

You can interface with your frequent files and directories utilities using `zfmfiles` and `zfmdirs`.
Currently, I use rupa's Z utility, so `zfmdirs` pulls out directory names from the $HOME/.z database.
Similarly, `zfmfiles` lists files from my $HOME/.viminfo file. You can replace the code in these
files to interface with autojump or whatever other utility you use. I'd rather use an existing tool for this that re-invent the same functionality (all these utilities hook into cd or chpwd)

##Changes##

A summary of version-wise changes. 

###0.0.2###

    Too many small changes to document. You can see the git log or tags listing for details.

    * you can select single or multiple files in all views (except for directory listings). Press ENTER
    for finishing selection, ESCAPE to cancel.

###0.0.1w###

    * fuzzyselectrow allows multiple selection too, on pressing ENTER
      Trying to standardize the select to one only - currently the select single 
      and multiple is a bit confusing. 

###0.0.1t###
    
    * display size and mtime if 15 rows only
    * filter for showing links (MENU F(ilter) LINKS)
    * pressing Enter in listing selects first item

###0.0.1r###

    * (In fuzzy search ) Enter selects during dir and file searches (BACKTICK k and BACKTICK l).
    This is like using Control-P or Control-P. Automatic selection as you
    type keys was dangerous.

###0.0.1o###

    * Selected items are bold faced

###0.0.1m###

    * Quick selection of recent files using sort of fuzzy matching. Earlier one had to 
    select based on row number.  MENU_KEY + l (select one), MENU_KEY + v (select multiple based on line numbers).

###0.0.1l###

    * Quick selection of directories to jump to through menu (backtick - k). This 
    picks up database from "z"'s database. Filters dirs as you type and goes into 
    first unique match.

###0.0.1k###

    * Added zfmcommands.zsh so user can add own menu and commands which will
    be picked up in when one presses $MENU_KEY (default backtick) + "c".

###0.0.1j###

    * Changed some file names to zfm prefix

###0.0.1i###

    * interface with `z` utility and `viminfo` through zfmdirs and zfmfiles.

###0.0.1g###

    * auto-editing on selection AUTO_TEXT_ACTION etc
    * do not clear pattern on selection, allow it to persist, clear when dir changed

##Installation##

You can either run this as an external application in its own shell or source the file. I suggest NOT sourcing it in the beginning.

Advantages of sourcing:

- you can navigate to a directory and when you exit, you remain in that directory 
- able to use "dirs" command to select recently used directories
- changes in preferences will remain in effect when you run zfm again. 

Disadvantages:

- in some cases I have changed a setting such as GLOB_DOTS which could affect your
  environment if you expect it to be off. I will try removing that soon.
- There are variables that are not local that will pollute your shell

Advantages of not sourcing:
- When you exit you remain where you were (you may want this)
- Any changes to environment do not affect your shell

Disadvantage:

- Unable to use "dirs" command to get frequent directories.
- Preferences changed will not be saved (I am not using any config
file at present)


If you want to source the zfm.zsh file then you must remove the last line which calls myzfm.
Now you can put this in your .zshrc:

    source ~/bin/zfm.zsh
    alias m=myzfm

*************************************************

Please use and give feedback. How can navigation be made faster / easier. 
What common use cases have i missed?
(I am new to zsh, btw. Please point me to links on advanced zsh scripting).

