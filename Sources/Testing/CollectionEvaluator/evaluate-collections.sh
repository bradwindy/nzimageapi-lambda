#!/bin/bash

# evaluate-collections.sh
# Evaluates collections with ❓ status by testing image resolutions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SAMPLES_PER_COLLECTION=3
DETAILS_FILE="/Users/bwindybank/Developer/nzimageapi-lambda/details-of-collections.txt"
TEMP_DIR="/tmp/collection-evaluator-$$"

# Check if API key is set
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo -e "${RED}Error: DIGITALNZ_API_KEY environment variable not set${NC}"
    echo "Please set it with: export DIGITALNZ_API_KEY=your_api_key"
    exit 1
fi

# Check if details file exists
if [ ! -f "$DETAILS_FILE" ]; then
    echo -e "${RED}Error: $DETAILS_FILE not found${NC}"
    exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Build ImageResolutionChecker
echo -e "${BLUE}🔨 Building ImageResolutionChecker...${NC}"
swift build --product ImageResolutionChecker 2>&1 | grep -E "(Compiling|Linking|Build complete)" || true

# Extract collections with ❓ status
echo -e "${BLUE}📋 Finding collections to evaluate...${NC}"

# Parse the file to find collections with ❓ status
collections_to_evaluate=()
while IFS= read -r line; do
    # Check if line is a collection header (starts with quotes)
    if [[ $line =~ ^\"([^\"]+)\":[[:space:]]*([0-9,]+), ]]; then
        current_collection="${BASH_REMATCH[1]}"
        current_count="${BASH_REMATCH[2]}"
    # Check if line contains Status: ❓
    elif [[ $line =~ Status:[[:space:]]*❓ ]] && [[ -n "$current_collection" ]]; then
        collections_to_evaluate+=("$current_collection")
        current_collection=""
    fi
done < "$DETAILS_FILE"

if [ ${#collections_to_evaluate[@]} -eq 0 ]; then
    echo -e "${YELLOW}No collections with ❓ status found.${NC}"
    exit 0
fi

echo -e "${GREEN}Found ${#collections_to_evaluate[@]} collections to evaluate${NC}"
echo ""

# Function to analyze resolution data
analyze_resolutions() {
    local results_file="$1"

    # Extract resolutions using jq
    local large_widths=$(jq -r '.largeThumbnailUrl.resolution.width // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local large_heights=$(jq -r '.largeThumbnailUrl.resolution.height // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local object_widths=$(jq -r '.objectUrl.resolution.width // empty' "$results_file" 2>/dev/null | paste -sd "," -)
    local object_heights=$(jq -r '.objectUrl.resolution.height // empty' "$results_file" 2>/dev/null | paste -sd "," -)

    local notes=""

    # Analyze large_thumbnail_url
    if [ -n "$large_widths" ]; then
        local avg_width=$(echo "$large_widths" | awk -F',' '{s=0; for(i=1;i<=NF;i++)s+=$i; print int(s/NF)}')
        local avg_height=$(echo "$large_heights" | awk -F',' '{s=0; for(i=1;i<=NF;i++)s+=$i; print int(s/NF)}')

        notes="${notes}- Thumbnail URL to use: Large\n"
        notes="${notes}- Average large_thumbnail resolution: ${avg_width}x${avg_height}\n"

        # Determine quality level
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

    # Analyze object_url if present
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

# Evaluate each collection
for collection in "${collections_to_evaluate[@]}"; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Evaluating: ${YELLOW}$collection${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    collection_file="$TEMP_DIR/$(echo "$collection" | sed 's/[^a-zA-Z0-9]/_/g').jsonl"

    # Collect samples
    echo -e "${BLUE}Collecting $SAMPLES_PER_COLLECTION samples...${NC}"
    for i in $(seq 1 $SAMPLES_PER_COLLECTION); do
        echo -n "  Sample $i/$SAMPLES_PER_COLLECTION... "

        if .build/debug/ImageResolutionChecker "$collection" >> "$collection_file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ (failed)${NC}"
        fi

        # Small delay between requests
        sleep 0.5
    done

    # Check if we got any successful results
    if [ ! -s "$collection_file" ]; then
        echo -e "${RED}Failed to get any results for this collection${NC}"
        echo -e "- Status: ❌" > "$TEMP_DIR/${collection}_notes.txt"
        echo -e "- Unable to fetch images from this collection" >> "$TEMP_DIR/${collection}_notes.txt"
        continue
    fi

    # Analyze the results
    echo -e "${BLUE}📈 Analyzing results...${NC}"
    notes=$(analyze_resolutions "$collection_file")

    # Print the analysis
    echo -e "${GREEN}Analysis:${NC}"
    echo -e "$notes"

    # Save notes for this collection
    # Change status to ⚠️ for now (needs manual review)
    echo -e "- Status: ⚠️" > "$TEMP_DIR/${collection}_notes.txt"
    echo -e "$notes" >> "$TEMP_DIR/${collection}_notes.txt"
    echo -e "- Evaluated on $(date +%Y-%m-%d)" >> "$TEMP_DIR/${collection}_notes.txt"

    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Evaluation complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Now update the details file
echo -e "${BLUE}📝 Updating details-of-collections.txt...${NC}"

output_file="$TEMP_DIR/details-of-collections-updated.txt"
current_collection=""
skip_until_next_collection=false

while IFS= read -r line; do
    # Check if this is a collection header
    if [[ $line =~ ^\"([^\"]+)\":[[:space:]]*([0-9,]+), ]]; then
        collection_name="${BASH_REMATCH[1]}"

        # Write the header line
        echo "$line" >> "$output_file"

        # Check if we have notes for this collection
        notes_file="$TEMP_DIR/${collection_name}_notes.txt"
        if [ -f "$notes_file" ]; then
            # We have new notes - write them and skip old notes
            cat "$notes_file" >> "$output_file"
            skip_until_next_collection=true
        else
            skip_until_next_collection=false
        fi
    elif [ "$skip_until_next_collection" = true ]; then
        # Skip lines until we hit the next collection or empty line
        if [[ -z "$line" ]]; then
            echo "$line" >> "$output_file"
            skip_until_next_collection=false
        fi
        # Skip the old notes
    else
        # Normal line, just write it
        echo "$line" >> "$output_file"
    fi
done < "$DETAILS_FILE"

# Backup original and replace
cp "$DETAILS_FILE" "$DETAILS_FILE.backup-$(date +%Y%m%d-%H%M%S)"
mv "$output_file" "$DETAILS_FILE"

echo -e "${GREEN}✅ Updated $DETAILS_FILE${NC}"
echo -e "${BLUE}Backup saved with timestamp${NC}"
echo ""
echo -e "${YELLOW}Note: Collections have been marked with ⚠️ status${NC}"
echo -e "${YELLOW}Please review the automated notes and update status to ✅ or ❌ as appropriate${NC}"
