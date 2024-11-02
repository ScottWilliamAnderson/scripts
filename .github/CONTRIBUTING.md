# Contributing Guidelines

## Code Style
- Use consistent indentation (4 spaces = 1 tab)
- Include comments for complex logic
- Add docstrings for functions
- Use appropriate, descriptive variable names
- Add error handling where necessary

## How to write a good commit message
- Separate subject from body with a blank line
- Limit the subject line to 50 characters
- Capitalize the subject line
- Do not end the subject line with a period
- Use the imperative mood in the subject line
- Wrap the body at 72 characters
- Use the body to explain what and why vs. how

### Example
```plaintext
Summarize changes in around 50 characters or less

More detailed explanatory text, if necessary. Wrap it to about 72
characters or so. In some contexts, the first line is treated as the
subject of the commit and the rest of the text as the body. The
blank line separating the summary from the body is critical (unless
you omit the body entirely); various tools like `log`, `shortlog`
and `rebase` can get confused if you run the two together.

Explain the problem that this commit is solving. Focus on why you
are making this change as opposed to how (the code explains that).
Are there side effects or other unintuitive consequences of this
change? Here's the place to explain them.

Further paragraphs come after blank lines.

 - Bullet points are okay, too

 - Typically a hyphen or asterisk is used for the bullet, preceded
   by a single space, with blank lines in between, but conventions
   vary here

If you use an issue tracker, put references to them at the bottom,
like this:

Resolves: #123
See also: #456, #789
```

*These commit message guideline come from [cbeams - How to Write a Git Commit Message](https://cbea.ms/git-commit/)*


## Adding New Scripts
1. Create a new folder for your script
2. Include a README.md with usage instructions
3. Add entry to main README.md
4. Ensure script is well-documented

## Testing
- Test on Windows 10/11
- Document any dependencies
- Include troubleshooting steps