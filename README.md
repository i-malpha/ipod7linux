# Syncing music to an iPod nano 7th gen with a linux based computer

DISCLAIMER: this is some code to play with, by no means a complete solution to use your iPod on Linux.

iTunes and this code can not be used together at this moment.

The code is not very tested, and the code supposes nothing can ever go wrong.

# Building

```
./build.sh
```

# Usage

Mount your iPod nano 7th gen.

The first time you do this, you have to restore your iPod (with iTunes, or on the iPod itself) and copy Locations.itdb to `<mount_point>/iPod_Control/iTunes/iTunes\ Library.itlp/` (untested iPods other than mine).

Then, several commands are available :

```
./main <mount_point> clear # erase everything
./main <mount_point> add <music_file> # add a track
./main <mount_point> adddir <music_directory> # add a whole music folder
```

# Requirements

ffmpeg (to get metadata), glib, gio, sqlite, vala.
