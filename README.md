# Trash.pl

A simple perl commandline tool for Freedesktop.org-compliant trash management.

## Usage:

```sh
# Send a file to the trash:
trash foo.txt

# List trash contents:
trash -l

# Untrash a file:
trash -u foo.txt

# Empty the trash:
trash -e
```

## Dependencies

This program requires Perl (developed with v5.34.0) with the Time::Ago module
(`cpanm Time::Ago`), [fzf](https://github.com/junegunn/fzf) (for picking which
file to untrash), and [exiftool](https://exiftool.org/) for showing file info
about trashed files.

## License

The license is MIT with the Commons Clause. See [LICENSE](LICENSE) for full
details.
