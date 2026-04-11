# Healthcare Data Warehouse Demo

This project is a small healthcare data warehouse example built from a normalized OLTP schema and transformed into a star schema for faster analytics.

## What This Project Does

The project starts by analyzing the performance of a normalized OLTP database.  
It then transforms that structure into a star schema to make reporting and analytical queries simpler and faster.

## Project Files

- `01-init.sql` - Creates the healthcare source tables for patients, providers, encounters, diagnoses, procedures, billing, and related entities.
- `etl_design.txt` - Describes the ETL design for building dimensions, fact tables, bridge tables, and refresh logic.

## Goals

- Compare normalized OLTP design with dimensional modeling
- Improve query performance for analytics
- Organize data into a star schema
- Support reporting on encounters, diagnoses, procedures, billing, and readmissions

## Overview

The source system uses a normalized structure for transactional data.  
The warehouse design flattens and reorganizes that data into dimensions and facts so it can be queried more efficiently.

## Notes

- The schema includes healthcare-style relationships between patients, providers, encounters, diagnoses, procedures, and billing.
- The ETL design includes incremental loading, handling missing values, and support for historical changes.
- The warehouse is intended for analytical queries, not day-to-day transaction processing.

## Getting Started

1. Run `01-init.sql` to create the source tables.
2. Review `etl_design.txt` and other `.txt` files to understand the data and warehouse loading approach.
3. Extend the model as needed for your own analytics use case.

## Generate data using the `generate_data.ts` script.