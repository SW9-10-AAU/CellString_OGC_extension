-- =============================================================================
-- CellString DuckDB extension
-- =============================================================================
-- Ensure the 'spatial' extension is installed: INSTALL spatial; LOAD spatial;
INSTALL spatial; 
LOAD spatial;
-- =============================================================================
-- Drop existing macros (for clean reinstallation)
-- =============================================================================
DROP MACRO IF EXISTS CS_Intersects;
DROP MACRO TABLE IF EXISTS CS_Intersection;
DROP MACRO TABLE IF EXISTS CS_Union;
DROP MACRO TABLE IF EXISTS CS_Difference;
DROP MACRO IF EXISTS CS_Contains;
DROP MACRO IF EXISTS CS_Disjoint;
DROP MACRO IF EXISTS CS_Coverage;
DROP MACRO IF EXISTS CS_CellAsPoint;
DROP MACRO IF EXISTS CS_CellIdToTileZXY;
DROP MACRO IF EXISTS CS_GetParentCellId;
DROP MACRO IF EXISTS CS_CellAsPolygon;
DROP MACRO IF EXISTS CS_AsLineString;
DROP MACRO IF EXISTS CS_AsPolygon;
DROP MACRO TABLE IF EXISTS CS_CoverageByMMSI;

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

-- int_to_quadkey: Converts a base-4 integer encoding to a quadkey string (UKC - https://pypi.org/project/ukc_core/)
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

-- --------------------------------------------------------------------------------
-- CellString macros
-- --------------------------------------------------------------------------------

-- CS_Intersects: Returns TRUE if cellstring A and B share at least one common cell.
CREATE OR REPLACE MACRO CS_Intersects(cs_a, cs_b) AS (
    EXISTS (
        SELECT 1
        FROM query_table(cs_a) a
        JOIN query_table(cs_b) b ON a.cell_z21 = b.cell_z21
    )
);

-- CS_Intersection: Returns the set of unique cells that are common to both cellstrings.
CREATE OR REPLACE MACRO CS_Intersection(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    INTERSECT
    SELECT cell_z21 FROM query_table(cs_b)
);

-- CS_Union: Returns all unique cells from both cellstrings.
CREATE OR REPLACE MACRO CS_Union(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    UNION
    SELECT cell_z21 FROM query_table(cs_b)
);

-- CS_Difference: Returns cells in cellstring A that are NOT in cellstring B.
CREATE OR REPLACE MACRO CS_Difference(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    EXCEPT
    SELECT cell_z21 FROM query_table(cs_b)
);

-- CS_Contains: Returns TRUE if cellstring A fully contains all cells of cellstring B.
CREATE OR REPLACE MACRO CS_Contains(cs_a, cs_b) AS (
    NOT EXISTS (
        SELECT cell_z21 FROM query_table(cs_b)
        EXCEPT
        SELECT cell_z21 FROM query_table(cs_a)
    )
);

-- CS_Disjoint: Returns TRUE if cellstring A and B have no cells in common.
CREATE OR REPLACE MACRO CS_Disjoint(cs_a, cs_b) AS (
    NOT EXISTS (
        SELECT cell_z21 FROM query_table(cs_a)
        INTERSECT
        SELECT cell_z21 FROM query_table(cs_b)
    )
);

-- Calculate the percentage of cells in cellstring b that are also in cellstring a - i.e. coverage percentage
CREATE OR REPLACE MACRO CS_Coverage(cs_a, cs_b) AS (
    COALESCE(
        (
            SELECT count(DISTINCT a.cell_z21) * 100.0
            FROM query_table(cs_a) a
            JOIN query_table(cs_b) b ON a.cell_z21 = b.cell_z21
        )
        /
        NULLIF((SELECT count(DISTINCT cell_z21) FROM query_table(cs_b)), 0),
        0.0
    )
);

-- Calculate coverage percentage of a vessel's footprint (cellstring) over a defined area (cellstring), grouped by vessel identifier (e.g. MMSI)
CREATE OR REPLACE MACRO CS_CoverageByMMSI(cs_area, cs_vessel_footprint) AS TABLE (
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
        JOIN area_cells a ON v.cell_z21 = a.cell_z21
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

-- Visualisation macros to convert cell IDs to geometries for plotting
-----------------------------------------------------------------------------------------------

-- -- CS_CellAsPolygon: Converts a cell ID to a polygon geometry representing the cell's area.
-- CREATE OR REPLACE MACRO CS_CellAsPolygon(cell_id, zoom) AS (
--    ST_Transform(
--        ST_TileEnvelope(
--            zoom::INTEGER,
--            list_sum(list_transform(range(zoom), i -> (cell_id >> (2 * i)) & 1 << i))::INTEGER,
--            list_sum(list_transform(range(zoom), i -> (cell_id >> (2 * i + 1)) & 1 << i))::INTEGER
--        ),
--        'EPSG:3857', 'EPSG:4326', true
--    )
-- );

CREATE OR REPLACE MACRO CS_CellIdToTileZXY(cell_id, zoom) AS (
    {
        z: zoom::INTEGER,
        --Bit De-interleaving, reversing a Morton Order (Z-order curve) encoding to get x and y
        x: list_sum(list_transform(range(zoom), i -> (cell_id >> (2 * i)) & 1 << i))::INTEGER, -- Even positions (0, 2, 4...) contain the bits for the X coordinate.
        y: list_sum(list_transform(range(zoom), i -> (cell_id >> (2 * i + 1)) & 1 << i))::INTEGER -- Odd positions (1, 3, 5...) contain the bits for the Y coordinate.
    }
);

CREATE OR REPLACE MACRO CS_CellAsPolygon(cell_id, zoom) AS (
   ST_Transform(
       ST_TileEnvelope(
           CS_CellIdToTileZXY(cell_id, zoom).z,
           CS_CellIdToTileZXY(cell_id, zoom).x,
           CS_CellIdToTileZXY(cell_id, zoom).y
       ),
       'EPSG:3857', 'EPSG:4326', true
   )
);

-- CS_CellAsPoint: Converts a cell ID to a point geometry at the cell's centroid.
CREATE OR REPLACE MACRO CS_CellAsPoint(cell_id, zoom) AS
    ST_Centroid(CS_CellAsPolygon(cell_id, zoom));

-- Reconstruct LineString from a trajectory (ordered by timestamp)
CREATE OR REPLACE MACRO CS_AsLineString(cs, zoom) AS (
    SELECT ST_MakeLine(list(CS_CellAsPoint(cell_z21, zoom) ORDER BY ts))
    FROM query_table(cs)
);

-- CS_CellStringAsPolygon: Converts all cells of a cellstring into a single or multi polygon geometry representing the union of cell areas.
CREATE OR REPLACE MACRO CS_AsPolygon(cs, zoom) AS (
    (
        SELECT 
            ST_Union_Agg(ST_Buffer(CS_CellAsPolygon(cell_z21, zoom), 0.00000000000001))
        FROM query_table(cs)
    )
);

