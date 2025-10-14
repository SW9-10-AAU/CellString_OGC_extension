-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION cellstring" to load this file. \quit

DROP OPERATOR IF EXISTS && (cellstring, cellstring);
DROP OPERATOR IF EXISTS & (cellstring, cellstring);
DROP FUNCTION IF EXISTS CST_Intersects(cellstring, cellstring);
DROP FUNCTION IF EXISTS CST_Intersection(cellstring, cellstring);
DROP DOMAIN IF EXISTS cellstring;

CREATE DOMAIN cellstring AS bigint[] NOT NULL;

COMMENT ON DOMAIN cellstring
    IS 'Alias domain for bigint[] representing “cells”';


-- OGC functions
CREATE FUNCTION CST_Intersects(a cellstring, b cellstring)
RETURNS boolean
LANGUAGE SQL
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT (a::bigint[]) && (b::bigint[]);
$$;

COMMENT ON FUNCTION CST_Intersects(cellstring, cellstring)
    IS 'Return true if two cellstrings share at least one cell (overlap)';

CREATE FUNCTION CST_Intersection(a cellstring, b cellstring)
RETURNS cellstring
LANGUAGE SQL
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT (a::bigint[]) & (b::bigint[])::bigint[];
$$;

COMMENT ON FUNCTION CST_Intersection(cellstring, cellstring)
    IS 'Return the array of common cells between two cellstrings';

CREATE FUNCTION CST_Contains(a cellstring, b cellstring)
RETURNS boolean
LANGUAGE SQL
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT (a::bigint[]) @> (b::bigint[])
       AND (a::bigint[]) && (b::bigint[]);
$$;

COMMENT ON FUNCTION CST_Contains(cellstring, cellstring)
    IS 'Return true if A contains B (all B’s cells are in A AND there is overlap)';

-- You might also create an operator alias, e.g.
CREATE OPERATOR @>~ (  -- custom name to avoid confusion
    PROCEDURE = CST_Contains,
    LEFTARG = cellstring,
    RIGHTARG = cellstring
);

-- Operator definitions
CREATE OPERATOR && (
    LEFTARG = cellstring,
    RIGHTARG = cellstring,
    PROCEDURE = CST_Intersects,
    COMMUTATOR = &&,  -- symmetric
    NEGATOR = =,      -- optional
    RESTRICT = contsel,
    JOIN = contjoinsel
);

CREATE OPERATOR & (
    LEFTARG = cellstring,
    RIGHTARG = cellstring,
    PROCEDURE = CST_Intersection
);