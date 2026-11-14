# Build benchmarks: generates a synthetic site and times `lsdocs build` on
# it, with the first-party plugins in-process, over stdio and over a pipe,
# and with growing page sizes.
#
# Run with `nur bench` (release build). Each case is built `runs` times and
# the median is reported.

# The first-party plugins every benchmark site uses, in config order.
export const PLUGINS = [
    [name builtin];
    [markdown parser-markdown]
    [toc transform-toc]
    [links transform-links]
    [nav transform-nav]
    [highlight transform-highlight]
    [html render-html]
]

# Markdown for page `i` of `pages`, with `sections` sections. Each section
# has a paragraph with a cross-reference to the next page, and every other
# one a code block.
export def page-text [i: int, pages: int, sections: int]: nothing -> string {
    let next = ($i + 1) mod $pages
    let body = 1..$sections | each {|k|
        let code = if $k mod 2 == 0 {
            $"\n```rust\nfn section_($k)\(\) -> u32 {\n    ($k) * 2\n}\n```\n"
        } else { "" }
        $"## Section ($k)\n\nPage ($i), section ($k). See []\(p($next).md#section-($k)\) and\n*more* text with `code` and **emphasis** to give the parser some work.\n($code)"
    }
    $"# Page ($i)\n\n($body | str join "\n")"
}

# Writes a site of `pages` pages with `sections` sections each into
# `dir/docs`.
export def generate [dir: path, pages: int, sections: int] {
    let docs = $dir | path join docs
    mkdir $docs
    0..<$pages | each {|i|
        page-text $i $pages $sections | save --force ($docs | path join $"p($i).md")
    } | ignore
    "# Benchmark site\n\nStart at [](p0.md).\n" | save --force ($docs | path join index.md)
}

# A `lsdocs.toml` running the first-party plugins in-process (`transport`
# "builtin") or out-of-process through `lsdocs plugin` over "stdio" or
# "pipe".
export def config [lsdocs: path, transport: string]: nothing -> string {
    let plugins = $PLUGINS | each {|p|
        let launch = if $transport == "builtin" {
            $"builtin = \"($p.builtin)\""
        } else {
            # Literal (single-quoted) TOML strings keep Windows paths intact.
            $"command = ['($lsdocs)', 'plugin', '($p.builtin)']\ntransport = \"($transport)\""
        }
        $"[[plugins]]\nname = \"($p.name)\"\n($launch)\n"
    }
    $"[site]\ntitle = \"Benchmark\"\nbase_url = \"https://example.com/\"\n\n($plugins | str join "\n")"
}

# The median of a list of durations.
export def median []: list<duration> -> duration {
    let sorted = $in | sort
    $sorted | get (($sorted | length) // 2)
}

# Builds `dir` with its config `runs` times and returns the median time.
# Without `cache`, builds bypass the build cache; with it, one untimed
# build fills the cache first, so the timed ones are fully cached.
def time-build [lsdocs: path, dir: path, runs: int, cache: bool]: nothing -> duration {
    let config = $dir | path join lsdocs.toml
    let flags = if $cache { [] } else { [--no-cache] }
    if $cache { ^$lsdocs build --config $config | complete | ignore }
    1..$runs | each {
        timeit {
            let result = ^$lsdocs build --config $config ...$flags | complete
            if $result.exit_code != 0 {
                error make {msg: $"build of ($dir) failed:\n($result.stderr)"}
            }
        }
    } | median
}

# Runs every benchmark case and returns a table of results.
export def cases [lsdocs: path, --pages: int = 200, --runs: int = 3]: nothing -> table {
    let root = mktemp --directory
    let cases = [
        # Transport cost on a typical site, then the same with every parse
        # and render result cached.
        [transport pages sections cache];
        [builtin $pages 5 false]
        [stdio $pages 5 false]
        [pipe $pages 5 false]
        [builtin $pages 5 true]
        [stdio $pages 5 true]
        # Tree size: fewer, bigger pages.
        [builtin 20 50 false]
        [stdio 20 50 false]
        [builtin 20 200 false]
        [stdio 20 200 false]
    ]
    let results = $cases | enumerate | each {|case|
        let c = $case.item
        let dir = $root | path join $"case($case.index)"
        generate $dir $c.pages $c.sections
        config $lsdocs $c.transport | save ($dir | path join lsdocs.toml)
        let time = time-build $lsdocs $dir $runs $c.cache
        let docs = $c.pages + 1
        {
            transport: $c.transport
            cached: $c.cache
            pages: $docs
            sections: $c.sections
            median: $time
            per_page: ($time / $docs)
        }
    }
    rm --recursive --force $root
    $results
}
