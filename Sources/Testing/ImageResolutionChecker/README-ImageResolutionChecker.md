# ImageResolutionChecker

A Swift command-line tool that fetches a random image from a specified Digital NZ collection and checks the actual pixel dimensions of available image URLs.

## What it does

1. Requests a random image from the specified collection via Digital NZ API
2. Downloads image data from available URLs (`large_thumbnail_url` and `object_url`)
3. Extracts pixel dimensions using ImageIO
4. Outputs machine-parseable JSON with resolution data

## Usage

**Using the wrapper script (recommended):**
```bash
# Check a specific collection
DIGITALNZ_API_KEY=your_key ./test-image-resolution.sh "Te Papa Collections Online"

# Or with export
export DIGITALNZ_API_KEY=your_key
./test-image-resolution.sh "Auckland Museum Collections"
```

**Or call the binary directly:**
```bash
# Check a specific collection
DIGITALNZ_API_KEY=your_key .build/debug/ImageResolutionChecker "Canterbury Museum"
```

## Output Format

Machine-parseable JSON with image resolution data:

```json
{
  "collection" : "Alexander Turnbull Library Flickr",
  "largeThumbnailUrl" : {
    "resolution" : {
      "height" : 639,
      "width" : 465
    },
    "url" : "https://live.staticflickr.com/5693/21448090258_583b745001_z.jpg"
  },
  "objectUrl" : {
    "resolution" : {
      "height" : 5155,
      "width" : 3748
    },
    "url" : "https://live.staticflickr.com/5693/21448090258_f6edccff24_o.jpg"
  },
  "recordId" : 36372943,
  "title" : "Soldiers loading a New Zealand trench mortar, near Colincamps, France"
}
```

**Note:** Not all collections provide both URL types. Some may only have `large_thumbnail_url`, and `object_url` may be omitted from the output if not available.

## Use Cases

- **Verify image quality** - Check if a collection provides high-resolution images
- **Compare URL fields** - See the difference between `large_thumbnail_url` and `object_url` resolutions
- **Collection evaluation** - Determine if a collection is suitable for high-quality image display
- **Automation** - Build scripts to evaluate multiple collections systematically

## Example Usage in Scripts

```bash
# Test multiple collections and save results
for collection in "Te Papa Collections Online" "Auckland Museum Collections" "Canterbury Museum"; do
  echo "Testing: $collection"
  DIGITALNZ_API_KEY=$API_KEY ./test-image-resolution.sh "$collection" >> results.jsonl
done

# Check if large_thumbnail_url has acceptable resolution
DIGITALNZ_API_KEY=$API_KEY ./test-image-resolution.sh "Te Papa Collections Online" | \
  jq '.largeThumbnailUrl.resolution | .width >= 1000 and .height >= 1000'

# Extract just the resolution dimensions
DIGITALNZ_API_KEY=$API_KEY ./test-image-resolution.sh "Canterbury Museum" | \
  jq '{collection, large: .largeThumbnailUrl.resolution, object: .objectUrl.resolution}'
```

## Understanding the Results

### large_thumbnail_url
This field typically contains a medium-to-large preview image. Resolution varies by collection:
- Some collections: 300-800 pixels
- Others: 1000+ pixels

### object_url
When present, this often provides the highest resolution available:
- Flickr collections: Full resolution (often 3000+ pixels)
- Other collections: May be similar to large_thumbnail_url or not provided

### Collection-Specific Behavior
Different collections have different URL processing:
- **Flickr-based** (e.g., Alexander Turnbull Library): `object_url` provides full resolution
- **Recollect-based** (e.g., Wellington City): URLs require processing for full resolution
- **Museum collections**: Vary widely in available resolutions

## Features

- Automatic build before execution
- Fetches random images for representative sampling
- Clean error messages for missing API key or invalid collections
- JSON output for easy parsing and automation
- Handles missing URL fields gracefully
