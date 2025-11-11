# CellString PostgreSQL Extension
The `cellstring` extension provides functions to manipulate `bigint[]`.

## Goal for CellString
An alternative to LineString for representing AIS data. The CellString extension is designed to efficiently handle arrays of cells, allowing for operations such as intersection, union, and difference, which are common in spatial analysis.

## Features
### Custom Domain
CellStrings are represented as `bigint[]`.

## Functions
The `cellstring` extension provides the following OGC functions:

| Function                                                   	 | Description                                                            	 | Implemented? 	 |
|--------------------------------------------------------------|--------------------------------------------------------------------------|----------------|
| CST_Intersects(a bigint[], b bigint[]) -> boolean      	     | Returns `TRUE` if two cellstrings share at least one cell (overlap)      | ✓              |
| CST_Intersection(a bigint[], b bigint[]) -> bigint[] 	       | Returns the intersection of two cellstrings (common cells)               | ✓            	 |
| CST_Union(a bigint[], b bigint[]) -> bigint[]        	       | Returns the union of two cellstrings (all cells in either)             	 | ✓            	 |
| CST_Difference(a bigint[], b bigint[]) -> bigint[]   	       | Returns cells in A that are not in B (A minus intersection)              | ✓            	 |
| CST_Contains(a bigint[], b bigint[]) -> boolean        	     | Returns `TRUE` if A contains B (all B’s cells are in A and they overlap) | ✓            	 |
| CST_Disjoint(a bigint[], b bigint[]) -> boolean              | Returns `TRUE` if they share no cell IDs                                 | ✓              |


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
