% TRASH(1)
% Bruce Hill (*bruce@bruce-hill.com*)
% Dec 3, 2021

# NAME

trash - A command-line trash tool.

# SYNOPSIS

`trash` \[*-v*\] \[*-i*\] \[*-u*\] \[*-e*\] \[\[`--`\] *files...*\]

# DESCRIPTION

`trash` is a Freedesktop.org compliant command line trash tool. You can use it
to put files into a "trash" bin, where they can later be restored or
permanently deleted.

# OPTIONS

`-h`, `--help`
: Print the usage and exit.

`-v`, `--verbose`
: Print extra information while running.

`-i`, `--interactive`
: Ask for confirmation on each file.

`-l`, `--list`
: List the files currently in the trash, as well as how long ago they were
trashed.

`-u`, `--untrash` \[*file*\]
: Restore a file from the trash to its original location. If an argument is
provided, it will be used for fuzzy matching, otherwise, the file will be
user-selected from a list of trashed files via `fzf`.

`-e`, `--empty`
: Permanently delete the files in the trash.

`-f`, `--force`
: Don't bother asking for any confirmations.

*files...*
: The files to delete.


# EXAMPLES

Send some files and folders to the trash:
```
trash foo.txt baz/
```

Restore *foo.txt* from the trash (assuming there are no other trashed files
matching that pattern):
```
trash -u foo.txt
```

Empty the trash:
```
trash -e
```
