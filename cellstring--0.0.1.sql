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
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT cs_a && cs_b;
$$;

COMMENT ON FUNCTION CST_Intersects(bigint[], bigint[])
  IS 'Returns true if two cellstrings share at least one cell (overlap)';

CREATE OR REPLACE FUNCTION CST_Intersection(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT cs_a & cs_b;
$$;

COMMENT ON FUNCTION CST_Intersection(bigint[], bigint[])
  IS 'Returns the intersection of two cellstrings (common cells)';

CREATE OR REPLACE FUNCTION CST_Union(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT cs_a | cs_b;
$$;

COMMENT ON FUNCTION CST_Union(bigint[], bigint[])
  IS 'Returns the union of two cellstrings (all cells in either)';

CREATE OR REPLACE FUNCTION CST_Difference(cs_a bigint[], cs_b bigint[])
    RETURNS bigint[]
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT cs_a - ((cs_a) & (cs_b));
$$;

COMMENT ON FUNCTION CST_Difference(bigint[], bigint[])
  IS 'Returns cells in A that are not in B (A minus intersection)';

CREATE OR REPLACE FUNCTION CST_Contains(cs_a bigint[], cs_b bigint[])
    RETURNS boolean
    LANGUAGE SQL IMMUTABLE
PARALLEL SAFE
AS $$
SELECT (cs_a @> cs_b AND cs_a && cs_b)
$$;

COMMENT ON FUNCTION CST_Contains(bigint[], bigint[])
  IS 'Returns true if A contains B (all B’s cells are in A and they overlap)';