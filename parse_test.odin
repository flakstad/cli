package cli

import "core:testing"

@(test)
test_match_command_picks_longest_match :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items", label = "items", shape = "items"},
    {path = "items show <item-id>", aliases = "item show <item-id>", label = "item.select", shape = "item.select"},
  }
  args := [?]string{"items", "show", "item-1"}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.spec_index, 1)
  testing.expect_value(t, match.id, "item.select")
  testing.expect_value(t, match.path, "items show <item-id>")
  testing.expect_value(t, match.label, "item.select")
  testing.expect_value(t, match.shape, "item.select")
  testing.expect_value(t, match.args_consumed, 3)

  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
}

@(test)
test_match_command_supports_aliases :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items show <item-id>", aliases = "item show <item-id>|i show <item-id>", label = "item.select", shape = "item.select"},
  }
  args := [?]string{"i", "show", "item-2"}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.id, "item.select")
  testing.expect_value(t, match.path, "i show <item-id>")
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-2")
}

@(test)
test_match_command_id_prefers_label_for_compat_specs :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items set-title <item-id>", label = "item.edit", shape = "item.set-title"},
  }
  args := [?]string{"items", "set-title", "item-1"}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.id, "item.edit")
  testing.expect_value(t, match.label, "item.edit")
  testing.expect_value(t, match.shape, "item.set-title")
}

@(test)
test_compiled_cli_matches_without_retokenizing_specs :: proc(t: ^testing.T) {
  flags := [?]Flag_Spec{
    {name = "--tag", mode = .Required},
  }
  specs := [?]Command_Spec{
    {path = "items tags add <item-id>", aliases = "item tags add <item-id>", label = "item.tags.add", shape = "item.tags.add", flags = flags[:]},
  }
  compiled := compile_cli(specs[:], nil)
  defer destroy_compiled_cli(compiled)

  args := [?]string{"item", "tags", "add", "--tag", "cli", "item-1"}
  match := match_compiled_command(compiled, args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.id, "item.tags.add")
  testing.expect_value(t, match.path, "item tags add <item-id>")
  testing.expect_value(t, match.spec_index, 0)
  testing.expect_value(t, match.shape, "item.tags.add")
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
}

@(test)
test_compile_cli_decls_accepts_slice_based_patterns :: proc(t: ^testing.T) {
  patterns := [?]string{"items show <item-id>", "item show <item-id>", "i show <item-id>"}
  specs := [?]Command_Decl{
    {patterns = patterns[:], id = "item.select", doc = "Show item"},
  }
  compiled := compile_cli_decls(specs[:], nil)
  defer destroy_compiled_cli(compiled)

  args := [?]string{"i", "show", "item-9"}
  match := match_compiled_command(compiled, args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.id, "item.select")
  testing.expect_value(t, match.path, "i show <item-id>")
  testing.expect_value(t, match.label, "item.select")
  testing.expect_value(t, match.shape, "item.select")
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-9")
}

@(test)
test_compile_cli_decls_accepts_slice_based_flag_names :: proc(t: ^testing.T) {
  patterns := [?]string{"items show <item-id>"}
  format_names := [?]string{"--format", "-f"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  specs := [?]Command_Decl{
    {patterns = patterns[:], id = "items.show", flags = flags[:]},
  }
  compiled := compile_cli_decls(specs[:], nil)
  defer destroy_compiled_cli(compiled)

  args := [?]string{"items", "show", "-f", "json", "item-1"}
  result := parse_compiled_command(args[:], compiled)
  defer destroy_command_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, result.match.id, "items.show")
  testing.expect_value(t, result.match.shape, "items.show")
  item_id, ok := positional(result.match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
  format, format_ok := parsed_command_flag_value(result, "--format")
  defer delete(format)
  testing.expect(t, format_ok)
  testing.expect_value(t, format, "json")
}

@(test)
test_parse_command_decls_uses_slice_based_commands_and_flags :: proc(t: ^testing.T) {
  db_names := [?]string{"--db"}
  global_flags := [?]Flag_Decl{
    {names = db_names[:], mode = .Required},
  }
  show_patterns := [?]string{"items show <item-id>", "item show <item-id>"}
  format_names := [?]string{"--format", "-f"}
  show_flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  specs := [?]Command_Decl{
    {patterns = show_patterns[:], id = "items.show", flags = show_flags[:]},
  }
  args := [?]string{"--db", "build/test.store", "item", "show", "-f", "json", "item-1"}

  result := parse_command_decls(args[:], specs[:], global_flags[:])
  defer destroy_command_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, result.match.id, "items.show")
  item_id, ok := positional(result.match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
  format, format_ok := parsed_command_flag_value(result, "--format")
  defer delete(format)
  testing.expect(t, format_ok)
  testing.expect_value(t, format, "json")
}

@(test)
test_match_command_decls_with_flags_skips_option_values :: proc(t: ^testing.T) {
  patterns := [?]string{"items tags add <item-id>"}
  specs := [?]Command_Decl{
    {patterns = patterns[:], id = "item.tags.add"},
  }
  tag_names := [?]string{"--tag", "-t"}
  flags := [?]Flag_Decl{
    {names = tag_names[:], mode = .Required},
  }
  args := [?]string{"items", "tags", "add", "-t", "cli", "item-1"}

  match := match_command_decls_with_flags(specs[:], args[:], flags[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.id, "item.tags.add")
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
}

@(test)
test_match_command_skips_help_only_specs :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items delete <item-id>", label = "items.delete", shape = "items.delete", help_only = true},
    {path = "items show <item-id>", label = "items.show", shape = "items.show"},
  }
  args := [?]string{"items", "delete", "item-1"}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, !match.ok)
}

@(test)
test_match_command_uses_flag_specs_to_skip_option_values :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items tags add <item-id>", label = "item.tags.add", shape = "item.tags.add"},
  }
  flags := [?]Flag_Spec{
    {name = "--tag", mode = .Required},
  }
  args := [?]string{"items", "tags", "add", "--tag", "cli", "item-1"}

  match := match_command_with_flags(specs[:], args[:], flags[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.args_consumed, 6)
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
}

@(test)
test_match_command_uses_flag_decls_to_skip_option_values :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items tags add <item-id>", label = "item.tags.add", shape = "item.tags.add"},
  }
  tag_names := [?]string{"--tag", "-t"}
  flags := [?]Flag_Decl{
    {names = tag_names[:], mode = .Required},
  }
  args := [?]string{"items", "tags", "add", "-t", "cli", "item-1"}

  match := match_command_with_flag_decls(specs[:], args[:], flags[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.args_consumed, 6)
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
}

@(test)
test_match_command_uses_command_specific_flags_to_skip_option_values :: proc(t: ^testing.T) {
  tag_flags := [?]Flag_Spec{
    {name = "--tag", mode = .Required},
  }
  specs := [?]Command_Spec{
    {path = "items tags add <item-id>", label = "item.tags.add", shape = "item.tags.add", flags = tag_flags[:]},
  }
  args := [?]string{"items", "tags", "add", "--tag", "cli", "item-1"}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")
}

@(test)
test_match_command_treats_unconfigured_option_value_as_next_positional :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items tags add <item-id>", label = "item.tags.add", shape = "item.tags.add"},
  }
  args := [?]string{"items", "tags", "add", "--tag", "cli", "item-1"}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  item_id, ok := positional(match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "cli")
}

@(test)
test_flag_takes_value_matches_aliases_and_equals_form :: proc(t: ^testing.T) {
  flags := [?]Flag_Spec{
    {name = "--description", aliases = "--body|-b", mode = .Required},
    {name = "--pretty", mode = .None},
  }

  testing.expect(t, flag_takes_value(flags[:], "--description"))
  testing.expect(t, flag_takes_value(flags[:], "--body=hello"))
  testing.expect(t, flag_takes_value(flags[:], "-b"))
  testing.expect(t, !flag_takes_value(flags[:], "--pretty"))
}

@(test)
test_top_level_words_derive_from_paths_aliases_and_extras :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items", aliases = "item|i|tasks", label = "items", shape = "items"},
    {path = "items show <item-id>", aliases = "item show <item-id>", label = "item.select", shape = "item.select"},
    {path = "status", label = "status", shape = "status"},
    {path = "draft", aliases = "d", label = "draft", shape = "draft", help_only = true},
  }
  extras := [?]string{"term", "items"}

  words := top_level_words(specs[:], extras[:])
  defer delete(words)

  testing.expect_value(t, words, "items item i tasks status term")
}

@(test)
test_suggest_top_level_word_uses_paths_aliases_and_extras :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items", aliases = "item|tasks", label = "items", shape = "items"},
    {path = "status", label = "status", shape = "status"},
  }
  extras := [?]string{"term"}

  suggestion := suggest_top_level_word(specs[:], extras[:], "stats")
  defer delete(suggestion)
  testing.expect_value(t, suggestion, "status")

  alias_suggestion := suggest_top_level_word(specs[:], extras[:], "tems")
  defer delete(alias_suggestion)
  testing.expect_value(t, alias_suggestion, "items")

  none := suggest_top_level_word(specs[:], extras[:], "zzzzzz")
  defer delete(none)
  testing.expect_value(t, none, "")
}

@(test)
test_top_level_words_and_suggestions_support_command_decls :: proc(t: ^testing.T) {
  item_patterns := [?]string{"items list", "item list", "i list"}
  status_patterns := [?]string{"status"}
  hidden_patterns := [?]string{"draft"}
  specs := [?]Command_Decl{
    {patterns = item_patterns[:], id = "items.list"},
    {patterns = status_patterns[:], id = "status"},
    {patterns = hidden_patterns[:], id = "draft", help_only = true},
  }
  extras := [?]string{"term", "items"}

  words := top_level_words_for_decls(specs[:], extras[:])
  defer delete(words)
  testing.expect_value(t, words, "items item i status term")

  suggestion := suggest_top_level_word_for_decls(specs[:], extras[:], "stats")
  defer delete(suggestion)
  testing.expect_value(t, suggestion, "status")
}

@(test)
test_parse_flags_returns_canonical_flags_and_rest :: proc(t: ^testing.T) {
  flags := [?]Flag_Spec{
    {name = "--format", aliases = "-f", mode = .Required},
    {name = "--pretty", mode = .None},
  }
  args := [?]string{"--format=json", "-f", "text", "--pretty", "items", "list"}

  result := parse_flags(args[:], flags[:])
  defer destroy_flag_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.flags), 3)
  testing.expect_value(t, result.flags[0].name, "--format")
  testing.expect_value(t, result.flags[0].value, "json")
  testing.expect_value(t, result.flags[1].name, "--format")
  testing.expect_value(t, result.flags[1].value, "text")
  testing.expect_value(t, result.flags[2].name, "--pretty")
  testing.expect_value(t, len(result.rest), 2)
  testing.expect_value(t, result.rest[0], "items")
  testing.expect_value(t, result.rest[1], "list")

  value, ok := parsed_flag_value(result, "--format")
  defer delete(value)
  testing.expect(t, ok)
  testing.expect_value(t, value, "json")
  testing.expect(t, parsed_flag_present(result, "--pretty"))
}

@(test)
test_parse_flag_decls_returns_canonical_flags_and_rest :: proc(t: ^testing.T) {
  format_names := [?]string{"--format", "-f"}
  pretty_names := [?]string{"--pretty"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
    {names = pretty_names[:], mode = .None},
  }
  args := [?]string{"-f", "json", "--pretty", "items", "list"}

  result := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.flags), 2)
  testing.expect_value(t, result.flags[0].name, "--format")
  testing.expect_value(t, result.flags[0].value, "json")
  testing.expect_value(t, result.flags[1].name, "--pretty")
  testing.expect_value(t, len(result.rest), 2)
  testing.expect_value(t, result.rest[0], "items")
  testing.expect_value(t, result.rest[1], "list")
}

@(test)
test_combine_flag_decls_appends_reusable_groups :: proc(t: ^testing.T) {
  format_names := [?]string{"--format"}
  pretty_names := [?]string{"--pretty"}
  output_flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  display_flags := [?]Flag_Decl{
    {names = pretty_names[:], mode = .None},
  }

  flags := combine_flag_decls(output_flags[:], display_flags[:])
  defer destroy_flag_decl_list(flags)

  testing.expect_value(t, len(flags), 2)
  testing.expect_value(t, flags[0].names[0], "--format")
  testing.expect_value(t, flags[1].names[0], "--pretty")
}

@(test)
test_combine_command_decls_appends_reusable_groups :: proc(t: ^testing.T) {
  item_patterns := [?]string{"items"}
  user_patterns := [?]string{"users"}
  item_commands := [?]Command_Decl{
    {patterns = item_patterns[:], id = "items", doc = "Item commands"},
  }
  user_commands := [?]Command_Decl{
    {patterns = user_patterns[:], id = "users", doc = "User commands"},
  }

  commands := combine_command_decls(item_commands[:], user_commands[:])
  defer destroy_command_decl_list(commands)

  testing.expect_value(t, len(commands), 2)
  testing.expect_value(t, commands[0].id, "items")
  testing.expect_value(t, commands[1].id, "users")
}

@(test)
test_combine_command_specs_appends_reusable_groups :: proc(t: ^testing.T) {
  item_commands := [?]Command_Spec{
    {path = "items", label = "items"},
  }
  user_commands := [?]Command_Spec{
    {path = "users", label = "users"},
  }

  commands := combine_command_specs(item_commands[:], user_commands[:])
  defer destroy_command_spec_list(commands)

  testing.expect_value(t, len(commands), 2)
  testing.expect_value(t, commands[0].path, "items")
  testing.expect_value(t, commands[1].path, "users")
}

@(test)
test_parse_flags_support_optional_values_repeated_values_and_defaults :: proc(t: ^testing.T) {
  scan_names := [?]string{"--with-scan"}
  header_names := [?]string{"--header"}
  limit_names := [?]string{"--limit"}
  flags := [?]Flag_Decl{
    {names = scan_names[:], mode = .Optional},
    {names = header_names[:], mode = .Required},
    {names = limit_names[:], mode = .Required},
  }
  args := [?]string{"--with-scan", "baseline", "--with-scan", "--header", "A: 1", "--header=B: 2", "--limit", "25", "http", "scan"}

  result := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.flags), 5)
  testing.expect_value(t, result.flags[0].name, "--with-scan")
  testing.expect(t, result.flags[0].has_value)
  testing.expect_value(t, result.flags[0].value, "baseline")
  testing.expect_value(t, result.flags[1].name, "--with-scan")
  testing.expect(t, !result.flags[1].has_value)
  testing.expect_value(t, parsed_flag_int_value_or(result, "--limit", 10), 25)
  testing.expect_value(t, parsed_flag_int_value_or(result, "--missing", 10), 10)

  scan := parsed_flag_value_or(result, "--with-scan", "default")
  defer delete(scan)
  testing.expect_value(t, scan, "baseline")

  headers := parsed_flag_values(result, "--header")
  defer destroy_string_list(headers)
  testing.expect_value(t, len(headers), 2)
  testing.expect_value(t, headers[0], "A: 1")
  testing.expect_value(t, headers[1], "B: 2")

  testing.expect_value(t, len(result.rest), 2)
  testing.expect_value(t, result.rest[0], "http")
  testing.expect_value(t, result.rest[1], "scan")
}

@(test)
test_parse_flags_validate_declared_choices :: proc(t: ^testing.T) {
  format_names := [?]string{"--format"}
  choices := [?]string{"text", "json"}
  flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required, choices = choices[:]},
  }

  ok_args := [?]string{"--format", "json"}
  ok := parse_flag_decls(ok_args[:], flags[:])
  defer destroy_flag_parse_result(ok)
  testing.expect(t, ok.ok)

  bad_args := [?]string{"--format", "xml"}
  bad := parse_flag_decls(bad_args[:], flags[:])
  defer destroy_flag_parse_result(bad)
  testing.expect(t, !bad.ok)
  testing.expect_value(t, bad.error, "--format must be one of: text, json")
}

@(test)
test_optional_flag_does_not_consume_following_option :: proc(t: ^testing.T) {
  scan_names := [?]string{"--with-scan"}
  pretty_names := [?]string{"--pretty"}
  flags := [?]Flag_Decl{
    {names = scan_names[:], mode = .Optional},
    {names = pretty_names[:], mode = .None},
  }
  args := [?]string{"--with-scan", "--pretty"}

  result := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.flags), 2)
  testing.expect_value(t, result.flags[0].name, "--with-scan")
  testing.expect(t, !result.flags[0].has_value)
  testing.expect(t, parsed_flag_present(result, "--pretty"))
}

@(test)
test_parse_flags_can_stop_at_first_positional :: proc(t: ^testing.T) {
  flags := [?]Flag_Spec{
    {name = "--db", mode = .Required},
  }
  args := [?]string{"--db", "build/test.store", "items", "--title", "Keep me"}

  result := parse_flags_with_config(args[:], Flag_Parse_Config{
    flags = flags[:],
    stop_at_first_positional = true,
  })
  defer destroy_flag_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.rest), 3)
  testing.expect_value(t, result.rest[0], "items")
  testing.expect_value(t, result.rest[1], "--title")
  testing.expect_value(t, result.rest[2], "Keep me")
}

@(test)
test_split_passthrough_args_returns_original_slices :: proc(t: ^testing.T) {
  args := [?]string{"http", "scan", "--url", "https://example.com", "--", "-tags", "tech"}

  parsed, passthrough := split_passthrough_args(args[:])

  testing.expect_value(t, len(parsed), 4)
  testing.expect_value(t, parsed[0], "http")
  testing.expect_value(t, parsed[3], "https://example.com")
  testing.expect_value(t, len(passthrough), 2)
  testing.expect_value(t, passthrough[0], "-tags")
  testing.expect_value(t, passthrough[1], "tech")
}

@(test)
test_parse_flags_return_passthrough_after_double_dash :: proc(t: ^testing.T) {
  url_names := [?]string{"--url"}
  flags := [?]Flag_Decl{
    {names = url_names[:], mode = .Required},
  }
  args := [?]string{"--url", "https://example.com", "scan", "--", "-tags", "tech"}

  result := parse_flag_decls(args[:], flags[:])
  defer destroy_flag_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, len(result.rest), 1)
  testing.expect_value(t, result.rest[0], "scan")
  testing.expect_value(t, len(result.passthrough), 2)
  testing.expect_value(t, result.passthrough[0], "-tags")
  testing.expect_value(t, result.passthrough[1], "tech")
}

@(test)
test_parse_flags_reports_unknown_missing_and_unwanted_values :: proc(t: ^testing.T) {
  flags := [?]Flag_Spec{
    {name = "--db", mode = .Required},
    {name = "--pretty", mode = .None},
  }

  unknown_args := [?]string{"--wat"}
  unknown := parse_flags(unknown_args[:], flags[:])
  defer destroy_flag_parse_result(unknown)
  testing.expect(t, !unknown.ok)
  testing.expect_value(t, unknown.error, "unknown flag: --wat")

  missing_args := [?]string{"--db"}
  missing := parse_flags(missing_args[:], flags[:])
  defer destroy_flag_parse_result(missing)
  testing.expect(t, !missing.ok)
  testing.expect_value(t, missing.error, "missing value for --db")

  unwanted_args := [?]string{"--pretty=true"}
  unwanted := parse_flags(unwanted_args[:], flags[:])
  defer destroy_flag_parse_result(unwanted)
  testing.expect(t, !unwanted.ok)
  testing.expect_value(t, unwanted.error, "flag does not take a value: --pretty")
}

@(test)
test_match_command_supports_variadic_positionals :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "bench <args...>", label = "bench", shape = "bench"},
  }
  args := [?]string{"bench", "--warmup", "3", "bin/gransk repo stats --dir ."}

  match := match_command(specs[:], args[:])
  defer destroy_match_result(match)

  testing.expect(t, match.ok)
  testing.expect_value(t, match.args_consumed, 4)
  values := positionals(match, "args")
  defer destroy_string_list(values)
  testing.expect_value(t, len(values), 3)
  testing.expect_value(t, values[0], "--warmup")
  testing.expect_value(t, values[1], "3")
  testing.expect_value(t, values[2], "bin/gransk repo stats --dir .")
}

@(test)
test_parse_command_returns_match_flags_and_rest :: proc(t: ^testing.T) {
  show_flags := [?]Flag_Spec{
    {name = "--format", aliases = "-f", mode = .Required},
    {name = "--pretty", mode = .None},
  }
  specs := [?]Command_Spec{
    {path = "items show <item-id>", aliases = "item show <item-id>", label = "items.show", shape = "items.show", flags = show_flags[:]},
  }
  args := [?]string{"--format=json", "items", "show", "--pretty", "item-1"}

  result := parse_command(args[:], specs[:], nil)
  defer destroy_command_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, result.match.id, "items.show")
  testing.expect_value(t, result.match.shape, "items.show")
  testing.expect_value(t, len(result.flags), 2)
  testing.expect_value(t, result.flags[0].name, "--format")
  testing.expect_value(t, result.flags[0].value, "json")
  testing.expect_value(t, result.flags[1].name, "--pretty")
  testing.expect_value(t, len(result.rest), 3)
  testing.expect_value(t, result.rest[0], "items")
  testing.expect_value(t, result.rest[1], "show")
  testing.expect_value(t, result.rest[2], "item-1")

  item_id, ok := positional(result.match, "item-id")
  defer delete(item_id)
  testing.expect(t, ok)
  testing.expect_value(t, item_id, "item-1")

  format, format_ok := parsed_command_flag_value(result, "--format")
  defer delete(format)
  testing.expect(t, format_ok)
  testing.expect_value(t, format, "json")
  testing.expect(t, parsed_command_flag_present(result, "--pretty"))
}

@(test)
test_parse_command_supports_command_specific_unknown_flags :: proc(t: ^testing.T) {
  wrapper_patterns := [?]string{"repo scc <args...>"}
  strict_patterns := [?]string{"repo stats"}
  specs := [?]Command_Decl{
    {patterns = wrapper_patterns[:], id = "repo.scc", allow_unknown_flags = true},
    {patterns = strict_patterns[:], id = "repo.stats"},
  }

  wrapper_args := [?]string{"repo", "scc", "--by-file", "src"}
  wrapper := parse_command_decls(wrapper_args[:], specs[:], nil)
  defer destroy_command_parse_result(wrapper)
  testing.expect(t, wrapper.ok)
  testing.expect_value(t, wrapper.match.id, "repo.scc")
  testing.expect_value(t, len(wrapper.rest), 4)

  strict_args := [?]string{"repo", "stats", "--by-file"}
  strict := parse_command_decls(strict_args[:], specs[:], nil)
  defer destroy_command_parse_result(strict)
  testing.expect(t, !strict.ok)
  testing.expect_value(t, strict.error, "unknown flag: --by-file")
}

@(test)
test_parse_command_validates_flags_for_matched_command :: proc(t: ^testing.T) {
  show_flags := [?]Flag_Spec{
    {name = "--format", mode = .Required},
  }
  list_flags := [?]Flag_Spec{
    {name = "--limit", mode = .Required},
  }
  specs := [?]Command_Spec{
    {path = "items show <item-id>", label = "items.show", shape = "items.show", flags = show_flags[:]},
    {path = "items list", label = "items.list", shape = "items.list", flags = list_flags[:]},
  }

  ok_args := [?]string{"items", "list", "--limit", "10"}
  ok_result := parse_command(ok_args[:], specs[:], nil)
  defer destroy_command_parse_result(ok_result)
  testing.expect(t, ok_result.ok)
  limit, limit_ok := parsed_command_flag_value(ok_result, "--limit")
  defer delete(limit)
  testing.expect(t, limit_ok)
  testing.expect_value(t, limit, "10")

  bad_args := [?]string{"items", "list", "--format", "json"}
  bad_result := parse_command(bad_args[:], specs[:], nil)
  defer destroy_command_parse_result(bad_result)
  testing.expect(t, !bad_result.ok)
  testing.expect_value(t, bad_result.error, "unknown flag: --format")
}

@(test)
test_parse_command_reports_flag_errors_before_matching :: proc(t: ^testing.T) {
  pretty_flags := [?]Flag_Spec{
    {name = "--pretty", mode = .None},
  }
  specs := [?]Command_Spec{
    {path = "items list", label = "items.list", shape = "items.list", flags = pretty_flags[:]},
  }
  args := [?]string{"items", "list", "--pretty=true"}

  result := parse_command(args[:], specs[:], nil)
  defer destroy_command_parse_result(result)

  testing.expect(t, !result.ok)
  testing.expect_value(t, result.error, "flag does not take a value: --pretty")
}

@(test)
test_parse_command_reports_missing_or_unknown_command :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items list", label = "items.list", shape = "items.list"},
  }

  empty_args := [?]string{}
  missing := parse_command(empty_args[:], specs[:], nil)
  defer destroy_command_parse_result(missing)
  testing.expect(t, !missing.ok)
  testing.expect_value(t, missing.error, "missing command")

  args := [?]string{"projects", "list"}
  unknown := parse_command(args[:], specs[:], nil)
  defer destroy_command_parse_result(unknown)
  testing.expect(t, !unknown.ok)
  testing.expect_value(t, unknown.error, "unknown command: projects")
}

@(test)
test_parse_compiled_command_reuses_compiled_cli :: proc(t: ^testing.T) {
  global_flags := [?]Flag_Spec{
    {name = "--db", mode = .Required},
  }
  show_flags := [?]Flag_Spec{
    {name = "--format", aliases = "-f", mode = .Required},
  }
  specs := [?]Command_Spec{
    {path = "items show <item-id>", label = "items.show", shape = "items.show", flags = show_flags[:]},
  }
  compiled := compile_cli(specs[:], global_flags[:])
  defer destroy_compiled_cli(compiled)

  args := [?]string{"--db", "build/test.store", "items", "show", "-f", "json", "item-1"}
  result := parse_compiled_command(args[:], compiled)
  defer destroy_command_parse_result(result)

  testing.expect(t, result.ok)
  testing.expect_value(t, result.match.shape, "items.show")
  db, db_ok := parsed_command_flag_value(result, "--db")
  defer delete(db)
  testing.expect(t, db_ok)
  testing.expect_value(t, db, "build/test.store")
  format, format_ok := parsed_command_flag_value(result, "--format")
  defer delete(format)
  testing.expect(t, format_ok)
  testing.expect_value(t, format, "json")
}

@(test)
test_option_helpers_read_separate_and_equals_values :: proc(t: ^testing.T) {
  args := [?]string{"items", "create", "--title", "First", "--status=todo", "--pretty"}

  title := option_value(args[:], "--title", "")
  defer delete(title)
  status := option_value(args[:], "--status", "")
  defer delete(status)

  testing.expect_value(t, title, "First")
  testing.expect_value(t, status, "todo")
  testing.expect(t, option_present(args[:], "--pretty", ""))
  testing.expect(t, option_present(args[:], "--status", ""))
}

@(test)
test_join_option_values_preserves_repeated_values :: proc(t: ^testing.T) {
  args := [?]string{"items", "tags", "set", "item-1", "--tag", "cli", "--tag=odin"}

  tags := join_option_values(args[:], "--tag")
  defer delete(tags)

  testing.expect_value(t, tags, "cli odin")
}
