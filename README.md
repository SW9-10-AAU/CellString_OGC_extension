# CellString Extension

The `cellstring` extension provides efficient functions to manipulate arrays of cell IDs for spatial analysis. It's designed as an alternative to LineString for representing trajectories and other spatial data as collections of discrete grid cells.

## Overview

Two implementations are available:

- **[PostgreSQL](./PostgreSQL_cellstring_extension/)** — Native SQL functions working with `bigint[]` and `int[]` array types
- **[DuckDB](./DuckDB_cellstring_extension/)** — Macro-based implementation using unnested cells with bit-encoded quadkeys

## Purpose

CellString provides an efficient alternative to LineString for representing AIS trajectories and other spatio-temporal data. It enables operations such as:

- **Intersection** — Find shared cells between trajectories
- **Union** — Combine cells from multiple trajectories
- **Difference** — Find cells in one trajectory but not another
- **Coverage Analysis** — Calculate coverage percentages
- **Visualization** — Convert cells to geometries (polygons, points, linestrings)

This approach is particularly useful for:
- Analyzing vessel trajectories (AIS data)
- Spatial overlap detection
- Spatio-temporal queries at scale
- Grid-based spatial analysis

## Installation

Choose your preferred implementation:

### PostgreSQL
See [PostgreSQL_cellstring_extension/README.md](./PostgreSQL_cellstring_extension/README.md) for installation and usage.

### DuckDB
See [DuckDB_cellstring_extension/README.md](./DuckDB_cellstring_extension/README.md) for installation and usage.

## Quick Comparison

| Feature | PostgreSQL | DuckDB |
|---------|-----------|--------|
| **Array Type** | `bigint[]`, `int[]` | Unnested tables with cell columns |
| **Implementation** | SQL Functions | Macros |
| **Encoding** | Integer encoded xy cells | Integer representation of Bit-encoded Z-order curve(quadkey) |
| **Spatio-temporal** | Basic timestamp support (trajectory start and end time) | Built-in with `ts` columns (cell enter and exit time)|
| **Dependencies** | PostGIS, bigintarray | Spatial extension DuckDB |

## Key Concepts

### Cells
Cells are encoded integers representing grid cells at specific zoom levels. The encoding scheme is database-agnostic and can be converted between different representations:

- **Coordinates**: X/Y tile coordinates can be decoded from cells
- **Quadkeys**: Cells can be converted to standard quadkey strings

### CellString Operations

All implementations support OGC-inspired spatial operations:

- `Intersects` — Boolean overlap check
- `Intersection` — Get common cells
- `Union` — Combine cell sets
- `Difference` — Get exclusive cells
- `Contains` — Check containment
- `Disjoint` — Check no overlap
- `Coverage` — Calculate coverage percentage

## License

See [LICENSE](./LICENSE) for license information.

## Repository

For the latest version, visit: [SW9-10-AAU/CellString_OGC_extension](https://github.com/SW9-10-AAU/CellString_OGC_extension)
