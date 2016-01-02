#!/usr/bin/fish
env PKG_CONFIG_PATH="/usr/lib/pkgconfig/:/usr/local/lib/pkgconfig/" valac main.vala artworkdb.vala id3tag.vapi    --pkg libgda-6.0 --pkg libxml-2.0 --pkg gio-2.0 --pkg gee-0.8 --Xcc=-lid3tag -g
