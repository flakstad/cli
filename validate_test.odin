package cli

import "core:strings"
import "core:testing"

@(test)
test_validate_command_decls_accepts_clean_cli :: proc(t: ^testing.T) {
  list_patterns := [?]string{"items list", "item list"}
  format_names := [?]string{"--format", "-f"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  specs := [?]Command_Decl{
    {patterns = list_patterns[:], id = "items.list", flags = flags[:]},
  }

  result := validate_command_decls(specs[:], nil)
  defer destroy_validation_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.errors), 0)
}

@(test)
test_validate_command_decls_reports_empty_ids_and_duplicate_patterns :: proc(t: ^testing.T) {
  first_patterns := [?]string{"items list"}
  second_patterns := [?]string{"items list"}
  specs := [?]Command_Decl{
    {patterns = first_patterns[:], id = ""},
    {patterns = second_patterns[:], id = "items.list"},
  }

  result := validate_command_decls(specs[:], nil)
  defer destroy_validation_result(result)

  testing.expect(t, !result.ok)
  testing.expect_value(t, len(result.errors), 2)
  testing.expect(t, strings.contains(result.errors[0], "empty id"))
  testing.expect(t, strings.contains(result.errors[1], "duplicate command pattern: items list"))
}

@(test)
test_validate_command_decls_reports_duplicate_flag_names :: proc(t: ^testing.T) {
  format_names := [?]string{"--format", "-f"}
  file_names := [?]string{"--file", "-f"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
    {names = file_names[:], mode = .Required},
  }

  result := validate_command_decls(nil, flags[:])
  defer destroy_validation_result(result)

  testing.expect(t, !result.ok)
  testing.expect_value(t, len(result.errors), 1)
  testing.expect(t, strings.contains(result.errors[0], "duplicate flag name: -f"))
}

@(test)
test_validate_command_decls_allows_help_only_duplicate_patterns :: proc(t: ^testing.T) {
  run_patterns := [?]string{"items audit"}
  help_patterns := [?]string{"items audit"}
  specs := [?]Command_Decl{
    {patterns = run_patterns[:], id = "items.audit"},
    {patterns = help_patterns[:], help_only = true},
  }

  result := validate_command_decls(specs[:], nil)
  defer destroy_validation_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.errors), 0)
}
