# PostgreSQL CellString Extension

Native SQL functions for working with cells as `bigint[]` and `int[]` array types. This implementation leverages PostgreSQL's built-in array operators for efficient spatial operations.

## Overview

The PostgreSQL CellString extension provides OGC-inspired spatial operations on arrays of cells. cells are encoded integers representing grid cells at specific zoom levels.

## Installation

### Prerequisites

- PostgreSQL 9.5+
- PostGIS extension
- [bigintarray](https://github.com/DanielJDufour/bigintarray/tree/main) extension

### Step 1: Install `bigintarray` extension

```bash
wget https://raw.githubusercontent.com/DanielJDufour/bigintarray/main/bigintarray--0.0.1.sql
psql -h {host} -p {port} -U {username} {database_name} < ./bigintarray--0.0.1.sql
```

### Step 2: Install `cellstring` extension

**From local source:**

```bash
cd PostgreSQL_cellstring_extension
psql -h {host} -p {port} -U {username} {database_name} < ./cellstring--0.0.1.sql
```

**From GitHub:**

```bash
wget https://raw.githubusercontent.com/SW9-10-AAU/CellString_OGC_extension/main/PostgreSQL_cellstring_extension/cellstring--0.0.1.sql
psql -h {host} -p {port} -U {username} {database_name} < ./cellstring--0.0.1.sql
```

## Functions

### Core OGC Operations

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Intersects** | `CST_Intersects(cs_a bigint[], cs_b bigint[])` | `boolean` | Returns TRUE if two cellstrings share at least one cell (overlap) |
| **Intersection** | `CST_Intersection(cs_a bigint[], cs_b bigint[])` | `bigint[]` | Returns the intersection of two cellstrings (common cells) |
| **Union** | `CST_Union(cs_a bigint[], cs_b bigint[])` | `bigint[]` | Returns the union of two cellstrings (all cells in either) |
| **Difference** | `CST_Difference(cs_a bigint[], cs_b bigint[])` | `bigint[]` | Returns cells in A that are not in B |
| **Contains** | `CST_Contains(cs_a bigint[], cs_b bigint[])` | `boolean` | Returns TRUE if A fully contains B |
| **Disjoint** | `CST_Disjoint(cs_a bigint[], cs_b bigint[])` | `boolean` | Returns TRUE if cellstrings share no cells |

### Analysis Functions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Coverage** | `CST_Coverage(cs_a bigint[], cs_b bigint[])` | `numeric` | Coverage percentage of cellstring A over cellstring B |
| **Coverage by MMSI** | `CST_Coverage_ByMMSI(traj_table REGCLASS, zoom INTEGER, area_cellstring bigint[])` | `TABLE (mmsi BIGINT, coverage_percent NUMERIC)` | Computes coverage per MMSI for trajectories in a table |
| **Union Aggregate** | `CST_Union_Agg(bigint[])` | `bigint[]` | Aggregate function to union multiple cellstrings (used in GROUP BY) |

### Visualization Functions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Tile XY Decoding** | `CST_TileXY(cell_id bigint, zoom integer)` | `TABLE (tile_x int, tile_y int)` | Decode cell into tile X/Y coordinates |
| **Cell as Polygon** | `CST_CellAsPolygon(cell_id bigint, zoom integer)` | `geometry(Polygon, 4326)` | Converts a cell to its polygon geometry (EPSG:4326) |
| **Cellstring as MultiPolygon** | `CST_AsMultiPolygon(cellstring bigint[], zoom integer)` | `geometry(MultiPolygon, 4326)` | Unites all cell polygons into a single MultiPolygon |
| **Cell as Point** | `CST_CellAsPoint(cell_id bigint, zoom integer)` | `geometry(Point, 4326)` | Returns the center point of a cell |
| **Cellstring as LineString** | `CST_AsLineString(cellstring bigint[], zoom integer)` | `geometry(LineString, 4326)` | Builds LineString from cell centers (respects cell order) |
| **Hausdorff Distance** | `CST_HausdorffDistance(cellstring bigint[], original_geom geometry, zoom integer)` | `double precision` | Computes Hausdorff distance between a LineString and CellString representation |

### Array Type Variants

All functions listed above also support `int[]` array variants with identical signatures and behavior. Use `int[]` variants when working with smaller cell values.

## Usage Examples

### Basic Overlap Detection

```sql
-- Check if two trajectories intersect
SELECT CST_Intersects(
    ARRAY[1688238506957, 1688238506958, 1688238506959]::bigint[],
    ARRAY[1688238506958, 1688238506959, 1688238506960]::bigint[]
) AS overlaps;
-- Output: true
```

### Finding Common Cells

```sql
-- Get the cells visited by both trajectory A and B
SELECT CST_Intersection(
    ARRAY[1, 2, 3, 4]::bigint[],
    ARRAY[2, 3, 5, 6]::bigint[]
) AS common_cells;
-- Output: {2,3}
```

### Combining Trajectories

```sql
-- Union cells from two trajectories
SELECT CST_Union(
    ARRAY[1, 2, 3]::bigint[],
    ARRAY[3, 4, 5]::bigint[]
) AS all_cells;
-- Output: {1,2,3,4,5}
```

### Computing Coverage

```sql
-- What percentage of area B does trajectory A cover?
SELECT CST_Coverage(
    ARRAY[1, 2, 3, 4, 5]::bigint[],
    ARRAY[2, 3, 4]::bigint[]
) AS coverage_percent;
-- Output: 100.00 (all cells of B are in A)
```

### Checking Containment

```sql
-- Does trajectory A fully contain trajectory B?
SELECT CST_Contains(
    ARRAY[1, 2, 3, 4, 5]::bigint[],
    ARRAY[2, 3]::bigint[]
) AS a_contains_b;
-- Output: true
```

### Checking Disjointness

```sql
-- Do trajectories A and B have no cells in common?
SELECT CST_Disjoint(
    ARRAY[1, 2, 3]::bigint[],
    ARRAY[4, 5, 6]::bigint[]
) AS are_disjoint;
-- Output: true
```

### Finding Exclusive Cells

```sql
-- What cells are in A but not in B?
SELECT CST_Difference(
    ARRAY[1, 2, 3, 4]::bigint[],
    ARRAY[2, 3, 5]::bigint[]
) AS exclusive_to_a;
-- Output: {1,4}
```

### Aggregating Multiple Cellstrings

```sql
-- Combine cells from multiple trajectories using aggregate function
SELECT 
    vessel_type,
    CST_Union_Agg(cellstring_z21) AS combined_coverage
FROM vessel_trajectories
WHERE date = '2026-03-24'
GROUP BY vessel_type;
```

### Coverage Analysis by Vessel (MMSI)

```sql
-- Calculate what percentage of an area each vessel covered
-- Table structure: vessel_trajectories(mmsi BIGINT, cellstring_z21 BIGINT[])

SELECT *
FROM CST_Coverage_ByMMSI(
    'vessel_trajectories'::REGCLASS,
    21,  -- zoom level
    ARRAY[1688238506957, 1688238506958, 1688238506959]::bigint[]  -- area of interest
)
ORDER BY coverage_percent DESC;
```

### Visualizing Cells as Geometries

```sql
-- Convert a single cell to a polygon
SELECT ST_AsGeoJSON(CST_CellAsPolygon(1688238506957::bigint, 21)) AS cell_geom;

-- Convert a cellstring to a MultiPolygon
SELECT ST_AsGeoJSON(
    CST_AsMultiPolygon(
        ARRAY[1688238506957, 1688238506958, 1688238506959]::bigint[],
        21
    )
) AS coverage_geom;
```

### Cell Center Points

```sql
-- Get the center point of a cell (useful for visualizations)
SELECT ST_AsText(CST_CellAsPoint(1688238506957::bigint, 21)) AS cell_center;

-- Get center points for all cells in a trajectory
SELECT 
    ROW_NUMBER() OVER (ORDER BY ordinality) AS position,
    ST_AsText(CST_CellAsPoint(cell_id, 21)) AS cell_center
FROM UNNEST(ARRAY[1688238506957, 1688238506958, 1688238506959]::bigint[]) WITH ORDINALITY AS t(cell_id, ordinality);
```

### Reconstructing Trajectories as LineStrings

```sql
-- Rebuild a trajectory as a LineString from cell centers
SELECT ST_AsGeoJSON(
    CST_AsLineString(
        ARRAY[1688238506957, 1688238506958, 1688238506959]::bigint[],
        21
    )
) AS trajectory_line;
```

### Comparing Original and Cellstring Representations

```sql
-- Calculate the Hausdorff distance between original trajectory and cellstring representation
-- (measures the maximum deviation)
SELECT CST_HausdorffDistance(
    ARRAY[1688238506957, 1688238506958, 1688238506959]::bigint[],
    ST_GeomFromText('LINESTRING(0 0, 1 1, 2 2)', 4326),  -- original trajectory
    21
) AS max_deviation_meters;
```

### Decoding Cell Coordinates

```sql
-- Get the tile X and Y coordinates of a cell
SELECT * FROM CST_TileXY(1688238506957::bigint, z);
-- Output: tile_x | tile_y
--         688238  | 506957
```

## Performance Considerations

1. **Array Size**: Large arrays (1000+ cells) may have slower operations. 

2. **Zoom Levels**: Higher zoom levels (e.g., 21) have larger cell values. Use `int[]` only when zoom level is guaranteed to be 13 or lower.

3. **Geometry Conversion**: Visualization functions (`CST_CellAsPolygon`, `CST_AsMultiPolygon`) are computationally expensive for large cellstrings. Consider pre-computing aggregations when possible.

## See Also

- [Main CellString Extension README](../README.md)
- [DuckDB CellString Extension](../DuckDB_cellstring_extension/)
- [PostGIS Documentation](https://postgis.net/documentation/)
