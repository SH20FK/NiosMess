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
