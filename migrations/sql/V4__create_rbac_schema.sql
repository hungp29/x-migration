-- Migration: V4 - RBAC core schema
--
-- Model: User → (many) UserRole → Role → (many) RolePermission → Permission
--
-- A Permission encodes a single capability as (resource, action) pairs, e.g.
--   resource = 'orders',  action = 'read'
--   resource = 'invoices', action = 'write'
--   resource = '*',        action = '*'   -- super-admin wildcard (checked in app layer)
--
-- Roles bundle permissions and are assigned to users, optionally with an
-- expiry date (useful for time-boxed elevated access).

-- ---------------------------------------------------------------------------
-- roles
-- ---------------------------------------------------------------------------
CREATE TABLE roles (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    -- System-managed roles cannot be renamed or deleted via the API.
    is_system   BOOLEAN     NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  roles           IS 'Named roles that bundle a set of permissions (e.g. admin, editor, viewer).';
COMMENT ON COLUMN roles.is_system IS 'True for built-in roles seeded by the platform; prevents accidental deletion.';

-- ---------------------------------------------------------------------------
-- permissions
-- ---------------------------------------------------------------------------
CREATE TABLE permissions (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resource    VARCHAR(100) NOT NULL,
    action      VARCHAR(100) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- A (resource, action) pair must be globally unique.
    CONSTRAINT uq_permissions_resource_action UNIQUE (resource, action)
);

COMMENT ON TABLE  permissions          IS 'Fine-grained capability descriptors: (resource, action) pairs.';
COMMENT ON COLUMN permissions.resource IS 'Domain object the permission applies to, e.g. "orders", "invoices", "*".';
COMMENT ON COLUMN permissions.action   IS 'Operation allowed, e.g. "read", "write", "delete", "*".';

-- ---------------------------------------------------------------------------
-- role_permissions  (Role ↔ Permission junction)
-- ---------------------------------------------------------------------------
CREATE TABLE role_permissions (
    role_id       UUID        NOT NULL REFERENCES roles       (id) ON DELETE CASCADE,
    permission_id UUID        NOT NULL REFERENCES permissions (id) ON DELETE CASCADE,
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    granted_by    UUID        REFERENCES users (id) ON DELETE SET NULL,

    PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_permission_id ON role_permissions (permission_id);

COMMENT ON TABLE role_permissions IS 'Many-to-many mapping of permissions to roles.';

-- ---------------------------------------------------------------------------
-- user_roles  (User ↔ Role assignment)
-- ---------------------------------------------------------------------------
CREATE TABLE user_roles (
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role_id    UUID        NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    granted_by UUID        REFERENCES users (id) ON DELETE SET NULL,
    -- NULL = permanent; non-NULL = access auto-expires at this timestamp.
    expires_at TIMESTAMPTZ,

    PRIMARY KEY (user_id, role_id)
);

-- Efficient lookup of all roles for a given user (hot path on every request).
CREATE INDEX idx_user_roles_user_id ON user_roles (user_id);

-- Find all users that hold a particular role (admin dashboard).
CREATE INDEX idx_user_roles_role_id ON user_roles (role_id);

-- Expiry sweep: find assignments that have lapsed.
CREATE INDEX idx_user_roles_expires_at
    ON user_roles (expires_at)
    WHERE expires_at IS NOT NULL;

COMMENT ON TABLE  user_roles           IS 'Assigns roles to users, optionally with an expiry for time-boxed access.';
COMMENT ON COLUMN user_roles.granted_by IS 'User who granted this role assignment; NULL if seeded or via automation.';
COMMENT ON COLUMN user_roles.expires_at IS 'When set, the role assignment is invalid after this timestamp.';

-- ---------------------------------------------------------------------------
-- updated_at trigger for roles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
