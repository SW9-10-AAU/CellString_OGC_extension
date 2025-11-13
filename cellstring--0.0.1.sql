-- cellstring--0.0.1.sql

-- Drop functions if exist (BIGINT array versions)
-- DROP FUNCTION IF EXISTS CST_Intersects(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersection(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Union(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Difference(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Contains(bigint[], bigint[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Disjoint(bigint[], bigint[]) CASCADE;

-- Drop aggregates if exist (BIGINT array version)
-- DROP AGGREGATE IF EXISTS CST_Union_Agg(bigint[]) CASCADE;

-- Drop functions if exist (INT array versions)
-- DROP FUNCTION IF EXISTS CST_Intersects(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Intersection(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Union(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Difference(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Contains(int[], int[]) CASCADE;
-- DROP FUNCTION IF EXISTS CST_Disjoint(int[], int[]) CASCADE;

-- Drop aggregates if exist (INT array version)
-- DROP AGGREGATE IF EXISTS CST_Union_Agg(int[]) CASCADE;


------------------------ Functions for cellstring operations (bigint[] inputs) -----------------------------
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
  

------------------------ Functions for cellstring operations (int[] inputs) -----------------------------

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
  IS 'Returns true if two cellstrings share at least one cell (overlap) [int array version]';

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
  IS 'Returns the intersection of two cellstrings (common cells) [int array version]';

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
  IS 'Returns the union of two cellstrings (all cells in either) [int array version]';

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
  IS 'Returns true if two cellstrings share no cells (i.e., disjoint: no overlap) [int array version]';

-- Aggregate for int[]
DROP AGGREGATE IF EXISTS CST_Union_Agg(int[]) CASCADE;

CREATE AGGREGATE CST_Union_Agg(int[]) (
    SFUNC = CST_Union,
    STYPE = int[]
);

COMMENT ON AGGREGATE CST_Union_Agg(int[])
  IS 'Aggregate to compute the union of multiple cellstrings [int array version]';

