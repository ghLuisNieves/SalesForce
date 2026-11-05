-- Solo lectura. Ejecutar en la misma base de la prueba Plan5_2.
USE [SFranquicias_TarjetasCopy];
GO

-- 1. Verificar el contexto y la definicion de la vista antes de retirarla.
SELECT DB_NAME() AS BaseActual;

SELECT
    OBJECT_SCHEMA_NAME(sm.object_id) AS Esquema,
    OBJECT_NAME(sm.object_id) AS Objeto,
    sm.definition AS Definicion
FROM sys.sql_modules AS sm
WHERE sm.object_id = OBJECT_ID(N'dbo.vw_emailduplicate');

-- 2. Indices y columnas de las tablas que faltan por revisar.
SELECT
    s.name AS Esquema,
    t.name AS Tabla,
    i.name AS Indice,
    i.type_desc AS TipoIndice,
    i.is_unique AS EsUnico,
    i.is_disabled AS Deshabilitado,
    i.filter_definition AS Filtro,
    c.name AS Columna,
    ic.key_ordinal AS OrdenClave,
    ic.is_descending_key AS Descendente,
    ic.is_included_column AS EsInclude
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.indexes AS i ON i.object_id = t.object_id
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id AND ic.index_id = i.index_id
INNER JOIN sys.columns AS c
    ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE s.name = N'dbo'
  AND t.name IN (N'ZMOVDET', N'FamSubFam')
  AND i.is_hypothetical = 0
ORDER BY t.name, i.index_id, ic.is_included_column,
         ic.key_ordinal, ic.index_column_id;

-- 3. Tipos y collations: validar claves e incompatibilidades de MATNR.
SELECT
    s.name AS Esquema,
    t.name AS Tabla,
    c.name AS Columna,
    ty.name AS Tipo,
    c.max_length AS LongitudBytes,
    c.precision AS Precision,
    c.scale AS Escala,
    c.collation_name AS Collation,
    c.is_nullable AS PermiteNull
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c ON c.object_id = t.object_id
INNER JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE s.name = N'dbo'
  AND (
       (t.name = N'ZMOVDET' AND c.name IN
           (N'IDDET', N'IDMOV', N'IDFACT', N'MATNR', N'ExternalId',
            N'MANDT', N'ARKTX', N'KWMENG', N'TOTALPOSICIONCONIVA'))
    OR (t.name = N'FamSubFam' AND c.name IN
           (N'MATNR', N'VTEXT', N'MATKL', N'WGBEZ60'))
    OR (t.name = N'ZMOV' AND c.name IN (N'IDMOV', N'IDPAIS', N'FECHMOV'))
    OR (t.name = N'MFACT' AND c.name IN (N'IDMOV', N'IDFACT', N'FECHREG'))
  )
ORDER BY t.name, c.column_id;
