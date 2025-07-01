#!/bin/bash

ASSETS_DIR="assets"
BASE_RES="resources/drawables/drawables.xml"

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

read -r -d '' INPUT_DATA << EOM
edge530 200x200 35x35 24x24
EOM

while read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  read -ra parts <<< "$line"
  device="${parts[0]}"
  sizes=("${parts[@]:1}")

  device_dir="resources-$device/drawables"
  mkdir -p "$device_dir"
  cp "$BASE_RES" "$device_dir/drawables.xml"

  echo "Processing device: $device"

  for i in "${!sizes[@]}"; do
    size="${sizes[$i]}"
    echo "  Handling size $i: $size"

    if [[ -n "${LINK_NAMES[$i]}" ]]; then
      for link_name in ${LINK_NAMES[$i]}; do
        asset_base="${LINK_TO_ASSET_BASE[$link_name]}"
        asset_file="$ASSETS_DIR/${asset_base}-${size}.png"
        target_link="$device_dir/$link_name"

        if [[ -f "$asset_file" ]]; then
          ln -sf "../../$asset_file" "$target_link"
          echo "    Linked $target_link -> $asset_file"
        else
          echo "    Warning: Missing asset: $asset_file"
        fi
      done
    else
      echo "    Warning: No link names defined for position $i"
    fi
  done

done <<< "$INPUT_DATA"
