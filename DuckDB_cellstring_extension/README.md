# DuckDB CellString Extension

Macro-based implementation using unnested cells with bit-encoded quadkeys. Designed for table-based cellstring representations with optional timestamp columns for spatio-temporal analysis.

## Overview

The DuckDB CellString extension provides OGC-inspired spatial operations on cellstrings represented as tables with cell columns. The implementation uses bit-encoding (Z-order curve/Morton order) for efficient cell manipulation and spatio-temporal queries.

Key features:
- **Unnested representation** — Cells stored in table rows rather than arrays
- **Bit-encoded operations** — Efficient Z-order curve encoding for tile coordinates
- **Spatio-temporal support** — Built-in timestamp column handling
- **Macro-based** — Easy to extend and customize

## Installation

### Prerequisites

- DuckDB 0.9+
- Spatial extension (automatically installed)

### Step 1: Download the macro file

```bash
wget https://raw.githubusercontent.com/SW9-10-AAU/CellString_OGC_extension/main/DuckDB_cellstring_extension/cellstring_duckdb_0.0.1.sql
```

### Step 2: Load macros into DuckDB

In DuckDB SQL interface:

```sql
.read cellstring_duckdb_0.0.1.sql
```

This automatically:
- Installs and loads the `spatial` extension
- Creates all CellString macros
- Safely replaces existing macros if reinstalling

## Functions

### Core OGC Operations

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Intersects** | `CS_Intersects(cs_a, cs_b)` | `boolean` | Returns TRUE if cells overlap (both arguments are table queries) |
| **Intersection** | `CS_Intersection(cs_a, cs_b)` | `TABLE` | Returns intersection cells from both cellstrings |
| **Union** | `CS_Union(cs_a, cs_b)` | `TABLE` | Returns cells from both cellstrings |
| **Difference** | `CS_Difference(cs_a, cs_b)` | `TABLE` | Returns cells in A that are NOT in B |
| **Contains** | `CS_Contains(cs_a, cs_b)` | `boolean` | Returns TRUE if A fully contains B |
| **Disjoint** | `CS_Disjoint(cs_a, cs_b)` | `boolean` | Returns TRUE if cellstrings share no cells |

### Analysis Functions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Coverage** | `CS_Coverage(cs_a, cs_b)` | `float` | Coverage percentage of cellstring A over cellstring B |
| **Coverage by MMSI** | `CS_CoverageByMMSI(cs_area, cs_vessel_footprint)` | `TABLE` | Coverage percentage per vessel (MMSI) over region |
| **Jaccard Similarity** | `CS_Jaccard(cs_a, cs_b)` | `TABLE` | Jaccard similarity score for trajectory similarity |

### Visualization Functions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Cell to Tile ZXY** | `CS_CellIdToTileZXY(cell_id, zoom)` | `STRUCT` | Decodes cell to `{z, x, y}`|
| **Cell as Polygon** | `CS_CellAsPolygon(cell_id, zoom)` | `geometry` | Converts cell to polygon geometry (EPSG:4326) |
| **Cellstring as Polygon** | `CS_AsPolygon(cs, zoom)` | `geometry` | Unions all cell polygons into a single geometry |
| **Cell as Point** | `CS_CellAsPoint(cell_id, zoom)` | `geometry` | Returns cell centroid as a point geometry |
| **Cellstring as LineString** | `CS_AsLineString(cs, zoom)` | `geometry` | Builds LineString from cell centers (requires `ts` column for ordering) |
| **Cell to Quadkey** | `CS_CellIdToQuadkey(cell_id, zoom)` | `string` | Converts cell to standard quadkey string |

### Tile Coordinate Functions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **Get Parent Cell** | `CS_GetParentCell(cell_id, from_zoom, to_zoom)` | `bigint` | Gets parent cell at coarser zoom level via bit-shifting |
| **Cell Distance** | `CS_Distance(cell_a, cell_b, zoom)` | `integer` | Chebyshev distance between two cells (max of x/y distance) - Decoding on the fly |
| **Distance Decoded** | `CS_Distance_Decoded(a_x, a_y, b_x, b_y)` | `integer` | Distance between pre-decoded tile coordinates |

### Neighborhood & Similarity Functions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| **KNN Search** | `CS_KNN(cs_a, cs_b, zoom, k)` | `TABLE` | Find K nearest neighbors to cellstring A from candidates B |
| **KNN Decoded** | `CS_KNN_Decoded(cs_a, cs_b, zoom, k)` | `TABLE` | KNN search using pre-decoded coordinates (optimized) |
| **Spatio-temporal Zoom** | `CS_TrajectorySpatiotemporalZoom(cs_a, target_z)` | `TABLE` | Aggregates trajectory to coarser zoom with entry/exit times |

## Usage Examples

### Setup: Sample Data

```sql
-- Create sample trajectory table
CREATE TABLE trajectory_cs (
    trajectory_id INTEGER,
    mmsi BIGINT,
    cell_z21 BIGINT,
    ts TIMESTAMP
);

INSERT INTO trajectory_cs VALUES
    (1, 123456789, 12343534553343, '2026-03-24 10:31:00'),
    (1, 123456789, 35315135431234, '2026-03-24 10:31:10'),
    (1, 123456789, 45312543543131, '2026-03-24 10:31:20'),
    (2, 987654321, 35315135431234, '2026-03-24 10:32:00'),
    (2, 987654321, 13254234213414, '2026-03-24 10:32:15'),
    (2, 987654321, 54231423143254, '2026-03-24 10:32:30');


CREATE TABLE region_cs (
    region_id INTEGER,
    name VARCHAR
    cell_z21 BIGINT

INSERT INTO trajectory_cs VALUES
    (1, 'test_area', 12343534553343),
    (1, 'test_area', 35315135431234),
    (1, 'test_area', 45312543543131),
    (1, 'test_area', 54231423143254);
);
```

### Basic Overlap Detection

```sql
-- Check if two trajectories intersect
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT CS_Intersects(traj_1, traj_2) AS overlaps;
-- Output: true/false
```

### Finding Common Cells

```sql
-- Get the cells visited by both trajectory 1 and 2
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT cell_z21 FROM CS_Intersection(traj_1, traj_2);
-- Output: cell_z21
```

### Combining Trajectories

```sql
-- Union cells from two trajectories
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT cell_z21 FROM CS_Union(traj_1, traj_2);
-- Output: All unique cells from both trajectories
```

### Computing Coverage

```sql
-- What percentage of trajectory 2 does trajectory 1 cover?
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT CS_Coverage(traj_1, traj_2) AS coverage_percent;
-- Output: procentage
```

### Checking Containment

```sql
-- Does trajectory 1 fully contain all cells of trajectory 2?
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT CS_Contains(traj_1, traj_2) AS traj1_contains_traj2;
-- Output: true/false
```

### Checking Disjointness

```sql
-- Do trajectories have no cells in common?
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_3 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 3)
SELECT CS_Disjoint(traj_1, traj_3) AS are_disjoint;
-- Output: true/false
```

### Finding Exclusive Cells

```sql
-- What cells are in trajectory 1 but not in trajectory 2?
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT cell_z21 FROM CS_Difference(traj_1, traj_2);
-- Output: cell_z21
```

### Coverage Analysis by Vessel (MMSI)

```sql
-- Calculate what percentage of an area each vessel covered
WITH region_cells AS (
    SELECT DISTINCT cell_z21 FROM region_cs WHERE region_id = 1
),
vessel_footprint AS (
    SELECT * FROM trajectory_cs 
)
SELECT * FROM CS_CoverageByMMSI(area_cells, vessel_footprint)
ORDER BY coverage_percentage DESC;
-- Output: procentage table
```

### Trajectory Similarity (Jaccard)

```sql
-- Find similar trajectories using Jaccard similarity
WITH query_traj AS (
    SELECT * FROM trajectory_cs WHERE trajectory_id = 1
),
candidate_trajs AS (
            SELECT * FROM trajectory_cs WHERE trajectory_id <> 1
)
SELECT * FROM CS_Jaccard(query_traj, candidate_trajs)
ORDER BY similarity_score DESC;
-- Output: trajectory_id's
```

### Visualizing Cells as Geometries

```sql
-- Convert a single cell to a polygon
SELECT ST_AsText(CS_CellAsPolygon(12343534553343::BIGINT, 21)) AS cell_polygon;

-- Convert trajectory to MultiPolygon coverage area
WITH traj_1 AS (
    SELECT DISTINCT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1
)
SELECT ST_AsText(CS_AsPolygon(traj_1, 21)) AS traj_polygon;
```

### Cell Center Points

```sql
-- Get the center point of a cell
SELECT ST_AsText(CS_CellAsPoint(12343534553343::BIGINT, 21)) AS cell_center;
```

### Reconstructing Trajectories as LineStrings

```sql
-- Rebuild a trajectory as a LineString from cell centers (ordered by timestamp)
WITH traj_1 AS (
    SELECT cell_z21, ts FROM trajectory_cs WHERE trajectory_id = 1
)
SELECT ST_AsText(CS_AsLineString(traj_1, 21)) AS trajectory_line;
```

### Decoding Cell Coordinates

```sql
-- Get the tile Z, X, and Y coordinates of a cell
SELECT * FROM (SELECT CS_CellIdToTileZXY(12343534553343::BIGINT, 21));
```

### Cell to Quadkey Conversion

```sql
-- Convert a cell to quadkey string
SELECT CS_CellIdToQuadkey(12343534553343::BIGINT, 21) AS quadkey;
```

### Getting Parent Cells (Zoom Level Aggregation)

```sql
-- Get parent cells at coarser zoom level (21 -> 17)
SELECT DISTINCT 
    CS_GetParentCell(cell_z21, 21, 17) AS parent_cell_z17
FROM trajectory_cs
WHERE trajectory_id = 1

-- Full spatio-temporal aggregation
SELECT * FROM CS_TrajectorySpatiotemporalZoom(
    (SELECT * FROM trajectory_cs WHERE trajectory_id = 1),
    17  -- zoom level 17
);
-- Output: parent_cell, entry_time, exit_time per parent cell
```

### Cell Distance Calculations

```sql
-- Calculate distance between two cells
SELECT CS_Distance(12343534553343::BIGINT, 35315135431234::BIGINT, 21) AS distance;

-- Find K closest cells from trajectory_cs to each cell in trajectory 1 using KNN
WITH traj_1_cells AS (
    SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1
)
SELECT * FROM CS_KNN(traj_1_cells, trajectory_cs, 21, 5)
ORDER BY min_distance;
```

### K-Nearest Neighbors Search

```sql
-- Find 5 nearest cells from trajectory_cs to a single query cell
WITH query_traj AS (
    SELECT 12343534553343::BIGINT AS cell_z21
)
SELECT * FROM CS_KNN(query_traj, trajectory_cs, 21, 5)
ORDER BY min_distance;
```

## Performance Tips

1. **Unnested Representation**: Tables with one row per cell are typically faster than arrays for large cellstrings (100+ cells).

2. **Pre-computed Coordinates**: For repeated distance calculations, use `CS_Distance_Decoded()` with pre-decoded coordinates to avoid repeated bit-shifting.

## See Also
- [Main CellString Extension README](../README.md)
- [PostgreSQL CellString Extension](../PostgreSQL_cellstring_extension/)
- [DuckDB Documentation](https://duckdb.org/docs/)
- [DuckDB Spatial Extension](https://duckdb.org/docs/extensions/spatial)
