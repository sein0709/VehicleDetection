"""Tests for the FieldEncryptor (SEC-5, SEC-6)."""

from __future__ import annotations

import pytest
from cryptography.fernet import Fernet, InvalidToken

from shared_contracts.encryption import FieldEncryptor


@pytest.fixture
def key() -> str:
    return Fernet.generate_key().decode()


@pytest.fixture
def encryptor(key: str) -> FieldEncryptor:
    return FieldEncryptor([key])


class TestFieldEncryptor:
    def test_encrypt_decrypt_roundtrip(self, encryptor: FieldEncryptor) -> None:
        plaintext = "rtsp://admin:secret@192.168.1.100/stream"
        ciphertext = encryptor.encrypt(plaintext)
        assert ciphertext != plaintext
        assert encryptor.decrypt(ciphertext) == plaintext

    def test_encrypt_produces_different_ciphertext(self, encryptor: FieldEncryptor) -> None:
        plaintext = "webhook-secret-123"
        ct1 = encryptor.encrypt(plaintext)
        ct2 = encryptor.encrypt(plaintext)
        assert ct1 != ct2  # Fernet includes timestamp + IV

    def test_decrypt_invalid_token_raises(self, encryptor: FieldEncryptor) -> None:
        with pytest.raises(InvalidToken):
            encryptor.decrypt("not-a-valid-token")

    def test_is_encrypted_heuristic(self, encryptor: FieldEncryptor) -> None:
        # Use longer plaintext so ciphertext exceeds 100 chars (heuristic threshold)
        ciphertext = encryptor.encrypt("x" * 50)
        assert encryptor.is_encrypted(ciphertext)
        assert not encryptor.is_encrypted("plain-text-value")
        assert not encryptor.is_encrypted("")

    def test_generate_key_produces_valid_key(self) -> None:
        key = FieldEncryptor.generate_key()
        enc = FieldEncryptor([key])
        assert enc.decrypt(enc.encrypt("test")) == "test"

    def test_empty_keys_raises(self) -> None:
        with pytest.raises(ValueError, match="At least one"):
            FieldEncryptor([])


class TestKeyRotation:
    def test_decrypt_with_old_key(self) -> None:
        old_key = Fernet.generate_key().decode()
        new_key = Fernet.generate_key().decode()

        old_enc = FieldEncryptor([old_key])
        ciphertext = old_enc.encrypt("secret-data")

        rotated_enc = FieldEncryptor([new_key, old_key])
        assert rotated_enc.decrypt(ciphertext) == "secret-data"

    def test_encrypt_uses_newest_key(self) -> None:
        old_key = Fernet.generate_key().decode()
        new_key = Fernet.generate_key().decode()

        rotated_enc = FieldEncryptor([new_key, old_key])
        ciphertext = rotated_enc.encrypt("new-data")

        new_only = FieldEncryptor([new_key])
        assert new_only.decrypt(ciphertext) == "new-data"

    def test_re_encrypt_migrates_to_new_key(self) -> None:
        old_key = Fernet.generate_key().decode()
        new_key = Fernet.generate_key().decode()

        old_enc = FieldEncryptor([old_key])
        old_ct = old_enc.encrypt("migrate-me")

        rotated_enc = FieldEncryptor([new_key, old_key])
        new_ct = rotated_enc.re_encrypt(old_ct)

        new_only = FieldEncryptor([new_key])
        assert new_only.decrypt(new_ct) == "migrate-me"

    def test_old_key_only_cannot_decrypt_new(self) -> None:
        old_key = Fernet.generate_key().decode()
        new_key = Fernet.generate_key().decode()

        new_enc = FieldEncryptor([new_key])
        ciphertext = new_enc.encrypt("new-only")

        old_only = FieldEncryptor([old_key])
        with pytest.raises(InvalidToken):
            old_only.decrypt(ciphertext)


class TestFromEnv:
    def test_from_env_missing_var_raises(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("ENCRYPTION_KEYS", raising=False)
        with pytest.raises(ValueError, match="not set"):
            FieldEncryptor.from_env()

    def test_from_env_with_keys(self, monkeypatch: pytest.MonkeyPatch) -> None:
        k1 = Fernet.generate_key().decode()
        k2 = Fernet.generate_key().decode()
        monkeypatch.setenv("ENCRYPTION_KEYS", f"{k1},{k2}")
        enc = FieldEncryptor.from_env()
        assert enc.decrypt(enc.encrypt("env-test")) == "env-test"
