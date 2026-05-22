package cli

import "core:fmt"
import "core:strings"

HELP_SYNTAX_COLUMN_MAX :: 34
HELP_TEXT_WIDTH :: 88

Help_Line :: struct {
  syntax: string,
  doc:    string,
}

Command_Doc :: struct {
  key:      string,
  usage:    string,
  doc:      string,
  aliases:  string,
  examples: string,
}

Root_Spec :: struct {
  name:     string,
  doc:      string,
  usage:    string,
  flags:    []Help_Line,
  surfaces: []Help_Line,
  commands: []Help_Line,
  examples: string,
  footer:   string,
}

command_doc_for_key :: proc(docs: []Command_Doc, key: string) -> (Command_Doc, bool) {
  for doc in docs {
    if doc.key == key do return doc, true
  }
  return Command_Doc{}, false
}

help_lines_for_flags :: proc(flags: []Flag_Spec) -> [dynamic]Help_Line {
  compiled := compile_flag_specs(flags)
  defer destroy_compiled_flags(compiled)
  return help_lines_for_compiled_flags(compiled[:])
}

help_lines_for_flag_decls :: proc(flags: []Flag_Decl) -> [dynamic]Help_Line {
  compiled := compile_flag_decls(flags)
  defer destroy_compiled_flags(compiled)
  return help_lines_for_compiled_flags(compiled[:])
}

help_lines_for_compiled_flags :: proc(flags: []Compiled_Flag) -> [dynamic]Help_Line {
  lines := make([dynamic]Help_Line)
  for flag in flags {
    if strings.trim_space(flag.doc) == "" do continue
    append(&lines, Help_Line{
      syntax = compiled_flag_help_syntax(flag),
      doc = strings.clone(flag.doc),
    })
  }
  return lines
}

help_lines_for_command_specs :: proc(specs: []Command_Spec) -> [dynamic]Help_Line {
  compiled := compile_cli(specs, nil)
  defer destroy_compiled_cli(compiled)
  return help_lines_for_compiled_commands(compiled)
}

help_lines_for_command_decls :: proc(specs: []Command_Decl) -> [dynamic]Help_Line {
  compiled := compile_cli_decls(specs, nil)
  defer destroy_compiled_cli(compiled)
  return help_lines_for_compiled_commands(compiled)
}

help_lines_for_compiled_commands :: proc(compiled: Compiled_CLI) -> [dynamic]Help_Line {
  lines := make([dynamic]Help_Line)
  for command in compiled.commands {
    if strings.trim_space(command.doc) == "" do continue
    append(&lines, Help_Line{
      syntax = compiled_command_help_syntax(command),
      doc = strings.clone(command.doc),
    })
  }
  return lines
}

help_lines_for_subcommands :: proc(specs: []Command_Spec, prefix: string) -> [dynamic]Help_Line {
  compiled := compile_cli(specs, nil)
  defer destroy_compiled_cli(compiled)
  return help_lines_for_compiled_subcommands(compiled, prefix)
}

help_lines_for_subcommand_decls :: proc(specs: []Command_Decl, prefix: string) -> [dynamic]Help_Line {
  compiled := compile_cli_decls(specs, nil)
  defer destroy_compiled_cli(compiled)
  return help_lines_for_compiled_subcommands(compiled, prefix)
}

help_lines_for_compiled_subcommands :: proc(compiled: Compiled_CLI, prefix: string) -> [dynamic]Help_Line {
  lines := make([dynamic]Help_Line)
  prefix_tokens := strings.fields(prefix)
  defer delete(prefix_tokens)
  for command in compiled.commands {
    if strings.trim_space(command.doc) == "" do continue
    if len(command.patterns) == 0 do continue
    pattern := command.patterns[0]
    if !compiled_tokens_have_literal_prefix(pattern.tokens[:], prefix_tokens) do continue
    if len(pattern.tokens) == len(prefix_tokens) {
      if strings.trim_space(command.help) == "" do continue
      append(&lines, Help_Line{
	syntax = compiled_command_help_syntax(command),
	doc = strings.clone(command.doc),
      })
      continue
    }
    if len(pattern.tokens) < len(prefix_tokens) do continue
    syntax := compiled_subcommand_help_syntax(command, pattern, len(prefix_tokens))
    append(&lines, Help_Line{
      syntax = syntax,
      doc = strings.clone(command.doc),
    })
  }
  return lines
}

root_usage_for_compiled :: proc(command_name: string, compiled: Compiled_CLI) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  clean_name := strings.trim_space(command_name)
  if clean_name == "" do clean_name = "app"
  strings.write_string(&builder, clean_name)
  if len(compiled.flags) > 0 {
    strings.write_string(&builder, " [flags]")
  }
  if compiled_has_dispatch_commands(compiled) {
    strings.write_string(&builder, " <command>")
  }
  return strings.clone(strings.to_string(builder))
}

root_usage_for_decls :: proc(command_name: string, commands: []Command_Decl, flags: []Flag_Decl) -> string {
  compiled := compile_cli_decls(commands, flags)
  defer destroy_compiled_cli(compiled)
  return root_usage_for_compiled(command_name, compiled)
}

command_usage_for_compiled :: proc(command_name: string, command: Compiled_Command, global_flags: []Compiled_Flag) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  clean_name := strings.trim_space(command_name)
  if clean_name == "" do clean_name = "app"
  strings.write_string(&builder, clean_name)
  if len(global_flags) > 0 {
    strings.write_string(&builder, " [global-flags]")
  }
  if len(command.patterns) > 0 {
    strings.write_byte(&builder, ' ')
    write_compiled_pattern_syntax(&builder, command.patterns[0])
  }
  write_flag_usage_list(&builder, command.flags[:])
  return strings.clone(strings.to_string(builder))
}

command_usage_for_id :: proc(command_name, id: string, compiled: Compiled_CLI) -> string {
  for command in compiled.commands {
    if command.id == id {
      return command_usage_for_compiled(command_name, command, compiled.flags[:])
    }
  }
  return strings.clone("")
}

compiled_command_for_id :: proc(compiled: Compiled_CLI, id: string) -> (Compiled_Command, bool) {
  for command in compiled.commands {
    if command.id == id do return command, true
  }
  return Compiled_Command{}, false
}

help_lines_for_compiled_command_flags :: proc(compiled: Compiled_CLI, id: string) -> [dynamic]Help_Line {
  command, ok := compiled_command_for_id(compiled, id)
  if !ok do return nil
  return help_lines_for_compiled_flags(command.flags[:])
}

render_compiled_command_help_for_key :: proc(command_name, key, prefix: string, compiled: Compiled_CLI, docs: []Command_Doc) -> string {
  doc, ok := command_doc_for_key(docs, key)
  if !ok do return strings.clone("")

  usage := ""
  if strings.trim_space(doc.usage) == "" {
    usage = command_usage_for_id(command_name, key, compiled)
    defer delete(usage)
    doc.usage = usage
  }

  subcommands := help_lines_for_compiled_subcommands(compiled, prefix)
  defer destroy_help_lines(subcommands)
  flags := help_lines_for_compiled_command_flags(compiled, key)
  defer destroy_help_lines(flags)
  return render_command_help(doc, subcommands[:], flags[:])
}

command_usage_for_decl_id :: proc(command_name, id: string, commands: []Command_Decl, flags: []Flag_Decl) -> string {
  compiled := compile_cli_decls(commands, flags)
  defer destroy_compiled_cli(compiled)
  return command_usage_for_id(command_name, id, compiled)
}

compiled_has_dispatch_commands :: proc(compiled: Compiled_CLI) -> bool {
  for command in compiled.commands {
    if !command.help_only do return true
  }
  return false
}

destroy_help_lines :: proc(lines: [dynamic]Help_Line) {
  for line in lines {
    delete(line.syntax)
    delete(line.doc)
  }
  delete(lines)
}

command_help_syntax :: proc(spec: Command_Spec) -> string {
  if strings.trim_space(spec.help) != "" {
    return strings.clone(spec.help)
  }
  fields := strings.fields(spec.path)
  defer delete(fields)
  if len(fields) == 0 {
    return strings.clone(spec.path)
  }
  return strings.clone(fields[0])
}

subcommand_help_syntax :: proc(spec: Command_Spec, relative_tokens: []string) -> string {
  if strings.trim_space(spec.help) != "" {
    return strings.clone(spec.help)
  }
  return strings.join(relative_tokens, " ")
}

compiled_command_help_syntax :: proc(command: Compiled_Command) -> string {
  if strings.trim_space(command.help) != "" {
    return strings.clone(command.help)
  }
  if len(command.patterns) == 0 {
    return strings.clone("")
  }
  if len(command.patterns[0].tokens) == 0 {
    return strings.clone(command.patterns[0].source)
  }
  return compiled_token_syntax(command.patterns[0].tokens[0])
}

compiled_subcommand_help_syntax :: proc(command: Compiled_Command, pattern: Command_Pattern, start: int) -> string {
  if strings.trim_space(command.help) != "" {
    return strings.clone(command.help)
  }
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for token, i in pattern.tokens[start:] {
    if i > 0 do strings.write_byte(&builder, ' ')
    text := compiled_token_syntax(token)
    strings.write_string(&builder, text)
    delete(text)
  }
  return strings.clone(strings.to_string(builder))
}

write_compiled_pattern_syntax :: proc(builder: ^strings.Builder, pattern: Command_Pattern) {
  for token, i in pattern.tokens {
    if i > 0 do strings.write_byte(builder, ' ')
    write_compiled_token_syntax(builder, token)
  }
}

compiled_token_syntax :: proc(token: Command_Token) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  write_compiled_token_syntax(&builder, token)
  return strings.clone(strings.to_string(builder))
}

write_compiled_token_syntax :: proc(builder: ^strings.Builder, token: Command_Token) {
  switch token.kind {
  case .Literal:
    strings.write_string(builder, token.text)
  case .Positional:
    fmt.sbprintf(builder, "<%s>", token.text)
  case .Variadic_Positional:
    fmt.sbprintf(builder, "<%s...>", token.text)
  case .One_Of:
    for choice, i in token.choices {
      if i > 0 do strings.write_byte(builder, '|')
      strings.write_string(builder, choice)
    }
  }
}

write_flag_usage_list :: proc(builder: ^strings.Builder, flags: []Compiled_Flag) {
  for flag in flags {
    strings.write_byte(builder, ' ')
    strings.write_byte(builder, '[')
    write_flag_usage(builder, flag)
    strings.write_byte(builder, ']')
  }
}

write_flag_usage :: proc(builder: ^strings.Builder, flag: Compiled_Flag) {
  name := flag.name
  if name == "" && len(flag.names) > 0 {
    name = flag.names[0]
  }
  strings.write_string(builder, name)
  if flag.mode == .Required || flag.mode == .Optional {
    value := compiled_flag_display_value_name(flag)
    defer delete(value)
    strings.write_byte(builder, ' ')
    if flag.mode == .Optional do strings.write_byte(builder, '[')
    strings.write_string(builder, value)
    if flag.mode == .Optional do strings.write_byte(builder, ']')
  }
}

tokens_have_prefix :: proc(tokens, prefix: []string) -> bool {
  if len(tokens) < len(prefix) do return false
  for part, i in prefix {
    if tokens[i] != part do return false
  }
  return true
}

compiled_flag_help_syntax :: proc(flag: Compiled_Flag) -> string {
  if strings.trim_space(flag.help) != "" {
    return strings.clone(flag.help)
  }
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for name, i in flag.names {
    if i > 0 do strings.write_string(&builder, " | ")
    value_name := compiled_flag_display_value_name(flag)
    append_flag_name_for_help(&builder, name, value_name, flag.mode)
    delete(value_name)
  }
  return strings.clone(strings.to_string(builder))
}

append_flag_name_for_help :: proc(builder: ^strings.Builder, name, value_name: string, mode: Flag_Value_Mode) {
  strings.write_string(builder, name)
  if mode == .Required || mode == .Optional {
    value := strings.trim_space(value_name)
    if value == "" do value = "VALUE"
    strings.write_byte(builder, ' ')
    if mode == .Optional do strings.write_byte(builder, '[')
    strings.write_string(builder, value)
    if mode == .Optional do strings.write_byte(builder, ']')
  }
}

compiled_flag_display_value_name :: proc(flag: Compiled_Flag) -> string {
  value := strings.trim_space(flag.value_name)
  if value != "" do return strings.clone(value)
  if len(flag.choices) > 0 do return join_display_choices(flag.choices[:])
  return strings.clone("VALUE")
}

join_display_choices :: proc(choices: []string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for choice, i in choices {
    if i > 0 do strings.write_byte(&builder, '|')
    strings.write_string(&builder, choice)
  }
  return strings.clone(strings.to_string(builder))
}

render_root_help :: proc(spec: Root_Spec) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)

  strings.write_string(&builder, "NAME\n")
  fmt.sbprintf(&builder, "  %s - %s\n\n", spec.name, spec.doc)
  strings.write_string(&builder, "SYNOPSIS\n")
  fmt.sbprintf(&builder, "  %s\n\n", spec.usage)
  append_help_lines(&builder, "FLAGS", spec.flags)
  append_help_lines(&builder, "SURFACES", spec.surfaces)
  append_help_lines(&builder, "COMMANDS", spec.commands)
  append_examples(&builder, spec.examples)
  if strings.trim_space(spec.footer) != "" {
    strings.write_string(&builder, spec.footer)
    if !strings.has_suffix(spec.footer, "\n") {
      strings.write_byte(&builder, '\n')
    }
  }
  return strings.clone(strings.to_string(builder))
}

render_command_help :: proc(doc: Command_Doc, subcommands, flags: []Help_Line) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)

  strings.write_string(&builder, "NAME\n")
  fmt.sbprintf(&builder, "  %s - %s\n\n", doc.key, doc.doc)
  strings.write_string(&builder, "SYNOPSIS\n")
  fmt.sbprintf(&builder, "  %s\n\n", doc.usage)
  append_help_lines(&builder, "SUBCOMMANDS", subcommands)
  append_help_lines(&builder, "FLAGS", flags)
  if strings.trim_space(doc.aliases) != "" {
    strings.write_string(&builder, "ALIASES\n")
    fmt.sbprintf(&builder, "  %s\n\n", doc.aliases)
  }
  append_examples(&builder, doc.examples)
  return strings.clone(strings.to_string(builder))
}

append_help_lines :: proc(builder: ^strings.Builder, title: string, lines: []Help_Line) {
  if len(lines) == 0 do return
  fmt.sbprintf(builder, "%s\n", title)

  width := 0
  for line in lines {
    if len(line.syntax) > width do width = len(line.syntax)
  }
  if width > HELP_SYNTAX_COLUMN_MAX do width = HELP_SYNTAX_COLUMN_MAX

  for line in lines {
    if len(line.syntax) > width {
      fmt.sbprintf(builder, "  %s\n", line.syntax)
      write_indent(builder, 4)
      write_wrapped_help_text(builder, 4, 4, line.doc)
      continue
    }

    padded := pad_right(line.syntax, width)
    fmt.sbprintf(builder, "  %s  ", padded)
    delete(padded)
    write_wrapped_help_text(builder, 2 + width + 2, 2 + width + 2, line.doc)
  }
  strings.write_byte(builder, '\n')
}

write_wrapped_help_text :: proc(builder: ^strings.Builder, column, continuation_indent: int, text: string) {
  clean := strings.trim_space(text)
  if clean == "" {
    strings.write_byte(builder, '\n')
    return
  }

  i := 0
  col := column
  first_on_line := true

  for i < len(clean) {
    for i < len(clean) && is_help_space(clean[i]) {
      i += 1
    }
    if i >= len(clean) do break

    start := i
    for i < len(clean) && !is_help_space(clean[i]) {
      i += 1
    }
    word := clean[start:i]
    separator_width := 0
    if !first_on_line do separator_width = 1

    if !first_on_line && col + separator_width + len(word) > HELP_TEXT_WIDTH {
      strings.write_byte(builder, '\n')
      write_indent(builder, continuation_indent)
      col = continuation_indent
      first_on_line = true
      separator_width = 0
    }

    if !first_on_line {
      strings.write_byte(builder, ' ')
      col += 1
    }
    strings.write_string(builder, word)
    col += len(word)
    first_on_line = false
  }

  strings.write_byte(builder, '\n')
}

write_indent :: proc(builder: ^strings.Builder, count: int) {
  for i := 0; i < count; i += 1 {
    strings.write_byte(builder, ' ')
  }
}

is_help_space :: proc(value: u8) -> bool {
  return value == ' ' || value == '\t' || value == '\n' || value == '\r'
}

append_examples :: proc(builder: ^strings.Builder, examples: string) {
  if strings.trim_space(examples) == "" do return
  strings.write_string(builder, "EXAMPLES\n")
  start := 0
  for i := 0; i <= len(examples); i += 1 {
    if i == len(examples) || examples[i] == '\n' {
      if i > start {
	fmt.sbprintf(builder, "  %s\n", examples[start:i])
      }
      start = i + 1
    }
  }
  strings.write_byte(builder, '\n')
}

pad_right :: proc(value: string, width: int) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  strings.write_string(&builder, value)
  for i := len(value); i < width; i += 1 {
    strings.write_byte(&builder, ' ')
  }
  return strings.clone(strings.to_string(builder))
}
