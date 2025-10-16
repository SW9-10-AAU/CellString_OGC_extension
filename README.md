# CellString PostgreSQL Extension
The `cellstring` extension provides a custom domain and associated functions and operators to efficiently represent and manipulate arrays of cells of `bigint`. This extension is particularly useful for applications involving spatial data or any domain where multi-sets of cells need to be modeled and operated upon.

## Goal for CellString
An alternative to LineString for representing AIS data. The CellString extension is designed to efficiently handle arrays of cells, allowing for operations such as intersection, union, and difference, which are common in spatial analysis.

## Features
### Custom Domain
`cellstring` is a user-defined domain over `bigint[]` that enforces non-null elements and provides a semantic abstraction for multi-sets of cells.

## Functions
The `cellstring` extension provides the following OGC functions:

| Function                                                   	| Description                                                            	   | Implemented? 	|
|------------------------------------------------------------	|----------------------------------------------------------------------------|--------------	|
| CST_Intersects(a cellstring, b cellstring) -> boolean      	| Returns `TRUE` if two cellstrings share at least one cell (overlap)      	 | ✓            	|
| CST_Intersection(a cellstring, b cellstring) -> cellstring 	| Returns the intersection of two cellstrings (common cells)             	   | ✓            	|
| CST_Union(a cellstring, b cellstring) -> cellstring        	| Returns the union of two cellstrings (all cells in either)             	   | ✓            	|
| CST_Difference(a cellstring, b cellstring) -> cellstring   	| Returns cells in A that are not in B (A minus intersection)            	   | ✓            	|
| CST_Contains(a cellstring, b cellstring) -> boolean        	| Returns `TRUE` if A contains B (all B’s cells are in A and they overlap) 	  | ✓            	|
## Operators

| Operator                               	| Description                                                                                                               	| Implemented? 	|
|----------------------------------------	|---------------------------------------------------------------------------------------------------------------------------	|--------------	|
| cellstring && cellstring -> boolean    	| Alias for `CST_Intersects`, returns `TRUE` if the two cellstrings share at least one common cell.                         	| ✓            	|
| cellstring & cellstring -> cellstring  	| Alias for `CST_Intersection`, returns a new `cellstring` containing the common cells.                                     	| ✓            	|
| cellstring \| cellstring -> cellstring 	| Alias for `CST_Union`, returns a new `cellstring` containing all unique cells.                                            	| ✓            	|
| cellstring - cellstring -> cellstring  	| Alias for `CST_Difference`, returns a new `cellstring` containing cells present in the first input but not in the second. 	| ✓            	|
| cellstring @>~ cellstring -> boolean   	| Alias for `CST_Contains`, returns `TRUE` if the first `cellstring` contains all cells of the second and they overlap.     	| ✓            	|

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
-- Create cellstring values
SELECT ARRAY[1, 2, 3]::cellstring AS a, ARRAY[2, 3, 4]::cellstring AS b;

-- Intersect two cellstrings
SELECT CST_Intersects(a, b) FROM (SELECT ARRAY[1, 2, 3]::cellstring AS a, ARRAY[2, 3, 4]::cellstring AS b) AS subquery;

-- Union of two cellstrings
SELECT CST_Union(a, b) FROM (SELECT ARRAY[1, 2, 3]::cellstring AS a, ARRAY[2, 3, 4]::cellstring AS b) AS subquery;
```
