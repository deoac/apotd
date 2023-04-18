[![Actions Status](https://github.com/deoac/apotd/actions/workflows/test.yml/badge.svg)](https://github.com/deoac/apotd/actions)

### sub print-version

```raku
sub print-version(
    $verbose
) returns Mu
```

Copied from <zef:lizmat>'s CLI::Version module. For some reason, I can't get it to work here. $?DISTRIBUTION.meta does not show data from my META6.json.

TITLE
=====

Astronomy Picture of the Day

SUBTITLE
========

Download Today's Astronomy Picture of the Day

VERSION
=======

This documentation refers to `apotd` version 1.0.3

SYNOPSIS
========

Usage:

    apotd [-d|--dir=<Str>] [-f|--filename=<Str>] [-a|--prepend-count]

      -d|--dir=<Str>         What directory should the image be saved to? [default: '$*HOME/Pictures/apotd']
      -f|--filename=<Str>    What filename should it be saved under? [default: the caption of the image]
      -a|--prepend-count     Add a count to the start of the filename. [default: False]

To downloand and save using the default behavior, simply:

```bash
$ apotd
```

DESCRIPTION
===========

NASA provides a website ([Astronomy Picture of the Day](https://apod.nasa.gov/apod/astropix.html)) which displays a different astronomy picture every day.

"Each day a different image or photograph of our fascinating universe is featured, along with a brief explanation written by a professional astronomer."

`apotd` will download today's image. Use it for wallpaper, screen savers, etc.

By default, `apotd` will save to

    ~/Pictures/apotd/

with the filename taken from the caption of the photo e.g.

    Dark Nebulae and Star Formation in Taurus.jpg

and will optionally prepend a number which increments with each new image, e.g.

    2483-Dark Nebulae and Star Formation in Taurus.jpg

Macintosh allows a comment to be associated with each file. So on Macs, `apodt` will copy the `alt` text and the permalink for the image into the file's comment. e.g.

    A star field strewn with bunches of brown dust is pictured. In the center
    is a bright area of light brown dust, and in the  center of that is
    a bright region of star formation.

    https://apod.nasa.gov/apod/ap230321.html

OPTIONS
=======

```bash
# Save to directory "foo"
$ apotd --dir=foo
$ apotd    -d=foo

# Save with the filename "bar"
# The image's extension, e.g. ".jpg", will be automatically added.
$ apotd --file=bar
$ apotd     -f=bar

# Prepend a count to the filename
$ apotd --prepend-count
$ apotd  -p
```

DIAGNOSTICS
===========

General problems
----------------

Failed to get the directory contents of <var>directory</var>: Failed to open dir: No such file or directory

Failed to create directory <var>directory</var>: Failed to mkdir: No such file or directory

Failed to resolve host name 'apod.nasa.gov'

Problems specific to `apotd`:
-----------------------------

Couldn't find an image on the site. It's probably a video today.

The image has already been saved as <var>filename</var>.

Couldn't write the alt-text to <var>path</var>.

Success
-------

Successfully wrote Pictures/apotd/ 2483-Dark Nebulae and Star Formation in Taurus.jpg

Successfully wrote the alt-text and permanent link as a comment to the file.

DEPENDENCIES
============

    LWP::Simple;
    Filetype::Magic;
    Digest::SHA1::Native;

ASSUMPTIONS
===========

`apotd` assumes that the caption of the photo is the first `<b> ... </b> ` line in the HTML code.

And that the image is the first `<IMG SRC= `html tag.

And that tag has an `alt=` attribute.

BUGS AND LIMITATIONS
====================

There are no known bugs in this module.

Please report problems to Shimon Bollinger <deoac.shimon@gmail.com>

AUTHOR
======

Shimon Bollinger <deoac.shimon@gmail.com>

Source can be located at: https://github.com/deoac/apotd.git

Comments, suggestions, and pull requests are welcome.

LICENSE AND COPYRIGHT
=====================

Copyright 2023 Shimon Bollinger

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. See [perlartistic](http://perldoc.perl.org/perlartistic.html).

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

