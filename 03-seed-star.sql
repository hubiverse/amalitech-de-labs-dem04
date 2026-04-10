-- 1. Load Date Dimension
INSERT INTO dim_date
VALUES (20240510, '2024-05-10', 2024, 5, 'May', 2, 'Friday', 0),
       (20240515, '2024-05-15', 2024, 5, 'May', 2, 'Wednesday', 0),
       (20240602, '2024-06-02', 2024, 6, 'June', 2, 'Sunday', 1),
       (20240606, '2024-06-06', 2024, 6, 'June', 2, 'Thursday', 0),
       (20240612, '2024-06-12', 2024, 6, 'June', 2, 'Wednesday', 0),
       (20240613, '2024-06-13', 2024, 6, 'June', 2, 'Thursday', 0);

-- 2. Load Dimensions
INSERT INTO dim_patient (patient_id, first_name, last_name, date_of_birth, gender, mrn, age_group)
VALUES (1001, 'John', 'Doe', '1955-03-15', 'M', 'MRN001', '65-74'),
       (1002, 'Jane', 'Smith', '1962-07-22', 'F', 'MRN002', '55-64'),
       (1003, 'Robert', 'Johnson', '1948-11-08', 'M', 'MRN003', '75+');

INSERT INTO dim_provider (provider_id, first_name, last_name, credential, specialty_name)
VALUES (101, 'James', 'Chen', 'MD', 'Cardiology'),
       (102, 'Sarah', 'Williams', 'MD', 'Internal Medicine'),
       (103, 'Michael', 'Rodriguez', 'MD', 'Emergency');

INSERT INTO dim_specialty (specialty_id, specialty_name, specialty_code)
VALUES (1, 'Cardiology', 'CARD'),
       (2, 'Internal Medicine', 'IM'),
       (3, 'Emergency', 'ER');

INSERT INTO dim_department (department_id, department_name, floor, capacity)
VALUES (1, 'Cardiology Unit', 3, 20),
       (2, 'Internal Medicine', 2, 30),
       (3, 'Emergency', 1, 45);

INSERT INTO dim_encounter_type (type_name)
VALUES ('Outpatient'),
       ('Inpatient'),
       ('ER');

INSERT INTO dim_diagnosis (icd10_code, icd10_description)
VALUES ('I10', 'Hypertension'),
       ('E11.9', 'Type 2 Diabetes'),
       ('I50.9', 'Heart Failure');

INSERT INTO dim_procedure (cpt_code, cpt_description)
VALUES ('99213', 'Office Visit'),
       ('93000', 'EKG'),
       ('71020', 'Chest X-ray');

-- 3. Load Fact Table (with pre-calculated metrics mapping to the OLTP data)
-- Note: surrogate keys match the insert order (1, 2, 3...)
INSERT INTO fact_encounters (encounter_id, date_key, discharge_date_key, patient_key, provider_key,
                             specialty_key, department_key, encounter_type_key, total_claim_amount,
                             total_allowed_amount, diagnosis_count, procedure_count, length_of_stay_days,
                             readmission_30_day_flag)
VALUES (7001, 20240510, 20240510, 1, 1, 1, 1, 1, 350.00, 280.00, 2, 2, 0, 0),
       (7002, 20240602, 20240606, 1, 1, 1, 1, 2, 12500.00, 10000.00, 2, 1, 4, 0),
       (7003, 20240515, 20240515, 2, 2, 2, 2, 1, 0.00, 0.00, 1, 1, 0, 0),
       (7004, 20240612, 20240613, 3, 3, 3, 3, 3, 0.00, 0.00, 1, 0, 1, 0);

-- 4. Load Bridge Tables
INSERT INTO bridge_encounter_diagnoses (encounter_key, diagnosis_key, diagnosis_sequence)
VALUES (1, 1, 1),
       (1, 2, 2),
       (2, 1, 1),
       (2, 3, 2),
       (3, 2, 1),
       (4, 1, 1);

INSERT INTO bridge_encounter_procedures (encounter_key, procedure_key, procedure_date_key)
VALUES (1, 1, 20240510),
       (1, 2, 20240510),
       (2, 1, 20240602),
       (3, 1, 20240515);