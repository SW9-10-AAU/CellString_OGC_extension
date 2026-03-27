-- =============================================================================
-- CellString DuckDB extension
-- =============================================================================
-- Usage: 
-- 1. Ensure the 'spatial' extension is installed: INSTALL spatial; LOAD spatial;
-- 2. Run this file: .read cellstring_macros.sql
-- =============================================================================

INSTALL spatial; 
LOAD spatial;

-- =============================================================================
-- Drop existing macros (for clean reinstallation)
-- =============================================================================
--TODO : Add drop statements for any new macros added in the future
DROP MACRO IF EXISTS CS_Intersects;
DROP MACRO TABLE IF EXISTS CS_Intersection;
DROP MACRO TABLE IF EXISTS CS_Union;
DROP MACRO TABLE IF EXISTS CS_Difference;
DROP MACRO IF EXISTS CS_Contains;
DROP MACRO IF EXISTS CS_Disjoint;
DROP MACRO IF EXISTS CS_Coverage;
DROP MACRO IF EXISTS CS_CellAsPoint;
DROP MACRO IF EXISTS CS_AsPolygon;
DROP MACRO IF EXISTS CS_AsLineString;
DROP MACRO IF EXISTS CS_CellStringAsPolygon;
DROP MACRO TABLE IF EXISTS CS_CoverageByMMSI;
DROP MACRO TABLE IF EXISTS CS_NewCoverageByMMSI;

-- DROP MACRO IF EXISTS quadkey_to_zoomxy;
-- DROP MACRO IF EXISTS zoomxy_to_quadkey;
DROP MACRO IF EXISTS CS_CellIdToQuadkey;

-- =============================================================================
-- Create macros
-- =============================================================================

--------------------------------------------------------------------------------
-- Helper macros - Quadkey conversion utilities
--------------------------------------------------------------------------------
-- quadkey_to_zoomxy: Converts a quadkey string to zoom, x, y tile coordinates
-- CREATE OR REPLACE MACRO quadkey_to_zoomxy(qkey) AS TABLE (
--     WITH RECURSIVE
--     digits AS (
--         SELECT
--             qkey,
--             length(qkey)::INT           AS zoom,
--             pos + 1                     AS pos,
--             substring(qkey, pos + 1, 1) AS digit
--         FROM range(length(qkey))        AS t(pos)
--     ),
--     recur(pos, digit, zoom, x, y) AS (
--         -- base case
--         SELECT 0, NULL, (SELECT zoom FROM digits LIMIT 1), 0::INT, 0::INT
--         UNION ALL
--         -- recursive step
--         SELECT
--             d.pos,
--             d.digit,
--             r.zoom,
--             r.x * 2 + CASE d.digit WHEN '1' THEN 1 WHEN '3' THEN 1 ELSE 0 END,
--             r.y * 2 + CASE d.digit WHEN '2' THEN 1 WHEN '3' THEN 1 ELSE 0 END
--         FROM recur r
--         JOIN digits d ON d.pos = r.pos + 1
--     )
--     SELECT zoom, x, y
--     FROM recur
--     WHERE pos = zoom
-- );

-- -- zoomxy_to_quadkey: Converts zoom, x, y tile coordinates to a quadkey string
-- CREATE OR REPLACE MACRO zoomxy_to_quadkey(zoom, x, y) AS (
--     WITH RECURSIVE bits(level, quad) AS (
--         -- start at level = zoom, quad = empty string
--         SELECT zoom AS level, ''::VARCHAR AS quad
--         UNION ALL
--         -- at each step compute digit for current level and append, then decrement level
--         SELECT
--             level - 1 AS level,
--             quad || CAST(
--                 (
--                     CAST(floor(x / pow(2, level - 1)) AS BIGINT) % 2
--                     + 2 * (CAST(floor(y / pow(2, level - 1)) AS BIGINT) % 2)
--                 ) AS INTEGER
--             ) AS quad
--         FROM bits
--         WHERE level > 0
--     )
--     -- when recursion finishes, one row will have level = 0 and quad = full quadkey
--     SELECT quad FROM bits WHERE level = 0 LIMIT 1
-- );

-- int_to_quadkey: Converts a base-4 integer encoding to a quadkey string
CREATE OR REPLACE MACRO CS_CellIdToQuadkey(cell_id, zoom) AS (
    WITH input AS (
        SELECT right(cell_id::BIT::VARCHAR, zoom * 2) AS bitstring
    )
    SELECT string_agg(digit, '' ORDER BY pos) AS quadkey
    FROM (
        SELECT
            CASE substr(bitstring, pos, 2)
                WHEN '00' THEN '0'
                WHEN '01' THEN '1'
                WHEN '10' THEN '2'
                WHEN '11' THEN '3'
            END AS digit,
            pos
        FROM input, generate_series(1, length(bitstring), 2) AS gs(pos)
        ORDER BY pos
    ) t
);

-- get the parent cell ID at a coarser zoom level by right-shifting the cell ID's bits according to the zoom difference
CREATE OR REPLACE MACRO CS_GetParentCellId(cell_id, from_zoom, to_zoom) AS (
   CASE
       WHEN to_zoom >= from_zoom THEN
           error(format('parent zoom level must be coarser than source zoom level. Parent zoom: {} not coarser than source zoom: {}', to_zoom, from_zoom))
      ELSE
           cell_id >> ((from_zoom - to_zoom) * 2)
   END
);

--TODO implement the macros.
-- --------------------------------------------------------------------------------
-- CellString macros
-- --------------------------------------------------------------------------------
CREATE OR REPLACE MACRO CS_Intersects
-- Overload 1: Two arguments (Spatial only)
   (cs_a, cs_b) AS (
       EXISTS (
           SELECT 1
           FROM query_table(cs_a) a
           INNER JOIN query_table(cs_b) b ON a.cell_z21 = b.cell_z21
       )
   ),
-- Overload 2: Three arguments (Spatio-Temporal)
   (cs_a, cs_b, time_interval) AS (
       EXISTS (
           SELECT 1
           FROM query_table(cs_a) a
           JOIN query_table(cs_b) b ON a.cell_z21 = b.cell_z21
           WHERE a.ts BETWEEN b.ts - time_interval AND b.ts + time_interval
       )
   );

CREATE OR REPLACE MACRO CS_Intersection
   -- Overload 1: Two arguments (Spatial only)
   (cs_a, cs_b) AS TABLE (
       SELECT DISTINCT a.cell_z21
       FROM query_table(cs_a) a
       INNER JOIN query_table(cs_b) b
         ON a.cell_z21 = b.cell_z21
   ),
   -- Overload 2: Three arguments (Spatio-Temporal)
   (cs_a, cs_b, time_interval) AS TABLE (
       SELECT Distinct a.cell_z21
       FROM query_table(cs_a) a
       INNER JOIN query_table(cs_b) b
         ON a.cell_z21 = b.cell_z21
       WHERE a.ts BETWEEN b.ts - time_interval AND b.ts + time_interval
   );

-- -- CS_Union: Returns all unique cells from both trajectories.
CREATE OR REPLACE MACRO CS_Union(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    UNION
    SELECT cell_z21 FROM query_table(cs_b)
);

-- -- CS_Difference: Returns cells in trajectory A that are NOT in trajectory B.
CREATE OR REPLACE MACRO CS_Difference(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    EXCEPT
    SELECT cell_z21 FROM query_table(cs_b)
);

-- -- CS_Contains: Returns TRUE if trajectory A fully contains all cells of trajectory B.
CREATE OR REPLACE MACRO CS_Contains(cs_a, cs_b) AS (
    NOT EXISTS (
        SELECT cell_z21 FROM query_table(cs_b)
        EXCEPT
        SELECT cell_z21 FROM query_table(cs_a)
    )
);

CREATE OR REPLACE MACRO CS_Disjoint(cs_a, cs_b) AS (
        NOT EXISTS (
            SELECT 1
            FROM query_table(cs_a) a
            INNER JOIN query_table(cs_b) b
              ON a.cell_z21 = b.cell_z21
        )
    );


--calculate the percentage of cells in cellstring b that are also in cellstring a - i.e. covarage procentage
CREATE OR REPLACE MACRO CS_Coverage(cs_a, cs_b) AS (
    COALESCE(
        (
            SELECT count(DISTINCT a.cell_z21) * 100.0
            FROM query_table(cs_a) a
            INNER JOIN query_table(cs_b) b ON a.cell_z21 = b.cell_z21
        )
        /
        NULLIF((SELECT count(DISTINCT cell_z21) FROM query_table(cs_b)), 0),
        0.0
    )
);

--Coverage macro: Computes the percentage of an area covered by a vessel trajectories
CREATE OR REPLACE MACRO CS_CoverageByMMSI(area_table, target_area_id, traj_table, stop_table) AS TABLE (
    WITH area_cells AS (
        SELECT
            cell_z21,
            COUNT(*) OVER() AS total_cells_in_area
        FROM query_table(area_table)
        WHERE area_id = target_area_id
    ),
    vessel_footprint AS (
        SELECT mmsi, cell_z21 FROM query_table(traj_table)
        UNION
        SELECT mmsi, cell_z21 FROM query_table(stop_table)
    ),
    intersecting_cells AS (
        SELECT
            v.mmsi,
            v.cell_z21,
            a.total_cells_in_area
        FROM vessel_footprint v
        INNER JOIN area_cells a ON v.cell_z21 = a.cell_z21
    )
    SELECT
        mmsi,
        COUNT(cell_z21) AS intersecting_cells,
        MAX(total_cells_in_area) AS total_area_cells,
        ROUND(
            (COUNT(cell_z21)::DOUBLE / NULLIF(MAX(total_cells_in_area), 0)) * 100,
            4
        ) AS coverage_percentage
    FROM intersecting_cells
    GROUP BY mmsi
    ORDER BY coverage_percentage DESC
);

CREATE OR REPLACE MACRO CS_NewCoverageByMMSI(cs_area, cs_vessel_footprint) AS TABLE (
    WITH area_cells AS (
        SELECT
            cell_z21,
            COUNT(*) OVER() AS total_cells_in_area
        FROM (SELECT DISTINCT cell_z21 FROM query_table(cs_area))
    ),
    unique_vessel_cells AS (
        SELECT DISTINCT mmsi, cell_z21 
        FROM query_table(cs_vessel_footprint)
    ),
    intersecting_cells AS (
        SELECT
            v.mmsi,
            v.cell_z21,
            a.total_cells_in_area
        FROM unique_vessel_cells v
        INNER JOIN area_cells a ON v.cell_z21 = a.cell_z21
    )
    SELECT
        mmsi,
        COUNT(cell_z21) AS intersecting_cells,
        MAX(total_cells_in_area) AS total_area_cells,
        ROUND(
            (COUNT(cell_z21)::DOUBLE / NULLIF(MAX(total_cells_in_area), 0)) * 100.0,
            4
        ) AS coverage_percentage
    FROM intersecting_cells
    GROUP BY mmsi
    ORDER BY coverage_percentage DESC
);

--Visualizoomation macros to convert cell IDs to geometries for plotting
-----------------------------------------------------------------------------------------------

-- CS_CellAsPoint: Converts a cell ID to a point geometry at the cell's centroid.
CREATE OR REPLACE MACRO CS_CellAsPoint(cell_id, zoom) AS
    ST_Centroid(CS_CellAsPolygon(cell_id, zoom));

-- Reconstruct LineString from a trajectory (ordered by timestamp)
CREATE OR REPLACE MACRO CS_AsLineString(traj_id_param, zoom) AS (
    SELECT ST_MakeLine(list(CS_CellAsPolygon(cell_id, zoom) ORDER BY timestamp))
    FROM cells
    WHERE traj_id = traj_id_param
);

-- CS_CellStringAsPolygon: Converts all cells of a cellstring into a single or multi polygon geometry representing the union of cell areas.
CREATE OR REPLACE MACRO CS_CellStringAsPolygon(cs, zoom) AS (
    (
        SELECT 
            ST_Union_Agg(ST_Buffer(CS_CellAsPolygon(cell_z21, zoom), 0.00000000000001))
        FROM query_table(cs)
    )
);

-- CS_CellAsPolygon: Converts a cell ID to a polygon geometry representing the cell's area.
CREATE OR REPLACE MACRO CS_CellAsPolygon(cell_id, zoom) AS (
   ST_Transform(
       ST_TileEnvelope(
           zoom::INTEGER,
           list_sum(list_transform(range(zoom), i -> (cell_id >> (2 * i)) & 1 << i))::INTEGER,
           list_sum(list_transform(range(zoom), i -> (cell_id >> (2 * i + 1)) & 1 << i))::INTEGER
       ),
       'EPSG:3857', 'EPSG:4326', true
   )
);