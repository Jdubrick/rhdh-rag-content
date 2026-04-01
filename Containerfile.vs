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
ARG BASE_IMAGE=quay.io/lightspeed-core/rag-content-cpu@sha256:297db4e12b07dcf460b1b5186764f32b6bb41841d77d085aa5e650e30f7b9031
FROM ${BASE_IMAGE} AS lightspeed-core-rag-builder
ARG RHDH_DOCS_VERSION="1.9"
ARG NUM_WORKERS=1

USER 0
WORKDIR /rag-content

RUN python -c "import nltk; nltk.download('stopwords')"

# The upstream GPU image does not include git; install it if missing.
RUN if ! command -v git > /dev/null 2>&1; then \
        (dnf install -y --nodocs --setopt=keepcache=0 git || \
         microdnf install -y --nodocs --setopt=keepcache=0 git) && \
        (dnf clean all 2>/dev/null || microdnf clean all 2>/dev/null || true); \
    fi

COPY scripts/ .
# Modify script inplace to account for new path
RUN sed -i 's/scripts\///' get_rhdh_plaintext_docs.sh
RUN ./get_rhdh_plaintext_docs.sh $RHDH_DOCS_VERSION

RUN set -e && for RHDH_VERSION in $(ls -1 rhdh-product-docs-plaintext); do \
        python ./generate_embeddings_rhdh.py \
            -f rhdh-product-docs-plaintext/${RHDH_VERSION} \
            -md embeddings_model \
            -mn ${EMBEDDING_MODEL} \
            -o vector_db/rhdh_product_docs/${RHDH_VERSION} \
            -w ${NUM_WORKERS} \
            -i rhdh-product-docs-$(echo $RHDH_VERSION | sed 's/\./_/g') \
            -t rhdh-docs-topic-map/rhdh_topic_map.yaml \
            --vector-store-type=llamastack-faiss \
            -v ${RHDH_VERSION}; \
    done

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.7@sha256:161a4e29ea482bab6048c2b36031b4f302ae81e4ff18b83e61785f40dc576f5d
COPY --from=lightspeed-core-rag-builder /rag-content/vector_db/rhdh_product_docs /rag/vector_db/rhdh_product_docs

USER 65532:65532
