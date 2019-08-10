# Regex

Open source regex implementation.

Not meant for production, created strickly for learning purposes!

# Supported Features

## Character Classes

A character class matches any one of a set of characters.


- <code><b>[</b><i>character_group</i><b>]</b></code> – matches any single character in *character_group*, example `[ae]`
- <code><b>[^</b><i>character_group</i><b>]</b></code> – negation, matches any single character taht is not in *character_group*, example `[^ae]`
- <code><b>[</b><i>first</i><b>-</b><i>last</i><b>]</b></code> – character range, matches any single character in the given range from *fisrt* to *last*, example `[a-z]`
- <code><b>.</b></code> – wildcard, matches any single character except `\n`
- <code><b>\w</b></code> - matches any word character (negation: <code><b>\W</b></code>)
- <code><b>\s</b></code> - matches any whitespace characte (negation: <code><b>\S</b></code>)
- <code><b>\d</b></code> - matches any decimal digit (negation: <code><b>\D</b></code>)
- <code><b>\z</b></code> - matches end of string (negation: <code><b>\Z</b></code>)
- <code><b>\p{</b><i>name</i><b>}</code></b> - matches characters from the given unicode category, example `\p{P}` for punctuation characters (only categories supported by `CharacterSet` are currently supported) (negation: <code><b>\P</b></code>)

## Options

`Regex` can be initialized with a set of options (`Regex.Options`).

- `.caseInsensitive` – match letters in the pattern independent of case.
- `.multiline` –  control the behavior of `^` and `$` anchors. By default, these match at the start and end of the input text. If this flag is set, will match at the start and end of each line within the input text.
- `.dotMatchesLineSeparators` – allow `.` to match any character, including line separators.

# References

- [Regular Expression Language Reference](https://docs.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference)

# License

Regex is available under the MIT license. See the LICENSE file for more info.
