-- Migration: V5 - Seed built-in roles and permissions
--
-- These rows are the source of truth for platform-defined access control.
-- Application code should reference roles/permissions by their stable `name`
-- / (resource, action) pair, never by generated UUID.
--
-- ON CONFLICT DO NOTHING makes this idempotent; re-running the migration
-- after an out-of-band INSERT will not raise an error.

-- ---------------------------------------------------------------------------
-- Built-in roles
-- ---------------------------------------------------------------------------
INSERT INTO roles (id, name, description, is_system) VALUES
    ('00000000-0000-0000-0000-000000000001', 'super_admin',
        'Unrestricted access to every resource and action.',           true),
    ('00000000-0000-0000-0000-000000000002', 'admin',
        'Full access to application resources; cannot manage platform settings.', true),
    ('00000000-0000-0000-0000-000000000003', 'editor',
        'Can read and write application data but cannot manage users or roles.', true),
    ('00000000-0000-0000-0000-000000000004', 'viewer',
        'Read-only access to application data.',                       true)
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Built-in permissions  (resource × action matrix)
-- ---------------------------------------------------------------------------
INSERT INTO permissions (resource, action, description) VALUES
    -- User management
    ('users', 'read',   'List and view user profiles'),
    ('users', 'write',  'Create and update user profiles'),
    ('users', 'delete', 'Deactivate or permanently delete users'),

    -- Role & permission management
    ('roles',       'read',   'View role definitions and assignments'),
    ('roles',       'write',  'Create, update, and assign roles'),
    ('roles',       'delete', 'Remove role definitions'),
    ('permissions', 'read',   'View permission definitions'),
    ('permissions', 'write',  'Create and update permissions'),

    -- Session management
    ('sessions', 'read',   'View active sessions for any user (admin)'),
    ('sessions', 'revoke', 'Forcefully revoke any active session'),

    -- Application domain resources

    -- Wildcard for super-admin (evaluated first in the permission check)
    ('*', '*', 'Full unrestricted access — super-admin only')
ON CONFLICT (resource, action) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Role → permission assignments
-- ---------------------------------------------------------------------------

-- super_admin: wildcard (*:*)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM   roles r, permissions p
WHERE  r.name = 'super_admin'
AND    p.resource = '*' AND p.action = '*'
ON CONFLICT DO NOTHING;

-- admin: everything except wildcard
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM   roles r
JOIN   permissions p ON p.resource <> '*'
WHERE  r.name = 'admin'
ON CONFLICT DO NOTHING;

-- editor: read + write on domain resources (no user/role/permission management)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM   roles r
JOIN   permissions p
       ON  p.resource IN ('orders', 'invoices')
       AND p.action   IN ('read', 'write')
WHERE  r.name = 'editor'
ON CONFLICT DO NOTHING;

-- viewer: read-only on domain resources
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM   roles r
JOIN   permissions p
       ON  p.resource IN ('orders', 'invoices')
       AND p.action   = 'read'
WHERE  r.name = 'viewer'
ON CONFLICT DO NOTHING;
