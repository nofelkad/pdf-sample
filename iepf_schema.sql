-- ============================================================================
-- Unclaimed Investment / IEPF Recovery Platform — Module 1 (Shareholder Data)
-- Enterprise PostgreSQL schema
--
-- Target: PostgreSQL 16+  (15 works; security_invoker views require >= 15)
-- Prerequisites:
--   * Run as a superuser (or a role allowed to CREATE EXTENSION / CREATE ROLE)
--   * Extensions: pg_trgm (fuzzy search), pgcrypto (gen_random_uuid on PG<13,
--     and field-level encryption helpers)
--
-- Conventions:
--   * snake_case everywhere; singular table names
--   * PK column: id | constraint names: pk_/fk_/uq_/ck_ prefixes
--   * index names: ix_<table>__<cols>, unique: uq_<table>__<cols>
--   * tenant-owned tables: tenant_id UUID NOT NULL + RLS (FORCED)
--   * schemas: reference (shared), app (tenant OLTP), staging (imports),
--     audit (change history), analytics (reporting objects)
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. Extensions, schemas, roles
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS reference;
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA reference IS 'Shared, tenant-agnostic reference data (geo, securities, lookups). Read-only for application roles.';
COMMENT ON SCHEMA app       IS 'Tenant-owned OLTP data. Every table carries tenant_id and is protected by forced RLS.';
COMMENT ON SCHEMA staging   IS 'Raw import landing zone (all-text). Data is validated/cleansed here before promotion to app.*';
COMMENT ON SCHEMA audit     IS 'Append-only change history.';
COMMENT ON SCHEMA analytics IS 'Materialized views and reporting objects. Accessed via tenant-filtering views only.';

-- Roles (NOLOGIN group roles; actual login users are granted membership).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
    CREATE ROLE app_rw NOLOGIN;                      -- application read/write (RLS-bound)
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_ro') THEN
    CREATE ROLE app_ro NOLOGIN;                      -- reporting / read-only (RLS-bound)
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_price_loader') THEN
    CREATE ROLE svc_price_loader NOLOGIN;            -- weekly NSE/BSE price sync job
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_import') THEN
    CREATE ROLE svc_import NOLOGIN;                  -- ETL / import pipeline
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'platform_admin') THEN
    CREATE ROLE platform_admin NOLOGIN BYPASSRLS;    -- cross-tenant support/ops (break-glass)
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 1. Session context helpers
--    The application sets, per transaction (never per connection when pooled):
--      SELECT set_config('app.current_tenant',  '<tenant uuid>', true);
--      SELECT set_config('app.current_user_id', '<user uuid>',   true);
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.current_tenant_id() RETURNS uuid
LANGUAGE sql STABLE PARALLEL SAFE
AS $$ SELECT NULLIF(current_setting('app.current_tenant', true), '')::uuid $$;

CREATE OR REPLACE FUNCTION app.current_user_id() RETURNS uuid
LANGUAGE sql STABLE PARALLEL SAFE
AS $$ SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid $$;

COMMENT ON FUNCTION app.current_tenant_id() IS 'Tenant context for RLS. NULL (no context) matches no rows — fail closed.';

-- Generic audit-column trigger: bumps updated_at / row_version on UPDATE.
CREATE OR REPLACE FUNCTION app.tg_touch_row() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at  := now();
  NEW.updated_by  := COALESCE(NEW.updated_by, app.current_user_id());
  NEW.row_version := OLD.row_version + 1;
  RETURN NEW;
END $$;

-- ----------------------------------------------------------------------------
-- 2. reference schema — shared lookups (no tenant_id, no RLS)
-- ----------------------------------------------------------------------------

CREATE TABLE reference.country (
  id          smallint GENERATED ALWAYS AS IDENTITY,
  iso2        char(2),
  name        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_country PRIMARY KEY (id),
  CONSTRAINT uq_country__name UNIQUE (name),
  CONSTRAINT uq_country__iso2 UNIQUE (iso2),
  CONSTRAINT ck_country__name_not_blank CHECK (btrim(name) <> '')
);
COMMENT ON TABLE reference.country IS 'Country master (source: ISO 3166). Cleansed geo columns FK here.';

CREATE TABLE reference.state (
  id          smallint GENERATED ALWAYS AS IDENTITY,
  country_id  smallint NOT NULL,
  name        text NOT NULL,
  short_code  text,
  CONSTRAINT pk_state PRIMARY KEY (id),
  CONSTRAINT fk_state__country FOREIGN KEY (country_id) REFERENCES reference.country (id),
  CONSTRAINT uq_state__country_name UNIQUE (country_id, name)
);
COMMENT ON TABLE reference.state IS 'State/province master, maintained from government lists (requirement: "updated by latest list as per govt data").';

CREATE TABLE reference.district (
  id        integer GENERATED ALWAYS AS IDENTITY,
  state_id  smallint NOT NULL,
  name      text NOT NULL,
  CONSTRAINT pk_district PRIMARY KEY (id),
  CONSTRAINT fk_district__state FOREIGN KEY (state_id) REFERENCES reference.state (id),
  CONSTRAINT uq_district__state_name UNIQUE (state_id, name)
);

-- India Post directory: one row per (pincode, locality). Drives the
-- requirement "blank state/district/locality automatically filled by system as per pincode".
CREATE TABLE reference.postal_index (
  id           integer GENERATED ALWAYS AS IDENTITY,
  country_id   smallint NOT NULL,
  pincode      text NOT NULL,
  locality     text,
  district_id  integer,
  state_id     smallint,
  CONSTRAINT pk_postal_index PRIMARY KEY (id),
  CONSTRAINT fk_postal_index__country  FOREIGN KEY (country_id)  REFERENCES reference.country (id),
  CONSTRAINT fk_postal_index__district FOREIGN KEY (district_id) REFERENCES reference.district (id),
  CONSTRAINT fk_postal_index__state    FOREIGN KEY (state_id)    REFERENCES reference.state (id),
  CONSTRAINT ck_postal_index__pincode_format CHECK (pincode ~ '^[0-9A-Za-z -]{3,10}$')
);
CREATE UNIQUE INDEX uq_postal_index__country_pin_locality
  ON reference.postal_index (country_id, pincode, COALESCE(locality, ''));
CREATE INDEX ix_postal_index__pincode ON reference.postal_index (pincode);

-- Listed-security master (shared: prices are public facts, fetched once for all tenants).
CREATE TABLE reference.security (
  id           bigint GENERATED ALWAYS AS IDENTITY,
  legal_name   text NOT NULL,
  isin         char(12),
  nse_symbol   text,
  bse_code     text,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_security PRIMARY KEY (id),
  CONSTRAINT uq_security__isin UNIQUE (isin),
  CONSTRAINT ck_security__isin_format CHECK (isin IS NULL OR isin ~ '^[A-Z]{2}[A-Z0-9]{9}[0-9]$')
);
COMMENT ON TABLE reference.security IS 'Listed-company/security master (ISIN, exchange symbols). Weekly price sync keys off this table.';

-- Price history: append-only time series, one row per security per pricing date.
-- Populated by the scheduled job ("system will update the price every Saturday night").
CREATE TABLE reference.security_price (
  security_id  bigint NOT NULL,
  price_date   date NOT NULL,
  close_price  numeric(12,2) NOT NULL,
  source       text NOT NULL DEFAULT 'NSE',
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_security_price PRIMARY KEY (security_id, price_date),
  CONSTRAINT fk_security_price__security FOREIGN KEY (security_id) REFERENCES reference.security (id),
  CONSTRAINT ck_security_price__positive CHECK (close_price > 0),
  CONSTRAINT ck_security_price__source CHECK (source IN ('NSE','BSE','MANUAL'))
);
COMMENT ON TABLE reference.security_price IS 'Weekly close-price history. Market value is ALWAYS derived from this table — never stored on records.';

CREATE OR REPLACE VIEW reference.latest_security_price AS
SELECT DISTINCT ON (security_id)
       security_id, price_date, close_price, source
FROM   reference.security_price
ORDER  BY security_id, price_date DESC;
COMMENT ON VIEW reference.latest_security_price IS 'Most recent price per security (index-backed DISTINCT ON over the PK).';

-- Investment type (MCA/IEPF-2 controlled vocabulary — lookup table, not enum:
-- the ministry adds categories over time and labels must be tenant-visible).
CREATE TABLE reference.investment_type (
  id     smallint GENERATED ALWAYS AS IDENTITY,
  code   text NOT NULL,
  label  text NOT NULL,
  CONSTRAINT pk_investment_type PRIMARY KEY (id),
  CONSTRAINT uq_investment_type__code UNIQUE (code),
  CONSTRAINT uq_investment_type__label UNIQUE (label)
);

INSERT INTO reference.investment_type (code, label) VALUES
  ('UNPAID_DIVIDEND',    'Amount for unclaimed and unpaid Dividend'),
  ('MATURED_DEPOSIT',    'Amount for matured deposits'),
  ('MATURED_DEBENTURE',  'Amount for matured debentures'),
  ('APPLICATION_REFUND', 'Amount for application money due for refund'),
  ('SHARES_TO_IEPF',     'Shares transferred to IEPF'),
  ('INTEREST_ON_ABOVE',  'Interest accrued on the above'),
  ('OTHER',              'Other unclaimed amounts');

-- Record workflow status ("Status of Shares" dropdown).
-- NOTE: 'NOT_STARTED' is an addition — the source dropdown has no initial state,
-- but a NOT NULL workflow column needs one. Flagged as an assumption.
CREATE TABLE reference.record_status (
  code         text NOT NULL,
  label        text NOT NULL,
  sort_order   smallint NOT NULL,
  is_terminal  boolean NOT NULL DEFAULT false,
  CONSTRAINT pk_record_status PRIMARY KEY (code),
  CONSTRAINT uq_record_status__label UNIQUE (label)
);

INSERT INTO reference.record_status (code, label, sort_order, is_terminal) VALUES
  ('NOT_STARTED',        'Not Started',               0, false),
  ('KYC_NOT_UPDATED',    'KYC Not Updated',          10, false),
  ('UNDER_PROCESS',      'Under Process',            20, false),
  ('PROCEDURE_ISSUED',   'Procedure Issued',         30, false),
  ('ENTITLEMENT_ISSUED', 'Entitlement Letter Issued',40, false),
  ('IEPF_FILED',         'IEPF Filed',               50, false),
  ('CLAIMED',            'Claimed',                  60, true),
  ('OTHERS',             'Others',                   90, false);

-- ----------------------------------------------------------------------------
-- 3. app schema — tenant-owned OLTP tables
-- ----------------------------------------------------------------------------

CREATE TABLE app.tenant (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL,
  status      text NOT NULL DEFAULT 'active',
  settings    jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_tenant PRIMARY KEY (id),
  CONSTRAINT uq_tenant__slug UNIQUE (slug),
  CONSTRAINT ck_tenant__slug_format CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  CONSTRAINT ck_tenant__status CHECK (status IN ('active','suspended','offboarding','deleted'))
);
COMMENT ON TABLE app.tenant IS 'One row per client organization. settings holds tenant-specific configuration (jsonb, schemaless by design).';

CREATE TABLE app.app_user (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL,
  email         text NOT NULL,
  display_name  text NOT NULL,
  user_type     text NOT NULL DEFAULT 'human',
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_app_user PRIMARY KEY (id),
  CONSTRAINT fk_app_user__tenant FOREIGN KEY (tenant_id) REFERENCES app.tenant (id),
  CONSTRAINT ck_app_user__type CHECK (user_type IN ('human','service')),
  CONSTRAINT ck_app_user__email CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);
CREATE UNIQUE INDEX uq_app_user__tenant_email ON app.app_user (tenant_id, lower(email));
COMMENT ON TABLE app.app_user IS 'Application identities per tenant, including per-tenant service accounts (user_type = service) used by system jobs for created_by/updated_by.';

-- A tenant''s registration of a company they work on. display_name is the
-- tenant''s label (source data shows "BPCL Ltd" vs legal names); the canonical
-- name lives on reference.security.
CREATE TABLE app.company (
  id           uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL,
  security_id  bigint,
  display_name text NOT NULL,
  short_code   text NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   uuid,
  row_version  integer NOT NULL DEFAULT 1,
  CONSTRAINT pk_company PRIMARY KEY (id),
  CONSTRAINT uq_company__tenant_id_id UNIQUE (tenant_id, id),          -- target for tenant-safe composite FKs
  CONSTRAINT fk_company__tenant   FOREIGN KEY (tenant_id)   REFERENCES app.tenant (id),
  CONSTRAINT fk_company__security FOREIGN KEY (security_id) REFERENCES reference.security (id),
  CONSTRAINT fk_company__created_by FOREIGN KEY (created_by) REFERENCES app.app_user (id),
  CONSTRAINT fk_company__updated_by FOREIGN KEY (updated_by) REFERENCES app.app_user (id),
  CONSTRAINT uq_company__tenant_short_code UNIQUE (tenant_id, short_code),
  CONSTRAINT uq_company__tenant_display_name UNIQUE (tenant_id, display_name),
  CONSTRAINT ck_company__short_code CHECK (short_code ~ '^[A-Z0-9]{2,6}$')
);
CREATE UNIQUE INDEX uq_company__tenant_security ON app.company (tenant_id, security_id)
  WHERE security_id IS NOT NULL;
COMMENT ON COLUMN app.company.short_code IS 'Tenant-chosen prefix (TCL, REL, ...) used to mint legacy record codes. Unique per tenant.';

-- One row per uploaded file ("Date of Preparation", "Remarks (From BI)" and the
-- dividend window are file-level facts — repeated on all 5,000 sample rows,
-- normalized out here).
CREATE TABLE app.import_batch (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL,
  company_id          uuid NOT NULL,
  source_file_name    text NOT NULL,
  source_file_sha256  text,
  prepared_on         date NOT NULL,
  dividend_year_from  smallint,
  dividend_year_to    smallint,
  analysis_remarks    text,
  status              text NOT NULL DEFAULT 'received',
  total_rows          integer,
  loaded_rows         integer,
  rejected_rows       integer,
  created_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid,
  updated_at          timestamptz NOT NULL DEFAULT now(),
  updated_by          uuid,
  row_version         integer NOT NULL DEFAULT 1,
  CONSTRAINT pk_import_batch PRIMARY KEY (id),
  CONSTRAINT uq_import_batch__tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_import_batch__tenant  FOREIGN KEY (tenant_id) REFERENCES app.tenant (id),
  CONSTRAINT fk_import_batch__company FOREIGN KEY (tenant_id, company_id)
      REFERENCES app.company (tenant_id, id),
  CONSTRAINT fk_import_batch__created_by FOREIGN KEY (created_by) REFERENCES app.app_user (id),
  CONSTRAINT fk_import_batch__updated_by FOREIGN KEY (updated_by) REFERENCES app.app_user (id),
  CONSTRAINT ck_import_batch__status CHECK (status IN ('received','validating','loaded','failed','archived')),
  CONSTRAINT ck_import_batch__year_order CHECK (
      dividend_year_from IS NULL OR dividend_year_to IS NULL
      OR dividend_year_from <= dividend_year_to)
);
CREATE UNIQUE INDEX uq_import_batch__tenant_file_hash
  ON app.import_batch (tenant_id, source_file_sha256)
  WHERE source_file_sha256 IS NOT NULL;
CREATE INDEX ix_import_batch__tenant_company ON app.import_batch (tenant_id, company_id);
COMMENT ON TABLE app.import_batch IS 'One row per imported file. The file-hash unique index makes re-imports idempotent.';

-- ============================================================================
-- CORE ENTITY: shareholder_record — one row per (company, folio/demat account)
-- ============================================================================
CREATE TABLE app.shareholder_record (
  id                        uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id                 uuid NOT NULL,
  company_id                uuid NOT NULL,
  import_batch_id           uuid,

  -- Identifiers
  record_code               text,          -- legacy "Unique Code" (short_code || padding || folio), minted at import
  folio_number              text,          -- physical-holding identifier, unique per company
  dp_account_number         text,          -- demat: DP Id - Client Id - Account Number
  folio_or_demat            text GENERATED ALWAYS AS (COALESCE(folio_number, dp_account_number)) STORED,
  investment_type_id        smallint NOT NULL,

  -- Investor identity (as printed in the company register — preserved verbatim)
  first_name                text NOT NULL,
  middle_name               text,
  last_name                 text,
  full_name                 text GENERATED ALWAYS AS (
                              btrim(regexp_replace(
                                COALESCE(first_name,'') || ' ' || COALESCE(middle_name,'') || ' ' || COALESCE(last_name,''),
                                '\s+', ' ', 'g'))) STORED,
  father_husband_first_name  text,
  father_husband_middle_name text,
  father_husband_last_name   text,
  father_husband_full_name  text GENERATED ALWAYS AS (
                              NULLIF(btrim(regexp_replace(
                                COALESCE(father_husband_first_name,'') || ' ' || COALESCE(father_husband_middle_name,'') || ' ' || COALESCE(father_husband_last_name,''),
                                '\s+', ' ', 'g')), '')) STORED,

  -- Cleansed identity (system-filled: PROPER(TRIM(...)) + corrections)
  cleaned_full_name         text,
  cleaned_father_husband_name text,

  -- KYC / PII (sensitive — see security notes; Aadhaar never stored in clear)
  date_of_birth             date,
  pan                       text,
  aadhaar_last4             text,
  aadhaar_encrypted         bytea,
  nominee_name              text,

  -- Address: raw as imported (immutable evidence) + cleansed/enriched
  address_raw               text,
  country_raw               text,
  state_raw                 text,
  district_raw              text,
  pincode_raw               text,
  cleaned_address           text,
  locality                  text,
  cleaned_pincode           text,
  country_id                smallint,
  state_id                  smallint,
  district_id               integer,
  geo_enriched_at           timestamptz,

  -- Holding / dividend facts from file preparation
  dividend_count            smallint NOT NULL,
  dividend_shares           integer NOT NULL,   -- "Final No Shares (Dividend)" — basis for market value
  shareholder_shares        integer NOT NULL,   -- "Final No of Shares (Shareholder)"
  shares_type               text NOT NULL,      -- iepf | non_iepf | suspense (classification at prep time)
  proposed_iepf_transfer_date date,
  under_litigation          boolean,            -- NULL = not yet assessed
  from_unpaid_suspense      boolean,            -- NULL = not yet assessed
  source_remarks            text,

  -- Workflow
  status_code               text NOT NULL DEFAULT 'NOT_STARTED',
  status_changed_at         timestamptz,
  status_changed_by         uuid,

  -- Validated share breakdown (user-verified during processing; NULL until verified)
  iepf_share_count          integer,
  non_iepf_share_count      integer,
  suspense_share_count      integer,
  total_share_count         integer GENERATED ALWAYS AS
                              (iepf_share_count + non_iepf_share_count + suspense_share_count) STORED,

  -- Full-text search document (names + father/husband + address + identifiers)
  search_tsv                tsvector GENERATED ALWAYS AS (
                              to_tsvector('simple',
                                COALESCE(cleaned_full_name,'') || ' ' ||
                                COALESCE(first_name,'')  || ' ' || COALESCE(middle_name,'') || ' ' || COALESCE(last_name,'') || ' ' ||
                                COALESCE(father_husband_first_name,'') || ' ' || COALESCE(father_husband_last_name,'') || ' ' ||
                                COALESCE(cleaned_address, address_raw, '') || ' ' ||
                                COALESCE(folio_number,'') || ' ' || COALESCE(dp_account_number,''))) STORED,

  -- Audit
  created_at                timestamptz NOT NULL DEFAULT now(),
  created_by                uuid,
  updated_at                timestamptz NOT NULL DEFAULT now(),
  updated_by                uuid,
  deleted_at                timestamptz,
  deleted_by                uuid,
  row_version               integer NOT NULL DEFAULT 1,

  CONSTRAINT pk_shareholder_record PRIMARY KEY (id),
  CONSTRAINT uq_shareholder_record__tenant_id_id UNIQUE (tenant_id, id),
  CONSTRAINT fk_shareholder_record__tenant  FOREIGN KEY (tenant_id) REFERENCES app.tenant (id),
  CONSTRAINT fk_shareholder_record__company FOREIGN KEY (tenant_id, company_id)
      REFERENCES app.company (tenant_id, id),
  CONSTRAINT fk_shareholder_record__batch   FOREIGN KEY (tenant_id, import_batch_id)
      REFERENCES app.import_batch (tenant_id, id),
  CONSTRAINT fk_shareholder_record__investment_type FOREIGN KEY (investment_type_id)
      REFERENCES reference.investment_type (id),
  CONSTRAINT fk_shareholder_record__status FOREIGN KEY (status_code)
      REFERENCES reference.record_status (code),
  CONSTRAINT fk_shareholder_record__country  FOREIGN KEY (country_id)  REFERENCES reference.country (id),
  CONSTRAINT fk_shareholder_record__state    FOREIGN KEY (state_id)    REFERENCES reference.state (id),
  CONSTRAINT fk_shareholder_record__district FOREIGN KEY (district_id) REFERENCES reference.district (id),
  CONSTRAINT fk_shareholder_record__created_by FOREIGN KEY (created_by) REFERENCES app.app_user (id),
  CONSTRAINT fk_shareholder_record__updated_by FOREIGN KEY (updated_by) REFERENCES app.app_user (id),
  CONSTRAINT fk_shareholder_record__deleted_by FOREIGN KEY (deleted_by) REFERENCES app.app_user (id),
  CONSTRAINT fk_shareholder_record__status_changed_by FOREIGN KEY (status_changed_by) REFERENCES app.app_user (id),

  CONSTRAINT ck_shareholder_record__identifier_present
      CHECK (folio_number IS NOT NULL OR dp_account_number IS NOT NULL),
  CONSTRAINT ck_shareholder_record__first_name_not_blank CHECK (btrim(first_name) <> ''),
  CONSTRAINT ck_shareholder_record__shares_type CHECK (shares_type IN ('iepf','non_iepf','suspense')),
  CONSTRAINT ck_shareholder_record__dividend_count CHECK (dividend_count BETWEEN 0 AND 200),
  CONSTRAINT ck_shareholder_record__dividend_shares_nonneg CHECK (dividend_shares >= 0),
  CONSTRAINT ck_shareholder_record__shareholder_shares_nonneg CHECK (shareholder_shares >= 0),
  CONSTRAINT ck_shareholder_record__bucket_counts_nonneg CHECK (
      COALESCE(iepf_share_count,0) >= 0 AND COALESCE(non_iepf_share_count,0) >= 0
      AND COALESCE(suspense_share_count,0) >= 0),
  CONSTRAINT ck_shareholder_record__pan_format
      CHECK (pan IS NULL OR pan ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'),
  CONSTRAINT ck_shareholder_record__aadhaar_last4
      CHECK (aadhaar_last4 IS NULL OR aadhaar_last4 ~ '^[0-9]{4}$'),
  CONSTRAINT ck_shareholder_record__dob_sane
      CHECK (date_of_birth IS NULL OR date_of_birth >= DATE '1875-01-01'),
  CONSTRAINT ck_shareholder_record__cleaned_pincode_format
      CHECK (cleaned_pincode IS NULL OR cleaned_pincode ~ '^[0-9A-Za-z -]{3,10}$'),
  CONSTRAINT ck_shareholder_record__soft_delete_pair
      CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

COMMENT ON TABLE  app.shareholder_record IS 'Core entity: one unclaimed-holding record per (company, folio/demat account). Raw register fields are immutable evidence; cleaned_* fields are system-enriched.';
COMMENT ON COLUMN app.shareholder_record.record_code IS 'Legacy Excel "Unique Code". Kept for continuity/reconciliation; real uniqueness is (tenant, company, folio).';
COMMENT ON COLUMN app.shareholder_record.dividend_shares IS 'Shares underlying the unclaimed dividends ("Final No Shares (Dividend)"). Sample data derives Market Value from THIS column x share price.';
COMMENT ON COLUMN app.shareholder_record.aadhaar_encrypted IS 'Aadhaar number encrypted at application layer (never stored in clear — Aadhaar Act 2016). aadhaar_last4 kept for display/matching.';
COMMENT ON COLUMN app.shareholder_record.search_tsv IS 'Generated full-text document. Market value is NOT stored: derive via reference.latest_security_price.';

-- Natural-key uniqueness (case-insensitive, soft-delete aware)
CREATE UNIQUE INDEX uq_shareholder_record__company_folio
  ON app.shareholder_record (tenant_id, company_id, upper(folio_number))
  WHERE folio_number IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX uq_shareholder_record__company_dp
  ON app.shareholder_record (tenant_id, company_id, upper(dp_account_number))
  WHERE dp_account_number IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX uq_shareholder_record__record_code
  ON app.shareholder_record (tenant_id, record_code)
  WHERE record_code IS NOT NULL AND deleted_at IS NULL;

-- Search / filter indexes (all live-rows-only)
CREATE INDEX ix_shareholder_record__name_trgm
  ON app.shareholder_record
  USING gin ((COALESCE(cleaned_full_name, full_name)) gin_trgm_ops)
  WHERE deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__address_trgm
  ON app.shareholder_record
  USING gin ((COALESCE(cleaned_address, address_raw)) gin_trgm_ops)
  WHERE deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__search_tsv
  ON app.shareholder_record USING gin (search_tsv)
  WHERE deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__tenant_company_status
  ON app.shareholder_record (tenant_id, company_id, status_code)
  WHERE deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__tenant_status
  ON app.shareholder_record (tenant_id, status_code)
  WHERE deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__tenant_pincode
  ON app.shareholder_record (tenant_id, cleaned_pincode)
  WHERE cleaned_pincode IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__tenant_state
  ON app.shareholder_record (tenant_id, state_id)
  WHERE state_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__tenant_iepf_date
  ON app.shareholder_record (tenant_id, proposed_iepf_transfer_date)
  WHERE deleted_at IS NULL;
CREATE INDEX ix_shareholder_record__tenant_batch
  ON app.shareholder_record (tenant_id, import_batch_id);
-- Default list order + keyset pagination: name ASC, id as tie-breaker
CREATE INDEX ix_shareholder_record__tenant_name_id
  ON app.shareholder_record (tenant_id, (COALESCE(cleaned_full_name, full_name)), id)
  WHERE deleted_at IS NULL;

-- Joint holders: 0..n per record ("Joint Holder 1/2" + "Count of Joint Holder")
CREATE TABLE app.record_joint_holder (
  id               bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id        uuid NOT NULL,
  record_id        uuid NOT NULL,
  holder_position  smallint NOT NULL,
  full_name        text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       uuid,
  CONSTRAINT pk_record_joint_holder PRIMARY KEY (id),
  CONSTRAINT fk_record_joint_holder__record FOREIGN KEY (tenant_id, record_id)
      REFERENCES app.shareholder_record (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_record_joint_holder__created_by FOREIGN KEY (created_by) REFERENCES app.app_user (id),
  CONSTRAINT uq_record_joint_holder__record_position UNIQUE (record_id, holder_position),
  CONSTRAINT ck_record_joint_holder__position CHECK (holder_position BETWEEN 1 AND 10),
  CONSTRAINT ck_record_joint_holder__name_not_blank CHECK (btrim(full_name) <> '')
);
COMMENT ON TABLE app.record_joint_holder IS 'Joint holders, one row per holder (replaces JH1/JH2 columns). "Count of Joint Holder" is derived: COUNT(*).';

-- Operational timeline: calls, cleansing runs, validation notes, status changes.
-- Append-only (UPDATE/DELETE revoked). Replaces the "Date of Calling",
-- "Data Cleaning Remarks", "Data Validation Remarks" columns with full history.
CREATE TABLE app.record_activity (
  id             bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id      uuid NOT NULL,
  record_id      uuid NOT NULL,
  activity_type  text NOT NULL,
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  remarks        text,
  details        jsonb,
  performed_by   uuid,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_record_activity PRIMARY KEY (id),
  CONSTRAINT fk_record_activity__record FOREIGN KEY (tenant_id, record_id)
      REFERENCES app.shareholder_record (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_record_activity__performed_by FOREIGN KEY (performed_by) REFERENCES app.app_user (id),
  CONSTRAINT ck_record_activity__type CHECK (
      activity_type IN ('call','data_cleaning','validation','status_change','note'))
);
CREATE INDEX ix_record_activity__record_time
  ON app.record_activity (record_id, occurred_at DESC);
CREATE INDEX ix_record_activity__tenant_type_time
  ON app.record_activity (tenant_id, activity_type, occurred_at DESC);

-- ----------------------------------------------------------------------------
-- 4. audit schema — field-level change history for the core entity
-- ----------------------------------------------------------------------------
CREATE TABLE audit.record_change (
  id               bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id        uuid NOT NULL,
  table_name       text NOT NULL,
  record_pk        uuid NOT NULL,
  operation        text NOT NULL,
  changed_at       timestamptz NOT NULL DEFAULT now(),
  changed_by       uuid,
  changed_columns  text[],
  old_values       jsonb,
  new_values       jsonb,
  CONSTRAINT pk_record_change PRIMARY KEY (id),
  CONSTRAINT ck_record_change__operation CHECK (operation IN ('U','D'))
);
CREATE INDEX ix_record_change__record ON audit.record_change (record_pk, changed_at DESC);
CREATE INDEX ix_record_change__tenant_time ON audit.record_change (tenant_id, changed_at DESC);
COMMENT ON TABLE audit.record_change IS 'Append-only diff log (UPDATE/DELETE) for app.shareholder_record. INSERTs are not logged: creation is fully described by the row + import_batch.';

CREATE OR REPLACE FUNCTION audit.tg_capture_record_change() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_old  jsonb;
  v_new  jsonb;
  v_cols text[];
  k      text;
BEGIN
  v_old := to_jsonb(OLD) - 'search_tsv' - 'updated_at' - 'updated_by' - 'row_version';
  IF TG_OP = 'UPDATE' THEN
    v_new := to_jsonb(NEW) - 'search_tsv' - 'updated_at' - 'updated_by' - 'row_version';
    SELECT array_agg(key) INTO v_cols
    FROM (
      SELECT key FROM jsonb_each(v_old) o(key, value)
      WHERE v_new -> key IS DISTINCT FROM value
    ) diff;
    IF v_cols IS NULL THEN
      RETURN NEW;  -- no material change
    END IF;
    INSERT INTO audit.record_change
      (tenant_id, table_name, record_pk, operation, changed_by, changed_columns, old_values, new_values)
    SELECT OLD.tenant_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, OLD.id, 'U',
           app.current_user_id(), v_cols,
           (SELECT jsonb_object_agg(c, v_old -> c) FROM unnest(v_cols) c),
           (SELECT jsonb_object_agg(c, v_new -> c) FROM unnest(v_cols) c);
    RETURN NEW;
  ELSE
    INSERT INTO audit.record_change
      (tenant_id, table_name, record_pk, operation, changed_by, old_values)
    VALUES (OLD.tenant_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, OLD.id, 'D',
            app.current_user_id(), v_old);
    RETURN OLD;
  END IF;
END $$;

CREATE TRIGGER tg_shareholder_record_touch
  BEFORE UPDATE ON app.shareholder_record
  FOR EACH ROW EXECUTE FUNCTION app.tg_touch_row();
CREATE TRIGGER tg_company_touch
  BEFORE UPDATE ON app.company
  FOR EACH ROW EXECUTE FUNCTION app.tg_touch_row();
CREATE TRIGGER tg_import_batch_touch
  BEFORE UPDATE ON app.import_batch
  FOR EACH ROW EXECUTE FUNCTION app.tg_touch_row();
CREATE TRIGGER tg_shareholder_record_audit
  AFTER UPDATE OR DELETE ON app.shareholder_record
  FOR EACH ROW EXECUTE FUNCTION audit.tg_capture_record_change();

-- ----------------------------------------------------------------------------
-- 5. staging schema — raw landing zone (everything text; nothing constrained)
-- ----------------------------------------------------------------------------
CREATE TABLE staging.shareholder_record_raw (
  id                       bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id                uuid NOT NULL,
  import_batch_id          uuid NOT NULL,
  source_row_number        integer NOT NULL,      -- Excel "Sr No" / physical row
  company_name             text,
  unique_code              text,
  dividend_count           text,
  dividend_shares          text,
  shares_type              text,
  address_available        text,
  first_name               text,
  middle_name              text,
  last_name                text,
  full_name                text,
  father_first_name        text,
  father_middle_name       text,
  father_last_name         text,
  father_full_name         text,
  address                  text,
  country                  text,
  state                    text,
  district                 text,
  pincode                  text,
  folio_number             text,
  dp_account_number        text,
  folio_or_demat           text,
  investment_type          text,
  shareholder_shares       text,
  proposed_iepf_transfer_date text,
  pan                      text,
  date_of_birth            text,
  aadhaar_number           text,
  nominee_name             text,
  joint_holder_name        text,
  remarks                  text,
  under_litigation         text,
  from_unpaid_suspense     text,
  share_price              text,
  market_value             text,
  preparation_date         text,
  bi_remarks               text,
  -- validation outcome
  is_valid                 boolean,
  validation_errors        jsonb,
  target_record_id         uuid,
  loaded_at                timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_shareholder_record_raw PRIMARY KEY (id),
  CONSTRAINT uq_shareholder_record_raw__batch_row UNIQUE (import_batch_id, source_row_number)
);
CREATE INDEX ix_shareholder_record_raw__batch ON staging.shareholder_record_raw (import_batch_id) ;
COMMENT ON TABLE staging.shareholder_record_raw IS 'All-text mirror of the upload template. Rows are validated/cleansed here; only valid rows are promoted to app.shareholder_record.';

-- ----------------------------------------------------------------------------
-- 6. Derived-value views (market value is computed, never stored)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW app.v_record_valuation
WITH (security_invoker = true) AS
SELECT r.id AS record_id,
       r.tenant_id,
       r.company_id,
       lp.price_date,
       lp.close_price                                    AS share_price,
       (r.dividend_shares::numeric * lp.close_price)     AS market_value,          -- Excel "Market Value"
       (COALESCE(r.total_share_count, r.shareholder_shares)::numeric
          * lp.close_price)                              AS updated_market_value   -- Excel "Updated Market Value"
FROM   app.shareholder_record r
JOIN   app.company c ON c.id = r.company_id AND c.tenant_id = r.tenant_id
LEFT   JOIN reference.latest_security_price lp ON lp.security_id = c.security_id
WHERE  r.deleted_at IS NULL;
COMMENT ON VIEW app.v_record_valuation IS 'Derived market values (shares x latest weekly price). security_invoker => caller RLS applies.';

CREATE OR REPLACE VIEW app.v_record_current
WITH (security_invoker = true) AS
SELECT r.id, r.tenant_id, r.company_id, c.display_name AS company_name,
       r.record_code, r.folio_number, r.dp_account_number, r.folio_or_demat,
       COALESCE(r.cleaned_full_name, r.full_name)        AS display_name,
       r.full_name, r.father_husband_full_name,
       COALESCE(r.cleaned_address, r.address_raw)        AS display_address,
       (COALESCE(r.cleaned_address, r.address_raw) IS NOT NULL) AS address_available,  -- derived, not stored
       r.cleaned_pincode, r.state_id, r.country_id,
       r.dividend_count, r.dividend_shares, r.shareholder_shares, r.shares_type,
       r.proposed_iepf_transfer_date, r.status_code, rs.label AS status_label,
       v.share_price, v.market_value, v.updated_market_value,
       (SELECT count(*) FROM app.record_joint_holder j WHERE j.record_id = r.id) AS joint_holder_count,
       (SELECT max(a.occurred_at) FROM app.record_activity a
         WHERE a.record_id = r.id AND a.activity_type = 'call')                  AS last_called_at,
       r.created_at, r.updated_at, r.row_version
FROM   app.shareholder_record r
JOIN   app.company c  ON c.id = r.company_id AND c.tenant_id = r.tenant_id
JOIN   reference.record_status rs ON rs.code = r.status_code
LEFT   JOIN app.v_record_valuation v ON v.record_id = r.id
WHERE  r.deleted_at IS NULL;
COMMENT ON VIEW app.v_record_current IS 'API read model: live records with derived fields (market value, address_available, joint-holder count, last call).';

-- ----------------------------------------------------------------------------
-- 7. analytics schema — materialized rollups (refreshed after the weekly
--    price sync and after large imports). MVs ignore RLS, so they are exposed
--    ONLY through tenant-filtering views.
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW analytics.company_portfolio_mv AS
SELECT r.tenant_id,
       r.company_id,
       c.display_name                                   AS company_name,
       count(*)                                         AS record_count,
       count(*) FILTER (WHERE r.status_code = 'CLAIMED')          AS claimed_count,
       count(*) FILTER (WHERE r.status_code = 'NOT_STARTED')      AS not_started_count,
       count(*) FILTER (WHERE r.shares_type = 'iepf')             AS iepf_record_count,
       count(*) FILTER (WHERE r.shares_type = 'non_iepf')         AS non_iepf_record_count,
       count(*) FILTER (WHERE r.shares_type = 'suspense')         AS suspense_record_count,
       sum(r.dividend_shares)::bigint                   AS total_dividend_shares,
       sum(r.shareholder_shares)::bigint                AS total_shareholder_shares,
       max(lp.close_price)                              AS share_price,
       max(lp.price_date)                               AS price_date,
       sum(r.dividend_shares::numeric * lp.close_price) AS total_market_value
FROM   app.shareholder_record r
JOIN   app.company c ON c.id = r.company_id AND c.tenant_id = r.tenant_id
LEFT   JOIN reference.latest_security_price lp ON lp.security_id = c.security_id
WHERE  r.deleted_at IS NULL
GROUP  BY r.tenant_id, r.company_id, c.display_name;
CREATE UNIQUE INDEX uq_company_portfolio_mv__tenant_company
  ON analytics.company_portfolio_mv (tenant_id, company_id);   -- enables REFRESH CONCURRENTLY

CREATE MATERIALIZED VIEW analytics.geo_distribution_mv AS
SELECT r.tenant_id,
       r.country_id,
       r.state_id,
       count(*)                        AS record_count,
       sum(r.dividend_shares)::bigint  AS total_dividend_shares
FROM   app.shareholder_record r
WHERE  r.deleted_at IS NULL
GROUP  BY r.tenant_id, r.country_id, r.state_id;
CREATE UNIQUE INDEX uq_geo_distribution_mv__keys
  ON analytics.geo_distribution_mv (tenant_id, COALESCE(country_id,0), COALESCE(state_id,0));

-- Tenant-safe accessors (plain views; the WHERE clause enforces tenancy because
-- materialized views do not participate in RLS):
CREATE OR REPLACE VIEW analytics.v_company_portfolio AS
SELECT * FROM analytics.company_portfolio_mv
WHERE  tenant_id = app.current_tenant_id();
CREATE OR REPLACE VIEW analytics.v_geo_distribution AS
SELECT * FROM analytics.geo_distribution_mv
WHERE  tenant_id = app.current_tenant_id();

-- ----------------------------------------------------------------------------
-- 8. Row-Level Security — fail-closed tenant isolation
-- ----------------------------------------------------------------------------
ALTER TABLE app.tenant                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tenant                    FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.app_user                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.app_user                  FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.company                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.company                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.import_batch              ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.import_batch              FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.shareholder_record        ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.shareholder_record        FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.record_joint_holder       ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.record_joint_holder       FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.record_activity           ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.record_activity           FORCE  ROW LEVEL SECURITY;
ALTER TABLE staging.shareholder_record_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE staging.shareholder_record_raw FORCE  ROW LEVEL SECURITY;
ALTER TABLE audit.record_change           ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.record_change           FORCE  ROW LEVEL SECURITY;

-- The tenant row itself: a session may see only its own tenant.
CREATE POLICY p_tenant_self ON app.tenant
  USING (id = app.current_tenant_id());

CREATE POLICY p_tenant_isolation ON app.app_user
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON app.company
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON app.import_batch
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON app.shareholder_record
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON app.record_joint_holder
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON app.record_activity
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON staging.shareholder_record_raw
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY p_tenant_isolation ON audit.record_change
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

-- ----------------------------------------------------------------------------
-- 9. Grants — least privilege
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA reference, app, analytics TO app_rw, app_ro;
GRANT USAGE ON SCHEMA staging, audit TO app_rw;
GRANT USAGE ON SCHEMA reference, app, staging TO svc_import;
GRANT USAGE ON SCHEMA reference TO svc_price_loader;

GRANT SELECT ON ALL TABLES IN SCHEMA reference TO app_rw, app_ro, svc_import;
GRANT SELECT, INSERT, UPDATE ON reference.security, reference.security_price TO svc_price_loader;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA app TO app_rw;   -- no DELETE: soft delete only
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_ro;
GRANT DELETE ON app.record_joint_holder TO app_rw;                    -- child rows are hard-deleted with corrections

GRANT SELECT, INSERT ON audit.record_change TO app_rw;                -- append-only: no UPDATE/DELETE grant
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app, audit TO app_rw;

GRANT SELECT, INSERT, UPDATE ON staging.shareholder_record_raw TO svc_import, app_rw;
GRANT SELECT, INSERT, UPDATE ON app.import_batch, app.shareholder_record,
      app.record_joint_holder, app.record_activity, app.company TO svc_import;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA staging TO svc_import, app_rw;

GRANT SELECT ON analytics.v_company_portfolio, analytics.v_geo_distribution TO app_rw, app_ro;
-- Deliberately NO grant on the raw MVs: tenants reach them only via the views above.

-- record_activity is append-only for everyone but the owner:
REVOKE UPDATE, DELETE ON app.record_activity FROM app_rw, svc_import;

COMMIT;

-- ============================================================================
-- Post-deployment notes (not part of the transaction):
-- 1. Create login roles per service, e.g.:
--      CREATE ROLE api_service LOGIN PASSWORD '...' IN ROLE app_rw;
-- 2. The application MUST set tenant context per transaction:
--      SELECT set_config('app.current_tenant',  :tenant_uuid, true);
--      SELECT set_config('app.current_user_id', :user_uuid,   true);
-- 3. Refresh analytics after the Saturday price sync and after bulk imports:
--      REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.company_portfolio_mv;
--      REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.geo_distribution_mv;
-- 4. autovacuum: consider per-table tuning on app.shareholder_record once it
--    exceeds ~10M rows (lower scale factors, higher cost limits).
-- ============================================================================
