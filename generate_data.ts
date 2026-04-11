import { faker } from "@faker-js/faker";
import * as fs from "fs";

// ============================================================================
// CONFIGURATION
// ============================================================================
const TARGET_ENCOUNTERS = 1000000; // Change this to 10000000 for 10M

// Scale associated tables based on encounters
const NUM_PATIENTS = Math.max(10, Math.floor(TARGET_ENCOUNTERS / 10)); // Avg 10 encounters per patient
const NUM_PROVIDERS = Math.max(10, Math.floor(TARGET_ENCOUNTERS / 1000)); // Avg 1000 encounters per provider
const NUM_SPECIALTIES = 20;
const NUM_DEPARTMENTS = 50;
const NUM_DIAGNOSES = 1000;
const NUM_PROCEDURES = 1000;

// Helper to format rows safely for MariaDB CSV import
const toCSV = (arr: any[]): string => {
    return arr
        .map((v) => {
            if (v === null || v === undefined) return "\\N"; // MariaDB NULL
            if (v instanceof Date)
                return `"${v.toISOString().slice(0, 19).replace("T", " ")}"`;
            if (typeof v === "string") return `"${v.replace(/"/g, '""')}"`;
            return v;
        })
        .join(",");
};

// Stream writer to prevent RAM exhaustion
async function writeData(
    filename: string,
    count: number,
    generator: (id: number) => any[] | any[][],
) {
    const stream = fs.createWriteStream("data/" + filename);

    for (let i = 1; i <= count; i++) {
        const rows = generator(i);
        // Handle both single rows and arrays of rows (for junction tables)
        const rowsToWrite = Array.isArray(rows[0])
            ? (rows as any[][])
            : [rows as any[]];

        for (const row of rowsToWrite) {
            const canWrite = stream.write(toCSV(row) + "\n");
            // Pause if buffer is full to clear memory
            if (!canWrite) {
                await new Promise((resolve) => stream.once("drain", resolve));
            }
        }

        if (i % 100000 === 0)
            console.log(
                `  ...wrote ${i.toLocaleString()} records to ${filename}`,
            );
    }

    stream.end();
    await new Promise((resolve) => stream.once("finish", resolve));
    console.log(`✅ Finished ${filename}`);
}

// ============================================================================
// GENERATORS
// ============================================================================
async function run() {
    console.log(
        `🚀 Starting generation for ${TARGET_ENCOUNTERS.toLocaleString()} encounters...\n`,
    );

    // 1. Specialties
    await writeData("specialties.csv", NUM_SPECIALTIES, (id) => [
        id,
        faker.person.jobArea(),
        faker.string.alpha({ length: 4, casing: "upper" }),
    ]);

    // 2. Departments
    await writeData("departments.csv", NUM_DEPARTMENTS, (id) => [
        id,
        `${faker.location.buildingNumber()} Wing`,
        faker.number.int({ min: 1, max: 10 }),
        faker.number.int({ min: 10, max: 100 }),
    ]);

    // 3. Diagnoses
    await writeData("diagnoses.csv", NUM_DIAGNOSES, (id) => [
        id,
        `ICD-${id}`,
        faker.lorem.words(3),
    ]);

    // 4. Procedures
    await writeData("procedures.csv", NUM_PROCEDURES, (id) => [
        id,
        `CPT-${id}`,
        faker.lorem.words(3),
    ]);

    // 5. Providers
    await writeData("providers.csv", NUM_PROVIDERS, (id) => [
        id,
        faker.person.firstName(),
        faker.person.lastName(),
        faker.helpers.arrayElement(["MD", "DO", "NP", "PA"]),
        faker.number.int({ min: 1, max: NUM_SPECIALTIES }),
        faker.number.int({ min: 1, max: NUM_DEPARTMENTS }),
    ]);

    // 6. Patients
    await writeData("patients.csv", NUM_PATIENTS, (id) => [
        id,
        faker.person.firstName(),
        faker.person.lastName(),
        faker.date.birthdate({ min: 1, max: 90, mode: "age" }),
        faker.helpers.arrayElement(["M", "F"]),
        `MRN-${id.toString().padStart(8, "0")}`,
    ]);

    // 7. Encounters, Billing, and Junctions
    let encounter_diagnosis_id = 1;
    let encounter_procedure_id = 1;

    const streamEncounters = fs.createWriteStream("data/encounters.csv");
    const streamBilling = fs.createWriteStream("data/billing.csv");
    const streamEncDiag = fs.createWriteStream("data/encounter_diagnoses.csv");
    const streamEncProc = fs.createWriteStream("data/encounter_procedures.csv");

    for (let id = 1; id <= TARGET_ENCOUNTERS; id++) {
        const type = faker.helpers.arrayElement([
            "Outpatient",
            "Inpatient",
            "ER",
        ]);
        const encounterDate = faker.date.recent({ days: 365 });
        const dischargeDate =
            type === "Inpatient"
                ? new Date(
                      encounterDate.getTime() +
                          faker.number.int({ min: 1, max: 14 }) * 86400000,
                  )
                : encounterDate;

        // Write Encounter
        const encCanWrite = streamEncounters.write(
            toCSV([
                id,
                faker.number.int({ min: 1, max: NUM_PATIENTS }),
                faker.number.int({ min: 1, max: NUM_PROVIDERS }),
                type,
                encounterDate,
                dischargeDate,
                faker.number.int({ min: 1, max: NUM_DEPARTMENTS }),
            ]) + "\n",
        );

        // Write Billing
        const claim = faker.number.float({
            min: 100,
            max: 10000,
            fractionDigits: 2,
        });
        const allowed =
            claim *
            faker.number.float({ min: 0.5, max: 0.9, fractionDigits: 2 });
        streamBilling.write(
            toCSV([
                id,
                id,
                claim,
                allowed,
                new Date(dischargeDate.getTime() + 86400000 * 5),
                faker.helpers.arrayElement(["Paid", "Pending", "Denied"]),
            ]) + "\n",
        );

        // Write 1-3 Diagnoses per encounter
        const diagCount = faker.number.int({ min: 1, max: 3 });
        for (let seq = 1; seq <= diagCount; seq++) {
            streamEncDiag.write(
                toCSV([
                    encounter_diagnosis_id++,
                    id,
                    faker.number.int({ min: 1, max: NUM_DIAGNOSES }),
                    seq,
                ]) + "\n",
            );
        }

        // Write 0-2 Procedures per encounter
        const procCount = faker.number.int({ min: 0, max: 2 });
        for (let p = 1; p <= procCount; p++) {
            streamEncProc.write(
                toCSV([
                    encounter_procedure_id++,
                    id,
                    faker.number.int({ min: 1, max: NUM_PROCEDURES }),
                    encounterDate,
                ]) + "\n",
            );
        }

        if (!encCanWrite)
            await new Promise((resolve) =>
                streamEncounters.once("drain", resolve),
            );
        if (id % 100000 === 0)
            console.log(
                `  ...generated ${id.toLocaleString()} encounters (and related tables)`,
            );
    }

    streamEncounters.end();
    streamBilling.end();
    streamEncDiag.end();
    streamEncProc.end();

    console.log(`\n🎉 Data Generation Complete!`);
}

run().catch(console.error);
