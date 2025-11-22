# CollectionEvaluator

A bash script that automatically evaluates collections marked with ❓ status by testing image resolutions and adding detailed notes to `details-of-collections.txt`.

## What it does

1. Scans `details-of-collections.txt` for collections with `Status: ❓`
2. For each collection, fetches 3 random image samples using ImageResolutionChecker
3. Analyzes resolution data (average dimensions, quality assessment)
4. Generates automated notes about image quality
5. Updates `details-of-collections.txt` with findings
6. Creates a timestamped backup of the original file

## Usage

**Basic usage:**
```bash
export DIGITALNZ_API_KEY=your_api_key
./evaluate-collections.sh
```

The script will automatically:
- Find all collections with ❓ status
- Test each one with multiple samples
- Update the file with analysis results

## What gets evaluated

The script analyzes:
- **large_thumbnail_url resolution** - Average dimensions across samples
- **object_url availability** - Whether high-res versions exist
- **Quality tier** - Categorizes as high (2000+), good (1000+), medium (600+), or low (<600 pixels)

## Example Output

```
📋 Finding collections to evaluate...
Found 3 collections to evaluate

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Evaluating: Nelson Provincial Museum
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Collecting 3 samples...
  Sample 1/3... ✓
  Sample 2/3... ✓
  Sample 3/3... ✓
📈 Analyzing results...
Analysis:
- Thumbnail URL to use: Large
- Average large_thumbnail resolution: 1024x768
- Quality: Good resolution (1000+ pixels)
- object_url available: No
- Evaluated on 2024-11-22

✅ Evaluation complete!
📝 Updating details-of-collections.txt...
✅ Updated details-of-collections.txt
```

## Generated Notes

For each collection, the script adds notes like:

```
"Nelson Provincial Museum": 198,196,
- Status: ⚠️
- Thumbnail URL to use: Large
- Average large_thumbnail resolution: 1024x768
- Quality: Good resolution (1000+ pixels)
- object_url available: No
- Evaluated on 2024-11-22
```

**Status meanings after evaluation:**
- `⚠️` - Automatically evaluated, needs manual review
- You should review these and change to:
  - `✅` - If the collection is suitable
  - `❌` - If the collection should be excluded

## Configuration

Edit the script to change:
- `SAMPLES_PER_COLLECTION=3` - Number of samples to test per collection (default: 3)
- Increase for more accurate results, decrease for faster evaluation

## Safety Features

- **Automatic backups** - Original file backed up with timestamp before changes
- **Failure handling** - Collections that fail to fetch are marked but don't stop the script
- **Review required** - Sets status to ⚠️ to indicate manual review needed

## Use Cases

- **Initial collection assessment** - Quickly evaluate new collections discovered by CollectionLister
- **Bulk evaluation** - Process multiple unknown collections at once
- **Quality baseline** - Establish resolution benchmarks for collection comparison
- **Maintenance** - Re-evaluate collections when Digital NZ updates their APIs

## Tips

1. **Review before accepting** - The automated analysis is a starting point; always verify manually
2. **Check the backup** - If something goes wrong, backups are in the same directory with timestamps
3. **Run incrementally** - Evaluate a few collections, review results, then continue
4. **Combine with ImageResolutionChecker** - For deeper analysis of specific collections

## Requirements

- `jq` - JSON processor (install with `brew install jq`)
- ImageResolutionChecker built and available
- DIGITALNZ_API_KEY environment variable set

## Limitations

- Samples 3 images per collection (may not represent full collection variability)
- Cannot detect URL processing requirements (like Recollect collections)
- Quality tiers are based on pixel dimensions only, not actual image content
- Some collections may have inconsistent image sizes
