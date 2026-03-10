"""Application-level field encryption for sensitive data (SEC-5, SEC-6).

Encrypts RTSP URLs (with credentials), webhook secrets, and API keys stored
in the database. Uses Fernet (AES-128-CBC + HMAC-SHA256) with support for
key rotation: encrypts with the newest key, decrypts by trying all keys.

Key rotation workflow:
1. Generate a new Fernet key: ``Fernet.generate_key()``
2. Prepend it to the ENCRYPTION_KEYS list (comma-separated env var)
3. Deploy — new writes use the new key, old ciphertext still decryptable
4. Run ``FieldEncryptor.re_encrypt(old_ciphertext)`` on existing rows
5. After migration, remove the old key
"""

from __future__ import annotations

import os
from typing import Sequence

from cryptography.fernet import Fernet, InvalidToken, MultiFernet


class FieldEncryptor:
    """Encrypt/decrypt sensitive database fields with key rotation support.

    Parameters
    ----------
    keys : sequence of Fernet key bytes/strings
        Ordered newest-first. The first key is used for encryption;
        all keys are tried for decryption.
    """

    def __init__(self, keys: Sequence[str | bytes]) -> None:
        if not keys:
            raise ValueError("At least one encryption key is required")
        fernet_instances = []
        for k in keys:
            raw = k.encode() if isinstance(k, str) else k
            fernet_instances.append(Fernet(raw))
        self._multi = MultiFernet(fernet_instances)
        self._primary = fernet_instances[0]

    @classmethod
    def from_env(cls, env_var: str = "ENCRYPTION_KEYS") -> "FieldEncryptor":
        """Create from a comma-separated environment variable of Fernet keys."""
        raw = os.environ.get(env_var, "")
        if not raw:
            raise ValueError(
                f"Environment variable {env_var} is not set. "
                "Generate a key with: python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
            )
        keys = [k.strip() for k in raw.split(",") if k.strip()]
        return cls(keys)

    def encrypt(self, plaintext: str) -> str:
        """Encrypt a string field, returning a URL-safe base64 token."""
        return self._multi.encrypt(plaintext.encode("utf-8")).decode("ascii")

    def decrypt(self, ciphertext: str) -> str:
        """Decrypt a token, trying all keys in order.

        Raises ``InvalidToken`` if no key can decrypt.
        """
        return self._multi.decrypt(ciphertext.encode("ascii")).decode("utf-8")

    def re_encrypt(self, ciphertext: str) -> str:
        """Decrypt with any key and re-encrypt with the primary (newest) key.

        Use during key rotation to migrate existing ciphertext.
        """
        return self._multi.rotate(ciphertext.encode("ascii")).decode("ascii")

    def is_encrypted(self, value: str) -> bool:
        """Heuristic check: Fernet tokens start with 'gAAAAA'."""
        return value.startswith("gAAAAA") and len(value) > 100

    @staticmethod
    def generate_key() -> str:
        """Generate a new Fernet key suitable for ENCRYPTION_KEYS."""
        return Fernet.generate_key().decode("ascii")
