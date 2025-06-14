-- ---------------------------------------------------------------------------
-- Spyro Devnet — Postgres bootstrap
-- This script is executed automatically by the official postgres image when
-- placed in /docker-entrypoint-initdb.d/ (read-only mount).
-- ---------------------------------------------------------------------------

-- 1. Create a dedicated role for Spyro-Node with password authentication
CREATE ROLE spyro WITH LOGIN PASSWORD 'spyro';

-- 2. Create the primary database owned by that role
CREATE DATABASE spyro OWNER spyro;

-- 3. Grant privileges (future-proof for additional schemas)
GRANT ALL PRIVILEGES ON DATABASE spyro TO spyro;

-- 4. In case you later add multiple schemas, ensure role can CREATE
ALTER ROLE spyro CREATEDB;
