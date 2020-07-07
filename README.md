# Game Setup
Simple game management developed for Final Respawn

## Installation

To install, download the repository, and compile `gamesetup.sp` using the necessary includes (`colours.inc` is included). Put the resulting `gamesetup.smx` in the `plugins` folder. Drag and drop the files.

## Commands

- **.menu** - Bring the menu up (must be leader)
- **.ready** or **.r** - Ready up
- **.gaben** - Ready up with a special message
- **.unready** or **.ur** - Unready
- **.pause** - Pause the game (must be captain)
- **.unpause** - Unpause the game (must be captain)
- **.map** - Choose the map (must be captain)
- **.stay** - Stay (must be captain)
- **.swap** or **.switch** - Swap (must be captain)
- **.endgame** or **.gg** - End the game (must be leader)
- **.help** or **.commands** - Get help

## Settings

- `sm_gamesetup_captainsystem` - Enable/disable the captain system
- `sm_gamesetup_leadersystem` - Enable/disable the `leaders.cfg` file
- `sm_gamesetup_overtimevote` - Enable/disable the overtime vote in competitive play
- `sm_gamesetup_pluginprefix` - Change the plugin prefix, see the translations file for colours
- `sm_gamesetup_showreadyhud` - Enable/disable the ready hud showing for everyone

## Configuration

### Leaders

Leaders are the game leaders, and have the ability to use the menu to set the game up. To change who is a leader, edit `configs/gamesetup/leaders.cfg`.

### Translations

If you want to change the messages, you can edit `translations/gamesetup.phrases.txt`. The colours you can use are at the top of the file.

### Modes

The configuration files for each of the modes are stored in `cfg/sourcemod/gamesetup`. `default.cfg` is executed before every gamemode change. The others are self explanatory.
