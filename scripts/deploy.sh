#!/bin/bash

# Deploy script for NZ Image API Lambda
# Usage:
#   ./scripts/deploy.sh                    # Build and package only
#   ./scripts/deploy.sh FUNCTION_NAME      # Build, package, and deploy to AWS

set -e

FUNCTION_NAME=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "======================================"
echo "NZ Image API Lambda Deployment"
echo "======================================"
echo ""

# Step 1: Build
echo "Step 1/3: Building Lambda with Docker..."
echo "This may take a few minutes on first run..."
cd "$PROJECT_DIR"
./scripts/build.sh

if [ $? -ne 0 ]; then
    echo "✗ Build failed!"
    exit 1
fi
echo "✓ Build successful"
echo ""

# Step 2: Package
echo "Step 2/3: Packaging Lambda..."
./scripts/package.sh

if [ $? -ne 0 ]; then
    echo "✗ Packaging failed!"
    exit 1
fi
echo "✓ Package created at .build/lambda/NZImageApiLambda/lambda.zip"
echo ""

# Step 3: Deploy (optional)
if [ -n "$FUNCTION_NAME" ]; then
    echo "Step 3/3: Deploying to AWS Lambda function: $FUNCTION_NAME"

    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        echo "✗ AWS CLI not found. Please install it:"
        echo "  brew install awscli"
        echo "  aws configure"
        exit 1
    fi

    # Upload the function
    echo "Uploading function code..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://.build/lambda/NZImageApiLambda/lambda.zip

    if [ $? -ne 0 ]; then
        echo "✗ Deployment failed!"
        echo ""
        echo "Make sure:"
        echo "  1. AWS CLI is configured (run: aws configure)"
        echo "  2. Function '$FUNCTION_NAME' exists in AWS"
        echo "  3. You have permission to update the function"
        exit 1
    fi

    echo "✓ Deployment successful!"
    echo ""
    echo "Don't forget to set environment variables in AWS Console:"
    echo "  - DIGITALNZ_API_KEY=your_api_key"
    echo "  - SECRET=your_secret"
    echo "  - LOG_LEVEL=info"
    echo ""
    echo "Or set them via CLI:"
    echo "  aws lambda update-function-configuration \\"
    echo "      --function-name $FUNCTION_NAME \\"
    echo "      --environment \"Variables={DIGITALNZ_API_KEY=your_key,SECRET=your_secret,LOG_LEVEL=info}\""
else
    echo "Step 3/3: Skipping deployment (no function name provided)"
    echo ""
    echo "To deploy manually:"
    echo "  1. Go to AWS Lambda Console: https://console.aws.amazon.com/lambda"
    echo "  2. Upload .build/lambda/NZImageApiLambda/lambda.zip"
    echo "  3. Set environment variables:"
    echo "     - DIGITALNZ_API_KEY=your_api_key"
    echo "     - SECRET=your_secret"
    echo "     - LOG_LEVEL=info"
    echo ""
    echo "Or deploy via CLI:"
    echo "  ./scripts/deploy.sh YOUR_FUNCTION_NAME"
fi

echo ""
echo "======================================"
echo "Done!"
echo "======================================"
