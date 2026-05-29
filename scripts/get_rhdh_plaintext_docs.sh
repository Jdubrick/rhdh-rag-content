#!/bin/bash

#
#
# Copyright Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eou pipefail

RHDH_VERSION=$1

GITHUB_PAT="${GITHUB_PAT:-}"

trap "rm -rf red-hat-developers-documentation-rhdh release-notes-mirror" EXIT

rm -rf rhdh-product-docs-plaintext/${RHDH_VERSION}
rm -rf rhdh-docs-topic-map
rm -rf release-notes-mirror

git clone --single-branch --branch release-${RHDH_VERSION} https://github.com/redhat-developer/red-hat-developers-documentation-rhdh

git clone --single-branch --branch release-${RHDH_VERSION} https://github.com/redhat-ai-dev/rhdh-docs-topic-map

RELEASE_NOTES_REPO="https://github.com/redhat-ai-dev/release-notes-mirror.git"
if [ -n "$GITHUB_PAT" ]; then
    RELEASE_NOTES_REPO="https://x-access-token:${GITHUB_PAT}@github.com/redhat-ai-dev/release-notes-mirror.git"
fi
git clone --single-branch --branch release-${RHDH_VERSION} "$RELEASE_NOTES_REPO"

RELEASE_NOTES_DEST="red-hat-developers-documentation-rhdh/titles/release-notes"
mkdir -p "${RELEASE_NOTES_DEST}/modules/generated"
cp release-notes-mirror/master.adoc "${RELEASE_NOTES_DEST}/"
cp -r release-notes-mirror/modules/generated/. "${RELEASE_NOTES_DEST}/modules/generated/"
cp release-notes-mirror/modules/ref-release-notes-fixed-security-issues.adoc \
    "${RELEASE_NOTES_DEST}/modules/"

python scripts/convert_adoc_to_txt_rhdh.py \
    -i red-hat-developers-documentation-rhdh \
    -o rhdh-product-docs-plaintext/${RHDH_VERSION} \
    -t rhdh-docs-topic-map/rhdh_topic_map.yaml
