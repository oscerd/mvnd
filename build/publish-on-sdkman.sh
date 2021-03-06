#!/usr/bin/env bash

set -e
#set -x

VERSION=$1

echo "SDKMAN_CONSUMER_KEY: $(echo ${SDKMAN_CONSUMER_KEY} | cut -c-3)..."
echo "SDKMAN_CONSUMER_TOKEN: $(echo ${SDKMAN_CONSUMER_TOKEN} | cut -c-3)..."

echo "Publishing version ${VERSION} on sdkman.io"

function publishRelease() {
    VERSION=$1
    SDKMAN_PLATFORM=$2
    MVND_PLATFORM=$3

    FILE="mvnd-${VERSION}-${MVND_PLATFORM}.zip"
    URL="https://github.com/mvndaemon/mvnd/releases/download/${VERSION}/${FILE}"
    RESPONSE="$(curl -s -X POST \
        -H "Consumer-Key: ${SDKMAN_CONSUMER_KEY}" \
        -H "Consumer-Token: ${SDKMAN_CONSUMER_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{"candidate": "mvnd", "version": "'${VERSION}'", "platform" : "'${SDKMAN_PLATFORM}'", "url": "'${URL}'"}' \
        https://vendors.sdkman.io/release)"

    node -pe "
        var json = JSON.parse(process.argv[1]);
        if (json.status == 201 || json.status == 409) {
            json.status + ' as expected from /release for ${FILE}';
        } else {
            console.log('Unexpected status from /release for ${FILE}: ' + process.argv[1]);
            process.exit(1);
        }
    " "${RESPONSE}"
}

publishRelease ${VERSION} LINUX_64 linux-amd64
publishRelease ${VERSION} MAC_OSX darwin-amd64
publishRelease ${VERSION} WINDOWS_64 windows-amd64

echo "Setting ${VERSION} as a default"
RESPONSE="$(curl -s -X PUT \
    -H "Consumer-Key: ${SDKMAN_CONSUMER_KEY}" \
    -H "Consumer-Token: ${SDKMAN_CONSUMER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{"candidate": "mvnd", "version": "'${VERSION}'"}' \
    https://vendors.sdkman.io/default)"

node -pe "
    var json = JSON.parse(process.argv[1]);
    if (json.status == 202) {
        json.status + ' as expected from /default';
    } else {
        console.log('Unexpected status from /default: ' + process.argv[1]);
        process.exit(1);
    }
" "${RESPONSE}"

RELEASE_URL=`curl -s -i https://git.io -F url=https://github.com/mvndaemon/mvnd/releases/tag/${VERSION} | grep Location | sed -e 's/Location: //g' | tr -d '\n' | tr -d '\r'`
echo "RELEASE_URL = $RELEASE_URL"

RESPONSE="$(curl -s -X POST \
    -H "Consumer-Key: ${SDKMAN_CONSUMER_KEY}" \
    -H "Consumer-Token: ${SDKMAN_CONSUMER_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{"text": "mvnd '${VERSION}' released '${RELEASE_URL}'"}' \
    https://vendors.sdkman.io/announce/freeform)"

node -pe "
    var json = JSON.parse(process.argv[1]);
    if (json.status == 200 || json.status == 201) {
        json.status + ' as expected from /announce/freeform';
    } else {
        console.log('Unexpected status from /announce/freeform: ' + process.argv[1]);
        process.exit(1);
    }
" "${RESPONSE}"
