import os
import time
import requests

LLAMA_STACK_URL = os.getenv("LLAMA_STACK_URL", "http://localhost:8321")
DOCS_DIR = os.getenv("DOCS_DIR", "/product_docs")
MAX_WAIT_SECONDS = int(os.getenv("MAX_WAIT_SECONDS", "120"))
DEFAULT_VECTOR_STORE_NAME = "rhdh-product-docs"

def wait_for_llama_stack():
    deadline = time.time() + MAX_WAIT_SECONDS

    while time.time() < deadline:
        try:
            r = requests.get(f"{LLAMA_STACK_URL}/v1/health", timeout=5)
            if r.status_code == 200:
                print("Llama Stack is ready.")
                return
        except requests.RequestException:
            pass

        print("Waiting for Llama Stack...")
        time.sleep(5)

    raise RuntimeError("Timed out waiting for Llama Stack")

def upload_file(path):
    with open(path, "rb") as f:
        resp = requests.post(
            f"{LLAMA_STACK_URL}/v1/files",
            files={"file": f},
            data={"purpose": "assistants"},
            timeout=60,
        )
    resp.raise_for_status()
    return resp.json()

def upload_all_files():
    all_ids = []
    for root, _, files in os.walk(DOCS_DIR):
        for fname in files:
            if not fname.endswith(".txt"):
                continue

            path = os.path.join(root, fname)
            print(f"Uploading {path}...")

            result = upload_file(path)
            file_id = result['id']
            all_ids.append(file_id)
            print(f"---> file_id={file_id}")
    return all_ids

def register_vector_store():

    resp = requests.post(
            f"{LLAMA_STACK_URL}/v1/vector_stores",
            json={
                "name": DEFAULT_VECTOR_STORE_NAME,
                "embedding_model": "sentence-transformers//app-root/embeddings_model",
                "embedding_dimension": 768
            },
            timeout=60,
        )
    resp.raise_for_status()
    return resp.json().get("id")

def attach_files_to_vector_store(vector_store_id, files):
    resp = requests.post(
            f"{LLAMA_STACK_URL}/v1/vector_stores/{vector_store_id}/file_batches",
            json={
                "file_ids": files,
                "attributes": {},
                "chunking_strategy": {
                    "type": "auto"
                }
            },
            timeout=60,
        )
    resp.raise_for_status()
    return resp.json()

def vector_store_present(vector_store_name):

    resp = requests.get(
        f"{LLAMA_STACK_URL}/v1/vector_stores",
    )
    resp.raise_for_status()
    if resp.status_code == 200:
        all_vector_stores = resp.json().get("data", [])
        for store in all_vector_stores:
            if store.get("name", "") == vector_store_name:
                print(f"Vector Store '{vector_store_name}' already present. Skipping creation ...")
                return True
    
    return False

def main():
    wait_for_llama_stack()
    if vector_store_present(DEFAULT_VECTOR_STORE_NAME):
        return
    all_file_ids = upload_all_files()
    vector_store_id = register_vector_store()
    attach_files_to_vector_store(vector_store_id, all_file_ids)

if __name__ == "__main__":
    main()
