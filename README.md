# Regex

Open source regular expression implementation.

> Created primarily for learning purposes, not meant for production.

# Usage

Create a `Regex` object by providing a pattern and an optional set of options (`Regex.Options`):

```swift
let regex = try Regex(#"<\/?[\w\s]*>|<.+[\W]>"#)
```

The pattern is parsed and compiled to the special internal representation. If there is an error in the pattern, the initializer will throw a detailed error with an index of the failing token and an error message. 

Use `isMatch(_:)` method to check if the regular expression patterns occurs in the input text:

```swift
regex.isMatch("<h1>Title</h1>")
```

Retrieve one or all occurrences text that matches the regular expression by calling `matched(in:)` method. Each match contains a range in the input string.

```swift
for match in regex.matches("<h1>Title</h1>\n<p>Text</p>") {
    print(match.value)
    // Prints ["<h1>", "</h1>", "<p>", "</p>"]
}
```

# Features

## Character Classes

A character class matches any one of a set of characters.

- <code><b>[</b><i>character_group</i><b>]</b></code> – matches any single character in *character_group*, e.g. `[ae]`
- <code><b>[^</b><i>character_group</i><b>]</b></code> – negation, matches any single character that is not in *character_group*, e.g. `[^ae]`
- <code><b>[</b><i>first</i><b>-</b><i>last</i><b>]</b></code> – character range, matches any single character in the given range from *first* to *last*, e.g. `[a-z]`
- <code><b>.</b></code> – wildcard, matches any single character except `\n`
- <code><b>\w</b></code> - matches any word character (negation: <code><b>\W</b></code>)
- <code><b>\s</b></code> - matches any whitespace character (negation: <code><b>\S</b></code>)
- <code><b>\d</b></code> - matches any decimal digit (negation: <code><b>\D</b></code>)
- <code><b>\z</b></code> - matches end of string (negation: <code><b>\Z</b></code>)
- <code><b>\p{</b><i>name</i><b>}</code></b> - matches characters from the given unicode category, e.g. `\p{P}` for punctuation characters (supported categories: `P`, `Lt`, `Ll`, `N`, `S`) (negation: <code><b>\P</b></code>)

> Characters consisting of **multiple unicode scalars** are interpreted as single characters, e.g. pattern  `"🇺🇸+"` matches `"🇺🇸"` and  `"🇺🇸🇺🇸"` but not `"🇸🇸"`. But when used inside character group, such characters are interpreted as individual unicode scalars, e.g. pattern `"[🇺🇸]"` matches `"🇺🇸"` and `"🇸🇸"` which consist of the same scalars.

## Character Escapes

The backslash (<code>\\</code>) either indicates that the character that follows is a special character or that the keyword should be interpreted literally.

- <code><b>\\</b><i>keyword</i></code> – interprets the keyword literally, e.g. `\{` matches the opening bracket
- <code><b>\\<i></b>special_character</i></code> – interprets the special character, e.g. `\b` matches word boundary (more info in "Anchors")
- <code><b>\\u{</b><i>nnnn</i><b>}</b></code> – matches a UTF-16 code unit, e.g. `\u0020` matches escape (Swift-specific feature)

## Anchors

Anchors specify a position in the string where a match must occur.

- <code><b>^</b></code> – matches the beginning of the string (or beginning of the line when `.multiline` option is enabled)
- <code><b>$</b></code> – matches the end of the string or `\n` at the end of the string (end of the line in `.multiline` mode)
- <code><b>\A</b></code> – matches the beginning of the string (ignores `.multiline` option)
- <code><b>\Z</b></code> – matches the end of the string or `\n` at the end of the string (ignores `.multiline` option)
- <code><b>\z</b></code> – matches the end of the string (ignores `.multiline` option)
- <code><b>\G</b></code> – match must occur at the point where the previous match ended

## Options

`Regex` can be initialized with a set of options (`Regex.Options`).

- `.caseInsensitive` – match letters in the pattern independent of case.
- `.multiline` –  control the behavior of `^` and `$` anchors. By default, these match at the start and end of the input text. If this flag is set, will match at the start and end of each line within the input text.
- `.dotMatchesLineSeparators` – allow `.` to match any character, including line separators.

# Unsupported Features

- Most unicode categories are not support, e.g.`\p{Sc}` (currency symbols) is not supported
- Character class subtraction, e.g. `[a-z-[b-f]]`
- Named blocks, e.g. `\p{IsGreek}`

# References

- [Regular Expression Language Reference](https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference)

# License

Regex is available under the MIT license. See the LICENSE file for more info.
