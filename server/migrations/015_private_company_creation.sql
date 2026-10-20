ALTER TABLE users ADD COLUMN can_create_companies BOOLEAN NOT NULL DEFAULT FALSE;
-- Preserve existing owners and the not-yet-configured initial account. An
-- invited member keeps access to their assigned firms only, even after revoke.
UPDATE users u SET can_create_companies=TRUE WHERE
 EXISTS(SELECT 1 FROM memberships m WHERE m.user_id=u.id AND m.role='owner') OR
 (NOT EXISTS(SELECT 1 FROM memberships m WHERE m.user_id=u.id) AND
  NOT EXISTS(SELECT 1 FROM company_invitations i WHERE i.accepted_by=u.id));
INSERT INTO schema_versions VALUES(16);
