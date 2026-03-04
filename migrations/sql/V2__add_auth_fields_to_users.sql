-- Migration: V2 - Add authentication fields to users
--
-- Passwords are NEVER stored in plain text. The application is responsible for
-- hashing with bcrypt/argon2 before writing to password_hash.
-- Sensitive tokens (password reset) are stored as SHA-256 hashes so that a
-- database read alone cannot be used to reset a victim's password.

ALTER TABLE users
    ADD COLUMN password_hash         TEXT,
    ADD COLUMN email_verified_at     TIMESTAMPTZ,
    ADD COLUMN failed_login_count    SMALLINT    NOT NULL DEFAULT 0,
    ADD COLUMN locked_at             TIMESTAMPTZ,
    ADD COLUMN last_login_at         TIMESTAMPTZ,
    -- SHA-256 hex digest of the raw reset token sent to the user's email.
    ADD COLUMN password_reset_token  TEXT        UNIQUE,
    ADD COLUMN password_reset_exp_at TIMESTAMPTZ;

-- Fast lookup when validating a password-reset link.
CREATE INDEX idx_users_password_reset_token
    ON users (password_reset_token)
    WHERE password_reset_token IS NOT NULL;

-- Efficiently find locked or unverified accounts during audits.
CREATE INDEX idx_users_locked_at
    ON users (locked_at)
    WHERE locked_at IS NOT NULL;

COMMENT ON COLUMN users.password_hash         IS 'Argon2id/bcrypt hash of the user''s password; NULL for SSO-only accounts.';
COMMENT ON COLUMN users.email_verified_at     IS 'Timestamp when the user confirmed their email address; NULL = unverified.';
COMMENT ON COLUMN users.failed_login_count    IS 'Consecutive failed login attempts since last success; reset on success.';
COMMENT ON COLUMN users.locked_at             IS 'Non-NULL when the account is locked due to too many failed attempts.';
COMMENT ON COLUMN users.password_reset_token  IS 'SHA-256 hash of the single-use reset token; NULL when not in a reset flow.';
COMMENT ON COLUMN users.password_reset_exp_at IS 'Expiry of the active password-reset token; checked before redemption.';
