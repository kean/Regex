# Regex

Open source regex engine.

> **Warning.** Not meant to be used in production, created for learning purposes! <br/> See [**Let's Build a Regex Engine**](https://kean.github.io/post/lets-build-regex) series to learn how this project came to be.

# Usage

Create a `Regex` object by providing a pattern and an optional set of options (`Regex.Options`):

```javascript
let regex = try Regex(#"<\/?[\w\s]*>|<.+[\W]>"#)
```

The pattern is parsed and compiled to the special internal representation. If there is an error in the pattern, the initializer will throw a detailed error with an index of the failing token and an error message. 

Use `isMatch(_:)` method to check if the regular expression patterns occurs in the input text:

```swift
regex.isMatch("<h1>Title</h1>")
```

Retrieve one or all occurrences text that matches the regular expression by calling `matches(in:)` method. Each match contains a range in the input string.

```swift
for match in regex.matches(in: "<h1>Title</h1>\n<p>Text</p>") {
    print(match.value)
    // Prints ["<h1>", "</h1>", "<p>", "</p>"]
}
```

If you just want a single match, use `regex.firstMatch(in:)`.

`Regex` is fully thead safe.

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

> Characters consisting of multiple unicode scalars (extended grapheme clusters) are interpreted as single characters, e.g. pattern  `"🇺🇸+"` matches `"🇺🇸"` and  `"🇺🇸🇺🇸"` but not `"🇸🇸"`. But when used inside character group, each unicode scalar is interpreted separately, e.g. pattern `"[🇺🇸]"` matches `"🇺🇸"` and `"🇸🇸"` which consist of the same scalars.

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
- <code><b>\b</b></code> – match must occur on a boundary between a word character and a non-word character (negation: `\B`)

## Grouping Constructs

Grouping constructs delineate the subexpressions of a regular expression and capture the substrings of an input string.

- <code><b>(</b><i>subexpression</i><b>)</b></code> – captures a *subexpression* in a group
- <code><b>(?:</b><i>subexpression</i><b>)</b></code> – non-capturing group

## Backreferences

Backreferences provide a convenient way to identify a repeated character or substring within a string.

- <code><b>\\</b><i>number</i></code> – matches the capture group at the given ordinal position e.g. `\4` matches the content of the fourth group

> If the referenced group can't be found in the pattern, the error will be thrown.

## Quantifiers

Quantifiers specify how many instances of a character, group, or character class must be present in the input for a match to be found.

- <code><b>\*</b></code> – match zero or more times
- <code><b>+</b></code> – match one or more times
- <code><b>?</b></code> – match zero or one time
- <code><b>{</b><i>n</i><b>}</b></code> – match exactly *n* times
- <code><b>{</b><i>n</i><b>,}</b></code> – match at least *n* times
- <code><b>{</b><i>n</i><b>,</b><i>m</i><b>}</b></code> – match from *n* to *m* times, closed range, e.g. `a{3,4}`

All quantifiers are **greedy** by default, they try to match as many occurrences of the pattern as possible. Append the `?` character to a quantifier to make it lazy and match as few occurrences as possible, e.g. `a+?`.

> Warning: **lazy** quantifiers might be used to control which groups and matches are captured, but they shouldn't be used to optimize matcher performance which already uses an algorithm which can handle even nested greedy quantifiers.

## Alternation

- <code><b>|</b></code> – match either left side or right side

## Options

`Regex` can be initialized with a set of options (`Regex.Options`).

- `.caseInsensitive` – match letters in the pattern independent of case.
- `.multiline` –  control the behavior of `^` and `$` anchors. By default, these match at the start and end of the input text. If this flag is set, will match at the start and end of each line within the input text.
- `.dotMatchesLineSeparators` – allow `.` to match any character, including line separators.

# Not supported Features

- Most unicode categories are not support, e.g.`\p{Sc}` (currency symbols) is not supported
- Character class subtraction, e.g. `[a-z-[b-f]]`
- Named blocks, e.g. `\p{IsGreek}`

# Grammar

See `Grammar.ebnf` for a formal description of the language using [EBNF](https://en.wikipedia.org/wiki/Extended_Backus–Naur_form) notation. See `Grammar.xhtml` for a visualization (railroad diagram) of the grammar generated thanks to [https://www.bottlecaps.de/rr/ui](https://www.bottlecaps.de/rr/ui). 

# References

- [Regular Expression Language Reference](https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference)

# License

Regex is available under the MIT license. See the LICENSE file for more info.
