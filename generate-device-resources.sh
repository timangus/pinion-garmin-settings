#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ASSETS_DIR="$SCRIPT_DIR/assets"
BASE_RES="$SCRIPT_DIR/resources/drawables/drawables.xml"

declare -a LINK_NAMES=(
  "connecting_image.png trigger_image.png"
  "launcher_icon.png"
  "scan_icon.png"
)

declare -A LINK_TO_ASSET_BASE=(
  ["connecting_image.png"]="connecting_image"
  ["trigger_image.png"]="trigger_image"
  ["launcher_icon.png"]="connecting_image"
  ["scan_icon.png"]="connecting_image"
)

BLACK_BG_SIZES=(
  "400x400"
  "250x250"
  "200x200"
  "150x150"
)

read -r -d '' INPUT_DATA << EOM
edge530 200x200 35x35 24x24
edge540 150x150 35x35 41x58
edge830 150x150 35x35 24x24
edge840 150x150 35x35 41x58
edge1030 250x250 36x36 24x24
edge1030plus 250x250 36x36 24x24
edge1040 250x250 40x40 24x24
edge1050 400x400 68x68 80x118
edgeexplore2 200x200 36x36 24x24
edgemtb 150x150 36x36 40x66
EOM

generate_image()
{
  local input="$1"
  local size="$2"
  local basename="${input%.*}"
  local output="${ASSETS_DIR}/${basename}-${size}.png"

  local apply_bg="false"
  for bg_size in "${BLACK_BG_SIZES[@]}"; do
    if [[ "$size" == "$bg_size" ]]; then
      apply_bg="true"
      break
    fi
  done

  if [[ ! -f "$ASSETS_DIR/$input" ]]; then
    echo "  Error: Source file '$ASSETS_DIR/$input' not found" >&2
    return 1
  fi

  echo "  Generating $output"

  if [[ "$apply_bg" == "true" ]]; then
    convert "$ASSETS_DIR/$input" -background black -flatten \
      -resize "$size" -gravity center -extent "$size" \
      -strip "$output"
  else
    convert "$ASSETS_DIR/$input" -background none \
      -brightness-contrast 15x25 \
      -resize "$size" -gravity center -extent "$size" \
      -strip "$output"
  fi
}

while read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  read -ra parts <<< "$line"
  device="${parts[0]}"
  sizes=("${parts[@]:1}")

  device_dir="$SCRIPT_DIR/resources-$device/drawables"
  mkdir -p "$device_dir"
  cp "$BASE_RES" "$device_dir/drawables.xml"

  echo "Processing device: $device"

  for i in "${!sizes[@]}"; do
    size="${sizes[$i]}"
    echo "  Handling size $i: $size"

    if [[ -n "${LINK_NAMES[$i]}" ]]; then
      for link_name in ${LINK_NAMES[$i]}; do
        asset_base="${LINK_TO_ASSET_BASE[$link_name]}"
        asset_input="${asset_base}.png"
        asset_file="$ASSETS_DIR/${asset_base}-${size}.png"
        target_link="$device_dir/$link_name"

        generate_image "$asset_input" "$size"

        if [[ -f "$asset_file" ]]; then
          relative_path=$(realpath --relative-to="$device_dir" "$asset_file")
          ln -sf "$relative_path" "$target_link"
          echo "    Linked $target_link -> $relative_path"
        else
          echo "    Warning: Missing asset: $asset_file"
        fi
      done
    else
      echo "    Warning: No link names defined for position $i"
    fi
  done

done <<< "$INPUT_DATA"
