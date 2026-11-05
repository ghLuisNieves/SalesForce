USE [SFranquicias_TarjetasCopy];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Version de prueba: mantiene v2 sin cambios.
-- Conserva el DISTINCT, los joins y el contrato de salida.
-- Sustituye COUNT(*) OVER() por materializacion y @@ROWCOUNT.
CREATE OR ALTER PROCEDURE dbo.Sp_Sel_IntegrationCRMMovimientos_v3_prueba
    @IdPais INT,
    @FechaCorte DATETIME2 = NULL,
    @PageSize INT = 0,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- Parametro conservado por compatibilidad, sin uso.
    IF @PageSize IS NULL OR @PageSize <= 0 OR @PageSize > 10000
        SET @PageSize = 10000;

    IF @PageNumber IS NULL OR @PageNumber < 1
        SET @PageNumber = 1;

    DECLARE @Offset BIGINT =
        (CONVERT(BIGINT, @PageNumber) - 1) * @PageSize;
    DECLARE @FechaHasta DATETIME2 = CONVERT(DATE, GETDATE());
    DECLARE @FechaDesde DATETIME2 = DATEADD(DAY, -170, @FechaHasta);
    DECLARE @TotalRecords INT;
    DECLARE @TotalPages INT;

    ;
WITH MovementData AS
    (
        SELECT DISTINCT
            MC.IDCTE,
            CONCAT(MT.IDFRQ, MT.TIPTRJ, MT.CONSEC) AS CARD,
            ZM.IDMOV,
            TM.DESTIPMOV,
            ZM.VALOR,
            ZM.NUMDOC,
            ZM.FECHMOV,
            ZM.NUMREF,
            ZM.ExternalId,
            T.IDPAIS AS Pais,
            MF.NOMFRQ AS FRQMOV
        FROM dbo.MCTE AS MC
        INNER JOIN dbo.MTRJ AS MT
            ON MT.IDCTE = MC.IDCTE
           AND MT.IDPAIS = MC.IDPAIS
        INNER JOIN dbo.ZMOV AS ZM
            ON ZM.IDFRQ = MT.IDFRQ
           AND ZM.TIPTRJ = MT.TIPTRJ
           AND ZM.CONSEC = MT.CONSEC
           AND ZM.IDPAIS = MT.IDPAIS
        INNER JOIN dbo.MFACT AS F
            ON F.IDMOV = ZM.IDMOV
        INNER JOIN dbo.TTIPMOV AS TM
            ON TM.IDTIPMOV = ZM.IDTIPMOV
        INNER JOIN dbo.MFRQ AS MF
            ON MF.IDFRQ = F.FRQFACT
           AND MF.IDPAIS = MC.IDPAIS
        INNER JOIN dbo.TPAIS AS T
            ON T.IDPAIS = MC.IDPAIS
        WHERE MC.IDPAIS = @IdPais
          AND MC.TELVALIDO = 1
          AND MC.LOEVM = 1
          AND MT.IDESTTRJ IN (2, 4)
          AND ZM.IDTIPMOV IN (1, 2, 3, 4)
          AND ZM.FECHMOV >= @FechaDesde
          AND ZM.FECHMOV < @FechaHasta
          AND (ZM.ExternalId IS NULL OR ZM.ExternalId = '')
          AND EXISTS
          (
              SELECT 1
              FROM [SterenClientes].[dbo].[CLTE] AS CL
              WHERE CL.id_clte = MC.IDBDCTES
          )
    )
    SELECT
        IDCTE, CARD, IDMOV, DESTIPMOV, VALOR, NUMDOC,
        FECHMOV, NUMREF, ExternalId, Pais, FRQMOV
    INTO #MovementData
    FROM MovementData;

    -- Debe capturarse inmediatamente despues del SELECT INTO.
    SET @TotalRecords = @@ROWCOUNT;

    SET @TotalPages = CONVERT(
        INT,
        (CONVERT(BIGINT, @TotalRecords) + @PageSize - 1) / @PageSize
    );

    SELECT
        IDCTE,
        CARD,
        IDMOV,
        DESTIPMOV,
        VALOR,
        NUMDOC,
        FECHMOV,
        NUMREF,
        ExternalId,
        Pais,
        FRQMOV,
        @TotalRecords AS TotalRecords,
        @TotalPages AS TotalPages
    FROM #MovementData
    ORDER BY IDMOV
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- Medicion: usar los mismos parametros que en v2 y activar Ctrl+M.
-- SET STATISTICS IO ON;
-- SET STATISTICS TIME ON;
-- EXEC dbo.Sp_Sel_IntegrationCRMMovimientos_v3_prueba
--     @IdPais = 1, @PageSize = 10000, @PageNumber = 1;
-- SET STATISTICS TIME OFF;
-- SET STATISTICS IO OFF;
