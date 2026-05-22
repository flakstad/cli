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

@(test)
test_validate_command_decls_reports_variadic_positionals_before_end :: proc(t: ^testing.T) {
  patterns := [?]string{"bench <args...> after"}
  specs := [?]Command_Decl{
    {patterns = patterns[:], id = "bench"},
  }

  result := validate_command_decls(specs[:], nil)
  defer destroy_validation_result(result)

  testing.expect(t, !result.ok)
  testing.expect(t, strings.contains(result.errors[0], "variadic positional must be last"))
}

@(test)
test_validate_flag_decls_reports_empty_choices :: proc(t: ^testing.T) {
  profile_names := [?]string{"--profile"}
  choices := [?]string{"quick", ""}
  flags := [?]Flag_Decl{
    {names = profile_names[:], mode = .Required, choices = choices[:]},
  }

  result := validate_command_decls(nil, flags[:])
  defer destroy_validation_result(result)

  testing.expect(t, !result.ok)
  testing.expect(t, strings.contains(result.errors[0], "choice 1 is empty"))
}

@(test)
test_validate_parsed_required_flags_reports_missing_flags :: proc(t: ^testing.T) {
  format_names := [?]string{"--format"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  args := [?]string{"--format", "json"}
  parsed := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(parsed)
  required := [?]string{"--format", "--url"}

  result := validate_parsed_required_flags(parsed.flags[:], required[:])
  defer destroy_validation_result(result)

  testing.expect(t, !result.ok)
  testing.expect_value(t, len(result.errors), 1)
  testing.expect_value(t, result.errors[0], "missing required flag: --url")
}

@(test)
test_validate_parsed_exactly_one_and_mutual_exclusion :: proc(t: ^testing.T) {
  url_names := [?]string{"--url"}
  file_names := [?]string{"--file"}
  flags := [?]Flag_Decl{
    {names = url_names[:], mode = .Required},
    {names = file_names[:], mode = .Required},
  }
  args := [?]string{"--url", "https://example.com", "--file", "urls.txt"}
  parsed := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(parsed)
  names := [?]string{"--url", "--file"}

  one := validate_parsed_exactly_one_flag(parsed.flags[:], names[:])
  defer destroy_validation_result(one)
  testing.expect(t, !one.ok)
  testing.expect_value(t, one.errors[0], "choose only one of: --url, --file")

  exclusive := validate_parsed_mutually_exclusive_flags(parsed.flags[:], names[:])
  defer destroy_validation_result(exclusive)
  testing.expect(t, !exclusive.ok)
  testing.expect_value(t, exclusive.errors[0], "choose only one of: --url, --file")
}

@(test)
test_validate_parsed_flag_one_of_checks_all_values :: proc(t: ^testing.T) {
  format_names := [?]string{"--format"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  args := [?]string{"--format", "xml"}
  parsed := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(parsed)
  allowed := [?]string{"text", "json"}

  result := validate_parsed_flag_one_of(parsed.flags[:], "--format", allowed[:])
  defer destroy_validation_result(result)

  testing.expect(t, !result.ok)
  testing.expect_value(t, result.errors[0], "--format must be one of: text, json")
}
