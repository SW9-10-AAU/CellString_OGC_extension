# CellString PostgreSQL Extension

## Install

### 1. Install bigintarray extension
The CellString extension is dependent on the [bigintarray](https://github.com/DanielJDufour/bigintarray/tree/main) extension.

#### 1. Run the following command to download the bigintarray extension:
```
wget https://raw.githubusercontent.com/DanielJDufour/bigintarray/main/bigintarray--0.0.1.sql
```
#### 2. Run the following command to install the bigintarray extension:
```
psql -h {0.0.0.0} -p {5432} --username {username} {database_name} < ./bigintarray--0.0.1.sql;
```
### 2. Install CellString extension
#### 1. Run the following command to download the CellString extension:
```
wget https://raw.githubusercontent.com/SW9-10-AAU/CellString_OGC_extension/main/CellString--0.0.1.sql
```
#### 2. Run the following command to install the CellString extension:
```
psql -h {0.0.0.0} -p {5432} --username {username} {database_name} < ./CellString--0.0.1.sql;
```

## OGC Functions
The CellString extension provides the following OGC functions:
