package cli

import "core:strings"
import "core:testing"

@(test)
test_render_root_help_includes_standard_sections :: proc(t: ^testing.T) {
  flags := [?]Help_Line{
    {"--db PATH", "Use a specific store"},
  }
  commands := [?]Help_Line{
    {"items", "Item commands"},
  }

  text := render_root_help(Root_Spec{
    name = "tool",
    doc = "Example CLI",
    usage = "tool [flags] <command>",
    flags = flags[:],
    commands = commands[:],
    examples = "tool items",
    footer = "More help.\n",
  })
  defer delete(text)

  testing.expect(t, strings.contains(text, "NAME\n  tool - Example CLI"))
  testing.expect(t, strings.contains(text, "SYNOPSIS\n  tool [flags] <command>"))
  testing.expect(t, strings.contains(text, "FLAGS\n  --db PATH"))
  testing.expect(t, strings.contains(text, "COMMANDS\n  items"))
  testing.expect(t, strings.contains(text, "EXAMPLES\n  tool items"))
  testing.expect(t, strings.has_suffix(text, "More help.\n"))
}

@(test)
test_render_command_help_includes_subcommands_flags_aliases_examples :: proc(t: ^testing.T) {
  subcommands := [?]Help_Line{
    {"show <id>", "Show a record"},
  }
  flags := [?]Help_Line{
    {"--json", "Print JSON"},
  }

  text := render_command_help(
    Command_Doc{
      key = "items",
      usage = "tool items <subcommand>",
      doc = "Item commands.",
      aliases = "item, i",
      examples = "tool items show item-1",
    },
    subcommands[:],
    flags[:],
  )
  defer delete(text)

  testing.expect(t, strings.contains(text, "NAME\n  items - Item commands."))
  testing.expect(t, strings.contains(text, "SUBCOMMANDS\n  show <id>"))
  testing.expect(t, strings.contains(text, "FLAGS\n  --json"))
  testing.expect(t, strings.contains(text, "ALIASES\n  item, i"))
  testing.expect(t, strings.contains(text, "EXAMPLES\n  tool items show item-1"))
}

@(test)
test_render_command_help_wraps_long_syntax_without_truncating :: proc(t: ^testing.T) {
  flags := [?]Help_Line{
    {"--title TEXT | --name TEXT | --label TEXT", "Set the title used when creating or updating an item."},
  }

  text := render_command_help(
    Command_Doc{
      key = "items",
      usage = "tool items",
      doc = "Item commands.",
    },
    nil,
    flags[:],
  )
  defer delete(text)

  testing.expect(t, strings.contains(text, "--label TEXT"))
  testing.expect(t, strings.contains(text, "    Set the title used"))
  testing.expect(t, !strings.contains(text, "..."))
}

@(test)
test_help_lines_for_flags_render_value_names_aliases_and_docs :: proc(t: ^testing.T) {
  flags := [?]Flag_Spec{
    {name = "--format", value_name = "text|json", mode = .Required, doc = "Select output format"},
    {name = "--json", mode = .None, doc = "Alias for JSON output"},
    {name = "--description", aliases = "--body", value_name = "TEXT", mode = .Required, doc = "Body text"},
    {name = "--at", value_name = "DATE", mode = .Required, doc = "Date arguments", help = "--at DATE | --date DATE | --clear"},
    {name = "--internal", mode = .None},
  }

  lines := help_lines_for_flags(flags[:])
  defer destroy_help_lines(lines)

  testing.expect_value(t, len(lines), 4)
  testing.expect_value(t, lines[0].syntax, "--format text|json")
  testing.expect_value(t, lines[0].doc, "Select output format")
  testing.expect_value(t, lines[1].syntax, "--json")
  testing.expect_value(t, lines[2].syntax, "--description TEXT | --body TEXT")
  testing.expect_value(t, lines[3].syntax, "--at DATE | --date DATE | --clear")
}

@(test)
test_help_lines_for_flag_decls_render_slice_names :: proc(t: ^testing.T) {
  format_names := [?]string{"--format", "-f"}
  pretty_names := [?]string{"--pretty"}
  flags := [?]Flag_Decl{
    {names = format_names[:], value_name = "text|json", mode = .Required, doc = "Select output format"},
    {names = pretty_names[:], mode = .None, doc = "Pretty-print output"},
  }

  lines := help_lines_for_flag_decls(flags[:])
  defer destroy_help_lines(lines)

  testing.expect_value(t, len(lines), 2)
  testing.expect_value(t, lines[0].syntax, "--format text|json | -f text|json")
  testing.expect_value(t, lines[0].doc, "Select output format")
  testing.expect_value(t, lines[1].syntax, "--pretty")
}

@(test)
test_help_lines_for_command_specs_use_documented_top_level_specs :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "help", label = "help", shape = "help"},
    {path = "items", aliases = "item|tasks", label = "items", shape = "items", doc = "Item commands"},
    {path = "items show <item-id>", label = "item.select", shape = "item.select", doc = "Hidden nested command"},
  }

  lines := help_lines_for_command_specs(specs[:])
  defer destroy_help_lines(lines)

  testing.expect_value(t, len(lines), 2)
  testing.expect_value(t, lines[0].syntax, "items")
  testing.expect_value(t, lines[0].doc, "Item commands")
  testing.expect_value(t, lines[1].syntax, "items")
  testing.expect_value(t, lines[1].doc, "Hidden nested command")
}

@(test)
test_help_lines_for_command_decls_use_slice_patterns :: proc(t: ^testing.T) {
  item_patterns := [?]string{"items", "item", "tasks"}
  show_patterns := [?]string{"items show <item-id>", "item show <item-id>"}
  specs := [?]Command_Decl{
    {patterns = item_patterns[:], id = "items", doc = "Item commands", help = "items"},
    {patterns = show_patterns[:], id = "item.select", doc = "Show one item", help = "show|get <item-id>"},
  }

  root_lines := help_lines_for_command_decls(specs[:])
  defer destroy_help_lines(root_lines)
  testing.expect_value(t, len(root_lines), 2)
  testing.expect_value(t, root_lines[0].syntax, "items")
  testing.expect_value(t, root_lines[1].syntax, "show|get <item-id>")

  subcommands := help_lines_for_subcommand_decls(specs[:], "items")
  defer destroy_help_lines(subcommands)
  testing.expect_value(t, len(subcommands), 2)
  testing.expect_value(t, subcommands[0].syntax, "items")
  testing.expect_value(t, subcommands[1].syntax, "show|get <item-id>")
}

@(test)
test_help_lines_for_compiled_commands_use_tokenized_patterns :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items show|get <item-id>", label = "items.show", shape = "items.show", doc = "Show item"},
  }
  compiled := compile_cli(specs[:], nil)
  defer destroy_compiled_cli(compiled)

  lines := help_lines_for_compiled_commands(compiled)
  defer destroy_help_lines(lines)

  testing.expect_value(t, len(lines), 1)
  testing.expect_value(t, lines[0].syntax, "items")
  testing.expect_value(t, lines[0].doc, "Show item")
}

@(test)
test_help_lines_for_subcommands_strip_prefix :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items", label = "items", shape = "items", doc = "Item commands", help = "items"},
    {path = "items list", label = "items.list", shape = "items.list", doc = "List items"},
    {path = "items show <item-id>", label = "item.select", shape = "item.select", doc = "Show one item", help = "show|get <item-id>"},
    {path = "items audit <item-id>", label = "items.audit", shape = "items.audit", doc = "Documented future command", help_only = true},
    {path = "projects list", label = "projects.list", shape = "projects.list", doc = "List projects"},
  }

  lines := help_lines_for_subcommands(specs[:], "items")
  defer destroy_help_lines(lines)

  testing.expect_value(t, len(lines), 4)
  testing.expect_value(t, lines[0].syntax, "items")
  testing.expect_value(t, lines[0].doc, "Item commands")
  testing.expect_value(t, lines[1].syntax, "list")
  testing.expect_value(t, lines[1].doc, "List items")
  testing.expect_value(t, lines[2].syntax, "show|get <item-id>")
  testing.expect_value(t, lines[2].doc, "Show one item")
  testing.expect_value(t, lines[3].syntax, "audit <item-id>")
  testing.expect_value(t, lines[3].doc, "Documented future command")
}

@(test)
test_help_lines_for_compiled_subcommands_render_token_kinds :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items show|get <item-id>", label = "items.show", shape = "items.show", doc = "Show one item"},
    {path = "items audit", label = "items.audit", shape = "items.audit", doc = "Hidden docs row", help_only = true},
  }
  compiled := compile_cli(specs[:], nil)
  defer destroy_compiled_cli(compiled)

  lines := help_lines_for_compiled_subcommands(compiled, "items")
  defer destroy_help_lines(lines)

  testing.expect_value(t, len(lines), 2)
  testing.expect_value(t, lines[0].syntax, "show|get <item-id>")
  testing.expect_value(t, lines[0].doc, "Show one item")
  testing.expect_value(t, lines[1].syntax, "audit")
  testing.expect_value(t, lines[1].doc, "Hidden docs row")
}

@(test)
test_usage_generation_derives_root_and_command_synopsis_from_decls :: proc(t: ^testing.T) {
  db_names := [?]string{"--db"}
  global_flags := [?]Flag_Decl{
    {names = db_names[:], value_name = "PATH", mode = .Required},
  }
  show_patterns := [?]string{"items show|get <item-id>"}
  format_names := [?]string{"--format", "-f"}
  pretty_names := [?]string{"--pretty"}
  show_flags := [?]Flag_Decl{
    {names = format_names[:], value_name = "text|json", mode = .Required},
    {names = pretty_names[:], mode = .None},
  }
  specs := [?]Command_Decl{
    {patterns = show_patterns[:], id = "items.show", flags = show_flags[:]},
  }

  root_usage := root_usage_for_decls("tool", specs[:], global_flags[:])
  defer delete(root_usage)
  testing.expect_value(t, root_usage, "tool [flags] <command>")

  compiled := compile_cli_decls(specs[:], global_flags[:])
  defer destroy_compiled_cli(compiled)
  command_usage := command_usage_for_id("tool", "items.show", compiled)
  defer delete(command_usage)
  testing.expect_value(t, command_usage, "tool [global-flags] items show|get <item-id> [--format text|json] [--pretty]")
}

@(test)
test_usage_generation_returns_empty_for_unknown_command_id :: proc(t: ^testing.T) {
  patterns := [?]string{"items list"}
  specs := [?]Command_Decl{
    {patterns = patterns[:], id = "items.list"},
  }

  usage := command_usage_for_decl_id("tool", "items.missing", specs[:], nil)
  defer delete(usage)

  testing.expect_value(t, usage, "")
}
