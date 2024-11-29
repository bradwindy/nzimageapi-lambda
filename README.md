# nzimageapi-lambda

## About

An AWS lambda form of my NZImageAPI https://github.com/bradwindy/nzimageapi 

## Building & Packaging for Release

This package requires the upx tool to make the resulting binary smaller due to AWS size limits. You can install this via Homebrew: `brew install upx`. 

You will also need docker running.

See `scripts` folder. You must build and then package, uploading the zip file to AWS.

## Invocation

To run locally, you must set the following environment variables in the scheme:

```
SECRET=super_secret_secret
LOCAL_LAMBDA_SERVER_ENABLED=true
```

The secret must match what is sent in the request. Change to something more secure than this example for production.

```
curl \
   -vvv \
   --header "Content-Type: application/json" \
   --request POST \
   --data '{
         "routeKey":"GET /image",
         "version":"2.0",
         "rawPath":"/image",
         "stageVariables":{},
         "requestContext":{
         "timeEpoch":1587750461466,
         "domainPrefix":"image",
         "accountId":"0123456789",
         "stage":"$default",
         "domainName":"image.test.com",
         "apiId":"pb5dg6g3rg",
         "requestId":"LgLpnibOFiAEPCA=",
         "http":{
            "path":"/image",
            "userAgent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
            "method":"GET",
            "protocol":"HTTP/1.1",
            "sourceIp":"91.64.117.86"
         },
         "time":"24/Apr/2020:17:47:41 +0000"
         },
         "isBase64Encoded":false,
         "rawQueryString":"",
         "headers":{
            "secret": "super_secret_secret",
            "host":"image.test.com",
            "user-agent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
            "content-length":"0"
         }
     }' \
   http://127.0.0.1:7000/invoke
```
