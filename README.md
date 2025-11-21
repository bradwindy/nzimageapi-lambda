# nzimageapi-lambda

A Swift AWS Lambda wrapper around the [DigitalNZ API](https://digitalnz.org/) that returns random images from New Zealand archives, libraries, and cultural institutions.

This project is WIP. I intend to publish this as a public API and website where people can easily view content from NZ archives.

## Prerequisites

- **DigitalNZ API Key**: Sign up for a free API key at https://digitalnz.org/
- **Docker**: Required for building the Lambda (install from https://www.docker.com/products/docker-desktop)
- **UPX**: Compression tool for reducing binary size
  ```bash
  brew install upx
  ```
- **AWS CLI** (for deployment): Install and configure
  ```bash
  brew install awscli
  aws configure
  ```

## Quick Start

**Using the deployed API:**
```bash
# Find your API endpoint
aws apigatewayv2 get-apis --query 'Items[*].[Name,ApiEndpoint]' --output table

# Get a random image
curl "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/image"
```

**For local development:**
```bash
# 1. Set your API key
export DIGITALNZ_API_KEY=your_api_key

# 2. Test a collection (builds and runs automatically)
./Sources/Testing/CollectionTester/test-collection.sh "Wellington City Recollect"

# Or test a random collection
./Sources/Testing/CollectionTester/test-collection.sh
```

## API Reference

### Finding Your Endpoint

Get your API Gateway URL:
```bash
aws apigatewayv2 get-apis --query 'Items[*].[Name,ApiEndpoint]' --output table
```

### Endpoints

#### `GET /image`

Returns a random image from a randomly selected collection.

**Example:**
```bash
curl "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/image"
```

**Response:**
```json
{
  "id": 12345678,
  "title": "Historic photograph",
  "description": "Description of the image...",
  "display_collection": "Auckland Libraries Heritage Images Collection",
  "thumbnail_url": "https://...",
  "large_thumbnail_url": "https://...",
  "landing_url": "https://..."
}
```

#### `GET /image?collection=<collection_name>`

Returns a random image from a specific collection.

**Example:**
```bash
curl "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/image?collection=Te%20Papa%20Collections%20Online"
```

**Note:** Collection names must be URL-encoded.

### Available Collections

Images are randomly selected from these NZ archives (weighted by collection size):

- Auckland Libraries Heritage Images Collection
- Auckland Museum Collections
- Te Papa Collections Online
- Kura Heritage Collections Online
- Canterbury Museum
- Antarctica NZ Digital Asset Manager
- National Publicity Studios black and white file prints
- Tauranga City Libraries Other Collection
- Hawke's Bay Knowledge Bank
- And many more...

See `Sources/NZImageApiLambda/NZImageApiLambda.swift:55-81` for the complete weighted list.

## Local Development

### Setup

1. **Configure your API key** (choose one method):

   Option A - Environment variable:
   ```bash
   export DIGITALNZ_API_KEY=your_api_key_here
   ```

   Option B - Using `.env` file (recommended):
   ```bash
   cp .env.example .env
   # Edit .env and add your API key
   source .env
   ```

   **Important:** Never commit your API key. The `.env` file is already in `.gitignore`.

2. **Build the project:**
   ```bash
   swift build
   ```

3. **Run the Lambda locally:**
   ```bash
   DIGITALNZ_API_KEY=$DIGITALNZ_API_KEY \
   SECRET=super_secret_secret \
   LOCAL_LAMBDA_SERVER_ENABLED=true \
   ./.build/debug/NZImageApiLambda
   ```

### Testing Locally

**Using CollectionTester (recommended):**
```bash
# Set your API key first
export DIGITALNZ_API_KEY=your_api_key

# Test random collection
./Sources/Testing/CollectionTester/test-collection.sh

# Test specific collection
./Sources/Testing/CollectionTester/test-collection.sh "Wellington City Recollect"

# Use custom port
./Sources/Testing/CollectionTester/test-collection.sh --port 8000 "Canterbury Museum"

# Show help
./Sources/Testing/CollectionTester/test-collection.sh --help
```

The `test-collection.sh` script automatically:
- Builds the CollectionTester and Lambda
- Starts a local Lambda server
- Makes a test request
- Validates the image URL
- Shuts down the server

**Using curl directly:**
```bash
curl -X POST http://127.0.0.1:7000/invoke \
  --header "Content-Type: application/json" \
  --data '{
    "routeKey":"GET /image",
    "version":"2.0",
    "rawPath":"/image",
    "requestContext":{"http":{"path":"/image","method":"GET"}},
    "headers":{"secret":"super_secret_secret"},
    "rawQueryString":"",
    "isBase64Encoded":false
  }'
```

## Deployment

### Building for AWS Lambda

The deployment script handles building with Docker and packaging with UPX:

```bash
# Build and package only
./scripts/deploy.sh

# Build, package, and deploy
./scripts/deploy.sh YOUR_FUNCTION_NAME
```

**Manual build steps:**
```bash
# 1. Build using Docker (compiles for Amazon Linux 2)
./scripts/build.sh

# 2. Package with UPX compression
./scripts/package.sh

# Result: .build/lambda/NZImageApiLambda/lambda.zip
```

### Deploying to AWS

#### Option 1: AWS Console

1. Go to [AWS Lambda Console](https://console.aws.amazon.com/lambda)
2. Select your function (or create new)
3. Upload `.build/lambda/NZImageApiLambda/lambda.zip`
4. Configure:
   - Runtime: `provided.al2` (Amazon Linux 2)
   - Handler: `bootstrap`
   - Architecture: `arm64`
   - Timeout: 60 seconds
5. Set environment variables (see Configuration section below)

#### Option 2: AWS CLI

**Update existing function:**
```bash
aws lambda update-function-code \
  --function-name YOUR_FUNCTION_NAME \
  --zip-file fileb://.build/lambda/NZImageApiLambda/lambda.zip

aws lambda update-function-configuration \
  --function-name YOUR_FUNCTION_NAME \
  --environment "Variables={DIGITALNZ_API_KEY=your_api_key,SECRET=your_secret,LOG_LEVEL=info}"
```

**Create new function:**
```bash
aws lambda create-function \
  --function-name NZImageApiLambda \
  --runtime provided.al2 \
  --role YOUR_LAMBDA_ROLE_ARN \
  --handler bootstrap \
  --zip-file fileb://.build/lambda/NZImageApiLambda/lambda.zip \
  --timeout 60 \
  --memory-size 256 \
  --architectures arm64 \
  --environment "Variables={DIGITALNZ_API_KEY=your_api_key,SECRET=your_secret,LOG_LEVEL=info}"
```

### Verifying Deployment

Test your deployed function:
```bash
# Test with a simple payload
aws lambda invoke \
  --function-name YOUR_FUNCTION_NAME \
  --payload '{"routeKey":"GET /image","version":"2.0","rawPath":"/image","requestContext":{"http":{"path":"/image","method":"GET"}}}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

## Configuration

### Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `DIGITALNZ_API_KEY` | Yes | Your DigitalNZ API key | `abc123xyz` |
| `SECRET` | Yes (AWS) | Authentication secret for API Gateway | `your_secret_value` |
| `LOCAL_LAMBDA_SERVER_ENABLED` | Yes (Local) | Enables local development server | `true` |
| `LOG_LEVEL` | No | Logging verbosity | `info`, `debug`, or `trace` |

### Security Best Practices

- **Never commit API keys** - Use environment variables or AWS Secrets Manager
- **Use strong secrets** - The example `super_secret_secret` is for local testing only
- **Enable CloudWatch Logs** - Monitor your Lambda function
- **Set minimal IAM permissions** - Lambda only needs basic execution permissions

### API Gateway Configuration

Your Lambda expects APIGatewayV2Request format. Ensure your API Gateway:
- Uses HTTP API (API Gateway v2)
- Routes `GET /image` to your Lambda function
- Passes the `secret` header (if authentication is required)

## Build Details

The build process:
- Uses Docker with `swift:6.0-amazonlinux2` image
- Compiles for AWS Lambda's Amazon Linux 2 runtime
- Statically links the Swift standard library
- Compresses the binary with UPX (~70% size reduction: 106MB → 32MB)
- Creates a `bootstrap` executable (required by AWS custom runtime)
