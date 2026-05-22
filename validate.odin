package cli

import "core:fmt"
import "core:strings"

Validation_Result :: struct {
  ok:     bool,
  errors: [dynamic]string,
}

destroy_validation_result :: proc(result: Validation_Result) {
  for error in result.errors {
    delete(error)
  }
  delete(result.errors)
}

validate_command_specs :: proc(commands: []Command_Spec, flags: []Flag_Spec) -> Validation_Result {
  compiled := compile_cli(commands, flags)
  defer destroy_compiled_cli(compiled)
  return validate_compiled_cli(compiled)
}

validate_command_decls :: proc(commands: []Command_Decl, flags: []Flag_Decl) -> Validation_Result {
  compiled := compile_cli_decls(commands, flags)
  defer destroy_compiled_cli(compiled)
  return validate_compiled_cli(compiled)
}

validate_compiled_cli :: proc(compiled: Compiled_CLI) -> Validation_Result {
  result := Validation_Result{errors = make([dynamic]string)}
  validate_compiled_flags(&result, "global flags", compiled.flags[:])

  for command, i in compiled.commands {
    if !command.help_only && command.id == "" {
      append_validation_error(&result, fmt.tprintf("command %d has empty id", i))
    }
    if len(command.patterns) == 0 {
      append_validation_error(&result, fmt.tprintf("command %d has no patterns", i))
    }
    for pattern, pattern_idx in command.patterns {
      validate_command_pattern(&result, fmt.tprintf("command %d pattern %d", i, pattern_idx), pattern)
    }
    validate_compiled_flags(&result, fmt.tprintf("command %d flags", i), command.flags[:])
  }

  for command, command_idx in compiled.commands {
    if command.help_only do continue
    for pattern, pattern_idx in command.patterns {
      if pattern.source == "" {
	append_validation_error(&result, fmt.tprintf("command %d pattern %d is empty", command_idx, pattern_idx))
      }
      for other_command in compiled.commands[command_idx:] {
	if other_command.help_only do continue
	other_start := 0
	if other_command.spec_index == command.spec_index {
	  other_start = pattern_idx + 1
	}
	for other_pattern in other_command.patterns[other_start:] {
	  if pattern.source == other_pattern.source {
	    append_validation_error(&result, fmt.tprintf("duplicate command pattern: %s", pattern.source))
	  }
	}
      }
    }
  }

  result.ok = len(result.errors) == 0
  return result
}

validate_command_pattern :: proc(result: ^Validation_Result, scope: string, pattern: Command_Pattern) {
  for token, i in pattern.tokens {
    if token.kind == .Variadic_Positional && i != len(pattern.tokens) - 1 {
      append_validation_error(result, fmt.tprintf("%s variadic positional must be last: %s", scope, pattern.source))
    }
  }
}

validate_compiled_flags :: proc(result: ^Validation_Result, scope: string, flags: []Compiled_Flag) {
  for flag, flag_idx in flags {
    if flag.name == "" {
      append_validation_error(result, fmt.tprintf("%s flag %d has empty canonical name", scope, flag_idx))
    }
    if len(flag.names) == 0 {
      append_validation_error(result, fmt.tprintf("%s flag %d has no names", scope, flag_idx))
    }
    for name in flag.names {
      if name == "" {
	append_validation_error(result, fmt.tprintf("%s flag %d has empty name", scope, flag_idx))
      }
      for other_flag in flags[flag_idx + 1:] {
	if compiled_flag_name_matches(other_flag, name) {
	  append_validation_error(result, fmt.tprintf("%s duplicate flag name: %s", scope, name))
	}
      }
    }
    for choice, choice_idx in flag.choices {
      if strings.trim_space(choice) == "" {
	append_validation_error(result, fmt.tprintf("%s flag %s choice %d is empty", scope, flag.name, choice_idx))
      }
    }
  }
}

append_validation_error :: proc(result: ^Validation_Result, error: string) {
  append(&result.errors, fmt.aprintf("%s", error))
}

validate_parsed_required_flags :: proc(flags: []Parsed_Flag, names: []string) -> Validation_Result {
  result := Validation_Result{errors = make([dynamic]string)}
  for name in names {
    if !parsed_flags_present(flags, name) {
      append_validation_error(&result, fmt.tprintf("missing required flag: %s", name))
    }
  }
  result.ok = len(result.errors) == 0
  return result
}

validate_parsed_exactly_one_flag :: proc(flags: []Parsed_Flag, names: []string) -> Validation_Result {
  result := Validation_Result{errors = make([dynamic]string)}
  count := parsed_flags_present_count(flags, names)
  if count == 0 {
    joined := join_validation_names(names)
    defer delete(joined)
    append_validation_error(&result, fmt.tprintf("missing one of required flags: %s", joined))
  } else if count > 1 {
    joined := join_validation_names(names)
    defer delete(joined)
    append_validation_error(&result, fmt.tprintf("choose only one of: %s", joined))
  }
  result.ok = len(result.errors) == 0
  return result
}

validate_parsed_mutually_exclusive_flags :: proc(flags: []Parsed_Flag, names: []string) -> Validation_Result {
  result := Validation_Result{errors = make([dynamic]string)}
  if parsed_flags_present_count(flags, names) > 1 {
    joined := join_validation_names(names)
    defer delete(joined)
    append_validation_error(&result, fmt.tprintf("choose only one of: %s", joined))
  }
  result.ok = len(result.errors) == 0
  return result
}

validate_parsed_flag_one_of :: proc(flags: []Parsed_Flag, name: string, allowed: []string) -> Validation_Result {
  result := Validation_Result{errors = make([dynamic]string)}
  for flag in flags {
    if flag.name != name || !flag.has_value do continue
    if !validation_value_in(flag.value, allowed) {
      joined := join_validation_names(allowed)
      defer delete(joined)
      append_validation_error(&result, fmt.tprintf("%s must be one of: %s", name, joined))
    }
  }
  result.ok = len(result.errors) == 0
  return result
}

parsed_flags_present :: proc(flags: []Parsed_Flag, name: string) -> bool {
  for flag in flags {
    if flag.name == name do return true
  }
  return false
}

parsed_flags_present_count :: proc(flags: []Parsed_Flag, names: []string) -> int {
  count := 0
  for name in names {
    if parsed_flags_present(flags, name) {
      count += 1
    }
  }
  return count
}

validation_value_in :: proc(value: string, allowed: []string) -> bool {
  for item in allowed {
    if value == item do return true
  }
  return false
}

join_validation_names :: proc(names: []string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for name, i in names {
    if i > 0 do strings.write_string(&builder, ", ")
    strings.write_string(&builder, name)
  }
  return strings.clone(strings.to_string(builder))
}
