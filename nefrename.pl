# This is a simple script I wrote to rename my Nikon nef and jpg files
# I've taken with my Nikon camera. The Nikon uses a file number with 4 digits
# so it is does not take long to cycle the number. I usually take raw (nef) and
# jpeg shots at the same time and only switch to raw/nef only when time
# (multiple shots) matters.
# I also edit my raw/nef files with capture NX and write a new jpg named
# <ORIGINAL_FILENAME>_copy.jpg.
#
# This script finds all nef/jpg files (and xx_copy.jpg files) and renames/copies
# (see --copy or --rename) them based on the --stem argument, the datetime
# the picture was taken (dependent on --date). If --keeptimes is set (the default)
# and you --copy the file, it tries to keep the modified and created times
# on the copy.
#
# If your nef files don't start with "DSC_" you can use --nefprefix to change it.
# If you add --save-exif then it gets the MakerNotes from the EXIF data in NEF files
# and saves them in filename.dump.
#
# If --creator specified (the default) then the exif data is updated in the new (or replaced file)
# with the contents of %new_exif (see below).
#
use 5.016;
use strict;
use warnings;
use Cwd;                        #  which dir are we in
use Getopt::Long;
# we use Image::ExifTool to get the date shot taken out of the nef/jpg
# and use it in renaming the file
use Image::ExifTool qw(:Public);
use File::Copy;                 #  to copy the original file instead of rename it
use Data::Dumper;

my %new_exif = (
    UsageTerms => 'No reuse without permission');

my %opt = (
    nefprefix => 'DSC_',
    keeptimes => 1,
    date => 1,
    creator => 1,
    verbose => 1);

GetOptions(
    'rename' => \$opt{rename},
    'copy' => \$opt{copy},
    'stem=s' => \$opt{stem},
    'date!' => \$opt{date},
    'verbose!' => \$opt{verbose},
    'nefprefix=s' => \$opt{nefprefix},
    'keeptimes!' => \$opt{keeptimes},
    'save-exif!' => \$opt{save_exif},
    'creator' => \$opt{creator},
) or die "Error in command line arguments";

my $nef_prefix = $opt{nefprefix};
if ($opt{copy} || $opt{rename}) {
    die "Need a stem for the file" if !$opt{stem};
} else {
    $opt{stem} = $opt{nefprefix};
}

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
                      "${nef_prefix}${img_no}_copy_resampled.jpg",
                      "${nef_prefix}${img_no}.NEF")) {
        my ($from, $to);
        $type++;
        if (-e $file) {
            my $info = ImageInfo($file);
            my $dt = $info->{DateTimeOriginal};
            $info = undef;
            my ($year, $month, $day);
            if ($opt{date} && $dt =~ /\A(\d{4}):(\d{2}):(\d{2})/) {
                ($year, $month, $day) = ($1, $2, $3);
            } elsif ($opt{date}) {
                die "did not find date in $dt";
            }
            my $sub_date = ($opt{date} ? "_${year}_${month}_${day}" : '');
            if ($type == 1) {
                $from = "${nef_prefix}${img_no}.JPG";
                $to = "${stem}_${fileno}${sub_date}.JPG";
            } elsif ($type == 2) {
                $from = "$ {nef_prefix}${img_no}_copy.JPG";
                $to = "${stem}_${fileno}${sub_date}_copy.JPG";
            } elsif ($type == 3) {
                $from = "${nef_prefix}${img_no}_copy.jpg";
                $to = "${stem}_${fileno}${sub_date}_copy.JPG";
            } elsif ($type == 4) {
                $from = "${nef_prefix}${img_no}_copy_resampled.jpg";
                $to = "${stem}_${fileno}${sub_date}_copy_resampled.JPG";
            } elsif ($type == 5) {
                $from = "$ {nef_prefix}${img_no}.NEF";
                $to = "${stem}_${fileno}${sub_date}.NEF"
            } else {
                die "how did we get here";
            }
            my @stat = stat($file);
            #say "atime = ", $stat[8], ", mtime = ", $stat[9];
            if ($from) {
                say "$from => $to" if $opt{verbose};

                my $et;
                if ($opt{creator}) {
                    $et = new Image::ExifTool;
                    unless ($et->ExtractInfo($from)) {
                        say "Failed to extract info from $from";
                        exit 1;
                    };
                    foreach (keys %new_exif) {
                        $et->SetNewValue($_, $new_exif{$_});
                    }
                }

                if ($opt{copy}) {
                    if ($opt{creator}) {
                        write_file_with_exif($et, $from, $to);
                    } else {
                        copy($from, $to ) or die "Failed to copy /$from/ to /$to/ - $!";
                    }
                    utime($stat[8], $stat[9], $to) if $opt{keeptimes};
                } elsif ($opt{rename}) {
                    if ($opt{creator}) {
                        $et->write_file_with_exif($et, $from);
                    } else {
                        rename($from, $to ) or die "Failed to rename /$from/ to /$to/ - $!";
                    }
                }

                if ($opt{save_exif} && $type == 5) {
                    my $exifTool = new Image::ExifTool;
                    $exifTool->Options(Group0 => ['EXIF', 'MakerNotes']);
                    $info = $exifTool->ImageInfo($file);
                    my $data = Dumper($info);
                    open(my $fh, '>:encoding(UTF-8)', "$ {stem}_$ {fileno}$ {sub_date}_makernotes.dumper") or
                        die "Failed to open exif makernotes file - $!";
                    print $fh $data;
                    close $fh;
                }
                $done++;
            }
        }
    }
    $fileno++ if $done;
}



sub write_file_with_exif {
    my ($et, $from, $to) = @_;

    my $written = $et->WriteInfo($from, $to);
    if ($written == 2) {
        warn("--creator and no changes were made on $from");
    } elsif (!$written) {
        my $error = $et->GetValue('Error');
        my $warning = $et->GetValue('Warning');
        warn("Warning writing $to from $from - $warning") if $warning;
        die("Error writing $to from $from - $error") if $error;
    }
}
