#! /bin/bash

generate_images()
{
    local INPUT="$1"
    local APPLY_BG="$2"
    shift 2
    local SIZES=("$@")
    local BASENAME="${INPUT%.*}"

    if [[ ! -f "$INPUT" ]]; then
        echo "Error: '$INPUT' not found"
        return 1
    fi

    if [[ "$APPLY_BG" != "true" && "$APPLY_BG" != "false" ]]; then
        echo "Error: apply_bg parameter must be 'true' or 'false'"
        return 1
    fi

    if [[ ${#SIZES[@]} -eq 0 ]]; then
        echo "Error: No sizes provided"
        return 1
    fi

    for SIZE in "${SIZES[@]}"; do
        local OUTPUT="${BASENAME}-${SIZE}.png"

        if [[ "$APPLY_BG" == "true" ]]; then
            convert "$INPUT" -background black -flatten \
                -resize "$SIZE" -gravity center -extent "$SIZE" \
                -strip "$OUTPUT"
        else
            convert "$INPUT" -background none \
                -resize "$SIZE" -gravity center -extent "$SIZE" \
                -strip "$OUTPUT"
        fi

        echo "Created $OUTPUT"
    done
}

generate_images connecting_image.png true 200x200
generate_images connecting_image.png false 24x24 35x35
generate_images trigger_image.png true 200x200
