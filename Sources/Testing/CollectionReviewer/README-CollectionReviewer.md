# CollectionReviewer

An interactive Swift CLI tool for manually reviewing collections that have been automatically evaluated (marked with 🔎 status). Presents sample images for human assessment and updates `Research/details-of-collections.txt` with your decisions.

## What it does

1. Scans `Research/details-of-collections.txt` for collections with `Status: 🔎`
2. For each collection, fetches 3 random images from the Digital NZ API
3. Displays clickable links to view each image
4. Prompts for a yes/no preliminary selection decision
5. If approved: prompts for notes, updates status to 🛠️
6. If rejected: updates status to ❌
7. Proceeds to the next collection

## Usage

**Basic usage:**
```bash
export DIGITALNZ_API_KEY=your_api_key
./review-collections.sh
```

The script will automatically:
- Build the CollectionReviewer Swift binary
- Find all collections with 🔎 status
- Present each for interactive review
- Update the file with your decisions

## Interactive Flow

```
═══════════════════════════════════════════════════════════════
[1/45] Reviewing: "Nelson Provincial Museum"
═══════════════════════════════════════════════════════════════

Fetching 3 random images...

Sample images from this collection:

Image 1:
  Title: Historic street scene
  View: https://digitalnz.org/records/12345678

Image 2:
  Title: Portrait of settler family
  View: https://digitalnz.org/records/23456789

Image 3:
  Title: Landscape photograph
  View: https://digitalnz.org/records/34567890

Existing evaluation notes:
  - Status: 🔎
  - Thumbnail URL to use: Large
  - Average large_thumbnail resolution: 706x544
  - Quality: Medium resolution (600+ pixels)
  - object_url available: No
  - Evaluated on 2025-11-22

Preliminary selection? (y/n): y
Enter your notes: Good variety of historical images, suitable for inclusion

Status updated to 🛠️
```

## Status Meanings

**Input status:**
- `🔎` - Automatically evaluated, ready for manual review

**Output statuses:**
- `🛠️` - Approved, needs implementation work (URL processing, etc.)
- `❌` - Rejected, will not be included

## Example Notes Added

When you approve a collection with notes:

```
"Nelson Provincial Museum": 198,196,
- Status: 🛠️
- Thumbnail URL to use: Large
- Average large_thumbnail resolution: 706x544
- Quality: Medium resolution (600+ pixels)
- object_url available: No
- Evaluated on 2025-11-22
- Review notes: Good historical content, diverse subject matter
```

## Clickable Links

The tool uses OSC 8 terminal escape sequences to create clickable hyperlinks. These work in:
- iTerm2
- macOS Terminal (Sonoma+)
- Most modern terminal emulators

If your terminal doesn't support clickable links, the URLs will still be displayed as plain text that you can copy/paste.

## Use Cases

- **Manual quality review** - Assess actual image content, not just resolution
- **Content categorization** - Determine if images fit your project's theme
- **Decision documentation** - Record reasoning for including/excluding collections
- **Workflow progression** - Move collections from evaluated to implementation phase

## Tips

1. **Click through all 3 images** - Get a representative sample before deciding
2. **Note specific concerns** - Record why you're accepting/rejecting for future reference
3. **Consider subject matter** - Resolution isn't everything; content relevance matters
4. **Take breaks** - Reviewing many collections can be tiring; quality decisions matter

## Requirements

- Swift 6.0+
- DIGITALNZ_API_KEY environment variable set
- Terminal with standard input support

## Limitations

- Only processes collections with 🔎 status
- Shows 3 random images (may not represent full collection variability)
- Cannot be run non-interactively (requires user input)
- Modifies file in place (no automatic backup - consider committing before running)
