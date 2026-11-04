#!/usr/bin/env bash
# Shared settings boundary for install/uninstall. Never print settings contents.
settings_json_valid() {
  # Slurp first: jq -e on a stream otherwise tests only its final result.
  # Validate the containers we traverse, allowing arbitrary settings, event
  # names and hook types (including prompt/agent hooks) to remain intact.
  jq -e -s '
    def hook_valid:
      type == "object"
      and (.type | type == "string")
      and (if has("command") or .type == "command"
           then .command | type == "string" else true end);
    def group_valid:
      type == "object"
      and (if has("matcher") then .matcher | type == "string" else true end)
      and (.hooks | type == "array" and all(.[]; hook_valid));
    length == 1 and (.[0] |
      type == "object"
      and (if has("hooks") then
        .hooks | type == "object"
        and all(.[]; type == "array" and all(.[]; group_valid))
      else true end))
  ' "$1" >/dev/null 2>&1
}

validate_existing_settings() {
  [[ -e "$1" || -L "$1" ]] || return 0
  if [[ ! -f "$1" ]] || ! settings_json_valid "$1"; then
    printf '%s\n' 'settings.json must contain exactly one JSON object with valid hook containers; refusing changes' >&2
    return 1
  fi
}
