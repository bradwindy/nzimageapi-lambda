# CollectionLister

A Swift command-line tool that lists all image collections available from the Digital NZ API with their current image counts.

## What it does

1. Queries the Digital NZ API for all available image collections
2. Retrieves image counts for each collection using the facets API
3. Sorts collections by image count (descending)
4. Outputs machine-parseable JSON

## Usage

**Using the wrapper script (recommended):**
```bash
# List all collections
DIGITALNZ_API_KEY=your_key ./list-collections.sh

# Or with export
export DIGITALNZ_API_KEY=your_key
./list-collections.sh
```

**Or call the binary directly:**
```bash
# List all collections
DIGITALNZ_API_KEY=your_key .build/debug/CollectionLister
```

## Output Format

Machine-parseable JSON with collections sorted by image count (descending):

```json
{
  "collections" : [
    {
      "count" : 3436813,
      "name" : "iNaturalist NZ — Mātaki Taiao"
    },
    {
      "count" : 367587,
      "name" : "Kura Heritage Collections Online"
    },
    {
      "count" : 365674,
      "name" : "Te Papa Collections Online"
    },
    ...
  ],
  "totalCollections" : 198
}
```

## Use Cases

- **Maintain `details-of-collections.txt`** - Update collection counts in the project's collection tracking file
- **Discover new collections** - Identify collections that have been added to Digital NZ since last check
- **Track collection growth** - Monitor how collection sizes change over time
- **Generate reports** - Pipe output to other tools for analysis

## Example Usage in Scripts

```bash
# Save to file for later analysis
DIGITALNZ_API_KEY=$API_KEY ./list-collections.sh > collections.json

# Count total collections
DIGITALNZ_API_KEY=$API_KEY ./list-collections.sh | jq '.totalCollections'

# Find collections with more than 100k images
DIGITALNZ_API_KEY=$API_KEY ./list-collections.sh | jq '.collections[] | select(.count > 100000)'

# Get just collection names
DIGITALNZ_API_KEY=$API_KEY ./list-collections.sh | jq -r '.collections[].name'
```

## Limitations

The Digital NZ API limits facet results to 350 items per page. This tool retrieves up to the maximum allowed (350) collections, sorted by image count. Collections beyond the top 350 will not be included in the results.

## Features

- Automatic build before execution
- Clean error messages for missing API key
- Sorted output (largest collections first)
- JSON output for easy parsing and automation
