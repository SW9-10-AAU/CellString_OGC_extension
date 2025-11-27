# CellString PostgreSQL Extension
The `cellstring` extension provides functions to manipulate `bigint[]`.

## Goal for CellString
An alternative to LineString for representing AIS data. The CellString extension is designed to efficiently handle arrays of cells, allowing for operations such as intersection, union, and difference, which are common in spatial analysis.

## Functions
The `cellstring` extension provides the following OGC functions:

| OGC Function                                                                                 | Description                                                                                                       | Implemented? |
|----------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|--------------|
| **CST_Intersects(a bigint[], b bigint[]) → boolean**                                         | Returns `TRUE` if two cellstrings share at least one cell (overlap).                                              | ✓            |
| **CST_Intersection(a bigint[], b bigint[]) → bigint[]**                                      | Returns the intersection of two cellstrings (common cells).                                                       | ✓            |
| **CST_Union(a bigint[], b bigint[]) → bigint[]**                                             | Returns the union of two cellstrings (all cells contained in either).                                             | ✓            |
| **CST_Difference(a bigint[], b bigint[]) → bigint[]**                                        | Returns cells in A that are not in B (A minus intersection).                                                      | ✓            |
| **CST_Contains(a bigint[], b bigint[]) → boolean**                                           | Returns `TRUE` if A fully contains B (all of B’s cells are present in A).                                         | ✓            |
| **CST_Disjoint(a bigint[], b bigint[]) → boolean**                                           | Returns `TRUE` if the two cellstrings share no common cell IDs.                                                   | ✓            |

Furthermore, the extension includes the following functions.
| Function                                                                                                                          | Description                                                                                                       | Implemented? |
|-----------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|--------------|
| **CST_Coverage(cs_a bigint[], cs_b bigint[]) → numeric**                                                                          | Returns the coverage percentage of cellstring A over cellstring B.                                                | ✓            |
| **CST_Coverage_ByMMSI(traj_table regclass, zoom int, area_cellstring bigint[]) -> setof (mmsi bigint, coverage_percent numeric)** | Computes coverage per MMSI for a trajectory table at a given zoom level against a given area cellstring.          | ✓            |
| **CST_TileXY(cell_id bigint, zoom int) → (tile_x int, tile_y int)**                                                               | Decodes a cell ID into tile X/Y coordinates for the given zoom level.                                             | ✓            |
| **CST_CellAsPolygon(cell_id bigint, zoom int) → geometry(Polygon, 4326)**                                                         | Converts a single cell ID into its polygon geometry using `ST_TileEnvelope`.                                      | ✓            |
| **CST_AsMultiPolygon(cellstring bigint[], zoom int) → geometry(MultiPolygon, 4326)**                                              | Converts a CellString into a MultiPolygon by unioning all cell polygons.                                          | ✓            |
| **CST_CellAsPoint(cell_id bigint, zoom int) → geometry(Point, 4326)**                                                             | Returns the geographic center point of a tile defined by a cell ID and zoom level.                                | ✓            |
| **CST_AsLineString(cellstring bigint[], zoom int) → geometry(LineString, 4326)**                                                  | Builds a LineString trajectory from the center points of the cells in a CellString, preserving order.             | ✓            |
| **CST_HausdorffDistance(cellstring bigint[], original_geom geometry, zoom int) → double**                                         | Computes the Hausdorff distance between a baseline LineString and its CellString representation at a given zoom.  | ✓            |



## Installation
### 1. Install `bigintarray` extension
The `cellstring` extension is dependent on the [bigintarray](https://github.com/DanielJDufour/bigintarray/tree/main) extension.

##### 1. Run the following command to download the `bigintarray` extension:
```
wget https://raw.githubusercontent.com/DanielJDufour/bigintarray/main/bigintarray--0.0.1.sql
```
##### 2. Run the following command to install the `bigintarray` extension:
```
psql -h {0.0.0.0} -p {5432} --username {username} {database_name} < ./bigintarray--0.0.1.sql;
```
### 2. Install `cellstring` extension
##### 1. Run the following command to download the `cellstring` extension:
```
wget https://raw.githubusercontent.com/SW9-10-AAU/CellString_OGC_extension/main/CellString--0.0.1.sql
```
##### 2. Run the following command to install the `cellstring` extension:
```
psql -h {0.0.0.0} -p {5432} --username {username} {database_name} < ./CellString--0.0.1.sql;
```
## Usage Example
```
-- Create cellstrings
SELECT ARRAY[1, 2, 3]::bigint[] AS a, ARRAY[2, 3, 4]::bigint[] AS b;

-- Do two cellstrings intersect?
SELECT CST_Intersects(a, b) FROM (SELECT ARRAY[1, 2, 3]::bigint[] AS a, ARRAY[2, 3, 4]::bigint[] AS b) AS subquery;

-- The union of two cellstrings
SELECT CST_Union(a, b) FROM (SELECT ARRAY[1, 2, 3]::bigint[] AS a, ARRAY[2, 3, 4]::bigint[] AS b) AS subquery;
```
