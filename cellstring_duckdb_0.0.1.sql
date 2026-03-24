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
-- DROP MACRO IF EXISTS CST_Intersects;
-- DROP MACRO IF EXISTS CST_Intersection;
-- DROP MACRO IF EXISTS CST_Union;
-- DROP MACRO IF EXISTS CST_Difference;
-- DROP MACRO IF EXISTS CST_Contains;
-- DROP MACRO IF EXISTS CST_Disjoint;
-- DROP MACRO IF EXISTS CST_Coverage;
DROP MACRO IF EXISTS CST_CellAsPoint;
DROP MACRO IF EXISTS CST_AsPolygon;
DROP MACRO IF EXISTS CST_AsLineString;
DROP MACRO IF EXISTS CST_CellAsPolygon;
DROP MACRO IF EXISTS CST_CoverageByMMSI;

-- DROP MACRO IF EXISTS quadkey_to_zxy;
-- DROP MACRO IF EXISTS zxy_to_quadkey;
-- DROP MACRO IF EXISTS int_to_quadkey;

-- =============================================================================
-- Create macros
-- =============================================================================

--------------------------------------------------------------------------------
-- Helper macros - Quadkey conversion utilities
--------------------------------------------------------------------------------
-- quadkey_to_zxy: Converts a quadkey string to z, x, y tile coordinates
-- CREATE OR REPLACE MACRO quadkey_to_zxy(qkey) AS TABLE (
--     WITH RECURSIVE
--     digits AS (
--         SELECT
--             qkey,
--             length(qkey)::INT           AS z,
--             pos + 1                     AS pos,
--             substring(qkey, pos + 1, 1) AS digit
--         FROM range(length(qkey))        AS t(pos)
--     ),
--     recur(pos, digit, z, x, y) AS (
--         -- base case
--         SELECT 0, NULL, (SELECT z FROM digits LIMIT 1), 0::INT, 0::INT
--         UNION ALL
--         -- recursive step
--         SELECT
--             d.pos,
--             d.digit,
--             r.z,
--             r.x * 2 + CASE d.digit WHEN '1' THEN 1 WHEN '3' THEN 1 ELSE 0 END,
--             r.y * 2 + CASE d.digit WHEN '2' THEN 1 WHEN '3' THEN 1 ELSE 0 END
--         FROM recur r
--         JOIN digits d ON d.pos = r.pos + 1
--     )
--     SELECT z, x, y
--     FROM recur
--     WHERE pos = z
-- );

-- -- zxy_to_quadkey: Converts z, x, y tile coordinates to a quadkey string
-- CREATE OR REPLACE MACRO zxy_to_quadkey(z, x, y) AS (
--     WITH RECURSIVE bits(level, quad) AS (
--         -- start at level = z, quad = empty string
--         SELECT z AS level, ''::VARCHAR AS quad
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

-- -- int_to_quadkey: Converts a base-4 integer encoding to a quadkey string
-- CREATE OR REPLACE MACRO int_to_quadkey(val, z) AS (
--     WITH input AS (
--         SELECT right(val::BIT::VARCHAR, z * 2) AS bitstring
--     )
--     SELECT string_agg(digit, '' ORDER BY pos) AS quadkey
--     FROM (
--         SELECT
--             CASE substr(bitstring, pos, 2)
--                 WHEN '00' THEN '0'
--                 WHEN '01' THEN '1'
--                 WHEN '10' THEN '2'
--                 WHEN '11' THEN '3'
--             END AS digit,
--             pos
--         FROM input, generate_series(1, length(bitstring), 2) AS gs(pos)
--         ORDER BY pos
--     ) t
-- );

--TODO implement the macros.
-- --------------------------------------------------------------------------------
-- CellString macros
-- --------------------------------------------------------------------------------

-- CST_Intersects: Returns TRUE if trajectory A shares any cells with trajectory B.
-- CREATE OR REPLACE MACRO CST_Intersects(traj_id_a, traj_id_b) AS (
--     SELECT COUNT(*) > 0
--     FROM cells a
--     JOIN cells b ON a.cell_id = b.cell_id
--     WHERE a.traj_id = traj_id_a AND b.traj_id = traj_id_b
-- );

-- -- CST_Intersection: Returns the list of common cells between two trajectories.
-- CREATE OR REPLACE MACRO CST_Intersection(traj_id_a, traj_id_b) AS TABLE (
--     SELECT DISTINCT a.cell_id
--     FROM cells a
--     JOIN cells b ON a.cell_id = b.cell_id
--     WHERE a.traj_id = traj_id_a AND b.traj_id = traj_id_b
-- );

-- -- CST_Union: Returns all unique cells from both trajectories.
-- CREATE OR REPLACE MACRO CST_Union(traj_id_a, traj_id_b) AS TABLE (
--     SELECT DISTINCT cell_id
--     FROM cells
--     WHERE traj_id = traj_id_a OR traj_id = traj_id_b
-- );

-- -- CST_Difference: Returns cells in trajectory A that are NOT in trajectory B.
-- CREATE OR REPLACE MACRO CST_Difference(traj_id_a, traj_id_b) AS TABLE (
--     SELECT DISTINCT a.cell_id
--     FROM cells a
--     WHERE a.traj_id = traj_id_a
--       AND NOT EXISTS (
--           SELECT 1 FROM cells b 
--           WHERE b.traj_id = traj_id_b AND b.cell_id = a.cell_id
--       )
-- );

-- -- CST_Contains: Returns TRUE if trajectory A fully contains all cells of trajectory B.
-- CREATE OR REPLACE MACRO CST_Contains(traj_id_a, traj_id_b) AS (
--     SELECT COUNT(*) = 0
--     FROM cells b
--     WHERE b.traj_id = traj_id_b
--       AND NOT EXISTS (
--           SELECT 1 FROM cells a 
--           WHERE a.traj_id = traj_id_a AND a.cell_id = b.cell_id
--       )
-- );

-- -- CST_Disjoint: Returns TRUE if trajectories share NO cells.
-- CREATE OR REPLACE MACRO CST_Disjoint(traj_id_a, traj_id_b) AS (
--     SELECT COUNT(*) = 0
--     FROM cells a
--     JOIN cells b ON a.cell_id = b.cell_id
--     WHERE a.traj_id = traj_id_a AND b.traj_id = traj_id_b
-- );



--Coverage macro: Computes the percentage of an area covered by a vessel trajectories
CREATE OR REPLACE MACRO CST_CoverageByMMSI(area_table, target_area_id, traj_table, stop_table) AS TABLE (
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


--Visualization macro to convert cell IDs to geometries for plotting
-----------------------------------------------------------------------------------------------

-- CST_CellAsPoint: Converts a cell ID to a point geometry at the cell's centroid.
CREATE OR REPLACE MACRO CST_CellAsPoint(cell_id) AS
    ST_Centroid(CST_CellAsPolygon(cell_id, 21));

-- Reconstruct LineString from a trajectory (ordered by timestamp)
CREATE OR REPLACE MACRO CST_AsLineString(traj_id_param) AS (
    SELECT ST_MakeLine(list(CST_CellAsPolygon(cell_id, 21) ORDER BY timestamp))
    FROM cells
    WHERE traj_id = traj_id_param
);

-- CST_AsPolygon: Converts all cells of a trajectory into a single polygon geometry representing the union of the cell areas.
CREATE OR REPLACE MACRO CST_AsPolygon(tbl_name, id_col, target_id) AS (
    SELECT
        ST_Union_Agg(ST_buffer((CST_CellAsPolygon(cell_val, 21)), 0.00000000000001))
    FROM query(
        'SELECT DISTINCT cell_z21 AS cell_val FROM ' || tbl_name ||
        ' WHERE ' || id_col || ' = ' || target_id
    )
);

-- CST_CellAsPolygon: Converts a cell ID to a polygon geometry representing the cell's area.
CREATE OR REPLACE MACRO CST_CellAsPolygon(tile_id, z) AS (
    ST_Transform(
        ST_TileEnvelope(
            z::INTEGER,
            -- Cast the sums to INTEGER to satisfy the function signature
            list_sum(list_transform(range(z), i -> (tile_id >> (2 * i)) & 1 << i))::INTEGER,
            list_sum(list_transform(range(z), i -> (tile_id >> (2 * i + 1)) & 1 << i))::INTEGER
        ),
        'EPSG:3857', 'EPSG:4326', true
    )
);