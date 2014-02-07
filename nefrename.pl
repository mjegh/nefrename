# This is a simple script I wrote to rename my Nikon nef and jpg files
# I've taken with my Nikon camera. The Nikon uses a file number with 4 digits
# so it is does not take long to cycle the number. I ususually take ram (nef) and
# jpeg shots at the same time and only switch to raw/nef only when time
# (multiple shots) matters.
# I also edit my raw/nef files with capture NX and write a new jpg named
# <ORIGINAL_FILENAME>_copy.jpg.
# This script finds all nef/jpg files (and xx_copy.jpg files) and renames/copies
# (see --copy or --rename) them based on the --stem argument, the datetime
# the picture was taken (dependent on --date). If --keeptimes is set (the default)
# and you --copy the file, it tries to keep the modified and created times
# on the copy.
# If you nef files don't start with "_DSC" you can use --nefprefix to change it.


use 5.016;
use strict;
use warnings;
use Cwd;                        #  which dir are we in
use Getopt::Long;
# we use Image::ExifTool to get the date shot taken out of the nef/jpg
# and use it in renaming the file
use Image::ExifTool qw(:Public);
use File::Copy;                 #  to copy the original file instead of rename it

my %opt = (copy => 1, nefprefix => '_DSC', keeptimes => 1, date => 1);

GetOptions(
    'rename' => \$opt{rename},
    'copy' => \$opt{copy},
    'stem=s' => \$opt{stem},
    'date!' => \$opt{date},
    'verbose!' => \$opt{verbose},
    'nefprefix=s' => \$opt{nefprefix},
    'keeptimes!' => \$opt{keeptimes}
) or die "Error in command line arguments";

die "Need a stem for the file" if !$opt{stem};
my $nef_prefix = $opt{nefprefix};

my $cwd = getcwd;
say "Working on dir $cwd" if $opt{verbose};

opendir (my $dh, $cwd) || die qq/cannot opendir $cwd: $!/;
my @files = readdir $dh;

my %img_nos;                    # hash of unique image numbers
# look at all the files in this dir, extract the photo number and store unique
# photo numbers in this hash
foreach my $file(@files) {
    if ($file =~ /${nef_prefix}(\d+)(_copy)*\.(JPG|NEF)/i) {
        $img_nos{$1}++;
    }
}

my $stem = $opt{stem};
my $fileno = 1;

foreach my $img_no(sort keys %img_nos ) {
    my $type = 0;
    my $done;
    foreach my $file(("${nef_prefix}${img_no}.JPG",
                      "${nef_prefix}${img_no}_copy.JPG",
                      "${nef_prefix}${img_no}_copy.jpg",
                      "${nef_prefix}${img_no}.NEF")) {
        my ($from, $to);
        $type++;
        if (-e $file) {
            my $info = ImageInfo($file);
            my $dt = $info->{DateTimeOriginal};
            my ($year, $month, $day);
            if ($opt{date} && $dt =~ /\A(\d{4}):(\d{2}):(\d{2})/) {
                ($year, $month, $day) = ($1, $2, $3);
            } elsif ($opt{date}) {
                die "did not find date in $dt";
            }
            my $sub_date = ($opt{date} ? "_${year}_${month}_${day}" : '');
            if ($type == 1) {
                $from = "_DSC${img_no}.JPG";
                $to = "${stem}_${fileno}${sub_date}.JPG";
            } elsif ($type == 2) {
                $from = "_DSC${img_no}_copy.JPG";
                $to = "${stem}_${fileno}${sub_date}_copy.JPG";
            } elsif ($type == 3) {
                $from = "_DSC${img_no}_copy.jpg";
                $to = "${stem}_${fileno}${sub_date}_copy.JPG";
            } elsif ($type == 4) {
                $from = "_DSC${img_no}.NEF";
                $to = "${stem}_${fileno}${sub_date}.NEF"
            } else {
                die "how did we get here";
            }
            my @stat = stat($file);
            #say "atime = ", $stat[8], ", mtime = ", $stat[9];
            if ($from) {
                say "$from => $to";
                if ($opt{copy}) {
                    copy($from, $to ) or die "Failed to copy /$from/ to /$to/ - $!";
                    utime($stat[8], $stat[9], $to) if $opt{keeptimes};
                } elsif ($opt{rename}) {
                    rename($from, $to ) or die "Failed to rename /$from/ to /$to/ - $!";
                }
                $done++;
            }
        }
    }
    $fileno++ if $done;
}
