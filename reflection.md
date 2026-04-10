# Analysis & Reflection

## 1. Why Is the Star Schema Faster?
The Star Schema achieves significantly faster read performance through three main architectural changes:
*   **Fewer and Shallower JOINs:** In the normalized schema, queries required deep relational chains (e.g., joining 4 tables to connect Billing to Specialty). The Star Schema flattens this. Every dimension is only exactly "one hop" away from the central fact table, turning slow nested loops into instant primary-key lookup.
*   **Pre-computed Data:** Heavy calculations are shifted from query-time to ETL-time. Metrics like `total_allowed_amount`, `length_of_stay_days`, and the complex `readmission_30_day_flag` are pre-computed and stored directly as integers/decimals in the fact table. 
*   **Denormalization:** By purposefully flattening the data (e.g., mapping `specialty_key` directly to the encounter instead of routing it through the provider), we eliminate the CPU overhead of traversing hierarchical relationships. Furthermore, extracting date parts (Year, Month) into a Date Dimension eliminates the need for row-by-row functions like `DATE_FORMAT()`.

## 2. Trade-offs: What Did You Gain? What Did You Lose?
Dimensional modeling is a deliberate trade-off between write-efficiency and read-efficiency.
*   **What I Lost:** 
    *   *Storage Efficiency:* Denormalization introduces data duplication. We store text like "May" and "Cardiology" repeatedly in the dimensions instead of normalizing them away.
    *   *ETL Complexity:* We now require a dedicated data pipeline to extract, transform, load, and manage historical updates between the OLTP and OLAP systems.
*   **What I Gained:** 
    *   Blazing-fast(😁) analytical queries that scale to millions of rows.
    *   A vastly simpler data model for business analysts to query (they no longer need to understand 3NF junction tables).
    *   Isolation, ensuring heavy analytical reports do not crash the live hospital production database.
*   **Was it worth it?** Absolutely. In modern data engineering, storage is cheap, but compute (CPU/RAM) and analyst time are expensive. Optimizing for read speed provides massive ROI.

## 3. Bridge Tables: Worth It?
*   **Why keep them:** Healthcare encounters have a true many-to-many relationship with diagnoses and procedures. If we denormalized diagnoses directly into the fact table via standard joins, we would violate our grain (1 row = 1 encounter) and cause a Cartesian product (i.e. row explosion), which artificially inflates revenue and patient counts. Bridge tables safely resolve this.
*   **The Trade-off:** The downside is that querying diagnosis/procedure data still requires traversing an extra table, adding slight query complexity compared to a purely flat table.
*   **Production Alternative:** If I were deploying this on a modern cloud data warehouse like Google BigQuery or Snowflake, I would abandon bridge tables entirely and use **Nested Arrays** or **JSON** (e.g., `ARRAY<STRUCT>`). This allows storing a list of diagnoses directly inside the single encounter row, combining the safety of a strict grain with the speed of zero joins.

## 4. Performance Quantification
*(Note: These numbers reflect execution on a micro-dataset of 4 rows. While the millisecond differences seem small here, the architectural shift prevents $O(N^2)$ scaling, meaning these improvements become exponential on datasets with millions of rows).*

**Query 3: 30-Day Readmission Rate**
*   **Original execution time:** 0.332 ms
*   **Optimized execution time:** 0.165 ms
*   **Improvement:** 2.0x faster
*   **Main reason for speedup:** We completely eliminated a massive, complex self-join on the encounters table. By pre-calculating the `readmission_30_day_flag` during ETL, the query became a simple arithmetic `SUM()` over an integer column.

**Query 4: Revenue by Specialty & Month**
*   **Original execution time:** 0.185 ms
*   **Optimized execution time:** 0.163 ms
*   **Improvement:** ~1.1x faster
*   **Main reason for speedup:** We eliminated a 4-table deep join hierarchy (Billing $\rightarrow$ Encounters $\rightarrow$ Providers $\rightarrow$ Specialties) by rolling revenue directly into the fact table. We also eliminated the CPU-heavy `DATE_FORMAT()` function by using pre-extracted date dimensions.
