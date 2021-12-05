#!/usr/bin/perl
#
# Command line tool for Freedesktop.org-compliant trash management
#
use feature say;
use Cwd qw(abs_path);
use File::Basename qw(basename);
use File::Find;
use File::Temp qw(tempfile);
use Getopt::Long;
use IPC::Open3 qw(open3);
use Number::Bytes::Human qw(format_bytes);
use POSIX qw(strftime);
use Time::Ago;
use Time::Piece;
use URI::Escape;

Getopt::Long::Configure("bundling");

my $PROGRAM = basename $0;
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
    print -t STDOUT ? "\x1B[1m@_[0] [y/N]\x1B[m " : "@_[0] [y/N] ";
    chomp(my $reply = <STDIN>);
    exit 1 if $reply ne "y";
}

sub trash_files {
    my @files;
    for (<~/.Trash/info/*>) {
        open my $f, $_;
        my %info = (trashinfo => $_, trashfile => s|/info/([^/]+)\.trashinfo$|/files/$1|r);
        /^(\w+)=(.*)/ and $info{$1} = $2 for <$f>;
        close $f;
        $info{DeletionDate} = localtime->strptime($info{DeletionDate}, "%FT%H:%M:%S");
        $info{DeletedAgo} = Time::Ago->in_words($info{DeletionDate})." ago";
        push @files, \%info;
    }
    return sort {$b->{DeletionDate} <=> $a->{DeletionDate}} @files;
}

if ($help) {
    print qq{
        $PROGRAM - Command line trash management tool
        Usage: $PROGRAM [flags] [files...]
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
    say "\x1B[1mTrash contents:\x1B[m" if -t STDOUT;
    say "$_->{DeletedAgo}\t$_->{Path}" for (reverse trash_files());
} elsif ($untrash) {
    my @files = trash_files() or say "No files currently in the trash" and exit 1;
    my $pid = open3(my $fzf_in, my $fzf_out, ">&STDERR",
        "fzf", "-d", '\\t', "--nth=3..", "--with-nth=3..", "-m", "-1", "-0",
        "--preview", "exiftool {2}", "--color", "preview-fg:6", "-q", "@ARGV");
    while (my ($i, $f) = each @files) {
        say $fzf_in "$i\t$f->{trashfile}\t$f->{DeletedAgo}\t$f->{Path}";
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
    my $size = 0;
    find(sub {$size += -s if -f}, $ENV{HOME}.'/.Trash/files/');
    my $n = 0;
    $n += 1 for (<~/.Trash/files/*>);
    say "\x1B[1mTrash contains $n items totaling ".format_bytes($size)."B:\x1B[m";
    if ($verbose) { say "$_->{DeletedAgo}\t$_->{Path}" for (reverse trash_files()) };
    confirm "Empty the trash?" unless $force;
    unlink <~/.Trash/files/* ~/.Trash/info/*>;
    say "Trash emptied!";
} else {
    say "No files provided. Run `$PROGRAM --help` to see usage." and exit 1 unless @ARGV;
    say "Trashing..." if $verbose;
    for (@ARGV) {
        say "File does not exist: $_" and $failed = 1 and next unless -e;
        confirm "Send to trash: $_?" if $interactive;
        say if $verbose;
        my $base = basename($_) =~ s/^\./_./r;
        my ($f, $filename) = tempfile "$ENV{HOME}/.Trash/info/$base-XXXXXX", SUFFIX => ".trashinfo";
        my $path = abs_path($_) =~ s|([^/]+)|uri_escape($1)|egr;
        my $date = strftime "%FT%H:%M:%S", localtime;
        print $f qq{
            [Trash Info]
            Path=$path
            DeletionDate=$date
        } =~ s/^\s*//mgr;
        close $f;
        rename $_, ($filename =~ s|/info/([^/]*)\.trashinfo$|/files/$1|r);
    }
    exit 1 if $failed;
}
