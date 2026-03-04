-- Migration: V3 - Create sessions table
--
-- Stores server-side session records for refresh-token rotation.
-- The raw refresh token is sent to the client (as an HttpOnly cookie or
-- response body). Only the SHA-256 hash is persisted here so that a DB
-- dump cannot be used to hijack live sessions.
--
-- Flow:
--   1. On login, generate a cryptographically random token, hash it, insert a row.
--   2. On token refresh, look up by token_hash, verify not revoked/expired,
--      issue a new token, rotate (revoke old row, insert new row).
--   3. On logout, set revoked_at = now().

CREATE TABLE sessions (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,

    -- SHA-256 hex digest of the raw refresh token issued to the client.
    token_hash    TEXT        NOT NULL UNIQUE,

    -- Absolute expiry enforced on every use regardless of activity.
    expires_at    TIMESTAMPTZ NOT NULL,

    -- NULL while the session is active; set on explicit logout or rotation.
    revoked_at    TIMESTAMPTZ,

    -- Audit / anomaly-detection context captured at session creation.
    ip_address    INET,
    user_agent    TEXT,

    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Primary access pattern: validate a token on every API request.
CREATE INDEX idx_sessions_token_hash
    ON sessions (token_hash);

-- Find all active sessions for a user (profile page / admin view).
CREATE INDEX idx_sessions_user_id_active
    ON sessions (user_id)
    WHERE revoked_at IS NULL;

-- Periodic cleanup job: find sessions to expire.
CREATE INDEX idx_sessions_expires_at
    ON sessions (expires_at)
    WHERE revoked_at IS NULL;

COMMENT ON TABLE  sessions                IS 'Server-side refresh-token records; enables token rotation and forced logout.';
COMMENT ON COLUMN sessions.token_hash     IS 'SHA-256 hash of the raw token given to the client; never store the raw token.';
COMMENT ON COLUMN sessions.revoked_at     IS 'Set on logout or rotation; NULL = session is still valid (subject to expires_at).';
