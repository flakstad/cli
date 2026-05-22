package cli

import "core:strings"
import "core:testing"

@(test)
test_completion_words_for_prefix_derive_next_command_tokens :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items list", aliases = "item list|items ls", label = "items.list", shape = "items.list"},
    {path = "items show <item-id>", aliases = "item show <item-id>|items get <item-id>", label = "items.show", shape = "items.show"},
    {path = "items tags add <item-id>", label = "items.tags.add", shape = "items.tags.add"},
    {path = "items tags remove <item-id>", aliases = "items tags rm <item-id>", label = "items.tags.remove", shape = "items.tags.remove"},
    {path = "items audit", label = "items.audit", shape = "items.audit", help_only = true},
  }

  top := completion_words_for_prefix(specs[:], "", nil)
  defer delete(top)
  testing.expect_value(t, top, "items item")

  items := completion_words_for_prefix(specs[:], "items", nil)
  defer delete(items)
  testing.expect_value(t, items, "list ls show get tags")

  tags := completion_words_for_prefix(specs[:], "items tags", nil)
  defer delete(tags)
  testing.expect_value(t, tags, "add remove rm")
}

@(test)
test_completion_words_for_compiled_prefix_reuse_compiled_cli :: proc(t: ^testing.T) {
  specs := [?]Command_Spec{
    {path = "items show|get <item-id>", label = "items.show", shape = "items.show"},
    {path = "items list", aliases = "items ls", label = "items.list", shape = "items.list"},
  }
  compiled := compile_cli(specs[:], nil)
  defer destroy_compiled_cli(compiled)

  words := completion_words_for_compiled_prefix(compiled, "items", nil)
  defer delete(words)
  testing.expect_value(t, words, "show get list ls")
}

@(test)
test_completion_words_for_decl_prefix_use_slice_patterns :: proc(t: ^testing.T) {
  list_patterns := [?]string{"items list", "item list", "items ls"}
  show_patterns := [?]string{"items show <item-id>", "item show <item-id>", "items get <item-id>"}
  specs := [?]Command_Decl{
    {patterns = list_patterns[:], id = "items.list"},
    {patterns = show_patterns[:], id = "items.show"},
  }

  top := completion_words_for_decl_prefix(specs[:], "", nil)
  defer delete(top)
  testing.expect_value(t, top, "items item")

  items := completion_words_for_decl_prefix(specs[:], "items", nil)
  defer delete(items)
  testing.expect_value(t, items, "list ls show get")
}

@(test)
test_completion_words_for_compiled_prefix_with_flags_includes_applicable_flags :: proc(t: ^testing.T) {
  verbose_names := [?]string{"--verbose", "-v"}
  format_names := [?]string{"--format"}
  list_patterns := [?]string{"items list"}
  show_patterns := [?]string{"items show <item-id>"}
  show_flags := [?]Flag_Decl{
    {names = format_names[:], mode = .Required},
  }
  global_flags := [?]Flag_Decl{
    {names = verbose_names[:], mode = .None},
  }
  specs := [?]Command_Decl{
    {patterns = list_patterns[:], id = "items.list"},
    {patterns = show_patterns[:], id = "items.show", flags = show_flags[:]},
  }
  compiled := compile_cli_decls(specs[:], global_flags[:])
  defer destroy_compiled_cli(compiled)

  root := completion_words_for_compiled_prefix_with_flags(compiled, "", nil)
  defer delete(root)
  testing.expect(t, strings.contains(root, "items"))
  testing.expect(t, strings.contains(root, "--verbose"))
  testing.expect(t, strings.contains(root, "-v"))

  show := completion_words_for_compiled_prefix_with_flags(compiled, "items show", nil)
  defer delete(show)
  testing.expect(t, strings.contains(show, "--verbose"))
  testing.expect(t, strings.contains(show, "--format"))
}

@(test)
test_render_completion_script_supports_bash :: proc(t: ^testing.T) {
  script := render_completion_script("ro", "bash", "items status")
  defer delete(script)

  testing.expect(t, strings.contains(script, "_ro_complete() {"))
  testing.expect(t, strings.contains(script, "compgen -W \"items status\""))
  testing.expect(t, strings.contains(script, "complete -F _ro_complete ro"))
}

@(test)
test_render_completion_script_supports_zsh :: proc(t: ^testing.T) {
  script := render_completion_script("ro", "zsh", "items status")
  defer delete(script)

  testing.expect(t, strings.contains(script, "#compdef ro"))
  testing.expect(t, strings.contains(script, "top=(items status)"))
  testing.expect(t, strings.contains(script, "compdef _ro ro"))
}

@(test)
test_render_completion_script_supports_fish :: proc(t: ^testing.T) {
  script := render_completion_script("ro", "fish", "items status")
  defer delete(script)

  testing.expect(t, strings.contains(script, "complete -c ro -f"))
  testing.expect(t, strings.contains(script, "complete -c ro -n '__fish_use_subcommand' -a 'items status'"))
}

@(test)
test_render_completion_script_sanitizes_function_name :: proc(t: ^testing.T) {
  script := render_completion_script("my-tool", "bash", "run")
  defer delete(script)

  testing.expect(t, strings.contains(script, "_my_tool_complete() {"))
  testing.expect(t, strings.contains(script, "complete -F _my_tool_complete my-tool"))
}
