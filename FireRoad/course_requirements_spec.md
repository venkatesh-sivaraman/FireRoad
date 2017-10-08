#  FireRoad Course Requirements Document

## Comments
Use the `%%` symbol for comments.

## Overall Document Format
1. The first line of the document is devoted to metadata about the major, minor, or set of course requirements. The metadata should be separated by the special `#,#` delimiter for easy parsing.
2. The second line of the document may contain a description of the course requirements list (newlines may be specified by typing `\n`).
3. The third line of the document must be empty.
4. Subsequent lines should contain the top-level sections of the course requirements list. Each section should consist of the following:
    * One line for the statement that corresponds to that requirement (should be defined further down in the document).
    * One line for a more verbose description of the section (no newlines allowed).
This list of top-level sections should be terminated by an empty line.
5. The subsequent lines should contain variable definitions (see "Variables").

## Requirements List
The requirements list is built on logical **statements** that define whether or not a user has satisfied given requirements. These are always in the form of a list of courses (or course characteristics) with optional modifications.

In general, comma-separated lists are ALL. Forward slash-separated lists are ANY.

Items in a statement may be parenthesized to nest lists together. For instance, `5.12,(5.60/20.110)` should match the set of courses `[5.12, 5.60]` or `[5.12, 20.110]`.

## List Modifications
A list of courses succeeded by `{>=x}`, where x is an integer, denotes that the given criterion must apply to at least x courses. A similar rule holds true for `{>x}`, `{<=x}`, and `{<x}`.

List modifications may only be applied to the top level of an expression. For example, the modifier in `variable_name := req1, req2 {>=3}` applies to the entire variable declaration; the modifier in `variable_name := (req1{>=3}), req2` would *still* be parsed as belonging to the entire variable declaration.

## Variables
Variables can be assigned using the syntax `variable_name := statement` or `variable_name, "title" := statement`. The title of the statement, if provided, must be human-readable and wrapped in double quotes.

Statements can contain variables as part of their definitions. For example:
```
x := 3.091
chem_requirement, "Chemistry Requirement" := x/5.112
```
