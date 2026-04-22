-- migrations/002-passwords.sql
-- Add password hashing support to users table.
-- Nullable initially so existing users aren't locked out during migration.
-- Use set-password.rkt to set passwords for all users before going live.

ALTER TABLE users ADD COLUMN password_hash TEXT;
