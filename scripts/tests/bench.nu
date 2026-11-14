# Tests for scripts/bench.nu. Run with `nur test scripts`.

use std/assert
use ../bench.nu [PLUGINS page-text generate config median]

def "test pages link to the next page" [] {
    let text = page-text 4 5 2
    assert str contains $text "# Page 4"
    assert str contains $text "## Section 2"
    assert str contains $text "[](p0.md#section-1)"
    assert str contains $text "```rust"
}

def "test generate writes every page and an index" [] {
    let dir = mktemp --directory
    generate $dir 3 1
    let files = ls ($dir | path join docs) | get name | path basename | sort
    rm --recursive --force $dir
    assert equal $files [index.md p0.md p1.md p2.md]
}

def "test config launches plugins as asked" [] {
    let builtin = config "/bin/lsdocs" builtin | from toml
    assert equal ($builtin.plugins | get builtin) ($PLUGINS | get builtin)
    let stdio = config 'C:\lsdocs.exe' stdio | from toml
    assert equal ($stdio.plugins | get 0 | get command) ['C:\lsdocs.exe' plugin parser-markdown]
    assert equal ($stdio.plugins | get 0 | get transport) stdio
}

def "test median of durations" [] {
    assert equal ([3sec 1sec 2sec] | median) 2sec
}

# Runs every test in this file.
export def main [] {
    test pages link to the next page
    test generate writes every page and an index
    test config launches plugins as asked
    test median of durations
    print $"bench tests: 4 passed"
}
