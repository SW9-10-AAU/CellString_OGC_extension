-- cellstring--0.0.1.sql

-- Drop any operators depending on cellstring first
--DROP OPERATOR IF EXISTS @>~ (cellstring, cellstring) CASCADE;
--DROP OPERATOR IF EXISTS && (cellstring, cellstring) CASCADE;
--DROP OPERATOR IF EXISTS & (cellstring, cellstring) CASCADE;
--DROP OPERATOR IF EXISTS | (cellstring, cellstring) CASCADE;
--DROP OPERATOR IF EXISTS - (cellstring, cellstring) CASCADE;

-- Drop functions
--DROP FUNCTION IF EXISTS CST_Contains(cellstring, cellstring) CASCADE;
--DROP FUNCTION IF EXISTS CST_Difference(cellstring, cellstring) CASCADE;
--DROP FUNCTION IF EXISTS CST_Union(cellstring, cellstring) CASCADE;
--DROP FUNCTION IF EXISTS CST_Intersection(cellstring, cellstring) CASCADE;
--DROP FUNCTION IF EXISTS CST_Intersects(cellstring, cellstring) CASCADE;

-- Finally drop the domain
--DROP DOMAIN IF EXISTS cellstring CASCADE;

-- Create domain; enforce no NULL elements
CREATE DOMAIN cellstring AS bigint[]
  NOT NULL
  CHECK (
    array_position(VALUE, NULL) IS NULL
  );

COMMENT ON DOMAIN cellstring
  IS 'Alias domain over bigint[] (no NULL elements) representing cell multi-sets';

-- Functions
CREATE OR REPLACE FUNCTION CST_Intersects(a cellstring, b cellstring)
    RETURNS boolean
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT (a::bigint[]) OPERATOR(pg_catalog.&&) (b::bigint[]);
$$;

COMMENT ON FUNCTION CST_Intersects(cellstring, cellstring)
  IS 'Returns true if two cellstrings share at least one cell (overlap)';

CREATE OR REPLACE FUNCTION CST_Intersection(a cellstring, b cellstring)
    RETURNS cellstring
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT (a::bigint[]) & (b::bigint[]);
$$;

COMMENT ON FUNCTION CST_Intersection(cellstring, cellstring)
  IS 'Returns the intersection of two cellstrings (common cells)';

CREATE OR REPLACE FUNCTION CST_Union(a cellstring, b cellstring)
    RETURNS cellstring
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT (a::bigint[]) | (b::bigint[]);
$$;

COMMENT ON FUNCTION CST_Union(cellstring, cellstring)
  IS 'Returns the union of two cellstrings (all cells in either)';

CREATE OR REPLACE FUNCTION CST_Difference(a cellstring, b cellstring)
    RETURNS cellstring
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT ((a::bigint[]) - ((a::bigint[]) & (b::bigint[])))::bigint[];
$$;

COMMENT ON FUNCTION CST_Difference(cellstring, cellstring)
  IS 'Returns cells in A that are not in B (A minus intersection)';

CREATE OR REPLACE FUNCTION CST_Contains(a cellstring, b cellstring)
    RETURNS boolean
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT (a::bigint[]) @> (b::bigint[])  -- all B in A
    AND (a::bigint[]) OPERATOR(pg_catalog.&&) (b::bigint[])  -- at least overlap
$$;

COMMENT ON FUNCTION CST_Contains(cellstring, cellstring)
  IS 'Returns true if A contains B (all B’s cells are in A and they overlap)';

-- Operators for main set ops
CREATE OPERATOR && (
  PROCEDURE = CST_Intersects,
  LEFTARG = cellstring,
  RIGHTARG = cellstring,
  COMMUTATOR = &&,
  RESTRICT = contsel,
  JOIN = contjoinsel
);

CREATE OPERATOR & (
  PROCEDURE = CST_Intersection,
  LEFTARG = cellstring,
  RIGHTARG = cellstring
);

CREATE OPERATOR | (
  PROCEDURE = CST_Union,
  LEFTARG = cellstring,
  RIGHTARG = cellstring
);

CREATE OPERATOR - (
  PROCEDURE = CST_Difference,
  LEFTARG = cellstring,
  RIGHTARG = cellstring
);

CREATE OPERATOR @>~ (
  PROCEDURE = CST_Contains,
  LEFTARG = cellstring,
  RIGHTARG = cellstring
);
