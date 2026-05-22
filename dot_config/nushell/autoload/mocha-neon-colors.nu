# ~/Code/dotfiles/dot_config/nushell/autoload/mocha-neon-colors.nu
# Mocha Neon ANSI mapping for nushell shape highlighting.

$env.config.color_config = {
  separator: "#585B70"
  leading_trailing_space_bg: { attr: n }
  header: { fg: "#B347FF", attr: b }
  empty: "#9580FF"
  bool: {|| if $in { "#50FA7B" } else { "#FF6B9D" } }
  int: "#FFD700"
  filesize: "#8BE9FD"
  duration: "#50FA7B"
  date: "#FF80BF"
  range: "#A6ADC8"
  float: "#FFD700"
  string: "#F0F0FF"
  nothing: "#585B70"
  binary: "#FF8C42"
  cell-path: "#9580FF"
  row_index: { fg: "#B347FF", attr: b }
  record: "#F0F0FF"
  list: "#F0F0FF"
  block: "#F0F0FF"
  hints: "#7F849C"
  search_result: { bg: "#313244", fg: "#FFD700" }
  shape_and: { fg: "#B347FF", attr: b }
  shape_binary: { fg: "#FF8C42", attr: b }
  shape_block: { fg: "#8AB4F8", attr: b }
  shape_bool: "#50FA7B"
  shape_custom: "#50FA7B"
  shape_datetime: { fg: "#FF80BF", attr: b }
  shape_directory: "#8BE9FD"
  shape_external: "#8BE9FD"
  shape_externalarg: { fg: "#50FA7B", attr: b }
  shape_filepath: "#8BE9FD"
  shape_flag: { fg: "#8AB4F8", attr: b }
  shape_float: { fg: "#FFD700", attr: b }
  shape_garbage: { fg: "#F0F0FF", bg: "#FF6B9D", attr: b }
  shape_globpattern: { fg: "#8BE9FD", attr: b }
  shape_int: { fg: "#FFD700", attr: b }
  shape_internalcall: { fg: "#8BE9FD", attr: b }
  shape_list: { fg: "#8BE9FD", attr: b }
  shape_literal: "#8AB4F8"
  shape_match_pattern: "#50FA7B"
  shape_matching_brackets: { attr: u }
  shape_nothing: "#50FA7B"
  shape_operator: "#FFD700"
  shape_or: { fg: "#B347FF", attr: b }
  shape_pipe: { fg: "#B347FF", attr: b }
  shape_range: { fg: "#FFD700", attr: b }
  shape_record: { fg: "#8BE9FD", attr: b }
  shape_redirection: { fg: "#B347FF", attr: b }
  shape_signature: { fg: "#50FA7B", attr: b }
  shape_string: "#50FA7B"
  shape_string_interpolation: { fg: "#8BE9FD", attr: b }
  shape_table: { fg: "#8AB4F8", attr: b }
  shape_variable: "#B347FF"
  shape_vardecl: "#B347FF"
  background: "#1E1E2E"
  foreground: "#F0F0FF"
  cursor: "#B347FF"
}
