-- cellstring--0.0.1.sql

----- Drop functions -----
-- DROP FUNCTION IF EXISTS CST_Intersects(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersects(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersection(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersection(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Union(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Union(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Difference(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Difference(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Contains(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Contains(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Disjoint(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Disjoint(int[], int[]) CASCADE;

-- DROP FUNCTION IF EXISTS CST_Coverage(bigint[], bigint[]) CASCADE;


-- DROP FUNCTION IF EXISTS CST_TileXY(bigint, integer) CASCADE;
-- DROP FUNCTION IF EXISTS CST_CellAsPolygon(bigint, integer) CASCADE;
-- DROP FUNCTION IF EXISTS CST_AsMultiPolygon(bigint[], integer) CASCADE;
-- DROP FUNCTION IF EXISTS CST_CellAsPoint(bigint, integer) CASCADE;
-- DROP FUNCTION IF EXISTS CST_AsLineString(bigint[], integer) CASCADE;
-- DROP FUNCTION IF EXISTS CST_HausdorffDistance(bigint[], geometry, integer) CASCADE;

----- Drop aggregates -----
-- DROP AGGREGATE IF EXISTS CST_Union_Agg(bigint[]) CASCADE;
-- DROP AGGREGATE IF EXISTS CST_Union_Agg(int[]) CASCADE;

------------------------ Functions for CellString operations (bigint[] inputs) -----------------------------
CREATE OR REPLACE FUNCTION CST_Intersects(cs_a bigint[], cs_b bigint[])
    RETURNS boolean
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a && cs_b;
$$;

COMMENT ON FUNCTION CST_Intersects(bigint[], bigint[])
  IS 'Returns true if two CellStrings share at least one cell (overlap)';

CREATE OR REPLACE FUNCTION CST_Intersection(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a & cs_b;
$$;

COMMENT ON FUNCTION CST_Intersection(bigint[], bigint[])
  IS 'Returns the intersection of two CellStrings (common cells)';

CREATE OR REPLACE FUNCTION CST_Union(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a | cs_b;
$$;

COMMENT ON FUNCTION CST_Union(bigint[], bigint[])
  IS 'Returns the union of two CellStrings (all cells in either)';

CREATE OR REPLACE FUNCTION CST_Difference(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a - ((cs_a) & (cs_b));
$$;

COMMENT ON FUNCTION CST_Difference(bigint[], bigint[])
  IS 'Returns cells in A that are not in B (A minus intersection)';

CREATE OR REPLACE FUNCTION CST_Contains(cs_a bigint[], cs_b bigint[])
    RETURNS boolean
    LANGUAGE SQL
   IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT (cs_a @> cs_b AND cs_a && cs_b)
$$;

COMMENT ON FUNCTION CST_Contains(bigint[], bigint[])
  IS 'Returns true if A contains B (all B’s cells are in A and they overlap)';

CREATE OR REPLACE FUNCTION CST_Disjoint(cs_a bigint[], cs_b bigint[])
  RETURNS boolean
  LANGUAGE SQL
  IMMUTABLE
  PARALLEL SAFE
AS $$
    SELECT NOT (cs_a && cs_b);
$$;

COMMENT ON FUNCTION CST_Disjoint(bigint[], bigint[])
  IS 'Returns true if two CellStrings share no cells (i.e., disjoint: no overlap)';
  
-- Aggregates
CREATE OR REPLACE AGGREGATE CST_Union_Agg(bigint[]) (
    SFUNC = CST_Union,
    STYPE = bigint[]
);

COMMENT ON AGGREGATE CST_Union_Agg(bigint[])
  IS 'Aggregate to compute the union of multiple CellStrings';
  

------------------------ Functions for CellString operations (int[] inputs) -----------------------------

-- CST_Intersects
CREATE OR REPLACE FUNCTION CST_Intersects(cs_a int[], cs_b int[])
    RETURNS boolean
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a && cs_b;
$$;

COMMENT ON FUNCTION CST_Intersects(int[], int[])
  IS 'Returns true if two CellStrings share at least one cell (overlap) [int array version]';

-- CST_Intersection
CREATE OR REPLACE FUNCTION CST_Intersection(cs_a int[], cs_b int[])
    RETURNS int[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a & cs_b;
$$;

COMMENT ON FUNCTION CST_Intersection(int[], int[])
  IS 'Returns the intersection of two CellStrings (common cells) [int array version]';

-- CST_Union
CREATE OR REPLACE FUNCTION CST_Union(cs_a int[], cs_b int[])
    RETURNS int[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a | cs_b;
$$;

COMMENT ON FUNCTION CST_Union(int[], int[])
  IS 'Returns the union of two CellStrings (all cells in either) [int array version]';

-- CST_Difference
CREATE OR REPLACE FUNCTION CST_Difference(cs_a int[], cs_b int[])
    RETURNS int[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a - (cs_a & cs_b);
$$;

COMMENT ON FUNCTION CST_Difference(int[], int[])
  IS 'Returns cells in A that are not in B (A minus intersection) [int array version]';

-- CST_Contains
CREATE OR REPLACE FUNCTION CST_Contains(cs_a int[], cs_b int[])
    RETURNS boolean
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT (cs_a @> cs_b AND cs_a && cs_b);
$$;

COMMENT ON FUNCTION CST_Contains(int[], int[])
  IS 'Returns true if A contains B (all B’s cells are in A and they overlap) [int array version]';

-- CST_Disjoint
CREATE OR REPLACE FUNCTION CST_Disjoint(cs_a int[], cs_b int[])
    RETURNS boolean
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT NOT (cs_a && cs_b);
$$;

COMMENT ON FUNCTION CST_Disjoint(int[], int[])
  IS 'Returns true if two CellStrings share no cells (i.e., disjoint: no overlap) [int array version]';

-- Aggregate for int[]
DROP AGGREGATE IF EXISTS CST_Union_Agg(int[]) CASCADE;

CREATE AGGREGATE CST_Union_Agg(int[]) (
    SFUNC = CST_Union,
    STYPE = int[]
);

COMMENT ON AGGREGATE CST_Union_Agg(int[])
  IS 'Aggregate to compute the union of multiple CellStrings [int array version]';


CREATE OR REPLACE FUNCTION CST_Coverage(cs_a bigint[], cs_b bigint[])
RETURNS numeric
LANGUAGE SQL
AS $$
    SELECT
        CASE
            WHEN cardinality(cs_b) = 0 THEN 0
            ELSE ROUND(
                (cardinality(CST_Intersection(cs_a, cs_b))::numeric
                 / cardinality(cs_b)) * 100,
                2
            )
        END AS coverage_percent;
$$;

COMMENT ON FUNCTION CST_Coverage(bigint[], bigint[])
  IS 'Returns the coverage percentage of cellstring A over cellstring B.';



-------------------------Visualisation of CellStrings with respect to zoom levels---------------------------

-- ==========================================================
-- Function: CST_TileXY(cell_id bigint, zoom int)
-- Purpose : Decode a cell ID into tile X/Y coordinates based on zoom level
-- ==========================================================
CREATE OR REPLACE FUNCTION CST_TileXY(
    cell_id BIGINT,
    zoom    INTEGER
)
RETURNS TABLE (
    tile_x INTEGER,
    tile_y INTEGER
)
  IMMUTABLE
  LANGUAGE plpgsql
AS
$$
DECLARE
    base_offset BIGINT;
    multiplier  BIGINT;
BEGIN
    IF zoom = 13 THEN
        base_offset := 100000000;
        multiplier  := 10000;
    ELSIF zoom = 17 THEN
        base_offset := 1000000000000;
        multiplier  := 1000000;
    ELSIF zoom = 21 THEN
        base_offset := 100000000000000;
        multiplier  := 10000000;
    ELSE
        RAISE EXCEPTION 'Unsupported zoom level: % (supported: 13, 17, 21)', zoom;
    END IF;

    RETURN QUERY
    SELECT 
        ((cell_id - base_offset) / multiplier)::INT AS tile_x,
        ((cell_id - base_offset) % multiplier)::INT AS tile_y;
END;
$$;

ALTER FUNCTION CST_TileXY(BIGINT, INTEGER) OWNER TO postgres;


-- ==========================================================
-- Function: CST_CellAsPolygon(cell_id bigint, zoom int)
-- Purpose : Convert a single cell ID to its polygon geometry
-- ==========================================================
CREATE OR REPLACE FUNCTION CST_CellAsPolygon(
    cell_id BIGINT,
    zoom    INTEGER
)
  RETURNS geometry(Polygon, 4326)
  IMMUTABLE
  LANGUAGE plpgsql
AS
$$
DECLARE
    tile_x INT;
    tile_y INT;
BEGIN
    SELECT coords.tile_x, coords.tile_y
      INTO tile_x, tile_y
      FROM CST_TileXY(cell_id, zoom) AS coords;

    RETURN ST_Transform(ST_TileEnvelope(zoom, tile_x, tile_y), 4326);
END;
$$;

ALTER FUNCTION CST_CellAsPolygon(BIGINT, INTEGER) OWNER TO postgres;



-- ==========================================================
-- Function: CST_AsMultiPolygon(cellstring bigint[], zoom int)
-- Purpose : Combine multiple cell polygons into a MultiPolygon
-- ==========================================================
CREATE OR REPLACE FUNCTION CST_AsMultiPolygon(
    cellstring BIGINT[],
    zoom       INTEGER
)
  RETURNS geometry(MultiPolygon, 4326)
  IMMUTABLE
  LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN (
        SELECT ST_Union(cell_geom)
          FROM UNNEST(cellstring) AS cell_id
          CROSS JOIN LATERAL (
              SELECT CST_CellAsPolygon(cell_id, zoom) AS cell_geom
          ) AS f
    );
END;
$$;

ALTER FUNCTION CST_AsMultiPolygon(BIGINT[], INTEGER) OWNER TO postgres;


CREATE OR REPLACE FUNCTION CST_CellAsPoint(
    cell_id BIGINT,
    zoom INTEGER
)
RETURNS geometry(Point, 4326)
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT ST_Centroid(CST_CellAsPolygon(cell_id, zoom));
$$;
COMMENT ON FUNCTION CST_CellAsPoint(BIGINT, INTEGER)
  IS 'Returns the center point (geometry) of a tile for a given cell ID and zoom level.';


CREATE OR REPLACE FUNCTION CST_AsLineString(
    cellstring BIGINT[],
    zoom INTEGER
)
RETURNS geometry(LineString, 4326)
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT ST_MakeLine(points.geom)
    FROM (
        SELECT CST_CellAsPoint(t.id, zoom) AS geom
        FROM unnest(cellstring) WITH ORDINALITY AS t(id, ord)
        ORDER BY t.ord
    ) AS points;
$$;

COMMENT ON FUNCTION CST_AsLineString(BIGINT[], INTEGER)
  IS 'Builds a LineString trajectory from the center points of the cells in a CellString.';


CREATE OR REPLACE FUNCTION CST_HausdorffDistance(
    cellstring BIGINT[],
    original_geom GEOMETRY,
    zoom INTEGER
)
RETURNS DOUBLE PRECISION
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT ST_HausdorffDistance(
        original_geom,
        CST_AsLineString(cellstring, zoom)
    );
$$;

COMMENT ON FUNCTION CST_HausdorffDistance(BIGINT[], GEOMETRY, INTEGER)
  IS 'Computes the Hausdorff distance between an original LineString and its CellString representation at a given zoom.';
