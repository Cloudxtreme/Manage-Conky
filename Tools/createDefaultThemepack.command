#!/bin/sh

#  createDefaultThemepack.sh
#  Manage Conky
#
#  Created by Nickolas Pylarinos on 09/08/2018.
#  Copyright © 2018 Nickolas Pylarinos. All rights reserved.

symroot="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"/..           # Manage-Conky dir location

# zip up default-themes
7z a "/tmp/default-themes-2.1.cmtp.7z" "$symroot/default-themes/*"

# replace the one we are using with the new one
rm "$symroot/Manage Conky/Resources/default-themes-2.1.cmtp.7z"
mv "/tmp/default-themes-2.1.cmtp.7z" "$symroot/Manage Conky/Resources"

# open Github Desktop
open "/Applications/Github Desktop.app"