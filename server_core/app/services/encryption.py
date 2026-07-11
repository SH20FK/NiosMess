"""AES-256-GCM symmetric encryption."""
import base64, os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app.config import settings

def _key() -> bytes:
    raw = settings.ENCRYPTION_KEY.encode("utf-8")
    return (raw + b"\x00" * 32)[:32]

def encrypt_text(plaintext: str) -> dict:
    iv = os.urandom(12)
    ct_tag = AESGCM(_key()).encrypt(iv, plaintext.encode(), None)
    ct, tag = ct_tag[:-16], ct_tag[-16:]
    return {
        "ciphertext": base64.b64encode(ct).decode(),
        "iv": base64.b64encode(iv).decode(),
        "tag": base64.b64encode(tag).decode(),
    }

def decrypt_text(ciphertext_b64: str, iv_b64: str, tag_b64: str) -> str:
    ct = base64.b64decode(ciphertext_b64)
    iv = base64.b64decode(iv_b64)
    tag = base64.b64decode(tag_b64)
    return AESGCM(_key()).decrypt(iv, ct + tag, None).decode()

def encrypt_bytes(data: bytes):
    iv = os.urandom(12)
    ct_tag = AESGCM(_key()).encrypt(iv, data, None)
    return ct_tag[:-16], iv, ct_tag[-16:]

def decrypt_bytes(ciphertext: bytes, iv: bytes, tag: bytes) -> bytes:
    return AESGCM(_key()).decrypt(iv, ciphertext + tag, None)

# ── Per-connection encryption (WebSocket transport encryption) ──────────────

def generate_connection_key() -> str:
    """Generate a random 32-byte AES key for a new connection, return as base64."""
    return base64.b64encode(os.urandom(32)).decode('ascii')

def encrypt_with_key(plaintext: str, key_b64: str) -> dict:
    """Encrypt text with a specific key (per-connection). Returns dict with ciphertext, iv, tag."""
    key = base64.b64decode(key_b64)
    iv = os.urandom(12)
    ct_tag = AESGCM(key).encrypt(iv, plaintext.encode('utf-8'), None)
    ct, tag = ct_tag[:-16], ct_tag[-16:]
    return {
        "ciphertext": base64.b64encode(ct).decode('ascii'),
        "iv": base64.b64encode(iv).decode('ascii'),
        "tag": base64.b64encode(tag).decode('ascii'),
    }

def decrypt_with_key(ciphertext_b64: str, iv_b64: str, tag_b64: str, key_b64: str) -> str:
    """Decrypt text with a specific key (per-connection)."""
    key = base64.b64decode(key_b64)
    ct = base64.b64decode(ciphertext_b64)
    iv = base64.b64decode(iv_b64)
    tag = base64.b64decode(tag_b64)
    return AESGCM(key).decrypt(iv, ct + tag, None).decode('utf-8')

def encrypt_payload_with_key(payload: dict, key_b64: str) -> dict:
    """Encrypt an entire JSON payload with per-connection key."""
    json_str = base64.b64encode(__import__('json').dumps(payload).encode('utf-8')).decode('ascii')
    return encrypt_with_key(json_str, key_b64)

def decrypt_payload_with_key(encrypted: dict, key_b64: str) -> dict:
    """Decrypt an encrypted payload back to the original dict."""
    json_str = decrypt_with_key(encrypted["ciphertext"], encrypted["iv"], encrypted["tag"], key_b64)
    return __import__('json').loads(base64.b64decode(json_str).decode('utf-8'))

# ── File encryption (for media files on disk) ────────────────────────────────

def encrypt_file(input_path: str, output_path: str) -> dict:
    """Encrypt a file on disk using AES-256-GCM. Returns iv and tag."""
    with open(input_path, 'rb') as f:
        plaintext = f.read()

    ciphertext, iv, tag = encrypt_bytes(plaintext)

    with open(output_path, 'wb') as f:
        f.write(ciphertext)

    return {
        "iv": base64.b64encode(iv).decode('ascii'),
        "tag": base64.b64encode(tag).decode('ascii'),
    }

def decrypt_file(input_path: str, output_path: str, iv_b64: str, tag_b64: str):
    """Decrypt a file on disk using AES-256-GCM."""
    with open(input_path, 'rb') as f:
        ciphertext = f.read()

    iv = base64.b64decode(iv_b64)
    tag = base64.b64decode(tag_b64)

    plaintext = decrypt_bytes(ciphertext, iv, tag)

    with open(output_path, 'wb') as f:
        f.write(plaintext)

def decrypt_file_to_bytes(file_path: str, iv_b64: str, tag_b64: str) -> bytes:
    """Decrypt a file and return plaintext bytes without writing to disk."""
    with open(file_path, 'rb') as f:
        ciphertext = f.read()

    iv = base64.b64decode(iv_b64)
    tag = base64.b64decode(tag_b64)

    return decrypt_bytes(ciphertext, iv, tag)
