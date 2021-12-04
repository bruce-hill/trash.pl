#!/usr/bin/perl
#
# Command line interface for Freedesktop.org-compliant trash
#
use feature say;
use URI::Escape;
use Getopt::Long;
use Time::Ago;
use Time::Piece;
use IPC::Open3 qw(open3);
use File::Temp qw(tempfile);
use File::Basename qw(basename);
use Cwd qw(abs_path);
use POSIX qw(strftime);

Getopt::Long::Configure("bundling");

my ($verbose, $help, $untrash, $list, $empty, $interactive, $force);

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
    return if $force;
    print "@_[0] [y/N] ";
    chomp(my $reply = <STDIN>);
    exit 1 if $reply ne "y";
}

sub trash_files {
    my @files;
    for (<~/.Trash/info/*>) {
        open my $f, $_;
        my %info = (trashinfo => $_, trashfile => s|/info/([^/]+)\.trashinfo$|/files/$1|r);
        /^(\w+)=(.*)/ and $info{$1} = $2 for <$f>;
        $info{DeletionDate} = localtime->strptime($info{DeletionDate}, "%FT%H:%M:%S");
        $info{DeletedAgo} = Time::Ago->in_words($info{DeletionDate});
        push @files, \%info;
    }
    return sort {$b->{DeletionDate} <=> $a->{DeletionDate}} @files;
}

if ($help) {
    print q{
        trash.pl - Command-line trash
        Usage: trash [flags] [files...]
        Flags:
            -h, --help         print this message and exit
            -v, --verbose      run in verbose mode
            -l, --list         list files currently in the trash
            -u, --untrash      return trashed files to their original location
            -e, --empty        empty the trash (permanently delete files)
            -i, --interactive  prompt before making changes
            -f, --force        bypass all prompts
    } =~ s/^\s*//mgr;
    exit 0;
} elsif ($list) {
    say "$_->{DeletedAgo}\t$_->{Path}" for (trash_files());
} elsif ($untrash) {
    my @files = trash_files() or die "No files currently in the trash";
    my $pid = open3(my $fzf_in, my $fzf_out, ">&STDERR",
        "fzf", "-d", '\\t', "--nth=3..", "--with-nth=3..", "-m", "-1", "-0",
        "--preview", "exiftool {2}", "--color", "preview-fg:6", "-q", "@ARGV");
    while (my ($i, $f) = each @files) {
        say $fzf_in "$i\t$f->{trashfile}\t$f->{DeletedAgo} ago\t$f->{Path}";
    }
    close $fzf_in;

    while (<$fzf_out> =~ /^(\d+)/) {
        my $f = $files[$1];
        if (-e $f->{Path}) {
            confirm "File already exists at: $f->{Path}\nDo you want to restore there anyways?";
        } elsif ($interactive) {
            confirm "Restore $f->{trashfile} -> `$f->{Path}?";
        }
        say "Restoring: $f->{trashfile} -> $f->{Path}" if $verbose;
        rename "$f->{trashfile}", $f->{Path};
        unlink $f->{trashinfo};
    }

    waitpid $pid, 0;
    exit $?>>8 if $?;
} elsif ($empty) {
    confirm "Empty the trash?" unless $force;
    say "Emptying..." if $verbose;
    say join "\n", <~/.Trash/files/* ~/.Trash/info/*> if $verbose;
    unlink <~/.Trash/files/* ~/.Trash/info/*>;
    say "Trash emptied!";
} else {
    die 'No files provided. Run `trash --help` to see usage.' unless @ARGV;
    say "Trashing..." if $verbose;
    for (@ARGV) {
        die "File does not exist: $_" unless -e;
        confirm "Send to trash: $_?" if $interactive;
        my $path = abs_path $_;
        say $path if $verbose;
        $path =~ s|([^/]+)|uri_escape($1)|eg;
        my $date = strftime "%FT%H:%M:%S", localtime;
        my $base = basename($_) =~ s/^\./_./r;
        my ($f, $filename) = tempfile "$ENV{HOME}/.Trash/info/$base-XXXXXX", SUFFIX => ".trashinfo";
        print $f qq{
            [Trash Info]
            Path=$path
            DeletionDate=$date
        } =~ s/^\s*//mgr;
        close $f;
        rename $_, ($filename =~ s|/info/([^/]*)\.trashinfo$|/files/$1|r);
    }
}
