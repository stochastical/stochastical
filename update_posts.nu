#!/usr/bin/env nu

const FEED_URL = "https://abstractnonsense.xyz/index.xml"
const README   = "README.md"
const N        = 5

# Fetch the RSS feed and update the README with the N most recent posts
def main []: nothing -> nothing {
    fetch-posts | update-readme
    print "README updated."
}

# Fetch and parse the RSS feed as structured XML
def fetch-feed []: nothing -> record {
    http get --raw $FEED_URL | decode | from xml
}

# Extract the text value of a named child element
def child [tag: string]: record -> string {
    $in | get content | where tag == $tag | first | get content | first | get content
}

# Decode HTML entities using Python's stdlib html.unescape
def decode-entities []: string -> string {
    $in | ^python3 -c "import html, sys; print(html.unescape(sys.stdin.read().strip()))"
}

# Format an RFC-2822 date string as "Mon D, YYYY"
# Note: %-d (no leading zero) is Linux-only; this script runs on ubuntu-latest
def format-date []: string -> string {
    $in | into datetime | format date "%b %-d, %Y"
}

# Build a markdown table of the N most recent posts from the feed
def fetch-posts []: nothing -> string {
    let items = fetch-feed
        | get content
        | where tag == "channel"
        | first
        | get content
        | where tag == "item"

    let rows = $items | first $N | each {|item|
        let title = $item | child "title" | decode-entities
        let link  = $item | child "link"
        let date  = $item | child "pubDate" | format-date
        "| [" + $title + "](" + $link + ") | " + $date + " |"
    }

    ["| Title | Date |", "|:---|:---|"] ++ $rows | str join "\n"
}

# Splice the posts table into the README between the marker comments
def update-readme []: string -> nothing {
    let posts        = $in
    let content      = open --raw $README
    let start_marker = "<!-- BLOG-POSTS:START -->"
    let end_marker   = "<!-- BLOG-POSTS:END -->"
    let before       = $content | split row $start_marker | first
    let after        = $content | split row $end_marker   | last
    $"($before)($start_marker)\n($posts)\n($end_marker)($after)" | save --force $README
}
