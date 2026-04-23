# CellString Extension

The `cellstring` extension provides efficient functions to manipulate arrays of cell IDs for spatial analysis. It's designed as an alternative to LineString for representing AIS trajectories and other spatial data as collections of discrete grid cells.

Two implementations are available: **PostgreSQL** (using `bigint[]` arrays) and **DuckDB** (using unnested cells with bit-encoded quadkeys stored as integers).

## Goal for CellString

An alternative to LineString for representing AIS data. The CellString extension efficiently handles arrays of cells, enabling operations such as intersection, union, and difference—common in spatial and spatio-temporal analysis.

---

## PostgreSQL Implementation

Native SQL functions working with `bigint[]` and `int[]` array types. Supports array-based operations using PostgreSQL's array operators.

### Functions

#### Core OGC Operations

| Function Signature                               | Returns    | Description                                                       |
| ------------------------------------------------ | ---------- | ----------------------------------------------------------------- |
| `CST_Intersects(cs_a bigint[], cs_b bigint[])`   | `boolean`  | Returns TRUE if two cellstrings share at least one cell (overlap) |
| `CST_Intersection(cs_a bigint[], cs_b bigint[])` | `bigint[]` | Returns the intersection of two cellstrings (common cells)        |
| `CST_Union(cs_a bigint[], cs_b bigint[])`        | `bigint[]` | Returns the union of two cellstrings                              |
| `CST_Difference(cs_a bigint[], cs_b bigint[])`   | `bigint[]` | Returns cells in A that are not in B                              |
| `CST_Contains(cs_a bigint[], cs_b bigint[])`     | `boolean`  | Returns TRUE if A fully contains B                                |
| `CST_Disjoint(cs_a bigint[], cs_b bigint[])`     | `boolean`  | Returns TRUE if cellstrings share no cells                        |

#### Analysis Functions

| Function Signature                                                                 | Returns                                         | Description                                           |
| ---------------------------------------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------- |
| `CST_Coverage(cs_a bigint[], cs_b bigint[])`                                       | `numeric`                                       | Coverage percentage of cellstring A over cellstring B |
| `CST_Coverage_ByMMSI(traj_table REGCLASS, zoom INTEGER, area_cellstring bigint[])` | `TABLE (mmsi BIGINT, coverage_percent NUMERIC)` | Computes coverage per MMSI for trajectories           |
| `CST_Union_Agg(bigint[])`                                                          | `bigint[]`                                      | Aggregate function to union multiple cellstrings      |

#### Visualization Functions

| Function Signature                                                                 | Returns                          | Description                                          |
| ---------------------------------------------------------------------------------- | -------------------------------- | ---------------------------------------------------- |
| `CST_TileXY(cell_id bigint, zoom integer)`                                         | `TABLE (tile_x int, tile_y int)` | Decode cell ID into tile X/Y coordinates             |
| `CST_CellAsPolygon(cell_id bigint, zoom integer)`                                  | `geometry(Polygon, 4326)`        | Converts a cell ID to its polygon geometry           |
| `CST_AsMultiPolygon(cellstring bigint[], zoom integer)`                            | `geometry(MultiPolygon, 4326)`   | Unites all cell polygons into a MultiPolygon         |
| `CST_CellAsPoint(cell_id bigint, zoom integer)`                                    | `geometry(Point, 4326)`          | Returns the center point of a cell                   |
| `CST_AsLineString(cellstring bigint[], zoom integer)`                              | `geometry(LineString, 4326)`     | Builds LineString from cell centers (ordered)        |
| `CST_HausdorffDistance(cellstring bigint[], original_geom geometry, zoom integer)` | `double precision`               | Hausdorff distance between LineString and CellString |

**Note:** All functions also support `int[]` array variants.

### Installation

#### Prerequisites

- PostgreSQL 9.5+
- PostGIS extension
- [bigintarray](https://github.com/DanielJDufour/bigintarray/tree/main) extension

#### Step 1: Install `bigintarray` extension

```bash
wget https://raw.githubusercontent.com/DanielJDufour/bigintarray/main/bigintarray--0.0.1.sql
psql -h {host} -p {port} -U {username} {database_name} < ./bigintarray--0.0.1.sql
```

#### Step 2: Install `cellstring` extension

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

### Usage Examples

Working with cellstrings as `bigint[]` arrays:

```sql
-- Basic intersection check
SELECT CST_Intersects(ARRAY[1, 2, 3]::bigint[], ARRAY[2, 3, 4]::bigint[]);

-- Get intersection cells
SELECT CST_Intersection(ARRAY[1, 2, 3]::bigint[], ARRAY[2, 3, 4]::bigint[]);

-- Compute union of two cellstrings
SELECT CST_Union(ARRAY[1, 2, 3]::bigint[], ARRAY[2, 3, 4]::bigint[]);

-- Calculate coverage
SELECT CST_Coverage(ARRAY[1, 2, 3, 4]::bigint[], ARRAY[2, 3]::bigint[]);

-- Visualize cells as polygons
SELECT CST_CellAsPolygon(1688238506957::bigint, 21) AS cell_polygon;

-- Check if cellstring A contains cellstring B
SELECT CST_Contains(ARRAY[1, 2, 3, 4]::bigint[], ARRAY[2, 3]::bigint[]);
```

---

## DuckDB Implementation

Macro-based implementation using unnested cells with bit-encoded quadkeys. Designed for table-based cellstring representations with optional timestamp columns for spatio-temporal analysis.

### Functions

#### Core OGC Operations

| Macro Signature               | Returns   | Description                                  |
| ----------------------------- | --------- | -------------------------------------------- |
| `CS_Intersects(cs_a, cs_b)`   | `boolean` | Returns TRUE if cells overlap (spatial only) |
| `CS_Intersection(cs_a, cs_b)` | `TABLE`   | Returns intersection cells (spatial only)    |
| `CS_Union(cs_a, cs_b)`        | `TABLE`   | Returns union of cells from both cellstrings |
| `CS_Difference(cs_a, cs_b)`   | `TABLE`   | Returns cells in A that are NOT in B         |
| `CS_Contains(cs_a, cs_b)`     | `boolean` | Returns TRUE if A fully contains B           |
| `CS_Disjoint(cs_a, cs_b)`     | `boolean` | Returns TRUE if cellstrings share no cells   |

#### Analysis & Visualization Functions

| Macro Signature                              | Returns    | Description                                                                 |
| :------------------------------------------- | :--------- | :-------------------------------------------------------------------------- |
| `CS_CellIdToTileZXY(cell_id, zoom)`          | `STRUCT`   | Decodes Cell ID into `{z, x, y}` using bit de-interleaving (Z-order curve). |
| `CS_Coverage(cs_a, cs_b)`                    | `float`    | Coverage percentage of cellstring A over cellstring B.                      |
| `CS_CoverageByMMSI(cs_area, cs_v_footprint)` | `TABLE`    | Coverage per MMSI using cellstring arguments.                               |
| `CS_CellAsPolygon(cell_id, zoom)`            | `geometry` | Converts cell ID to polygon geometry (EPSG:4326).                           |
| `CS_AsPolygon(cs, zoom)`                     | `geometry` | Unions all cell polygons from a cellstring into a single geometry.          |
| `CS_CellAsPoint(cell_id, zoom)`              | `geometry` | Returns cell centroid as a point.                                           |
| `CS_AsLineString(cs, zoom)`                  | `geometry` | Builds LineString from cell centers (requires `ts` column for ordering).    |
| `CS_CellIdToQuadkey(cell_id, zoom)`          | `string`   | Converts cell ID to a standard Quadkey string.                              |
| `CS_GetParentCellId(id, z_in, z_out)`        | `bigint`   | Gets parent cell ID at coarser zoom level via bit-shifting.                 |

### Installation

#### Prerequisites

- DuckDB 0.9+
- Spatial extension (automatically installed)

#### Step 1: Download the macro file

```bash
wget https://raw.githubusercontent.com/SW9-10-AAU/CellString_OGC_extension/main/DuckDB_cellstring_exstension/cellstring_duckdb_0.0.1.sql
```

#### Step 2: Load macros into DuckDB

In DuckDB SQL interface:

```sql
.read cellstring_duckdb_0.0.1.sql
```

This automatically:

- Installs and loads the `spatial` extension
- Creates all CellString macros
- Safely replaces existing macros if reinstalling

### Usage Examples

Working with cellstrings as tables with `cell_z21` column (unnested):

```sql
-- Setup: Create sample trajectory table
CREATE TABLE trajectory_cs (
    trajectory_id INTEGER,
    cell_z21 BIGINT,
    ts TIMESTAMP
);

INSERT INTO trajectory_cs VALUES
    (1, 12343534553343, '2026-03-24 10:31:00'),
    (1, 35315135431234, '2026-03-24 10:31:10'),
    (2, 35315135431234, '2026-03-24 10:32:00'),
    (2, 13254234213414, '2026-03-24 10:32:15');

-- Spatial intersection check
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT CS_Intersects(traj_1, traj_2) AS is_intersecting;

-- Get intersection cells
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT * FROM CS_Intersection(traj_1, traj_2);

-- Calculate coverage percentage
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1),
     traj_2 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 2)
SELECT CS_Coverage(traj_1, traj_2) AS coverage_percent;

-- Visualize cells as polygons
WITH traj_1 AS (SELECT DISTINCT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1)
SELECT ST_AsText(CS_CellAsPolygon(cell_z21, 21)) AS cell_polygon FROM traj_1;

-- Reconstruct trajectory as LineString
WITH traj_1 AS (SELECT cell_z21, ts FROM trajectory_cs WHERE trajectory_id = 1)
SELECT ST_AsText(CS_AsLineString(traj_1, 21)) AS trajectory_linestring;

-- Convert cell ID to quadkey (bit-encoded as integer)
SELECT CS_CellIdToQuadkey(12343534553343, 21) AS quadkey;

-- Get parent cell at coarser zoom level
SELECT CS_GetParentCellId(12343534553343, 21, 17) AS parent_cell_id;

-- Returns a struct: {z: 21, x: ..., y: ...}
SELECT CS_CellIdToTileZXY(12343534553343, 21) AS tile_coords;

-- Computes the percentage of a target area covered by each vessel's footprint
WITH target_area AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1)
SELECT * FROM CS_CoverageByMMSI(target_area, trajectory_cs);

-- Converts a Cell ID into a Point geometry at the center of the tile
SELECT ST_AsText(CS_CellAsPoint(12343534553343, 21)) AS centroid_point;

-- Unions all cells in a cellstring into a single (Multi)Polygon geometry
WITH traj_1 AS (SELECT cell_z21 FROM trajectory_cs WHERE trajectory_id = 1)
SELECT ST_AsText(CS_AsPolygon(traj_1, 21)) AS area_geometry;
```
