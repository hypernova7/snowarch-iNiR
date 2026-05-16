#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="cava"

PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
CAVA_CONFIG_DIR="$XDG_CONFIG_HOME/cava"
CAVA_CONFIG="$CAVA_CONFIG_DIR/config"

# Marker comments to identify iNiR-managed color section
MARKER_BEGIN="# BEGIN inir-generated-colors"
MARKER_END="# END inir-generated-colors"

# Extract a hex color from palette.json
palette_color() {
  local key="$1"
  jq -r ".$key // empty" "$PALETTE_FILE" 2>/dev/null
}

# Build gradient colors from Material You palette.
# Maps: primary_container → secondary_container → primary → tertiary → secondary → tertiary_container
build_gradient() {
  local -a colors=()
  local c
  for key in primary_container secondary_container primary tertiary secondary tertiary_container primary_fixed_dim tertiary_fixed_dim; do
    c=$(palette_color "$key")
    [[ -n "$c" ]] && colors+=("$c")
    [[ ${#colors[@]} -ge 8 ]] && break
  done

  # Fallback: if we got fewer than 2 colors, bail
  if [[ ${#colors[@]} -lt 2 ]]; then
    log_module "Not enough palette colors for gradient (got ${#colors[@]})"
    return 1
  fi

  printf '%s\n' "${colors[@]}"
}

# Generate the [color] section with gradient
generate_color_section() {
  local -a gradient=()
  while IFS= read -r c; do
    gradient+=("$c")
  done < <(build_gradient)

  [[ ${#gradient[@]} -ge 2 ]] || return 1

  local bg
  bg=$(palette_color "background")
  [[ -n "$bg" ]] || bg=$(palette_color "surface")

  printf '%s\n' "$MARKER_BEGIN"
  printf '[color]\n'
  [[ -n "${bg:-}" ]] && printf "background = '%s'\n" "$bg"
  printf 'gradient = 1\n'

  local i=1
  for c in "${gradient[@]}"; do
    printf "gradient_color_%d = '%s'\n" "$i" "$c"
    ((i++))
  done

  printf '%s\n' "$MARKER_END"
}

# Inject or replace the color section in cava config.
# If no config exists, create one with just the color section.
apply_cava_colors() {
  [[ -f "$PALETTE_FILE" ]] || { log_module "palette.json not found, skipping"; return 0; }
  command -v cava &>/dev/null || { log_module "cava not installed, skipping"; return 0; }

  local color_block
  color_block=$(generate_color_section) || { log_module "Failed to generate colors"; return 0; }

  mkdir -p "$CAVA_CONFIG_DIR"

  if [[ ! -f "$CAVA_CONFIG" ]]; then
    # No existing config — write just our section
    printf '%s\n' "$color_block" > "$CAVA_CONFIG"
    log_module "Created cava config with theme colors"
    return 0
  fi

  # Config exists — replace between markers or append
  if grep -qF "$MARKER_BEGIN" "$CAVA_CONFIG"; then
    # Replace existing managed section
    local tmp
    tmp=$(mktemp)
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v block="$color_block" '
      $0 == begin { skip=1; printed=0 }
      skip && $0 == end { skip=0; print block; printed=1; next }
      !skip { print }
    ' "$CAVA_CONFIG" > "$tmp"
    mv "$tmp" "$CAVA_CONFIG"
  else
    # No markers — check for existing [color] section and replace it
    if grep -q '^\[color\]' "$CAVA_CONFIG"; then
      local tmp
      tmp=$(mktemp)
      awk -v block="$color_block" '
        /^\[color\]/ { in_color=1; print block; next }
        in_color && /^\[/ { in_color=0 }
        !in_color { print }
      ' "$CAVA_CONFIG" > "$tmp"
      mv "$tmp" "$CAVA_CONFIG"
    else
      # No [color] section at all — append
      printf '\n%s\n' "$color_block" >> "$CAVA_CONFIG"
    fi
  fi

  log_module "Applied theme colors to cava config"
}

# Remove iNiR-managed colors when theming is disabled
strip_cava_colors() {
  [[ -f "$CAVA_CONFIG" ]] || return 0
  grep -qF "$MARKER_BEGIN" "$CAVA_CONFIG" || return 0

  local tmp
  tmp=$(mktemp)
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    $0 == begin { skip=1; next }
    skip && $0 == end { skip=0; next }
    !skip { print }
  ' "$CAVA_CONFIG" > "$tmp"
  mv "$tmp" "$CAVA_CONFIG"
  log_module "Stripped iNiR colors from cava config"
}

main() {
  local enabled
  enabled=$(config_bool '.appearance.wallpaperTheming.enableCava' false)

  if [[ "$enabled" == 'true' ]]; then
    apply_cava_colors
  else
    strip_cava_colors
  fi
}

main "$@"
