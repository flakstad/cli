package cli

import "core:fmt"

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
  }
}

append_validation_error :: proc(result: ^Validation_Result, error: string) {
  append(&result.errors, fmt.aprintf("%s", error))
}
