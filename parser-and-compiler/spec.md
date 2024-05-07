# RonDB REST SQL

RonDB REST SQL is a subset of MySQL.
A query that is accepted by RonDB REST SQL should hopefully execute faster than via MySQL, but always produce the same result as MySQL.
This document only details the supported subset of MySQL.
For the meaning of functions, operators and other keywords, refer to the MySQL documentation.

## Functionality

- `SELECT` is the only statement supported. A select expression can only be
  - A column name.
  - An aggregate function `AVG`, `COUNT`, `MAX`, `MIN` or `SUM`, of an arithmetic expression. Such an arithmetic expression can only contain
    - Column names
    - Positive integer literals
    - Operators `+`, `-`, `*`, `/`, `%`.
    - Parentheses
  - `COUNT(*)`.
  - One of the above, aliased using `AS`.
- `FROM` is required and can only refer to one table. No joins or subqueries.
- `WHERE` is supported. The condition is restricted to the following:
  - Column names
  - String literals
  - Positive integer literals
  - Parentheses
  - Operators `OR`, `||`, `XOR`, `AND`, `&&`, `NOT`, `=`, `>=`, `>`, `<=`, `<`, `!=`, `<>`, `IS NULL`, `IS NOT NULL`, `|`, `&`, `<<`, `>>`, `+`, `-`, `*`, `/`, `%`, `^`, `!`
  - Functions `DATE_ADD`, `DATE_SUB` and `EXTRACT` with constant-only arguments, e.g. `DATE_ADD('2024-05-07', INTERVAL '75' MICROSECOND)`.
- `GROUP BY`: Supported, but only for column names, no expressions.
- `ORDER BY`, `ASC`, `DESC`: Supported, but only for column names, no expressions.

## Data types

todo

## Syntax elements

- Single-quoted strings are supported in the `WHERE` condition, but not as the alias after `AS`.
  Therefore, aliases cannot contain characters with code points higher than U+FFFF.
  Character set introducer and `COLLATE` clause are not supported.
- Column names, table names and aliases can be unquoted or use backtick quotes.
  However, unquoted identifiers may not coincide with a MySQL keyword, even if such unquoted identifier is allowed by MySQL, and even if the keyword is not implemented by RonDB REST SQL.
- Double quotes are not supported, neither for identifiers nor strings.
  This makes the `ANSI_QUOTES` SQL mode irrelevant.

## Encoding

- RonDB REST SQL supports and requires UTF-8 encoding.
- NUL characters are not allowed anywhere, but can be represented in strings by means of escape sequence.
- No Unicode normalization will be performed by the server.
