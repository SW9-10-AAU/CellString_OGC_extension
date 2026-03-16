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
DROP MACRO IF EXISTS CST_Intersects;
DROP MACRO IF EXISTS CST_Intersection;
DROP MACRO IF EXISTS CST_Union;
DROP MACRO IF EXISTS CST_Difference;
DROP MACRO IF EXISTS CST_Contains;
DROP MACRO IF EXISTS CST_Disjoint;
DROP MACRO IF EXISTS CST_Coverage;
DROP MACRO IF EXISTS CST_TileXY;
DROP MACRO IF EXISTS CST_CellAsPoint;
DROP MACRO IF EXISTS CST_CellAsPolygon;
DROP MACRO IF EXISTS CST_AsLineString;
DROP MACRO IF EXISTS CST_AsPolygon;

DROP MACRO IF EXISTS quadkey_to_zxy;
DROP MACRO IF EXISTS zxy_to_quadkey;
DROP MACRO IF EXISTS int_to_quadkey;

-- =============================================================================
-- Create macros
-- =============================================================================

--------------------------------------------------------------------------------
-- Helper macros - Quadkey conversion utilities
--------------------------------------------------------------------------------
-- quadkey_to_zxy: Converts a quadkey string to z, x, y tile coordinates
CREATE OR REPLACE MACRO quadkey_to_zxy(qkey) AS TABLE (
    WITH RECURSIVE
    digits AS (
        SELECT
            qkey,
            length(qkey)::INT           AS z,
            pos + 1                     AS pos,
            substring(qkey, pos + 1, 1) AS digit
        FROM range(length(qkey))        AS t(pos)
    ),
    recur(pos, digit, z, x, y) AS (
        -- base case
        SELECT 0, NULL, (SELECT z FROM digits LIMIT 1), 0::INT, 0::INT
        UNION ALL
        -- recursive step
        SELECT
            d.pos,
            d.digit,
            r.z,
            r.x * 2 + CASE d.digit WHEN '1' THEN 1 WHEN '3' THEN 1 ELSE 0 END,
            r.y * 2 + CASE d.digit WHEN '2' THEN 1 WHEN '3' THEN 1 ELSE 0 END
        FROM recur r
        JOIN digits d ON d.pos = r.pos + 1
    )
    SELECT z, x, y
    FROM recur
    WHERE pos = z
);

-- zxy_to_quadkey: Converts z, x, y tile coordinates to a quadkey string
CREATE OR REPLACE MACRO zxy_to_quadkey(z, x, y) AS (
    WITH RECURSIVE bits(level, quad) AS (
        -- start at level = z, quad = empty string
        SELECT z AS level, ''::VARCHAR AS quad
        UNION ALL
        -- at each step compute digit for current level and append, then decrement level
        SELECT
            level - 1 AS level,
            quad || CAST(
                (
                    CAST(floor(x / pow(2, level - 1)) AS BIGINT) % 2
                    + 2 * (CAST(floor(y / pow(2, level - 1)) AS BIGINT) % 2)
                ) AS INTEGER
            ) AS quad
        FROM bits
        WHERE level > 0
    )
    -- when recursion finishes, one row will have level = 0 and quad = full quadkey
    SELECT quad FROM bits WHERE level = 0 LIMIT 1
);

-- int_to_quadkey: Converts a base-4 integer encoding to a quadkey string
CREATE OR REPLACE MACRO int_to_quadkey(val, z) AS (
    WITH input AS (
        SELECT right(val::BIT::VARCHAR, z * 2) AS bitstring
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

-- --------------------------------------------------------------------------------
-- CellString macros
-- --------------------------------------------------------------------------------


-- CST_Intersects: Returns TRUE if trajectory A shares any cells with trajectory B.
CREATE OR REPLACE MACRO CST_Intersects(traj_id_a, traj_id_b) AS (
    SELECT COUNT(*) > 0
    FROM cells a
    JOIN cells b ON a.cell_id = b.cell_id
    WHERE a.traj_id = traj_id_a AND b.traj_id = traj_id_b
);

-- CST_Intersection: Returns the list of common cells between two trajectories.
CREATE OR REPLACE MACRO CST_Intersection(traj_id_a, traj_id_b) AS TABLE (
    SELECT DISTINCT a.cell_id
    FROM cells a
    JOIN cells b ON a.cell_id = b.cell_id
    WHERE a.traj_id = traj_id_a AND b.traj_id = traj_id_b
);

-- CST_Union: Returns all unique cells from both trajectories.
CREATE OR REPLACE MACRO CST_Union(traj_id_a, traj_id_b) AS TABLE (
    SELECT DISTINCT cell_id
    FROM cells
    WHERE traj_id = traj_id_a OR traj_id = traj_id_b
);

-- CST_Difference: Returns cells in trajectory A that are NOT in trajectory B.
CREATE OR REPLACE MACRO CST_Difference(traj_id_a, traj_id_b) AS TABLE (
    SELECT DISTINCT a.cell_id
    FROM cells a
    WHERE a.traj_id = traj_id_a
      AND NOT EXISTS (
          SELECT 1 FROM cells b 
          WHERE b.traj_id = traj_id_b AND b.cell_id = a.cell_id
      )
);

-- CST_Contains: Returns TRUE if trajectory A fully contains all cells of trajectory B.
CREATE OR REPLACE MACRO CST_Contains(traj_id_a, traj_id_b) AS (
    SELECT COUNT(*) = 0
    FROM cells b
    WHERE b.traj_id = traj_id_b
      AND NOT EXISTS (
          SELECT 1 FROM cells a 
          WHERE a.traj_id = traj_id_a AND a.cell_id = b.cell_id
      )
);

-- CST_Disjoint: Returns TRUE if trajectories share NO cells.
CREATE OR REPLACE MACRO CST_Disjoint(traj_id_a, traj_id_b) AS (
    SELECT COUNT(*) = 0
    FROM cells a
    JOIN cells b ON a.cell_id = b.cell_id
    WHERE a.traj_id = traj_id_a AND b.traj_id = traj_id_b
);

 -- New: Uses quadkey integer decoding at fixed zoom 21
CREATE OR REPLACE MACRO CST_TileXY(cell_id) AS (
    SELECT {'x': x, 'y': y} FROM quadkey_to_zxy(int_to_quadkey(cell_id, 21))
);

-- CST_CellAsPolygon: Converts a cell ID to its corresponding polygon geometry (tile envelope).
CREATE OR REPLACE MACRO CST_CellAsPolygon(cell_id) AS
    ST_Transform(
        ST_TileEnvelope(21, CST_TileXY(cell_id).x, CST_TileXY(cell_id).y),
        'EPSG:3857',
        'EPSG:4326',
        true
    );

-- CST_CellAsPoint: Converts a cell ID to a point geometry at the cell's centroid.
CREATE OR REPLACE MACRO CST_CellAsPoint(cell_id) AS
    ST_Centroid(CST_CellAsPolygon(cell_id));

-- Reconstruct LineString from a trajectory (ordered by timestamp)
CREATE OR REPLACE MACRO CST_AsLineString(traj_id_param) AS (
    SELECT ST_MakeLine(list(CST_CellAsPoint(cell_id) ORDER BY timestamp))
    FROM cells
    WHERE traj_id = traj_id_param
);

-- CST_AsPolygon: Reconstructs a full Polygon from a trajectory's cells.
CREATE OR REPLACE MACRO CST_AsPolygon(tablename, col_name, col_val) AS (
    SELECT ST_Union_Agg(CST_CellAsPolygon(cell_z21))
    FROM query_table(tablename)
    WHERE COLUMNS(col_name) = col_val
);


--experiment fast visual

CREATE OR REPLACE MACRO fast_CST_AsPolygon(tbl_name, id_col, target_id) AS (
    SELECT
        -- ConcaveHull ensures all unique cells are "melted" into one single Polygon
        ST_ConcaveHull(
            ST_Union_Agg(fast_tile_to_geom(cell_val, 21)),
            0.1::DOUBLE,
            false
        )
    FROM query(
        'SELECT cell_z21 AS cell_val FROM ' || tbl_name ||
        ' WHERE ' || id_col || ' = ' || target_id
    )
);


CREATE OR REPLACE MACRO fast_tile_to_geom(tile_id, z) AS (
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








-- CST_Coverage_ByMMSI (DuckDB query):
-- SELECT mmsi, CST_Coverage(CST_Union(cellstring_col), area_cellstring) 
-- FROM trajectories GROUP BY mmsi ORDER BY 2 DESC;


-- CST_Coverage: Returns the coverage percentage of cellstring A over cellstring B.
-- CREATE OR REPLACE MACRO CST_Coverage(cs_a, cs_b) AS 
--     CASE 
--         WHEN len(cs_b) = 0 THEN 0 
--         ELSE round((len(list_intersect(cs_a, cs_b))::DOUBLE / len(cs_b)::DOUBLE) * 100, 2) 
--     END;