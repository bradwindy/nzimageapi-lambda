#!/bin/bash
# Temporary limited version for testing - only processes first 5 collections

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SAMPLES_PER_COLLECTION=3
DETAILS_FILE="/Users/bradley/Developer/nzimageapi-lambda/Research/details-of-collections.txt"
TEMP_DIR="/tmp/collection-evaluator-$$"
MAX_COLLECTIONS=5  # Limit to 5 for testing

if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo -e "${RED}Error: DIGITALNZ_API_KEY environment variable not set${NC}"
    exit 1
fi

if [ ! -f "$DETAILS_FILE" ]; then
    echo -e "${RED}Error: $DETAILS_FILE not found${NC}"
    exit 1
fi

mkdir -p "$TEMP_DIR"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

echo -e "${BLUE}🔨 Building ImageResolutionChecker...${NC}"
swift build --product ImageResolutionChecker 2>&1 | grep -E "(Compiling|Linking|Build complete)" || true

echo -e "${BLUE}📋 Finding collections to evaluate...${NC}"

collections_to_evaluate=()
count=0
while IFS= read -r line && [ $count -lt $MAX_COLLECTIONS ]; do
    if [[ $line =~ ^\"([^\"]+)\":[[:space:]]*([0-9,]+), ]]; then
        current_collection="${BASH_REMATCH[1]}"
    elif [[ $line =~ Status:[[:space:]]*❓ ]] && [[ -n "$current_collection" ]]; then
        collections_to_evaluate+=("$current_collection")
        count=$((count + 1))
        current_collection=""
    fi
done < "$DETAILS_FILE"

echo -e "${GREEN}Found ${#collections_to_evaluate[@]} collections to evaluate (limited to first $MAX_COLLECTIONS)${NC}"
echo ""

analyze_resolutions() {
    local results_file="$1"
    local large_widths=$(jq -r '.largeThumbnailUrl.resolution.width // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local large_heights=$(jq -r '.largeThumbnailUrl.resolution.height // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local object_widths=$(jq -r '.objectUrl.resolution.width // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local object_heights=$(jq -r '.objectUrl.resolution.height // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local notes=""

    if [ -n "$large_widths" ]; then
        local avg_width=$(echo "$large_widths" | awk -F',' '{s=0; for(i=1;i<=NF;i++)s+=$i; print int(s/NF)}')
        local avg_height=$(echo "$large_heights" | awk -F',' '{s=0; for(i=1;i<=NF;i++)s+=$i; print int(s/NF)}')

        notes="${notes}- Thumbnail URL to use: Large\n"
        notes="${notes}- Average large_thumbnail resolution: ${avg_width}x${avg_height}\n"

        if [ "$avg_width" -ge 2000 ] || [ "$avg_height" -ge 2000 ]; then
            notes="${notes}- Quality: High resolution (2000+ pixels)\n"
        elif [ "$avg_width" -ge 1000 ] || [ "$avg_height" -ge 1000 ]; then
            notes="${notes}- Quality: Good resolution (1000+ pixels)\n"
        elif [ "$avg_width" -ge 600 ] || [ "$avg_height" -ge 600 ]; then
            notes="${notes}- Quality: Medium resolution (600+ pixels)\n"
        else
            notes="${notes}- Quality: Low resolution (<600 pixels)\n"
        fi
    fi

    if [ -n "$object_widths" ]; then
        local avg_obj_width=$(echo "$object_widths" | awk -F',' '{s=0; for(i=1;i<=NF;i++)s+=$i; print int(s/NF)}')
        local avg_obj_height=$(echo "$object_heights" | awk -F',' '{s=0; for(i=1;i<=NF;i++)s+=$i; print int(s/NF)}')
        notes="${notes}- object_url available: Yes (${avg_obj_width}x${avg_obj_height})\n"
        if [ "$avg_obj_width" -ge 3000 ] || [ "$avg_obj_height" -ge 3000 ]; then
            notes="${notes}- object_url provides very high resolution images\n"
        fi
    else
        notes="${notes}- object_url available: No\n"
    fi

    echo -e "$notes"
}

for collection in "${collections_to_evaluate[@]}"; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Evaluating: ${YELLOW}$collection${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    collection_file="$TEMP_DIR/$(echo "$collection" | sed 's/[^a-zA-Z0-9]/_/g').jsonl"

    echo -e "${BLUE}Collecting $SAMPLES_PER_COLLECTION samples...${NC}"
    for i in $(seq 1 $SAMPLES_PER_COLLECTION); do
        echo -n "  Sample $i/$SAMPLES_PER_COLLECTION... "
        if .build/debug/ImageResolutionChecker "$collection" >> "$collection_file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ (failed)${NC}"
        fi
        sleep 0.5
    done

    if [ ! -s "$collection_file" ]; then
        echo -e "${RED}Failed to get any results for this collection${NC}"
        echo -e "- Status: ❌" > "$TEMP_DIR/${collection}_notes.txt"
        echo -e "- Unable to fetch images from this collection" >> "$TEMP_DIR/${collection}_notes.txt"
        continue
    fi

    echo -e "${BLUE}📈 Analyzing results...${NC}"
    notes=$(analyze_resolutions "$collection_file")

    echo -e "${GREEN}Analysis:${NC}"
    echo -e "$notes"

    echo -e "- Status: ⚠️" > "$TEMP_DIR/${collection}_notes.txt"
    echo -e "$notes" >> "$TEMP_DIR/${collection}_notes.txt"
    echo -e "- Evaluated on $(date +%Y-%m-%d)" >> "$TEMP_DIR/${collection}_notes.txt"
    echo ""
done

echo -e "${GREEN}✅ Test evaluation complete! (Processed ${#collections_to_evaluate[@]} collections)${NC}"
echo -e "${YELLOW}This was a test run. Notes saved to $TEMP_DIR${NC}"
echo -e "${YELLOW}Review the results before running the full script.${NC}"
