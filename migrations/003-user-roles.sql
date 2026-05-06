-- migrations/003-user-roles.sql
-- Add role column to users.
-- 'editor' can create, edit, and delete entries.
-- 'viewer' can only read.
-- Existing users default to 'editor'.

ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'editor';

-- Set guest to viewer.
UPDATE users SET role = 'viewer' WHERE name = 'guest';
