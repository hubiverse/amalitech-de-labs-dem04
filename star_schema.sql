-- ==============================================================================
-- HealthTech Analytics: Star Schema DDL
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DIMENSION TABLES
-- ------------------------------------------------------------------------------

-- Date Dimension: Eliminates runtime date math
CREATE TABLE dim_date
(
    date_key      INT PRIMARY KEY,     -- Format: YYYYMMDD (e.g., 20240510)
    calendar_date DATE        NOT NULL,
    year          INT         NOT NULL,
    month         INT         NOT NULL,
    month_name    VARCHAR(20) NOT NULL,
    quarter       INT         NOT NULL,
    day_of_week   VARCHAR(15) NOT NULL,
    is_weekend    TINYINT(1)  NOT NULL -- 1 for weekend, 0 for weekday
);

-- Patient Dimension: Holds demographic data and historical groupings
CREATE TABLE dim_patient
(
    patient_key   INT AUTO_INCREMENT PRIMARY KEY, -- Surrogate Key
    patient_id    INT NOT NULL,                   -- Natural Key (OLTP ID)
    first_name    VARCHAR(200),
    last_name     VARCHAR(200),
    date_of_birth DATE,
    gender        CHAR(1),
    mrn           VARCHAR(20),
    age_group     VARCHAR(20)                     -- Pre-calculated (e.g., '65-74', '75+')
);

-- Provider Dimension: Holds provider details
CREATE TABLE dim_provider
(
    provider_key   INT AUTO_INCREMENT PRIMARY KEY,
    provider_id    INT NOT NULL,
    first_name     VARCHAR(100),
    last_name      VARCHAR(100),
    credential     VARCHAR(20),
    specialty_name VARCHAR(100) -- Denormalized for quick provider lookup
);

-- Specialty Dimension: Flattened from Providers to allow direct Fact grouping
CREATE TABLE dim_specialty
(
    specialty_key  INT AUTO_INCREMENT PRIMARY KEY,
    specialty_id   INT          NOT NULL,
    specialty_name VARCHAR(100) NOT NULL,
    specialty_code VARCHAR(10)
);

-- Department Dimension: The physical location of the encounter
CREATE TABLE dim_department
(
    department_key  INT AUTO_INCREMENT PRIMARY KEY,
    department_id   INT NOT NULL,
    department_name VARCHAR(100),
    floor           INT,
    capacity        INT
);

-- Encounter Type Dimension: Explicit breakdown (Inpatient, Outpatient, ER)
CREATE TABLE dim_encounter_type
(
    encounter_type_key INT AUTO_INCREMENT PRIMARY KEY,
    type_name          VARCHAR(50) NOT NULL
);

-- Diagnosis Dimension: For resolving the bridge table
CREATE TABLE dim_diagnosis
(
    diagnosis_key     INT AUTO_INCREMENT PRIMARY KEY,
    icd10_code        VARCHAR(10) NOT NULL,
    icd10_description VARCHAR(200)
);

-- Procedure Dimension: For resolving the bridge table
CREATE TABLE dim_procedure
(
    procedure_key   INT AUTO_INCREMENT PRIMARY KEY,
    cpt_code        VARCHAR(10) NOT NULL,
    cpt_description VARCHAR(200)
);

-- ------------------------------------------------------------------------------
-- 2. FACT TABLE
-- ------------------------------------------------------------------------------

-- Fact Encounters
CREATE TABLE fact_encounters
(
    encounter_key           INT AUTO_INCREMENT PRIMARY KEY,
    encounter_id            INT NOT NULL,             -- Natural Key

    -- Foreign Keys to Dimensions
    date_key                INT NOT NULL,             -- Links to dim_date (Admission/Encounter Date)
    discharge_date_key      INT,                      -- Links to dim_date (Discharge Date, if applicable)
    patient_key             INT NOT NULL,             -- Links to dim_patient
    provider_key            INT NOT NULL,             -- Links to dim_provider
    specialty_key           INT NOT NULL,             -- Links to dim_specialty
    department_key          INT NOT NULL,             -- Links to dim_department
    encounter_type_key      INT NOT NULL,             -- Links to dim_encounter_type

    -- Pre-Aggregated Metrics
    total_claim_amount      DECIMAL(12, 2) DEFAULT 0.00,
    total_allowed_amount    DECIMAL(12, 2) DEFAULT 0.00,
    diagnosis_count         INT            DEFAULT 0,
    procedure_count         INT            DEFAULT 0,
    length_of_stay_days     INT            DEFAULT 0,
    readmission_30_day_flag TINYINT(1)     DEFAULT 0, -- 1 if readmitted within 30 days, 0 otherwise

    -- Constraints
    FOREIGN KEY (date_key) REFERENCES dim_date (date_key),
    FOREIGN KEY (discharge_date_key) REFERENCES dim_date (date_key),
    FOREIGN KEY (patient_key) REFERENCES dim_patient (patient_key),
    FOREIGN KEY (provider_key) REFERENCES dim_provider (provider_key),
    FOREIGN KEY (specialty_key) REFERENCES dim_specialty (specialty_key),
    FOREIGN KEY (department_key) REFERENCES dim_department (department_key),
    FOREIGN KEY (encounter_type_key) REFERENCES dim_encounter_type (encounter_type_key)
);

-- Indexes for aggregations by Dimensions
CREATE INDEX idx_fact_date ON fact_encounters (date_key);
CREATE INDEX idx_fact_specialty ON fact_encounters (specialty_key);
CREATE INDEX idx_fact_patient ON fact_encounters (patient_key);
CREATE INDEX idx_fact_type ON fact_encounters (encounter_type_key);


-- ------------------------------------------------------------------------------
-- 3. BRIDGE TABLES
-- ------------------------------------------------------------------------------

-- Encounter Diagnoses Bridge
CREATE TABLE bridge_encounter_diagnoses
(
    encounter_key      INT NOT NULL,
    diagnosis_key      INT NOT NULL,
    diagnosis_sequence INT,
    PRIMARY KEY (encounter_key, diagnosis_key),
    FOREIGN KEY (encounter_key) REFERENCES fact_encounters (encounter_key),
    FOREIGN KEY (diagnosis_key) REFERENCES dim_diagnosis (diagnosis_key)
);

-- Encounter Procedures Bridge
CREATE TABLE bridge_encounter_procedures
(
    encounter_key      INT NOT NULL,
    procedure_key      INT NOT NULL,
    procedure_date_key INT,
    PRIMARY KEY (encounter_key, procedure_key),
    FOREIGN KEY (encounter_key) REFERENCES fact_encounters (encounter_key),
    FOREIGN KEY (procedure_key) REFERENCES dim_procedure (procedure_key),
    FOREIGN KEY (procedure_date_key) REFERENCES dim_date (date_key)
);