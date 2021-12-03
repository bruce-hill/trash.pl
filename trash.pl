#!/usr/bin/perl
#
# Command line interface for Freedesktop.org-compliant trash
#
use feature say;
use URI::Escape;
use Getopt::Long;
use Time::Ago;
use IPC::Open3;
use Time::Piece;
use File::Temp qw/ tempfile /;
use Cwd qw(abs_path);
use POSIX qw(strftime);

Getopt::Long::Configure("bundling");

my $verbose = "";
my $help = "";
my $untrash = "";
my $list = "";
my $empty = "";
my $interactive = "";
my $force = "";

GetOptions(
    "verbose|v" => \$verbose,
    "help|h" => \$help,
    "untrash|u" => \$untrash,
    "list|l" => \$list,
    "empty|e" => \$empty,
    "interactive|i" => \$interactive,
    "force|f" => \$force,
);

sub confirm {
    if (!$force) {
        print "@_[0] [y/N] ";
        chomp(my $reply = <STDIN>);
        if ($reply ne "y") {
            exit 1;
        }
    }
}

if ($help) {
    say "bin.pl - Command-line trash";
    exit 0;
} elsif ($list) {
    for (<~/.Trash/info/*>) {
        open my $f, $_;
        my %info;
        /^(\w+)=(.*)/ and $info{$1} = $2 for <$f>;
        $date = localtime->strptime($info{DeletionDate}, "%FT%H:%M:%S");
        my $ago = Time::Ago->in_words($date);
        say "$ago ago\t$info{Path}";
    }
} elsif ($untrash) {
    @files=();
    my $i = 0;
    for (<~/.Trash/info/*>) {
        open my $f, $_;
        my %info = (i => $i++, trashinfo => $_);
        /^(\w+)=(.*)/ and $info{$1} = $2 for <$f>;
        $info{DeletionDate} = localtime->strptime($info{DeletionDate}, "%FT%H:%M:%S");
        (my $deleted) = /([^\/]+)\.trashinfo$/;
        push(@files, \%info)
    }

    if (!@files) {
        say "No files currently in the trash.";
        exit 1;
    }

    my $pid = open3(my $fzf_in, my $fzf_out, ">&STDERR",
        "fzf", "-d", '\\t', "--nth=2..", "--with-nth=2..", "-m", "-1", "-0", "-q", "@ARGV");
    for (sort {$b->{DeletionDate} <=> $a->{DeletionDate}} @files) {
        $ago = Time::Ago->in_words($_->{DeletionDate});
        say $fzf_in "$_->{i}\t$ago ago\t$_->{Path}";
    }
    close $fzf_in;

    while (<$fzf_out> =~ /^(\d+)/) {
        my $f = $files[$1];
        if (-e $f->{Path}) {
            confirm "File already exists at: $f->{Path}\nDo you want to restore there anyways?";
        } elsif ($interactive) {
            confirm "Restore $f->{Path}?";
        }
        (my $trashfile) = $f->{trashinfo} =~ /([^\/]+)\.trashinfo/;
        say "Restoring: $ENV{HOME}/.Trash/files/$trashfile -> $f->{Path}" if $verbose;
        rename "$ENV{HOME}/.Trash/files/$trashfile", $f->{Path};
        unlink $f->{trashinfo};
    }

    waitpid($pid, 0);
    if (my $exit_status = $? >> 8) {
        exit $exit_status;
    }
} elsif ($empty) {
    confirm "Empty the trash?" unless $force;
    say "Emptying..." if $verbose;
    for (<~/.Trash/files/*>) {
        say if $verbose;
        unlink;
    }
    for (<~/.Trash/info/*>) {
        unlink;
    }
    say "Trash emptied!";
} else {
    say "Trashing..." if $verbose;
    for (@ARGV) {
        if (!-e) {
            say "File does not exist: $_";
            exit 1;
        }
        confirm "Send to trash: $_?" if $interactive;
        my ($f, $filename) = tempfile("$ENV{HOME}/.Trash/info/$_-XXXXXX", SUFFIX => ".trashinfo");
        say $f "[Trash Info]";
        my $path = abs_path $_;
        say $path if $verbose;
        $path =~ s|([^/]+)|uri_escape($1)|eg;
        say $f "Path=$path";
        my $date = strftime("%FT%H:%M:%S", localtime);
        say $f "DeletionDate=$date";
        close $f;
        my $dest = $filename =~ s;/info/([^/]*)\.trashinfo$;/files/$1;r;
        rename $_, $dest;
    }
}
