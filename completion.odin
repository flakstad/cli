package cli

import "core:fmt"
import "core:strings"

completion_words_for_prefix :: proc(specs: []Command_Spec, prefix: string, extra_words: []string) -> string {
  compiled := compile_cli(specs, nil)
  defer destroy_compiled_cli(compiled)
  return completion_words_for_compiled_prefix(compiled, prefix, extra_words)
}

completion_words_for_decl_prefix :: proc(specs: []Command_Decl, prefix: string, extra_words: []string) -> string {
  compiled := compile_cli_decls(specs, nil)
  defer destroy_compiled_cli(compiled)
  return completion_words_for_compiled_prefix(compiled, prefix, extra_words)
}

completion_words_for_compiled_prefix :: proc(compiled: Compiled_CLI, prefix: string, extra_words: []string) -> string {
  words := completion_word_list_for_compiled_prefix(compiled, prefix, extra_words)
  defer destroy_string_words(words)
  return join_words(words[:])
}

completion_words_for_compiled_prefix_with_flags :: proc(compiled: Compiled_CLI, prefix: string, extra_words: []string) -> string {
  words := completion_word_list_for_compiled_prefix_with_flags(compiled, prefix, extra_words)
  defer destroy_string_words(words)
  return join_words(words[:])
}

completion_words_for_compiled_partial_prefix :: proc(compiled: Compiled_CLI, prefix: string, extra_words: []string) -> string {
  if completion_prefix_is_complete(prefix) {
    return completion_words_for_compiled_prefix(compiled, prefix, extra_words)
  }
  tokens := strings.fields(prefix)
  defer delete(tokens)
  if len(tokens) == 0 {
    return completion_words_for_compiled_prefix(compiled, prefix, extra_words)
  }
  if len(tokens) == 1 {
    words := completion_words_for_compiled_prefix(compiled, "", extra_words)
    if completion_words_contains(words, tokens[0]) {
      delete(words)
      return completion_words_for_compiled_prefix(compiled, prefix, extra_words)
    }
    filtered := filter_completion_words(words, tokens[0])
    delete(words)
    return filtered
  }

  completed_prefix := join_completion_prefix(tokens[:len(tokens) - 1])
  defer delete(completed_prefix)
  words := completion_words_for_compiled_prefix(compiled, completed_prefix, extra_words)
  defer delete(words)
  return filter_completion_words(words, tokens[len(tokens) - 1])
}

completion_words_for_compiled_partial_prefix_with_flags :: proc(compiled: Compiled_CLI, prefix: string, extra_words: []string) -> string {
  if completion_prefix_is_complete(prefix) {
    return completion_words_for_compiled_prefix_with_flags(compiled, prefix, extra_words)
  }
  tokens := strings.fields(prefix)
  defer delete(tokens)
  if len(tokens) == 0 {
    return completion_words_for_compiled_prefix_with_flags(compiled, prefix, extra_words)
  }
  if len(tokens) == 1 {
    words := completion_words_for_compiled_prefix_with_flags(compiled, "", extra_words)
    if completion_words_contains(words, tokens[0]) {
      delete(words)
      return completion_words_for_compiled_prefix_with_flags(compiled, prefix, extra_words)
    }
    filtered := filter_completion_words(words, tokens[0])
    delete(words)
    return filtered
  }

  completed_prefix := join_completion_prefix(tokens[:len(tokens) - 1])
  defer delete(completed_prefix)
  words := completion_words_for_compiled_prefix_with_flags(compiled, completed_prefix, extra_words)
  defer delete(words)
  return filter_completion_words(words, tokens[len(tokens) - 1])
}

completion_word_list_for_compiled_prefix :: proc(compiled: Compiled_CLI, prefix: string, extra_words: []string) -> [dynamic]string {
  words := make([dynamic]string)
  prefix_tokens := strings.fields(prefix)
  defer delete(prefix_tokens)

  for command in compiled.commands {
    if command.help_only do continue
    for pattern in command.patterns {
      append_completion_words_for_compiled_pattern(&words, pattern, prefix_tokens)
    }
  }

  for word in extra_words {
    append_unique_word(&words, strings.trim_space(word))
  }
  return words
}

completion_word_list_for_compiled_prefix_with_flags :: proc(compiled: Compiled_CLI, prefix: string, extra_words: []string) -> [dynamic]string {
  words := completion_word_list_for_compiled_prefix(compiled, prefix, extra_words)
  append_completion_words_for_flags(&words, compiled.flags[:])

  prefix_tokens := strings.fields(prefix)
  defer delete(prefix_tokens)
  append_completion_words_for_matching_command_flags(&words, compiled, prefix_tokens[:])
  return words
}

completion_prefix_is_complete :: proc(prefix: string) -> bool {
  return strings.trim_space(prefix) == "" || strings.has_suffix(prefix, " ")
}

join_completion_prefix :: proc(tokens: []string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  for token, i in tokens {
    if i > 0 do strings.write_byte(&builder, ' ')
    strings.write_string(&builder, token)
  }
  return strings.clone(strings.to_string(builder))
}

completion_words_contains :: proc(words, target: string) -> bool {
  fields := strings.fields(words)
  defer delete(fields)
  for word in fields {
    if word == target do return true
  }
  return false
}

filter_completion_words :: proc(words, partial: string) -> string {
  fields := strings.fields(words)
  defer delete(fields)
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  wrote := false
  for word in fields {
    if !strings.has_prefix(word, partial) do continue
    if wrote do strings.write_byte(&builder, ' ')
    strings.write_string(&builder, word)
    wrote = true
  }
  return strings.clone(strings.to_string(builder))
}

render_completion_script :: proc(command_name, shell, top_words: string) -> string {
  clean_shell := strings.to_lower(strings.trim_space(shell))
  defer delete(clean_shell)
  clean_name := strings.trim_space(command_name)
  if clean_name == "" do clean_name = "app"
  func_name := completion_function_name(clean_name)
  defer delete(func_name)

  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  switch clean_shell {
  case "bash":
    fmt.sbprintf(&builder, "%s_complete() ", func_name)
    strings.write_string(&builder, "{\n")
    strings.write_string(&builder, "  local cur\n")
    strings.write_string(&builder, "  cur=\"${COMP_WORDS[COMP_CWORD]}\"\n")
    strings.write_string(&builder, "  if [[ ${COMP_CWORD} -eq 1 ]]; then\n")
    fmt.sbprintf(&builder, "    COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") )\n", top_words)
    strings.write_string(&builder, "  else\n")
    strings.write_string(&builder, "    COMPREPLY=()\n")
    strings.write_string(&builder, "  fi\n")
    strings.write_string(&builder, "}\n")
    fmt.sbprintf(&builder, "complete -F %s_complete %s\n", func_name, clean_name)
    return strings.clone(strings.to_string(builder))
  case "zsh":
    fmt.sbprintf(&builder, "#compdef %s\n\n", clean_name)
    fmt.sbprintf(&builder, "%s() ", func_name)
    strings.write_string(&builder, "{\n")
    strings.write_string(&builder, "  local -a top\n")
    fmt.sbprintf(&builder, "  top=(%s)\n", top_words)
    strings.write_string(&builder, "  if (( CURRENT == 2 )); then\n")
    strings.write_string(&builder, "    _describe 'command' top\n")
    strings.write_string(&builder, "  fi\n")
    strings.write_string(&builder, "}\n")
    fmt.sbprintf(&builder, "compdef %s %s\n", func_name, clean_name)
    return strings.clone(strings.to_string(builder))
  case "fish":
    fmt.sbprintf(&builder, "complete -c %s -f\n", clean_name)
    fmt.sbprintf(&builder, "complete -c %s -n '__fish_use_subcommand' -a '%s'\n", clean_name, top_words)
    return strings.clone(strings.to_string(builder))
  }
  return strings.clone("")
}

render_dynamic_completion_script :: proc(command_name, shell, words_command: string) -> string {
  clean_shell := strings.to_lower(strings.trim_space(shell))
  defer delete(clean_shell)
  clean_name := strings.trim_space(command_name)
  if clean_name == "" do clean_name = "app"
  clean_words_command := strings.trim_space(words_command)
  if clean_words_command == "" do clean_words_command = fmt.tprintf("%s completion words", clean_name)
  func_name := completion_function_name(clean_name)
  defer delete(func_name)

  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  switch clean_shell {
  case "bash":
    fmt.sbprintf(&builder, "%s_complete() ", func_name)
    strings.write_string(&builder, "{\n")
    strings.write_string(&builder, "  local cur words\n")
    strings.write_string(&builder, "  cur=\"${COMP_WORDS[COMP_CWORD]}\"\n")
    strings.write_string(&builder, "  words=$(")
    strings.write_string(&builder, clean_words_command)
    strings.write_string(&builder, " \"${COMP_WORDS[@]:1:$COMP_CWORD}\" 2>/dev/null)\n")
    strings.write_string(&builder, "  COMPREPLY=( $(compgen -W \"$words\" -- \"$cur\") )\n")
    strings.write_string(&builder, "}\n")
    fmt.sbprintf(&builder, "complete -F %s_complete %s\n", func_name, clean_name)
    return strings.clone(strings.to_string(builder))
  case "zsh":
    fmt.sbprintf(&builder, "#compdef %s\n\n", clean_name)
    fmt.sbprintf(&builder, "%s() ", func_name)
    strings.write_string(&builder, "{\n")
    strings.write_string(&builder, "  local raw\n")
    strings.write_string(&builder, "  local -a completions\n")
    strings.write_string(&builder, "  raw=\"$(")
    strings.write_string(&builder, clean_words_command)
    strings.write_string(&builder, " ${words[2,CURRENT]} 2>/dev/null)\"\n")
    strings.write_string(&builder, "  completions=(${=raw})\n")
    strings.write_string(&builder, "  compadd -- $completions\n")
    strings.write_string(&builder, "}\n")
    fmt.sbprintf(&builder, "compdef %s %s\n", func_name, clean_name)
    return strings.clone(strings.to_string(builder))
  case "fish":
    fmt.sbprintf(&builder, "function %s_complete\n", func_name)
    strings.write_string(&builder, "  set -l tokens (commandline -opc)\n")
    strings.write_string(&builder, "  set -e tokens[1]\n")
    strings.write_string(&builder, "  ")
    strings.write_string(&builder, clean_words_command)
    strings.write_string(&builder, " $tokens 2>/dev/null\n")
    strings.write_string(&builder, "end\n")
    fmt.sbprintf(&builder, "complete -c %s -f -a '(%s_complete)'\n", clean_name, func_name)
    return strings.clone(strings.to_string(builder))
  }
  return strings.clone("")
}

append_completion_words_for_flags :: proc(words: ^[dynamic]string, flags: []Compiled_Flag) {
  for flag in flags {
    for name in flag.names {
      append_unique_word(words, strings.trim_space(name))
    }
  }
}

append_completion_words_for_matching_command_flags :: proc(words: ^[dynamic]string, compiled: Compiled_CLI, prefix_tokens: []string) {
  for command in compiled.commands {
    if command.help_only do continue
    for pattern in command.patterns {
      if compiled_tokens_have_literal_prefix(pattern.tokens[:], prefix_tokens) {
	append_completion_words_for_flags(words, command.flags[:])
	break
      }
    }
  }
}

append_completion_words_for_compiled_pattern :: proc(words: ^[dynamic]string, pattern: Command_Pattern, prefix_tokens: []string) {
  if len(pattern.tokens) <= len(prefix_tokens) do return
  if !compiled_tokens_have_literal_prefix(pattern.tokens[:], prefix_tokens) do return
  append_completion_compiled_token(words, pattern.tokens[len(prefix_tokens)])
}

compiled_tokens_have_literal_prefix :: proc(tokens: []Command_Token, prefix_tokens: []string) -> bool {
  if len(tokens) < len(prefix_tokens) do return false
  for prefix, i in prefix_tokens {
    token := tokens[i]
    switch token.kind {
    case .Literal:
      if token.text != prefix do return false
    case .One_Of:
      if !compiled_token_choice_matches(token, prefix) do return false
    case .Positional, .Variadic_Positional:
      return false
    }
  }
  return true
}

append_completion_compiled_token :: proc(words: ^[dynamic]string, token: Command_Token) {
  switch token.kind {
  case .Literal:
    append_unique_word(words, strings.trim_space(token.text))
  case .One_Of:
    for choice in token.choices {
      append_unique_word(words, strings.trim_space(choice))
    }
  case .Positional, .Variadic_Positional:
  }
}

completion_function_name :: proc(command_name: string) -> string {
  builder := strings.builder_make()
  defer strings.builder_destroy(&builder)
  strings.write_byte(&builder, '_')
  for ch in command_name {
    switch {
    case ch >= 'a' && ch <= 'z', ch >= 'A' && ch <= 'Z', ch >= '0' && ch <= '9':
      strings.write_rune(&builder, ch)
      case:
      strings.write_byte(&builder, '_')
    }
  }
  return strings.clone(strings.to_string(builder))
}
