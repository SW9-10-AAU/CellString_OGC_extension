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

-- =============================================================================
-- Create macros
-- =============================================================================

-- CST_Intersects: Returns TRUE if cellstring a intersects with cellstring b.
CREATE OR REPLACE MACRO CST_Intersects(cs_a, cs_b) AS 
    len(list_intersect(cs_a, cs_b)) > 0;

-- CST_Intersection: Returns the list of common cells.
CREATE OR REPLACE MACRO CST_Intersection(cs_a, cs_b) AS 
    list_intersect(cs_a, cs_b);

-- CST_Union: Returns unique union of both lists (A + B distinct).
CREATE OR REPLACE MACRO CST_Union(cs_a, cs_b) AS 
    list_distinct(list_concat(cs_a, cs_b));

-- CST_Difference: Returns cells in A that are NOT in B.
CREATE OR REPLACE MACRO CST_Difference(cs_a, cs_b) AS 
    list_filter(cs_a, x -> NOT list_contains(cs_b, x));

-- CST_Contains: Returns TRUE if A fully contains B.
CREATE OR REPLACE MACRO CST_Contains(cs_a, cs_b) AS 
    len(list_filter(cs_b, x -> NOT list_contains(cs_a, x))) = 0;

-- CST_Disjoint: Returns TRUE if NO cells overlap.
CREATE OR REPLACE MACRO CST_Disjoint(cs_a, cs_b) AS 
    len(list_intersect(cs_a, cs_b)) = 0;

-- CST_Coverage: Returns the coverage percentage of cellstring A over cellstring B.
CREATE OR REPLACE MACRO CST_Coverage(cs_a, cs_b) AS 
    CASE 
        WHEN len(cs_b) = 0 THEN 0 
        ELSE round((len(list_intersect(cs_a, cs_b))::DOUBLE / len(cs_b)::DOUBLE) * 100, 2) 
    END;

-- CST_TileXY: Returns a STRUCT(x, y) for a given ID and zoom.
CREATE OR REPLACE MACRO CST_TileXY(cell_id, zoom) AS
    CASE 
        WHEN zoom = 13 THEN 
            {'x': ((cell_id - 100000000)::BIGINT // 10000), 
             'y': ((cell_id - 100000000)::BIGINT % 10000)}
        WHEN zoom = 17 THEN 
            {'x': ((cell_id - 1000000000000)::BIGINT // 1000000), 
             'y': ((cell_id - 1000000000000)::BIGINT % 1000000)}
        WHEN zoom = 21 THEN 
            {'x': ((cell_id - 100000000000000)::BIGINT // 10000000), 
             'y': ((cell_id - 100000000000000)::BIGINT % 10000000)}
        ELSE 
            {'x': NULL, 'y': NULL} -- Invalid zoom
    END;

-- CST_CellAsPoint: Converts Cell ID -> Geometry Point (Center of tile).
CREATE OR REPLACE MACRO CST_CellAsPoint(cell_id, zoom) AS
    ST_Centroid(CST_CellAsPolygon(cell_id, zoom));

-- CST_CellAsPolygon: Converts Cell ID -> Geometry Polygon (Tile Envelope).
CREATE OR REPLACE MACRO CST_CellAsPolygon(cell_id, zoom) AS
    ST_TileEnvelope(zoom, CST_TileXY(cell_id, zoom).x, CST_TileXY(cell_id, zoom).y)

-- CST_AsLineString: Reconstructs a full LineString from a list of cell IDs.
CREATE OR REPLACE MACRO CST_AsLineString(cs, zoom) AS
    ST_MakeLine(
        list_transform(cs, id -> CST_CellAsPoint(id, zoom))
    );

-- CST_AsPolygon: Reconstructs a full Polygon from a list of cell IDs.
CREATE OR REPLACE MACRO CST_AsPolygon(cs, zoom) AS
    ST_MakePolygon(
        ST_Union(list_transform(cs, id -> CST_CellAsPolygon(id, zoom)))
    );

-- CST_Coverage_ByMMSI (DuckDB query):
-- SELECT mmsi, CST_Coverage(CST_Union(cellstring_col), area_cellstring) 
-- FROM trajectories GROUP BY mmsi ORDER BY 2 DESC;