#! /usr/bin/env raku
use v6.d;

#===============================================================================
#
#         FILE  APOTD
#
#  DESCRIPTION: Download the Astronomy Picture of the Day
#
#       AUTHOR: <Shimon Bollinger>  (<deoac.bollinger@gmail.com>)
#      VERSION: 1.0.0
#     REVISION: Last modified: Sat 15 Apr 2023 04:12:02 PM EDT
#===============================================================================

use Filetype::Magic;
use Digest::SHA1::Native;
use LWP::Simple;

constant $APOTD-PAGE   = "https://apod.nasa.gov/apod/astropix.html";
constant $WEBSITE      = $APOTD-PAGE.IO.dirname;
constant $APOTD-FOLDER = "%*ENV<HOME>/Pictures/apotd";

# Don't allow these characters in a filename.
# Then the filename will not cause problems on Linux, Windows, or MacOS
my regex filename-bad-chars  { <[ <  > | \\ : (  ) & ; # ]> }
my regex shell-special-chars { <[ ' " $ ! \\ ; ]> | \h }
my regex equals-sign         { <[ = ]> }
my regex single-quote        { <[ ' ]> }
my regex dbl-quote           { <[ " ]> }
my regex not-dbl-quote       { <-[ " ]> }
my regex in-dbl-quotes       {
                                <dbl-quote>
                                $<quoted-string>=(<not-dbl-quote>+)
                                <dbl-quote>
                             }

sub USAGE {
say q:to/END/;
Usage:

    -d|--dir=<Str>         What directory should the image be saved to? [default: '$*HOME/Pictures/apotd']
    -f|--filename=<Str>    What filename should it be saved under? [default: the caption of the image]
    -p|--prepend-count     Add a count to the start of the filename. [default: False]
END

} # end of sub USAGE

my sub main (
        #| What directory should the image be saved to?
    Str  :d(:$dir)      is copy = $APOTD-FOLDER,
        #| What filename should it be saved under? [default: the caption of the image]
    Str  :f(:$filename) is copy,
        #| Add a count to the start of the filename.
    Bool :p(:$prepend-count)    = False,
    Bool :$debug        is copy = False,
) is export {
    my $is-cronjob = !$*IN.t; # i.e. stdin not from a terminal
    $debug ||= $is-cronjob;   # always log debug info when running as a cronjob.

    note "\n", DateTime.now if $debug;

    my $html-source = try LWP::Simple.get: $APOTD-PAGE;

    mail-die "Couldn't get from the $APOTD-PAGE.\n" ~
        "Are you connected to the internet?\n" ~
        " $!"
            without $html-source;

    # First, extract the filename of the image from the page
    my ($image-name, $image-ext) = get-filename $html-source;

    # Second, extract the actual image (usually a JPEG) from the site
    my ($image, $image-hash) = get-image $image-name;

    # If the user has not supplied a filename, take it from the image caption
    $filename //=  make-filename $html-source;

    # Don't add images that have already been downloaded
    die-if-image-exists $image-hash;

    my Str $path;
    if $prepend-count {
        prepend-count $filename if $prepend-count;
    } # end of if $prepend-count
    $path = "$dir/$filename.$image-ext";

    dd $path if $debug;

    # ... aaaand save it!
    if my $success = save-image($path, $image) {
        say "Successfully wrote $path";
    } else {
        $success.throw;
    } # end of if save-image ($path, $image)

    # Now write the alt-text to the 'comment' section of a MacOS file.
    if $*DISTRO.auth ~~ rx:s/ Apple Inc. / {
        my $alt-text = get-alt-text $html-source;
        my $comment  = get-comment $alt-text;

        # ...aaand write the comment into the comment box!
        my Proc $result = write-comment $path, $comment;

        # shell returns 0 on success.
        if $result.exitcode == 0 {
            say  "Successfully wrote the alt-text and "   ~
                 "permanent link as a comment to the file."
        } else {
            mail-die "Couldn't write the alt-text to $path.\n",
                "exit code: {$result.exitcode}\n",
                "   stdout: {$result.out.slurp()}\n",
                "   stderr: {$result.err.slurp()}";
        } # end of if $result.exitcode == 0
    } # end of if $*DISTRO.auth ~~ rx:s/ Apple Inc. /

    # ------------------- Program ends here ----------------------- #



    # ------------ Subroutine Definitions start here -------------- #
    #
    sub get-alt-text (Str $html-source --> Str) {
        my @alt-text = gather for $html-source.lines  {
            # The last line of the alt-text is "See explanation..."
            # so we use ff^
            take $_ if rx{ alt <equals-sign> } ff^
                       rx{ <dbl-quote> $};
        } # end of for $html-source.lines
        my $alt-text = @alt-text.subst(rx{^ alt <equals-sign> <dbl-quote>})
                                .subst("\n", ' ', :g); # don't need the line-breaks

        if $alt-text.trim eq '' or
           $alt-text.starts-with: 'See Explanation' {
            $alt-text = '';
            note "No alt-text for this image." if $debug;
        } # end of if $alt-text.starts-with: 'See Explanation'|''

        dd $alt-text if $debug;
        return $alt-text;
    } # end of sub get-alt-text ($Str $html-source --> Str)

    sub get-comment (Str $alt-text --> Str) {
        # Get the path to the permanent link to this image.
        # astropix page names are of the form 'apYYMMDD.html'
        my $html-page-name = DateTime.now( formatter =>
            { sprintf 'ap%02d%02d%02d', .year % 100, .month, .day }
        );

        # Join the alt-text and the link into the comment.
        # MacOS requires \r, not \n
        my $comment = "$alt-text\r\r$WEBSITE/$html-page-name.html";
        note "\n---------" if $debug;
        dd $comment if $debug;

        return $comment;
    } # end of sub get-comment (Str $alt-text --> Str)


    sub write-comment (Str $path, Str $comment
                        --> Proc) {
        my $path-encoded    = escape-special-chars $path;
        my $comment-encoded = escape-special-chars $comment;
        my $shell-cmd = Q:scalar:to/END/.subst("\n", ' ', :g);
            osascript -e 'on run {f, c}'
            -e 'tell app "Finder" to set comment of
               (POSIX file f as alias) to c'
            -e end file://$path-encoded
                $comment-encoded
        END

        note "\n---------" if $debug;
        dd $shell-cmd if $debug;

        my Proc $result = shell($shell-cmd, :out, :err);
        note "\n---------" if $debug;
        dd $result if $debug;
        note "\n---------" if $debug;
        note $result.out.slurp(:close) if $debug;
        note "\n---------" if $debug;
        note $result.err.slurp(:close) if $debug;

        return $result;
    } # end of sub write-comment (Str $path-encoded, Str $comment-encoded)

    # We need to escape the blank spaces because so that the command line
    # will interpret the path and comment as each being a single  argument
    sub escape-special-chars (Str $str is copy --> Str) {
        $str .= subst: / <shell-special-chars> /, "\\" ~ *, :g;
        return $str;
    } # end of sub escape-special-chars (Str $str is copy --> Str)

    sub get-filename (Str $html-source --> List) {
        # There is only one <IMG SRC= ...> tag on the page.
        my $img-html = $html-source.lines.grep: /IMG \s+ SRC \= (.*) /;
        dd $img-html if $debug;
        mail-die "Couldn't find an image on the site.  It's probably a video today."
            if $img-html eq $(().Seq); # This is what grep returns if it doesn't find anything.


        $img-html ~~ / <in-dbl-quotes> /;
        my Str $image-name = $/<in-dbl-quotes><quoted-string>.Str;
        dd $image-name if $debug;
        mail-die "Weird. There's an HTML tag for an image, " ~
            "but no source for the image!\n\t$img-html"
            without $image-name;
        my Str $image-ext = $image-name.IO.extension;

        return ($image-name, $image-ext);
    } # end of sub get-filename (Str $html-source --> List)

    sub get-image (Str $image-name --> List) {
        my $url = "$WEBSITE/$image-name";
        dd $url if $debug;
        my $image = LWP::Simple.get($url);
        mail-die "Couldn't download the image from the site.\n $!"
            without $image;
        my $image-hash = sha1-hex($image);
        dd $image-hash if $debug;

        return ($image, $image-hash);
    } # end of sub get-image (Str $image-name --> List)

    sub make-filename (Str $html-source --> Str) {
        # The caption is the first <b> ... </b> line.
        # (Until they redesign the site...)
        my Str $caption = $html-source.lines.grep(/\<b\>/).first;

        # get rid of the HTML tags
        $caption .= subst: rx{ \< <[b\/r]>+ \> },  :g;

        # get rid of chars which might be problematic in a filename.
        $caption .= subst: rx{ <filename-bad-chars> }, '★', :g;
        $caption .= trim;
        dd $caption if $debug;

        return $caption;
    } # end of sub make-filename (Str $html-source --> Str)

    # Compare this file's SHA hash with the saved images
    sub die-if-image-exists (Str $image-hash) {
        FILE:
        for $dir.IO.dir -> $file {
            next FILE if file-type($file) !~~ /image/;
            if $image-hash eqv sha1-hex(slurp($file, :bin)) {
                mail-die "The image has already been saved as {$file.basename}";
            } # end of if sha1-hex(slurp($file, :bin))
        } # end of for $dir.IO.dir -> $file
    } # end of sub die-if-image-exists (Str $image-hash)

    # This sub modifies the $filename argument
    sub prepend-count (Str $filename is rw --> Str) {
        # To increment the number, we need to know the last image saved
        # An image name will be something like '0073_RockyRed7_DeepAI_960.jpg'
        my @dir-listing = dir($dir);
        my $most-recent-image =
                @dir-listing
            .grep({try file-type($_) ~~ /image/ })
            .sort({ .IO.modified })
            .reverse
            .head
            .basename with @dir-listing;

        # increment the count (in this case to 0074)
        my $count  = 0;
        dd $most-recent-image if $debug;

        # 'try'ing in case the most recent filename doesn't exist or
        # doesn't begin with 4 digits. In which case, $count == 0
        try $count = $most-recent-image.comb(4).first.join + 1;

        $filename = sprintf "%04d-$filename", $count;
    } # end of sub prepend-count (Str $filename is copy --> Str)

    sub save-image (Str $path, Buf $image --> Bool) {
        dd $path if $debug;
        mkdir $dir unless $dir.IO.e;
        my $success = spurt $path, $image;
        dd $success if $debug;

        return $success;
    } # end of sub save-image (Str, Buf --> Bool)

    sub mail-die (Str $msg) is hidden-from-backtrace {
        my $mail-error = mail-me $msg;
        $msg ~= "\n$mail-error" if $mail-error.chars > 0;
        die $msg;
    } # end of sub mail-die ($msg)

    #| #TODO Get this working
    sub mail-me (Str $body) {
        my $to = 'deoac.bollinger@gmail.com';
        my $subject = 'apotd error';

        my $command = qq:to/END/;
            echo '$body' | mail -s '$subject' $to
        END

        dd $command if $debug;
        my $mailed = shell $command;
        my $retval = '';
        $retval = "Couldn't mail, exit code {$mailed.exitcode}"
            if $mailed.exitcode ≠ 0; # remember, 0 == success

        return $retval;
    } # end of sub mail-me (Str $msg)

    CATCH {
        default {
            # Don't normally show the backtrace.
            $*ERR.say: .message;
            $*ERR.say: .backtrace.nice if $debug;
        }
    };

    } # end of sub main (...) is export
 

=begin pod

=begin comment
    When not using Pod::To::Markdown2 or Pod::To::HTML2, use these instead
    of =head1 NAME

    =TITLE Astronomy Picture of the Day

    =SUBTITLE Download Today's Astronomy Picture of the Day
=end comment

    =head1 NAME 

    apotd - Download Today's Astronomy Picture of the Day

=head1 VERSION

This documentation refers to C<apotd> version 1.0.0


=head1 USAGE

Usage:

  apotd [-d|--dir=<Str>] [-f|--filename=<Str>] [-a|--prepend-count]

    -d|--dir=<Str>         What directory should the image be saved to? [default: '$*HOME/Pictures/apotd']
    -f|--filename=<Str>    What filename should it be saved under? [default: the caption of the image]
    -a|--prepend-count     Add a count to the start of the filename. [default: False]

To downloand and save using the default behavior, simply:

=begin code :lang<bash>
$ apotd
=end code


=head1 OPTIONS

=begin code :lang<bash>
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
=end code

=head1 DESCRIPTION

NASA provides a website (L<Astronomy Picture of the
Day|https://apod.nasa.gov/apod/astropix.html>) which displays a different
astronomy picture every day.

"Each day a different image or photograph of our
fascinating universe is featured,
along with a brief explanation written by a professional astronomer."

C<apotd> will download today's image.  Use it for wallpaper, screen savers, etc.

By default, C<apotd> will save to

    ~/Pictures/apotd/

with the filename taken from the caption of the photo e.g.

    Dark Nebulae and Star Formation in Taurus.jpg

and will optionally prepend a number which increments with each new image, e.g.

    2483-Dark Nebulae and Star Formation in Taurus.jpg

Macintosh allows a comment to be associated with each file.  So on Macs,
C<apodt> will copy the C<alt> text and the permalink for the image into the
file's comment. e.g.

    A star field strewn with bunches of brown dust is pictured. In the center
    is a bright area of light brown dust, and in the  center of that is
    a bright region of star formation.

    https://apod.nasa.gov/apod/ap230321.html

=head1 DIAGNOSTICS

=head2 General problems

Failed to get the directory contents of R<directory>:
Failed to open dir: No such file or directory

Failed to create directory R<directory>:
Failed to mkdir: No such file or directory

Failed to resolve host name 'apod.nasa.gov'

=head2 Problems specific to C<apotd>:

Couldn't find an image on the site.  It's probably a video today.

The image has already been saved as R<filename>.

Couldn't write the alt-text to R<path>.

=head2 Success

Successfully wrote Pictures/apotd/
2483-Dark Nebulae and Star Formation in Taurus.jpg

Successfully wrote the alt-text and permanent link as a comment to the file.

=head1 DEPENDENCIES

    CLI::Version
    LWP::Simple;
    Filetype::Magic;
    Digest::SHA1::Native;

=head1 ASSUMPTIONS

C<apotd> assumes that the caption of the photo is the first
C< <b> ... </b> > line in the HTML code.

And that the image is the first C<< <IMG SRC= >>html tag.

And that tag has an C<alt=> attribute.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Shimon Bollinger <deoac.shimon@gmail.com>

=head1 AUTHOR

Shimon Bollinger  <deoac.shimon@gmail.com>

Source can be located at: https://github.com/deoac/apotd.git

Comments, suggestions, and pull requests are welcome.

=head1 LICENCE AND COPYRIGHT

Copyright 2023 Shimon Bollinger

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
See L<perlartistic|http://perldoc.perl.org/perlartistic.html>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=end pod
