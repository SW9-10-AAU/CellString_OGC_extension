-- cellstring--0.0.1.sql

-- Drop functions
-- DROP FUNCTION IF EXISTS CST_Contains(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Difference(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Union(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersection(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersects(bigint[], bigint[]) CASCADE;

-- Functions
CREATE OR REPLACE FUNCTION CST_Intersects(cs_a bigint[], cs_b bigint[])
    RETURNS boolean
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a && cs_b;
$$;

COMMENT ON FUNCTION CST_Intersects(bigint[], bigint[])
  IS 'Returns true if two cellstrings share at least one cell (overlap)';

CREATE OR REPLACE FUNCTION CST_Intersection(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a & cs_b;
$$;

COMMENT ON FUNCTION CST_Intersection(bigint[], bigint[])
  IS 'Returns the intersection of two cellstrings (common cells)';

CREATE OR REPLACE FUNCTION CST_Union(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL
    IMMUTABLE
    PARALLEL SAFE
AS $$
    SELECT cs_a | cs_b;
$$;

COMMENT ON FUNCTION CST_Union(bigint[], bigint[])
  IS 'Returns the union of two cellstrings (all cells in either)';

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
  IS 'Returns true if two cellstrings share no cells (i.e., disjoint: no overlap)';
  
-- Aggregates
CREATE AGGREGATE CST_Union_Agg(bigint[]) (
    SFUNC = CST_Union,
    STYPE = bigint[]
);

COMMENT ON AGGREGATE CST_Union_Agg(bigint[])
  IS 'Aggregate to compute the union of multiple cellstrings';



-------------------------Visualisation of cellstrings with respect to zoom levels---------------------------
-- ==========================================================
-- Drop existing functions (safe for reloads)
-- ==========================================================
-- DROP FUNCTION IF EXISTS decode_cellid_to_tile_xy(bigint, integer) CASCADE;
-- DROP FUNCTION IF EXISTS cellid_to_polygon(bigint, integer)        CASCADE;
-- DROP FUNCTION IF EXISTS cellids_to_polygons(bigint[], integer)    CASCADE;


-- ==========================================================
-- Function: decode_cellid_to_tile_xy(cell_id bigint, zoom int)
-- Purpose : Decode a cell ID into tile X/Y coordinates based on zoom level
-- ==========================================================
CREATE OR REPLACE FUNCTION decode_cellid_to_tile_xy(
    cell_id BIGINT,
    zoom     INTEGER
)
RETURNS TABLE (
    x INTEGER,
    y INTEGER
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
        ((cell_id - base_offset) / multiplier)::INT AS x,
        ((cell_id - base_offset) % multiplier)::INT AS y;
END;
$$;

ALTER FUNCTION decode_cellid_to_tile_xy(BIGINT, INTEGER) OWNER TO postgres;



-- ==========================================================
-- Function: cellid_to_polygon(cell_id bigint, zoom int)
-- Purpose : Convert a single cell ID to its polygon geometry
-- ==========================================================
CREATE OR REPLACE FUNCTION draw_cell(
    cell_id BIGINT,
    zoom     INTEGER
)
  RETURNS geometry
  IMMUTABLE
  LANGUAGE plpgsql
AS
$$
DECLARE
    px INT;
    py INT;
BEGIN
    SELECT d.x, d.y
      INTO px, py
      FROM decode_cellid_to_tile_xy(cell_id, zoom) AS d;

    RETURN ST_Transform(ST_TileEnvelope(zoom, px, py), 4326);
END;
$$;

ALTER FUNCTION draw_cell(BIGINT, INTEGER) OWNER TO postgres;



-- ==========================================================
-- Function: cellids_to_polygons(cell_ids bigint[], zoom int)
-- Purpose : Combine multiple cell polygons into a MultiPolygon
-- ==========================================================
CREATE OR REPLACE FUNCTION draw_cellstring(
    cell_ids BIGINT[],
    zoom     INTEGER
)
  RETURNS geometry
  IMMUTABLE
  LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN (
        SELECT ST_Union(cell_geom)
          FROM UNNEST(cell_ids) AS cid
          CROSS JOIN LATERAL (
              SELECT draw_cell(cid, zoom) AS cell_geom
          ) AS f
    );
END;
$$;

ALTER FUNCTION draw_cellstring(BIGINT[], INTEGER) OWNER TO postgres;
