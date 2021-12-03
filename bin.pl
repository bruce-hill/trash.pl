#!/usr/bin/perl -l
#
# Command line interface for Freedesktop.org-compliant trash
#
use URI::Escape;
use Getopt::Long;
use Time::Ago;
use Time::Piece;
use IPC::Open3;
use File::Copy;
use File::Temp qw/ tempfile /;
use Cwd qw(abs_path);

Getopt::Long::Configure("bundling");

my $verbose = "";
my $help = "";
my $untrash = "";
my $list = "";
my $empty = "";

GetOptions(
    "verbose|v" => \$verbose,
    "help|h" => \$help,
    "untrash|u" => \$untrash,
    "list|l" => \$list,
    "empty|e" => \$empty,
);

if ($help) {
    print "Help";
    exit 0;
}

if ($empty) {
    print "Emptying...";
    for (glob "~/.Trash/files/*") {
        print if $verbose;
        unlink;
    }
    for (glob "~/.Trash/info/*") {
        unlink;
    }
} elsif ($untrash) {
    @files=();
    my $i = 0;
    for (glob "~/.Trash/info/*") {
        open(my $info, "<", $_);
        @lines = <$info>;
        (my $path) = ($lines[1] =~ /^Path=(.*)/);
        $path = uri_unescape($path);
        (my $date) = ($lines[2] =~ /^DeletionDate=(.*)/);
        $date = Time::Piece->strptime($date, "%FT%H:%M:%S");
        # (my $deleted) = ($_ =~ s@/info/(.*)\.trashinfo$@/files/$1@);
        (my $deleted) = /([^\/]+)\.trashinfo$/;
        push(@files, {i => $i++, trashinfo => $_, path => $path, date => $date, deleted => $deleted})
    }

    my $pid = open3(my $fzf_in, my $fzf_out, ">&STDERR",
        "fzf", "-d", '\\t', "--nth=2..", "--with-nth=2..", "-m", "-1", "-0", "-q", "@ARGV");
    for (sort {$b->{date} <=> $a->{date}} @files) {
        $ago = Time::Ago->in_words($_->{date});
        print $fzf_in "$_->{i}\t$ago ago\t$_->{path}";
    }
    close($fzf_in);

    while ((my $i) = <$fzf_out> =~ /^(\d+)/) {
        print "Restoring: $ENV{HOME}/.Trash/files/$files[$i]->{deleted} -> $files[$i]->{path}" if $verbose;
        rename "$ENV{HOME}/.Trash/files/$files[$i]->{deleted}", $files[$i]->{path};
        unlink $files[$i]->{trashinfo};
    }

    waitpid($pid, 0);
    if (my $exit_status = $? >> 8) {
        exit $exit_status;
    }
} elsif ($list) {
    for (glob "~/.Trash/info/*") {
        open(my $info, "<", $_);
        @lines = <$info>;
        (my $path) = ($lines[1] =~ /^Path=(.*)/);
        $path = uri_unescape($path);
        (my $date) = ($lines[2] =~ /^DeletionDate=(.*)/);
        $date = Time::Piece->strptime($date, "%FT%H:%M:%S");
        $ago = Time::Ago->in_words($date);
        print "$date\t$path";
    }
} else {
    print "Deleting..." if $verbose;
    for (@ARGV) {
        if (! -e $_) {
            print "File does not exist: $_";
            exit 1;
        }
        my ($f, $filename) = tempfile("$ENV{HOME}/.Trash/info/$_-XXXXXX", SUFFIX => ".trashinfo");
        print $f "[Trash Info]";
        my $path = abs_path($_);
        print $path if $verbose;
        $path =~ s;([^/]+);uri_escape($1);eg;
        print $f "Path=$path";
        my $date = localtime->strftime("%FT%H:%M:%S");
        print $f "DeletionDate=$date";
        close($f);
        my $dest = $filename =~ s;/info/([^/]*)\.trashinfo$;/files/$1;r;
        rename $_, $dest;
    }
}
