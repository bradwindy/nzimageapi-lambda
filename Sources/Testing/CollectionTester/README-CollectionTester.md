# CollectionTester

A Swift command-line tool for testing the NZ Image API Lambda locally. Uses the shared `LambdaTesting` library for Lambda server management.

## What it replaces

CollectionTester replaces the old `CollectionFetcher` (simple HTTP client).

A convenience wrapper script `test-collection.sh` is provided alongside CollectionTester for easier command-line usage.

## What it does

1. Builds the lambda (optionally with `--clean` for a clean build)
2. Starts a local lambda server
3. Makes a test request for a specific or random collection
4. Validates the JSON response
5. Verifies the image URL is accessible
6. Shuts down the server automatically

## Shared Library

CollectionTester uses the `LambdaTesting` library (`Sources/Testing/LambdaTesting/`) which provides:
- Lambda build and server lifecycle management
- Request formatting for API Gateway payloads
- Image URL validation

This library is also used by `CollectionReviewer` for consistent Lambda testing.

## Usage

**Using the wrapper script (recommended):**
```bash
# Test a random collection
DIGITALNZ_API_KEY=your_key ./test-collection.sh

# Test a specific collection
DIGITALNZ_API_KEY=your_key ./test-collection.sh "Wellington City Recollect"

# Use custom port
DIGITALNZ_API_KEY=your_key ./test-collection.sh --port 8000 "Canterbury Museum"

# Show help
./test-collection.sh --help
```

**Or call the binary directly:**
```bash
# Test a random collection
DIGITALNZ_API_KEY=your_key .build/debug/CollectionTester

# Test a specific collection
DIGITALNZ_API_KEY=your_key .build/debug/CollectionTester "Wellington City Recollect"

# Use custom port
DIGITALNZ_API_KEY=your_key .build/debug/CollectionTester --port 8000 "Canterbury Museum"

# Show help
.build/debug/CollectionTester --help
```

## Options

- `--port <port>` - Port for lambda server (default: 7000)
- `--host <host>` - Host for lambda server (default: 127.0.0.1)
- `--clean` - Do a clean build before testing (recommended to avoid cache issues)
- `-h, --help` - Show help message

## Example Output

```
🔨 Building lambda...
✅ Build complete

🚀 Starting local lambda server on port 7000...
⏳ Waiting for server to start...
✅ Server is ready!

🔍 Making request...
📁 Collection: Canterbury Museum

✅ Success!

  "id": 54213714,
  "title": "Postcard of a street in Poruba, Ostrava",
  ...

🔍 Verifying image URL...
📸 Image URL: https://collection.canterburymuseum.com/...
✅ Image URL is valid (HTTP 200)
   Content-Type: image/jpeg
   File Type: JPEG image

🧹 Shutting down lambda server...
```

## Features

- Automatic build before each test
- Port conflict detection and resolution
- Server health checking
- Comprehensive error reporting
- Image file type detection
- Clean shutdown on exit or Ctrl+C
