-- =============================================================================
-- CellString DuckDB extension
-- =============================================================================

-- Ensure the DuckDB spatial extension is installed:
INSTALL spatial; 
LOAD spatial;

-- =============================================================================
-- Drop existing macros
-- =============================================================================
DROP MACRO IF EXISTS CS_Intersects;
DROP MACRO TABLE IF EXISTS CS_Intersection;
DROP MACRO TABLE IF EXISTS CS_Union;
DROP MACRO TABLE IF EXISTS CS_Difference;
DROP MACRO IF EXISTS CS_Contains;
DROP MACRO IF EXISTS CS_Disjoint;
DROP MACRO IF EXISTS CS_Coverage;
DROP MACRO IF EXISTS CS_CellAsPoint;
DROP MACRO IF EXISTS CS_CellToTileZXY;
DROP MACRO IF EXISTS CS_CellToQuadkey;
DROP MACRO IF EXISTS CS_GetParentCell;
DROP MACRO IF EXISTS CS_CellAsPolygon;
DROP MACRO IF EXISTS CS_AsLineString;
DROP MACRO IF EXISTS CS_AsPolygon;
DROP MACRO TABLE IF EXISTS CS_CoverageByMMSI;
DROP MACRO TABLE IF EXISTS CS_Jaccard;
DROP MACRO IF EXISTS CS_Distance;
DROP MACRO IF EXISTS CS_Distance_Decoded;
DROP MACRO TABLE IF EXISTS CS_KNN;
DROP MACRO TABLE IF EXISTS CS_KNN_Decoded;
DROP MACRO TABLE IF EXISTS CS_TrajectorySpatiotemporalZoom;


-- Drop old macros (renamed ones)
DROP MACRO IF EXISTS CS_CellIdToTileZXY;
DROP MACRO IF EXISTS CS_CellIdToQuadkey;
DROP MACRO IF EXISTS CS_GetParentCellId;

-- =============================================================================
-- Create macros
-- =============================================================================

-- int_to_quadkey: Converts a base-4 integer encoding to a quadkey string (UKC_core: https://pypi.org/project/ukc_core/)
CREATE OR REPLACE MACRO CS_CellToQuadkey(cell, zoom) AS (
    WITH input AS (
        SELECT right(cell::BIT::VARCHAR, zoom * 2) AS bitstring
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

-- Get the parent cell at a coarser zoom level by right-shifting the cell's bits according to the zoom difference
CREATE OR REPLACE MACRO CS_GetParentCell(cell, from_zoom, to_zoom) AS (
   CASE
       WHEN to_zoom = from_zoom THEN
           cell
       WHEN to_zoom > from_zoom THEN
           error(format('Parent zoom level must be coarser or equal to current zoom level. Parent zoom level: {} not coarser or equal to current zoom: {}', to_zoom, from_zoom))
      ELSE
           cell >> ((from_zoom - to_zoom) * 2)
   END
);


-- =============================================================================
-- CellString macros
-- =============================================================================

-- CS_Intersection: Returns the set of unique cells that are common to both CellStrings.
CREATE OR REPLACE MACRO CS_Intersection(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    INTERSECT
    SELECT cell_z21 FROM query_table(cs_b)
);

-- CS_Intersects: Returns TRUE if CellString A and B share at least one common cell.
CREATE OR REPLACE MACRO CS_Intersects(cs_a, cs_b) AS (
    EXISTS (
        SELECT 1
        FROM CS_Intersection(cs_a, cs_b)
    )
);

-- CS_Union: Returns all unique cells from both CellStrings.
CREATE OR REPLACE MACRO CS_Union(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    UNION
    SELECT cell_z21 FROM query_table(cs_b)
);

-- CS_Difference: Returns cells in CellString A that are NOT in CellString B.
CREATE OR REPLACE MACRO CS_Difference(cs_a, cs_b) AS TABLE (
    SELECT cell_z21 FROM query_table(cs_a)
    EXCEPT
    SELECT cell_z21 FROM query_table(cs_b)
);

-- CS_Contains: Returns TRUE if CellString A fully contains all cells of CellString B.
CREATE OR REPLACE MACRO CS_Contains(cs_a, cs_b) AS (
    NOT EXISTS (
        CS_Difference(cs_a, cs_b)
    )
);

-- CS_Disjoint: Returns TRUE if CellString A and B have no cells in common.
CREATE OR REPLACE MACRO CS_Disjoint(cs_a, cs_b) AS (
    NOT EXISTS (
        CS_Intersection(cs_a, cs_b)
    )
);

-- Calculate the percentage of cells in CellString b that are also in CellString a - i.e. coverage percentage
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

-- Calculate coverage percentage of vessels' footprint (CellString) over a defined CellString region (CellString), grouped by vessel identifier (MMSI)
CREATE OR REPLACE MACRO CS_CoverageByMMSI(cs_region, cs_vessel_footprint) AS TABLE (
    WITH region_cells AS (
        SELECT
            cell_z21,
            COUNT(*) OVER() AS total_cells_in_region
        FROM (SELECT DISTINCT cell_z21 FROM query_table(cs_region))
    ),
    unique_vessel_cells AS (
        SELECT DISTINCT mmsi, cell_z21 
        FROM query_table(cs_vessel_footprint)
    ),
    intersecting_cells AS (
        SELECT
            v.mmsi,
            v.cell_z21,
            a.total_cells_in_region
        FROM unique_vessel_cells v
        JOIN region_cells a ON v.cell_z21 = a.cell_z21
    )
    SELECT
        mmsi,
        COUNT(cell_z21) AS intersecting_cells,
        MAX(total_cells_in_region) AS total_region_cells,
        ROUND(
            (COUNT(cell_z21)::DOUBLE / NULLIF(MAX(total_cells_in_region), 0)) * 100.0,
            4
        ) AS coverage_percentage
    FROM intersecting_cells
    GROUP BY mmsi
    ORDER BY coverage_percentage DESC
);

-----------------------------------------------------------------------------------------------
-- Visualisation macros to convert cells to geometries
-----------------------------------------------------------------------------------------------

CREATE OR REPLACE MACRO CS_CellToTileZXY(cell, zoom) AS (
    {
        z: zoom::INTEGER,
        --Bit De-interleaving, reversing a Morton Order (Z-order curve) encoding to get x and y
        x: list_sum(list_transform(range(zoom), i -> (cell >> (2 * i)) & 1 << i))::INTEGER, -- Even positions (0, 2, 4...) contain the bits for the X coordinate.
        y: list_sum(list_transform(range(zoom), i -> (cell >> (2 * i + 1)) & 1 << i))::INTEGER -- Odd positions (1, 3, 5...) contain the bits for the Y coordinate.
    }
);

CREATE OR REPLACE MACRO CS_CellAsPolygon(cell, zoom) AS (
   ST_Transform(
       ST_TileEnvelope(
           CS_CellToTileZXY(cell, zoom).z,
           CS_CellToTileZXY(cell, zoom).x,
           CS_CellToTileZXY(cell, zoom).y
       ),
       'EPSG:3857', 'EPSG:4326', true
   )
);

-- CS_CellAsPoint: Converts a cell to a point geometry at the cell's centroid.
CREATE OR REPLACE MACRO CS_CellAsPoint(cell, zoom) AS
    ST_Centroid(CS_CellAsPolygon(cell, zoom));

-- Reconstruct LineString from a CellString
CREATE OR REPLACE MACRO CS_AsLineString(cs, zoom) AS (
    SELECT ST_MakeLine(list(CS_CellAsPoint(cell_z21, zoom) ORDER BY ts))
    FROM query_table(cs)
);

-- CS_CellStringAsPolygon: Converts all cells of a CellString into a single or multipolygon geometry representing the union of cells.
CREATE OR REPLACE MACRO CS_AsPolygon(cs, zoom) AS (
    (
        SELECT 
            ST_Union_Agg(ST_Buffer(CS_CellAsPolygon(cell_z21, zoom), 0.00000000000001)) -- tiny buffer to ensure proper union of adjacent polygons
        FROM query_table(cs)
    )
);

-- CS_Jaccard: Calculates the Jaccard similarity score between a query CellString trajectory and candidate CellString trajectories.
CREATE OR REPLACE MACRO CS_Jaccard(cs_a, cs_b) AS TABLE (
    WITH intersection_stats AS (
        SELECT
            c.trajectory_id,
            COUNT(DISTINCT c.cell_z21) AS intersection_cnt
        FROM query_table(cs_b) c
        JOIN cs_a q ON c.cell_z21 = q.cell_z21
        GROUP BY c.trajectory_id
    ),
    candidate_counts AS (
        SELECT
            trajectory_id,
            COUNT(DISTINCT cell_z21) AS candidate_cnt
        FROM query_table(cs_b)
        GROUP BY trajectory_id
    ),
    query_count AS (
        SELECT COUNT(DISTINCT cell_z21) AS query_cnt
        FROM query_table(cs_a)
    )
    SELECT
        i.trajectory_id,
        i.intersection_cnt::FLOAT / (q.query_cnt + c.candidate_cnt - i.intersection_cnt)::FLOAT AS similarity_score
    FROM intersection_stats i
    JOIN candidate_counts c ON i.trajectory_id = c.trajectory_id
    CROSS JOIN query_count q
);


CREATE OR REPLACE MACRO CS_Distance(cell_a, cell_b, zoom) AS (
    GREATEST(
        ABS(
            CS_CellToTileZXY(cell_a, zoom).x
            - CS_CellToTileZXY(cell_b, zoom).x
        ),
        ABS(
            CS_CellToTileZXY(cell_a, zoom).y
            - CS_CellToTileZXY(cell_b, zoom).y
        )
    )
);
       
CREATE OR REPLACE MACRO CS_Distance_Decoded(a_x, a_y, b_x, b_y) AS (
    GREATEST(
        ABS(a_x - b_x),
        ABS(a_y - b_y)
    )
);
--------------------
-- Below is required to do distance with CS_Distance_Decoded, which requires pre-decoding the cells to x,y tile coordinates.
--------------------
-- CREATE OR REPLACE TEMP TABLE trajectory_decoded AS
-- SELECT
--     trajectory_id,
--     cell_z21,
--     CS_CellToTileZXY(cell_z21, 21).x AS x,
--     CS_CellToTileZXY(cell_z21, 21).y AS y
-- FROM trajectory_cs;
--------------------


CREATE OR REPLACE MACRO CS_KNN(cs_a, cs_b, zoom, k) AS TABLE (
    WITH a_cells AS (
        SELECT DISTINCT cell_z21 FROM query_table(cs_a)
    ),
    b_cells AS (
        SELECT DISTINCT cell_z21, trajectory_id FROM query_table(cs_b)
    ),
    distance_calculations AS (
        SELECT
            b.trajectory_id,
            MIN(CS_Distance(a.cell_z21, b.cell_z21, zoom)) AS min_distance
        FROM a_cells a
        CROSS JOIN b_cells b
        GROUP BY b.trajectory_id
    )
    SELECT trajectory_id, min_distance
    FROM distance_calculations
    ORDER BY min_distance
    LIMIT k
);

CREATE OR REPLACE MACRO CS_KNN_Decoded(cs_a, cs_b, zoom, k) AS TABLE (
    WITH
    a_cells AS (
        SELECT * FROM query_table(cs_a)
    ),
    b_cells AS (
        SELECT * FROM query_table(cs_b)
    ),
    distance_calculations AS (
        SELECT
            b.trajectory_id,
            MIN(CS_Distance_Decoded(a.x, a.y, b.x, b.y)) AS min_distance
        FROM a_cells a
        CROSS JOIN b_cells b
        GROUP BY b.trajectory_id
    )
    SELECT
        trajectory_id,
        min_distance
    FROM distance_calculations
    ORDER BY min_distance
    LIMIT k
);
--------------------
-- Below is required to do distance with CS_Distance_Decoded, which requires pre-decoding the cells to x,y tile coordinates.
--------------------
-- CREATE OR REPLACE TEMP TABLE trajectory_decoded AS
-- SELECT
--     trajectory_id,
--     cell_z21,
--     CS_CellToTileZXY(cell_z21, 21).x AS x,
--     CS_CellToTileZXY(cell_z21, 21).y AS y
-- FROM trajectory_cs
--------------------

CREATE OR REPLACE MACRO CS_TrajectorySpatiotemporalZoom(cs_a, target_z) AS TABLE (
SELECT 
   trajectory_id,
   mmsi,
   CS_GetParentCell(cell_z21, 21, target_z) AS parent_cell,
   MIN(ts_entry) AS parent_entry,
   MAX(ts_exit) AS parent_exit
FROM query_table(cs_a)
GROUP BY 
   trajectory_id,
   mmsi,
   parent_cell
);