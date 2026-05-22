# cli

Declarative command-line parsing for Odin, with strong subcommand, help, and completion support.

You describe commands and flags as data. The package matches argv, parses flags, returns named positionals, and can render help from the same declarations.

## Getting started

Here's a small example app with two subcommands:

```odin
package main

import cli "path/to/vendored/cli"
import "core:fmt"
import "core:os"

FORMAT_NAMES := [?]string{"--format", "-f"}
HELP_NAMES := [?]string{"--help", "-h"}

FLAGS := [?]cli.Flag_Decl{
  {names = FORMAT_NAMES[:], value_name = "text|json", mode = .Required, doc = "Output format"},
  {names = HELP_NAMES[:], mode = .None, doc = "Show help"},
}

LIST_PATTERNS := [?]string{"items list", "items ls"}
SHOW_PATTERNS := [?]string{"items show <item-id>", "items get <item-id>"}

COMMANDS := [?]cli.Command_Decl{
  {patterns = LIST_PATTERNS[:], id = "items.list", doc = "List items"},
  {patterns = SHOW_PATTERNS[:], id = "items.show", doc = "Show one item"},
}

main :: proc() {
  compiled := cli.compile_cli_decls(COMMANDS[:], FLAGS[:])
  defer cli.destroy_compiled_cli(compiled)

  result := cli.validate_compiled_cli(compiled)
  defer cli.destroy_validation_result(result)
  if !result.ok {
    for err in result.errors do fmt.eprintln(err)
    os.exit(1)
  }

  parsed := cli.parse_compiled_command(os.args[1:], compiled)
  defer cli.destroy_command_parse_result(parsed)
  if !parsed.ok {
    fmt.eprintln(parsed.error)
    print_help(compiled)
    os.exit(1)
  }

  if cli.parsed_command_flag_present(parsed, "--help") {
    print_help(compiled)
    return
  }

  format := "text"
  format_value, has_format := cli.parsed_command_flag_value(parsed, "--format")
  defer delete(format_value)
  if has_format do format = format_value

  switch parsed.match.id {
  case "items.list":
    fmt.printf("listing items as %s\n", format)
  case "items.show":
    id, ok := cli.positional(parsed.match, "item-id")
    defer delete(id)
    if !ok {
      fmt.eprintln("missing item id")
      os.exit(1)
    }
    fmt.printf("showing %s as %s\n", id, format)
  }
}

print_help :: proc(compiled: cli.Compiled_CLI) {
  flags := cli.help_lines_for_compiled_flags(compiled.flags[:])
  defer cli.destroy_help_lines(flags)

  subcommands := cli.help_lines_for_compiled_subcommands(compiled, "items")
  defer cli.destroy_help_lines(subcommands)

  text := cli.render_command_help(cli.Command_Doc{
    key = "items",
    usage = "example items <subcommand> [flags]",
    doc = "Item commands.",
    examples = "example items list\nexample items show item-1 --format json",
  }, subcommands[:], flags[:])
  defer delete(text)

  fmt.println(text)
}

```

## Help Output

The help output from the example looks like this:

```text
NAME
  items - Item commands.

SYNOPSIS
  example items <subcommand> [flags]

SUBCOMMANDS
  list            List items
  show <item-id>  Show one item

FLAGS
  --format text|json | -f text|json  Output format
  --help | -h                        Show help

EXAMPLES
  example items list
  example items show item-1 --format json
```
