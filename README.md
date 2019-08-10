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

Retrieve one or all occurences text that matches the regular expression by calling `matched(in:)` method. Each match contains a range in the input string.

```swift
for match in regex.matches("<h1>Title</h1>\n<p>Text</p>") {
	print(match.value)
	// Prints ["<h1>", "</h1>", "<p>", "</p>"]
}
```

# Supported Features

## Character Classes

A character class matches any one of a set of characters.

- <code><b>[</b><i>character_group</i><b>]</b></code> – matches any single character in *character_group*, e.g. `[ae]`
- <code><b>[^</b><i>character_group</i><b>]</b></code> – negation, matches any single character taht is not in *character_group*, e.g. `[^ae]`
- <code><b>[</b><i>first</i><b>-</b><i>last</i><b>]</b></code> – character range, matches any single character in the given range from *fisrt* to *last*, e.g. `[a-z]`
- <code><b>.</b></code> – wildcard, matches any single character except `\n`
- <code><b>\w</b></code> - matches any word character (negation: <code><b>\W</b></code>)
- <code><b>\s</b></code> - matches any whitespace characte (negation: <code><b>\S</b></code>)
- <code><b>\d</b></code> - matches any decimal digit (negation: <code><b>\D</b></code>)
- <code><b>\z</b></code> - matches end of string (negation: <code><b>\Z</b></code>)
- <code><b>\p{</b><i>name</i><b>}</code></b> - matches characters from the given unicode category, e.g. `\p{P}` for punctuation characters (only categories supported by `CharacterSet` are currently supported) (negation: <code><b>\P</b></code>)

## Character Escapes

The backslash (<code>\\</code>) either indicates that the character that follows is a special character, e.g. `\b` indicates a word boundary, or that the keyword should be intepreted literally, e.g. `\{` matches the opening bracket.

- <code><b>\u{</b><i>nnnn</i><b>}</b></code> – matches a UTF-16 code unit, e.g. `\u0020` matches escape (Swift-specific feature)

## Options

`Regex` can be initialized with a set of options (`Regex.Options`).

- `.caseInsensitive` – match letters in the pattern independent of case.
- `.multiline` –  control the behavior of `^` and `$` anchors. By default, these match at the start and end of the input text. If this flag is set, will match at the start and end of each line within the input text.
- `.dotMatchesLineSeparators` – allow `.` to match any character, including line separators.

# References

- [Regular Expression Language Reference](https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference)

# License

Regex is available under the MIT license. See the LICENSE file for more info.
