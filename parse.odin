package cli

import "core:fmt"
import "core:strconv"
import "core:strings"

Command_Spec :: struct {
  path:                string,
  aliases:             string,
  label:               string,
  shape:               string,
  doc:                 string,
  help:                string,
  flags:               []Flag_Spec,
  help_only:           bool,
  allow_unknown_flags: bool,
}

Command_Decl :: struct {
  patterns:            []string,
  id:                  string,
  label:               string,
  shape:               string,
  doc:                 string,
  help:                string,
  flags:               []Flag_Decl,
  help_only:           bool,
  allow_unknown_flags: bool,
}

Command_Token_Kind :: enum {
  Literal,
  Positional,
  Variadic_Positional,
  One_Of,
}

Command_Token :: struct {
  kind:    Command_Token_Kind,
  text:    string,
  choices: [dynamic]string,
}

Command_Pattern :: struct {
  source: string,
  tokens: [dynamic]Command_Token,
}

Compiled_Command :: struct {
  spec_index:          int,
  id:                  string,
  label:               string,
  shape:               string,
  doc:                 string,
  help:                string,
  flags:               [dynamic]Compiled_Flag,
  help_only:           bool,
  allow_unknown_flags: bool,
  patterns:            [dynamic]Command_Pattern,
}

Compiled_CLI :: struct {
  commands: [dynamic]Compiled_Command,
  flags:    [dynamic]Compiled_Flag,
}

Flag_Value_Mode :: enum {
  None,
  Required,
  Optional,
}

Flag_Spec :: struct {
  name:       string,
  aliases:    string,
  value_name: string,
  mode:       Flag_Value_Mode,
  choices:    []string,
  doc:        string,
  help:       string,
}

Flag_Decl :: struct {
  names:      []string,
  value_name: string,
  mode:       Flag_Value_Mode,
  choices:    []string,
  doc:        string,
  help:       string,
}

Compiled_Flag :: struct {
  name:       string,
  names:      [dynamic]string,
  value_name: string,
  mode:       Flag_Value_Mode,
  choices:    [dynamic]string,
  doc:        string,
  help:       string,
}

Match_Config :: struct {
  flags: []Flag_Spec,
}

Match_Decl_Config :: struct {
  flags: []Flag_Decl,
}

Flag_Parse_Config :: struct {
  flags:                    []Flag_Spec,
  extra_flags:              []Flag_Spec,
  allow_unknown:            bool,
  stop_at_first_positional: bool,
}

Flag_Decl_Parse_Config :: struct {
  flags:                    []Flag_Decl,
  extra_flags:              []Flag_Decl,
  allow_unknown:            bool,
  stop_at_first_positional: bool,
}

Parsed_Flag :: struct {
  name:      string,
  value:     string,
  has_value: bool,
}

Flag_Parse_Result :: struct {
  ok:          bool,
  error:       string,
  flags:       [dynamic]Parsed_Flag,
  rest:        [dynamic]string,
  passthrough: [dynamic]string,
}

Command_Parse_Config :: struct {
  commands:            []Command_Spec,
  flags:               []Flag_Spec,
  allow_unknown_flags: bool,
}

Command_Decl_Parse_Config :: struct {
  commands:            []Command_Decl,
  flags:               []Flag_Decl,
  allow_unknown_flags: bool,
}

Command_Parse_Result :: struct {
  ok:          bool,
  error:       string,
  match:       Match_Result,
  flags:       [dynamic]Parsed_Flag,
  rest:        [dynamic]string,
  passthrough: [dynamic]string,
}

Compiled_Command_Parse_Config :: struct {
  allow_unknown_flags: bool,
}

Compiled_Flag_Parse_Config :: struct {
  flags:                    []Compiled_Flag,
  extra_flags:              []Compiled_Flag,
  allow_unknown:            bool,
  stop_at_first_positional: bool,
}

destroy_flag_parse_result :: proc(result: Flag_Parse_Result) {
  if len(result.error) > 0 {
    delete(result.error)
  }
  destroy_parsed_flags(result.flags)
  destroy_string_words(result.rest)
  destroy_string_words(result.passthrough)
}

compile_cli :: proc(commands: []Command_Spec, flags: []Flag_Spec) -> Compiled_CLI {
  compiled := Compiled_CLI{flags = compile_flag_specs(flags)}
  compiled.commands = make([dynamic]Compiled_Command)
  for spec, spec_idx in commands {
    command := Compiled_Command{
      spec_index = spec_idx,
      id = coalesce_command_id(spec.label, spec.shape),
      label = spec.label,
      shape = spec.shape,
      doc = spec.doc,
      help = spec.help,
      flags = compile_flag_specs(spec.flags),
      help_only = spec.help_only,
      allow_unknown_flags = spec.allow_unknown_flags,
    }
    command.patterns = make([dynamic]Command_Pattern)
    append_compiled_pattern(&command.patterns, spec.path)
    if strings.trim_space(spec.aliases) != "" {
      aliases := strings.split(spec.aliases, "|")
      defer delete(aliases)
      for alias in aliases {
	append_compiled_pattern(&command.patterns, alias)
      }
    }
    append(&compiled.commands, command)
  }
  return compiled
}

compile_cli_decls :: proc(commands: []Command_Decl, flags: []Flag_Decl) -> Compiled_CLI {
  compiled := Compiled_CLI{flags = compile_flag_decls(flags)}
  compiled.commands = make([dynamic]Compiled_Command)
  for spec, spec_idx in commands {
    command := Compiled_Command{
      spec_index = spec_idx,
      id = coalesce_command_id(spec.id, coalesce_command_id(spec.shape, spec.label)),
      label = coalesce_command_id(spec.label, spec.id),
      shape = coalesce_command_id(spec.shape, spec.id),
      doc = spec.doc,
      help = spec.help,
      flags = compile_flag_decls(spec.flags),
      help_only = spec.help_only,
      allow_unknown_flags = spec.allow_unknown_flags,
      patterns = make([dynamic]Command_Pattern),
    }
    for pattern in spec.patterns {
      append_compiled_pattern(&command.patterns, pattern)
    }
    append(&compiled.commands, command)
  }
  return compiled
}

destroy_compiled_cli :: proc(compiled: Compiled_CLI) {
  for command in compiled.commands {
    for pattern in command.patterns {
      delete(pattern.source)
      for token in pattern.tokens {
	delete(token.text)
	destroy_string_words(token.choices)
      }
      delete(pattern.tokens)
    }
    delete(command.patterns)
    destroy_compiled_flags(command.flags)
  }
  delete(compiled.commands)
  destroy_compiled_flags(compiled.flags)
}

destroy_command_parse_result :: proc(result: Command_Parse_Result) {
  if len(result.error) > 0 {
    delete(result.error)
  }
  destroy_match_result(result.match)
  destroy_parsed_flags(result.flags)
  destroy_string_words(result.rest)
  destroy_string_words(result.passthrough)
}

compile_flag_specs :: proc(flags: []Flag_Spec) -> [dynamic]Compiled_Flag {
  compiled := make([dynamic]Compiled_Flag)
  for flag in flags {
    clean_name := strings.trim_space(flag.name)
    if clean_name == "" do continue
    item := Compiled_Flag{
      name = strings.clone(clean_name),
      value_name = strings.clone(flag.value_name),
      mode = flag.mode,
      choices = clone_string_slice(flag.choices),
      doc = strings.clone(flag.doc),
      help = strings.clone(flag.help),
      names = make([dynamic]string),
    }
    append_unique_word(&item.names, clean_name)
    if strings.trim_space(flag.aliases) != "" {
      aliases := strings.split(flag.aliases, "|")
      defer delete(aliases)
      for alias in aliases {
	append_unique_word(&item.names, strings.trim_space(alias))
      }
    }
    append(&compiled, item)
  }
  return compiled
}

compile_flag_decls :: proc(flags: []Flag_Decl) -> [dynamic]Compiled_Flag {
  compiled := make([dynamic]Compiled_Flag)
  for flag in flags {
    name := ""
    for candidate in flag.names {
      clean := strings.trim_space(candidate)
      if clean != "" {
	name = clean
	break
      }
    }
    if name == "" do continue
    item := Compiled_Flag{
      name = strings.clone(name),
      value_name = strings.clone(flag.value_name),
      mode = flag.mode,
      choices = clone_string_slice(flag.choices),
      doc = strings.clone(flag.doc),
      help = strings.clone(flag.help),
      names = make([dynamic]string),
    }
    for candidate in flag.names {
      append_unique_word(&item.names, strings.trim_space(candidate))
    }
    append(&compiled, item)
  }
  return compiled
}

destroy_compiled_flags :: proc(flags: [dynamic]Compiled_Flag) {
  for flag in flags {
    delete(flag.name)
    delete(flag.value_name)
    delete(flag.doc)
    delete(flag.help)
    destroy_string_words(flag.choices)
    destroy_string_words(flag.names)
  }
  delete(flags)
}

combine_flag_decls :: proc(groups: ..[]Flag_Decl) -> [dynamic]Flag_Decl {
  flags := make([dynamic]Flag_Decl)
  append_flag_decls(&flags, ..groups)
  return flags
}

append_flag_decls :: proc(flags: ^[dynamic]Flag_Decl, groups: ..[]Flag_Decl) {
  for group in groups {
    for flag in group {
      append(flags, flag)
    }
  }
}

destroy_flag_decl_list :: proc(flags: [dynamic]Flag_Decl) {
  delete(flags)
}

combine_flag_specs :: proc(groups: ..[]Flag_Spec) -> [dynamic]Flag_Spec {
  flags := make([dynamic]Flag_Spec)
  append_flag_specs(&flags, ..groups)
  return flags
}

append_flag_specs :: proc(flags: ^[dynamic]Flag_Spec, groups: ..[]Flag_Spec) {
  for group in groups {
    for flag in group {
      append(flags, flag)
    }
  }
}

destroy_flag_spec_list :: proc(flags: [dynamic]Flag_Spec) {
  delete(flags)
}

has_any_prefix :: proc(value: string, prefixes: []string) -> bool {
  for prefix in prefixes {
    if strings.has_prefix(value, prefix) do return true
  }
  return false
}

top_level_words :: proc(specs: []Command_Spec, extra_words: []string) -> string {
  words := top_level_word_list(specs, extra_words)
  defer destroy_string_words(words)
  return join_words(words[:])
}

top_level_words_for_decls :: proc(specs: []Command_Decl, extra_words: []string) -> string {
  compiled := compile_cli_decls(specs, nil)
  defer destroy_compiled_cli(compiled)
  return top_level_words_for_compiled(compiled, extra_words)
}

top_level_words_for_compiled :: proc(compiled: Compiled_CLI, extra_words: []string) -> string {
  words := top_level_word_list_for_compiled(compiled, extra_words)
  defer destroy_string_words(words)
  return join_words(words[:])
}

join_words :: proc(words: []string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for word, i in words {
    if i > 0 do strings.write_byte(&builder, ' ')
    strings.write_string(&builder, word)
  }
  return strings.clone(strings.to_string(builder))
}

top_level_word_list :: proc(specs: []Command_Spec, extra_words: []string) -> [dynamic]string {
  compiled := compile_cli(specs, nil)
  defer destroy_compiled_cli(compiled)
  return top_level_word_list_for_compiled(compiled, extra_words)
}

top_level_word_list_for_decls :: proc(specs: []Command_Decl, extra_words: []string) -> [dynamic]string {
  compiled := compile_cli_decls(specs, nil)
  defer destroy_compiled_cli(compiled)
  return top_level_word_list_for_compiled(compiled, extra_words)
}

top_level_word_list_for_compiled :: proc(compiled: Compiled_CLI, extra_words: []string) -> [dynamic]string {
  return completion_word_list_for_compiled_prefix(compiled, "", extra_words)
}

destroy_string_list :: proc(words: [dynamic]string) {
  destroy_string_words(words)
}

suggest_top_level_word :: proc(specs: []Command_Spec, extra_words: []string, input: string) -> string {
  words := top_level_word_list(specs, extra_words)
  defer destroy_string_words(words)
  return suggest_word(words[:], input)
}

suggest_top_level_word_for_decls :: proc(specs: []Command_Decl, extra_words: []string, input: string) -> string {
  words := top_level_word_list_for_decls(specs, extra_words)
  defer destroy_string_words(words)
  return suggest_word(words[:], input)
}

suggest_top_level_word_for_compiled :: proc(compiled: Compiled_CLI, extra_words: []string, input: string) -> string {
  words := top_level_word_list_for_compiled(compiled, extra_words)
  defer destroy_string_words(words)
  return suggest_word(words[:], input)
}

suggest_word :: proc(words: []string, input: string) -> string {
  clean := strings.to_lower(strings.trim_space(input))
  defer delete(clean)
  if clean == "" do return strings.clone("")

  best_word := ""
  best_distance := 1 << 30
  for word in words {
    candidate := strings.to_lower(strings.trim_space(word))
    defer delete(candidate)
    if candidate == "" do continue
    if candidate == clean do return strings.clone(word)
    distance := edit_distance(clean, candidate)
    if distance < best_distance {
      best_distance = distance
      best_word = word
    }
  }
  if best_word == "" do return strings.clone("")
  if best_distance <= suggestion_threshold(len(clean)) {
    return strings.clone(best_word)
  }
  return strings.clone("")
}

suggestion_threshold :: proc(input_len: int) -> int {
  if input_len <= 4 do return 1
  if input_len <= 8 do return 2
  return 3
}

edit_distance :: proc(a, b: string) -> int {
  if len(a) == 0 do return len(b)
  if len(b) == 0 do return len(a)

  prev := make([]int, len(b) + 1)
  defer delete(prev)
  curr := make([]int, len(b) + 1)
  defer delete(curr)

  for j := 0; j <= len(b); j += 1 {
    prev[j] = j
  }

  for i := 1; i <= len(a); i += 1 {
    curr[0] = i
    for j := 1; j <= len(b); j += 1 {
      cost := 0
      if a[i - 1] != b[j - 1] do cost = 1
      curr[j] = min_int(
	curr[j - 1] + 1,
	prev[j] + 1,
	prev[j - 1] + cost,
      )
    }
    for j := 0; j <= len(b); j += 1 {
      prev[j] = curr[j]
    }
  }
  return prev[len(b)]
}

min_int :: proc(values: ..int) -> int {
  if len(values) == 0 do return 0
  best := values[0]
  for value in values[1:] {
    if value < best do best = value
  }
  return best
}

parse_flags :: proc(args: []string, flags: []Flag_Spec) -> Flag_Parse_Result {
  return parse_flags_with_config(args, Flag_Parse_Config{flags = flags})
}

parse_flag_decls :: proc(args: []string, flags: []Flag_Decl) -> Flag_Parse_Result {
  return parse_flag_decls_with_config(args, Flag_Decl_Parse_Config{flags = flags})
}

parse_flag_decls_with_config :: proc(args: []string, config: Flag_Decl_Parse_Config) -> Flag_Parse_Result {
  compiled_flags := compile_flag_decls(config.flags)
  defer destroy_compiled_flags(compiled_flags)
  compiled_extra_flags := compile_flag_decls(config.extra_flags)
  defer destroy_compiled_flags(compiled_extra_flags)
  return parse_compiled_flags_with_config(args, Compiled_Flag_Parse_Config{
    flags = compiled_flags[:],
    extra_flags = compiled_extra_flags[:],
    allow_unknown = config.allow_unknown,
    stop_at_first_positional = config.stop_at_first_positional,
  })
}

parse_command :: proc(args: []string, commands: []Command_Spec, flags: []Flag_Spec) -> Command_Parse_Result {
  return parse_command_with_config(args, Command_Parse_Config{
    commands = commands,
    flags = flags,
  })
}

parse_command_decls :: proc(args: []string, commands: []Command_Decl, flags: []Flag_Decl) -> Command_Parse_Result {
  return parse_command_decls_with_config(args, Command_Decl_Parse_Config{
    commands = commands,
    flags = flags,
  })
}

parse_command_with_config :: proc(args: []string, config: Command_Parse_Config) -> Command_Parse_Result {
  compiled := compile_cli(config.commands, config.flags)
  defer destroy_compiled_cli(compiled)
  return parse_compiled_command_with_config(args, compiled, Compiled_Command_Parse_Config{
    allow_unknown_flags = config.allow_unknown_flags,
  })
}

parse_command_decls_with_config :: proc(args: []string, config: Command_Decl_Parse_Config) -> Command_Parse_Result {
  compiled := compile_cli_decls(config.commands, config.flags)
  defer destroy_compiled_cli(compiled)
  return parse_compiled_command_with_config(args, compiled, Compiled_Command_Parse_Config{
    allow_unknown_flags = config.allow_unknown_flags,
  })
}

parse_compiled_command :: proc(args: []string, compiled: Compiled_CLI) -> Command_Parse_Result {
  return parse_compiled_command_with_config(args, compiled, Compiled_Command_Parse_Config{})
}

parse_compiled_command_with_config :: proc(args: []string, compiled: Compiled_CLI, config: Compiled_Command_Parse_Config) -> Command_Parse_Result {
  global_flags := parse_compiled_flags_with_config(args, Compiled_Flag_Parse_Config{
    flags = compiled.flags[:],
    allow_unknown = true,
  })
  if !global_flags.ok {
    result := Command_Parse_Result{
      ok = false,
      error = strings.clone(global_flags.error),
    }
    destroy_flag_parse_result(global_flags)
    return result
  }

  match := match_compiled_command(compiled, args)
  if !match.ok {
    result := Command_Parse_Result{
      ok = false,
      match = match,
      error = command_parse_match_error(global_flags.rest[:]),
    }
    destroy_flag_parse_result(global_flags)
    return result
  }
  destroy_flag_parse_result(global_flags)

  flag_result := parse_compiled_flags_with_config(args, Compiled_Flag_Parse_Config{
    flags = compiled.flags[:],
    extra_flags = compiled_command_flags(compiled, match.spec_index),
    allow_unknown = config.allow_unknown_flags || compiled_command_allows_unknown_flags(compiled, match.spec_index),
  })
  if !flag_result.ok {
    result := Command_Parse_Result{
      ok = false,
      match = match,
      error = strings.clone(flag_result.error),
    }
    destroy_flag_parse_result(flag_result)
    return result
  }

  result := Command_Parse_Result{
    ok = true,
    match = match,
    flags = flag_result.flags,
    rest = flag_result.rest,
    passthrough = flag_result.passthrough,
  }
  return result
}

parse_compiled_flags_with_config :: proc(args: []string, config: Compiled_Flag_Parse_Config) -> Flag_Parse_Result {
  result := Flag_Parse_Result{ok = true}
  result.flags = make([dynamic]Parsed_Flag)
  result.rest = make([dynamic]string)
  result.passthrough = make([dynamic]string)

  i := 0
  for i < len(args) {
    arg := args[i]
    if arg == "--" {
      append_remaining_args(&result.passthrough, args[i + 1:])
      return result
    }
    if !is_option(arg) {
      if config.stop_at_first_positional {
	append_remaining_args(&result.rest, args[i:])
	return result
      }
      append(&result.rest, strings.clone(arg))
      i += 1
      continue
    }

    name := option_name(arg)
    flag, found := compiled_flag_for_name_in(config.flags, config.extra_flags, name)
    if !found {
      if config.allow_unknown {
	append(&result.rest, strings.clone(arg))
	i += 1
	continue
      }
      result.ok = false
      result.error = strings.clone(fmt.tprintf("unknown flag: %s", name))
      return result
    }

    value := ""
    has_value := false
    if eq_idx := strings.index(arg, "="); eq_idx >= 0 {
      value = arg[eq_idx + 1:]
      has_value = true
    }

    switch flag.mode {
    case .Required:
      if !has_value {
	if i + 1 >= len(args) {
	  result.ok = false
	  result.error = strings.clone(fmt.tprintf("missing value for %s", flag.name))
	  return result
	}
	i += 1
	value = args[i]
	has_value = true
      }
    case .Optional:
      if !has_value && i + 1 < len(args) && !is_option(args[i + 1]) {
	i += 1
	value = args[i]
	has_value = true
      }
    case .None:
      if has_value {
	result.ok = false
	result.error = strings.clone(fmt.tprintf("flag does not take a value: %s", flag.name))
	return result
      }
    }

    if has_value && len(flag.choices) > 0 && !compiled_flag_value_allowed(flag, value) {
      choices := join_choice_values(flag.choices[:])
      defer delete(choices)
      result.ok = false
      result.error = strings.clone(fmt.tprintf("%s must be one of: %s", flag.name, choices))
      return result
    }

    append(&result.flags, Parsed_Flag{
      name = strings.clone(flag.name),
      value = strings.clone(value),
      has_value = has_value,
    })
    i += 1
  }
  return result
}

parse_flags_with_config :: proc(args: []string, config: Flag_Parse_Config) -> Flag_Parse_Result {
  compiled_flags := compile_flag_specs(config.flags)
  defer destroy_compiled_flags(compiled_flags)
  compiled_extra_flags := compile_flag_specs(config.extra_flags)
  defer destroy_compiled_flags(compiled_extra_flags)
  return parse_compiled_flags_with_config(args, Compiled_Flag_Parse_Config{
    flags = compiled_flags[:],
    extra_flags = compiled_extra_flags[:],
    allow_unknown = config.allow_unknown,
    stop_at_first_positional = config.stop_at_first_positional,
  })
}

flag_spec_for_name :: proc(flags: []Flag_Spec, name: string) -> (Flag_Spec, bool) {
  for flag in flags {
    if flag_name_matches(flag, name) do return flag, true
  }
  return Flag_Spec{}, false
}

compiled_flag_for_name :: proc(flags: []Compiled_Flag, name: string) -> (Compiled_Flag, bool) {
  for flag in flags {
    if compiled_flag_name_matches(flag, name) do return flag, true
  }
  return Compiled_Flag{}, false
}

compiled_flag_for_name_in :: proc(flags, extra_flags: []Compiled_Flag, name: string) -> (Compiled_Flag, bool) {
  if flag, ok := compiled_flag_for_name(flags, name); ok {
    return flag, true
  }
  return compiled_flag_for_name(extra_flags, name)
}

parsed_flag_present :: proc(result: Flag_Parse_Result, name: string) -> bool {
  for flag in result.flags {
    if flag.name == name do return true
  }
  return false
}

parsed_flag_value :: proc(result: Flag_Parse_Result, name: string) -> (string, bool) {
  for flag in result.flags {
    if flag.name == name && flag.has_value {
      return strings.clone(flag.value), true
    }
  }
  return strings.clone(""), false
}

parsed_flag_values :: proc(result: Flag_Parse_Result, name: string) -> [dynamic]string {
  return parsed_flag_values_from_flags(result.flags[:], name)
}

parsed_flag_value_or :: proc(result: Flag_Parse_Result, name, default_value: string) -> string {
  value, ok := parsed_flag_value(result, name)
  if ok do return value
  delete(value)
  return strings.clone(default_value)
}

parsed_flag_int_value_or :: proc(result: Flag_Parse_Result, name: string, default_value: int) -> int {
  value, ok := parsed_flag_value(result, name)
  defer delete(value)
  if !ok do return default_value
  parsed, parsed_ok := strconv.parse_int(value, 10)
  if !parsed_ok do return default_value
  return parsed
}

parsed_command_flag_present :: proc(result: Command_Parse_Result, name: string) -> bool {
  for flag in result.flags {
    if flag.name == name do return true
  }
  return false
}

parsed_command_flag_value :: proc(result: Command_Parse_Result, name: string) -> (string, bool) {
  for flag in result.flags {
    if flag.name == name && flag.has_value {
      return strings.clone(flag.value), true
    }
  }
  return strings.clone(""), false
}

parsed_command_flag_values :: proc(result: Command_Parse_Result, name: string) -> [dynamic]string {
  return parsed_flag_values_from_flags(result.flags[:], name)
}

parsed_command_flag_value_or :: proc(result: Command_Parse_Result, name, default_value: string) -> string {
  value, ok := parsed_command_flag_value(result, name)
  if ok do return value
  delete(value)
  return strings.clone(default_value)
}

parsed_command_flag_int_value_or :: proc(result: Command_Parse_Result, name: string, default_value: int) -> int {
  value, ok := parsed_command_flag_value(result, name)
  defer delete(value)
  if !ok do return default_value
  parsed, parsed_ok := strconv.parse_int(value, 10)
  if !parsed_ok do return default_value
  return parsed
}

parsed_flag_values_from_flags :: proc(flags: []Parsed_Flag, name: string) -> [dynamic]string {
  values := make([dynamic]string)
  for flag in flags {
    if flag.name == name && flag.has_value {
      append(&values, strings.clone(flag.value))
    }
  }
  return values
}

command_parse_match_error :: proc(rest: []string) -> string {
  if len(rest) == 0 {
    return strings.clone("missing command")
  }
  return strings.clone(fmt.tprintf("unknown command: %s", rest[0]))
}

destroy_parsed_flags :: proc(flags: [dynamic]Parsed_Flag) {
  for flag in flags {
    delete(flag.name)
    delete(flag.value)
  }
  delete(flags)
}

append_remaining_args :: proc(rest: ^[dynamic]string, args: []string) {
  for arg in args {
    append(rest, strings.clone(arg))
  }
}

split_passthrough_args :: proc(args: []string) -> ([]string, []string) {
  for arg, i in args {
    if arg == "--" {
      return args[:i], args[i + 1:]
    }
  }
  return args, nil
}

option_name :: proc(arg: string) -> string {
  if idx := strings.index(arg, "="); idx >= 0 {
    return arg[:idx]
  }
  return arg
}

append_top_level_word :: proc(words: ^[dynamic]string, pattern: string) {
  fields := strings.fields(pattern)
  defer delete(fields)
  if len(fields) == 0 do return
  append_unique_word(words, fields[0])
}

append_unique_word :: proc(words: ^[dynamic]string, word: string) {
  if word == "" do return
  for existing in words^ {
    if existing == word do return
  }
  append(words, strings.clone(word))
}

clone_string_slice :: proc(words: []string) -> [dynamic]string {
  cloned := make([dynamic]string)
  for word in words {
    append(&cloned, strings.clone(word))
  }
  return cloned
}

destroy_string_words :: proc(words: [dynamic]string) {
  for word in words {
    delete(word)
  }
  delete(words)
}

Named_Value :: struct {
  name:  string,
  value: string,
}

Match_Result :: struct {
  ok:            bool,
  spec_index:    int,
  id:            string,
  path:          string,
  label:         string,
  shape:         string,
  args_consumed: int,
  positionals:   [dynamic]Named_Value,
}

destroy_match_result :: proc(result: Match_Result) {
  delete(result.id)
  delete(result.path)
  delete(result.label)
  delete(result.shape)
  for value in result.positionals {
    delete(value.name)
    delete(value.value)
  }
  delete(result.positionals)
}

match_command :: proc(specs: []Command_Spec, args: []string) -> Match_Result {
  return match_command_with_config(specs, args, Match_Config{})
}

match_command_decls :: proc(specs: []Command_Decl, args: []string) -> Match_Result {
  return match_command_decls_with_config(specs, args, Match_Decl_Config{})
}

match_command_with_flags :: proc(specs: []Command_Spec, args: []string, flags: []Flag_Spec) -> Match_Result {
  return match_command_with_config(specs, args, Match_Config{flags = flags})
}

match_command_with_flag_decls :: proc(specs: []Command_Spec, args: []string, flags: []Flag_Decl) -> Match_Result {
  compiled := compile_cli(specs, nil)
  defer destroy_compiled_cli(compiled)
  compiled_flags := compile_flag_decls(flags)
  defer destroy_compiled_flags(compiled_flags)
  return match_compiled_command_with_extra_flags(compiled, args, compiled_flags[:])
}

match_command_decls_with_flags :: proc(specs: []Command_Decl, args: []string, flags: []Flag_Decl) -> Match_Result {
  return match_command_decls_with_config(specs, args, Match_Decl_Config{flags = flags})
}

match_command_with_config :: proc(specs: []Command_Spec, args: []string, config: Match_Config) -> Match_Result {
  compiled := compile_cli(specs, config.flags)
  defer destroy_compiled_cli(compiled)
  return match_compiled_command(compiled, args)
}

match_command_decls_with_config :: proc(specs: []Command_Decl, args: []string, config: Match_Decl_Config) -> Match_Result {
  compiled := compile_cli_decls(specs, config.flags)
  defer destroy_compiled_cli(compiled)
  return match_compiled_command(compiled, args)
}

match_compiled_command :: proc(compiled: Compiled_CLI, args: []string) -> Match_Result {
  best := Match_Result{spec_index = -1}
  best.positionals = make([dynamic]Named_Value)
  for command in compiled.commands {
    if command.help_only do continue
    for pattern in command.patterns {
      if matched, consumed, positionals := match_compiled_pattern(pattern, args, compiled.flags[:], command.flags[:]); matched {
	candidate := match_result_from_compiled(command, pattern.source, consumed, positionals)
	if candidate_is_better(candidate, best) {
	  destroy_match_result(best)
	  best = candidate
	} else {
	  destroy_match_result(candidate)
	}
      } else {
	destroy_named_values(positionals)
      }
    }
  }
  return best
}

match_compiled_command_with_flags :: proc(compiled: Compiled_CLI, args: []string, flags: []Flag_Spec) -> Match_Result {
  compiled_flags := compile_flag_specs(flags)
  defer destroy_compiled_flags(compiled_flags)
  return match_compiled_command_with_extra_flags(compiled, args, compiled_flags[:])
}

match_compiled_command_with_flag_decls :: proc(compiled: Compiled_CLI, args: []string, flags: []Flag_Decl) -> Match_Result {
  compiled_flags := compile_flag_decls(flags)
  defer destroy_compiled_flags(compiled_flags)
  return match_compiled_command_with_extra_flags(compiled, args, compiled_flags[:])
}

match_compiled_command_with_extra_flags :: proc(compiled: Compiled_CLI, args: []string, flags: []Compiled_Flag) -> Match_Result {
  best := Match_Result{spec_index = -1}
  best.positionals = make([dynamic]Named_Value)
  for command in compiled.commands {
    if command.help_only do continue
    for pattern in command.patterns {
      if matched, consumed, positionals := match_compiled_pattern(pattern, args, flags, command.flags[:]); matched {
	candidate := match_result_from_compiled(command, pattern.source, consumed, positionals)
	if candidate_is_better(candidate, best) {
	  destroy_match_result(best)
	  best = candidate
	} else {
	  destroy_match_result(candidate)
	}
      } else {
	destroy_named_values(positionals)
      }
    }
  }
  return best
}

candidate_is_better :: proc(candidate, best: Match_Result) -> bool {
  if !best.ok do return true
  if candidate.args_consumed > best.args_consumed do return true
  return false
}

match_result_from :: proc(spec: Command_Spec, spec_idx: int, path: string, consumed: int, positionals: [dynamic]Named_Value) -> Match_Result {
  id := coalesce_command_id(spec.label, spec.shape)
  return Match_Result{
    ok = true,
    spec_index = spec_idx,
    id = strings.clone(id),
    path = strings.clone(path),
    label = strings.clone(spec.label),
    shape = strings.clone(spec.shape),
    args_consumed = consumed,
    positionals = positionals,
  }
}

match_result_from_compiled :: proc(command: Compiled_Command, path: string, consumed: int, positionals: [dynamic]Named_Value) -> Match_Result {
  label := command.label
  if strings.trim_space(label) == "" do label = command.id
  shape := command.shape
  if strings.trim_space(shape) == "" do shape = command.id
  return Match_Result{
    ok = true,
    spec_index = command.spec_index,
    id = strings.clone(command.id),
    path = strings.clone(path),
    label = strings.clone(label),
    shape = strings.clone(shape),
    args_consumed = consumed,
    positionals = positionals,
  }
}

append_compiled_pattern :: proc(patterns: ^[dynamic]Command_Pattern, pattern: string) {
  clean := strings.trim_space(pattern)
  if clean == "" do return
  tokens := strings.fields(clean)
  defer delete(tokens)
  compiled := Command_Pattern{
    source = strings.clone(clean),
    tokens = make([dynamic]Command_Token),
  }
  for token in tokens {
    append(&compiled.tokens, compile_command_token(token))
  }
  append(patterns, compiled)
}

compile_command_token :: proc(token: string) -> Command_Token {
  clean := strings.trim_space(token)
  if is_placeholder(clean) {
    text := clean[1:len(clean) - 1]
    if strings.has_suffix(text, "...") {
      return Command_Token{
	kind = .Variadic_Positional,
	text = strings.clone(text[:len(text) - 3]),
      }
    }
    return Command_Token{
      kind = .Positional,
      text = strings.clone(text),
    }
  }
  if strings.contains(clean, "|") {
    compiled := Command_Token{
      kind = .One_Of,
      choices = make([dynamic]string),
    }
    parts := strings.split(clean, "|")
    defer delete(parts)
    for part in parts {
      choice := strings.trim_space(part)
      if choice == "" do continue
      append(&compiled.choices, strings.clone(choice))
    }
    return compiled
  }
  return Command_Token{
    kind = .Literal,
    text = strings.clone(clean),
  }
}

coalesce_command_id :: proc(primary, fallback: string) -> string {
  if strings.trim_space(primary) != "" do return primary
  return fallback
}

compiled_command_flags :: proc(compiled: Compiled_CLI, spec_index: int) -> []Compiled_Flag {
  for command in compiled.commands {
    if command.spec_index == spec_index do return command.flags[:]
  }
  return nil
}

compiled_command_allows_unknown_flags :: proc(compiled: Compiled_CLI, spec_index: int) -> bool {
  for command in compiled.commands {
    if command.spec_index == spec_index do return command.allow_unknown_flags
  }
  return false
}

match_compiled_pattern :: proc(pattern: Command_Pattern, args: []string, flags, spec_flags: []Compiled_Flag) -> (bool, int, [dynamic]Named_Value) {
  positionals := make([dynamic]Named_Value)
  arg_idx := 0
  for token in pattern.tokens {
    if token.kind == .Variadic_Positional {
      for arg_idx < len(args) {
	append(&positionals, Named_Value{name = strings.clone(token.text), value = strings.clone(args[arg_idx])})
	arg_idx += 1
      }
      return true, arg_idx, positionals
    }
    for arg_idx < len(args) && is_option(args[arg_idx]) {
      if compiled_flag_consumes_next_arg_in(args, arg_idx, flags, spec_flags) {
	arg_idx += 2
      } else {
	arg_idx += 1
      }
    }
    if arg_idx >= len(args) {
      return false, 0, positionals
    }
    arg := args[arg_idx]
    switch token.kind {
    case .Literal:
      if token.text != arg do return false, 0, positionals
    case .Positional:
      append(&positionals, Named_Value{name = strings.clone(token.text), value = strings.clone(arg)})
    case .Variadic_Positional:
    case .One_Of:
      if !compiled_token_choice_matches(token, arg) do return false, 0, positionals
    }
    arg_idx += 1
  }
  return true, arg_idx, positionals
}

compiled_token_choice_matches :: proc(token: Command_Token, arg: string) -> bool {
  for choice in token.choices {
    if choice == arg do return true
  }
  return false
}

destroy_named_values :: proc(values: [dynamic]Named_Value) {
  for value in values {
    delete(value.name)
    delete(value.value)
  }
  delete(values)
}

is_placeholder :: proc(token: string) -> bool {
  return len(token) >= 3 && strings.has_prefix(token, "<") && strings.has_suffix(token, ">")
}

is_option :: proc(arg: string) -> bool {
  return strings.has_prefix(arg, "-")
}

flag_takes_value :: proc(flags: []Flag_Spec, arg: string) -> bool {
  compiled := compile_flag_specs(flags)
  defer destroy_compiled_flags(compiled)
  return compiled_flag_takes_value(compiled[:], arg)
}

compiled_flag_takes_value :: proc(flags: []Compiled_Flag, arg: string) -> bool {
  name := arg
  if idx := strings.index(name, "="); idx >= 0 {
    name = name[:idx]
  }
  for flag in flags {
    if flag.mode == .None do continue
    if compiled_flag_name_matches(flag, name) do return true
  }
  return false
}

compiled_flag_takes_value_in :: proc(flags, extra_flags: []Compiled_Flag, arg: string) -> bool {
  if compiled_flag_takes_value(flags, arg) do return true
  return compiled_flag_takes_value(extra_flags, arg)
}

compiled_flag_value_mode :: proc(flags: []Compiled_Flag, arg: string) -> (Flag_Value_Mode, bool) {
  name := arg
  if idx := strings.index(name, "="); idx >= 0 {
    name = name[:idx]
  }
  for flag in flags {
    if compiled_flag_name_matches(flag, name) do return flag.mode, true
  }
  return .None, false
}

compiled_flag_value_mode_in :: proc(flags, extra_flags: []Compiled_Flag, arg: string) -> (Flag_Value_Mode, bool) {
  if mode, ok := compiled_flag_value_mode(flags, arg); ok {
    return mode, true
  }
  return compiled_flag_value_mode(extra_flags, arg)
}

compiled_flag_consumes_next_arg_in :: proc(args: []string, idx: int, flags, extra_flags: []Compiled_Flag) -> bool {
  if idx < 0 || idx >= len(args) do return false
  arg := args[idx]
  if strings.contains(arg, "=") do return false
  if idx + 1 >= len(args) do return false
  mode, ok := compiled_flag_value_mode_in(flags, extra_flags, arg)
  if !ok do return false
  switch mode {
  case .Required:
    return true
  case .Optional:
    return !is_option(args[idx + 1])
  case .None:
    return false
  }
  return false
}

flag_name_matches :: proc(flag: Flag_Spec, name: string) -> bool {
  if name == flag.name do return true
  if strings.trim_space(flag.aliases) == "" do return false
  aliases := strings.split(flag.aliases, "|")
  defer delete(aliases)
  for alias in aliases {
    if strings.trim_space(alias) == name do return true
  }
  return false
}

compiled_flag_name_matches :: proc(flag: Compiled_Flag, name: string) -> bool {
  for flag_name in flag.names {
    if flag_name == name do return true
  }
  return false
}

compiled_flag_value_allowed :: proc(flag: Compiled_Flag, value: string) -> bool {
  for choice in flag.choices {
    if value == choice do return true
  }
  return false
}

join_choice_values :: proc(choices: []string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for choice, i in choices {
    if i > 0 do strings.write_string(&builder, ", ")
    strings.write_string(&builder, choice)
  }
  return strings.clone(strings.to_string(builder))
}

positional :: proc(result: Match_Result, name: string) -> (string, bool) {
  for value in result.positionals {
    if value.name == name {
      return strings.clone(value.value), true
    }
  }
  return strings.clone(""), false
}

positionals :: proc(result: Match_Result, name: string) -> [dynamic]string {
  values := make([dynamic]string)
  for value in result.positionals {
    if value.name == name {
      append(&values, strings.clone(value.value))
    }
  }
  return values
}

option_value :: proc(args: []string, primary, secondary: string) -> string {
  primary_eq := fmt.tprintf("%s=", primary)
  secondary_eq := ""
  if len(secondary) > 0 {
    secondary_eq = fmt.tprintf("%s=", secondary)
  }
  for arg, i in args {
    if arg == primary || (len(secondary) > 0 && arg == secondary) {
      if i + 1 < len(args) {
	return strings.clone(args[i + 1])
      }
      return strings.clone("")
    }
    if strings.has_prefix(arg, primary_eq) {
      return strings.clone(arg[len(primary) + 1:])
    }
    if len(secondary) > 0 && strings.has_prefix(arg, secondary_eq) {
      return strings.clone(arg[len(secondary) + 1:])
    }
  }
  return strings.clone("")
}

option_present :: proc(args: []string, primary, secondary: string) -> bool {
  primary_eq := fmt.tprintf("%s=", primary)
  secondary_eq := ""
  if len(secondary) > 0 {
    secondary_eq = fmt.tprintf("%s=", secondary)
  }
  for arg in args {
    if arg == primary || (len(secondary) > 0 && arg == secondary) {
      return true
    }
    if strings.has_prefix(arg, primary_eq) {
      return true
    }
    if len(secondary) > 0 && strings.has_prefix(arg, secondary_eq) {
      return true
    }
  }
  return false
}

join_option_values :: proc(args: []string, name: string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  name_eq := fmt.tprintf("%s=", name)
  for arg, i in args {
    value := ""
    if arg == name {
      if i + 1 < len(args) {
	value = args[i + 1]
      }
    } else if strings.has_prefix(arg, name_eq) {
      value = arg[len(name) + 1:]
    }
    clean := strings.trim_space(value)
    if clean == "" do continue
    if strings.builder_len(builder) > 0 do strings.write_byte(&builder, ' ')
    strings.write_string(&builder, clean)
  }
  return strings.clone(strings.to_string(builder))
}

positional_arg :: proc(args: []string, idx: int) -> (string, bool) {
  if idx >= len(args) || strings.has_prefix(args[idx], "-") {
    return strings.clone(""), false
  }
  return strings.clone(args[idx]), true
}
