USE [SFranquicias_TarjetasCopy];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Prueba aislada: movimientos de ayer por ZMOV.FECHMOV.
-- Conserva la firma, el orden de columnas y los calculos comerciales originales.
-- No requiere crear ni reconstruir indices permanentes.
-- Variante V5: probar el indice temporal IdRow mediante un hint local al SELECT final.
-- Se retira vw_emailduplicate: no filtra tickets y puede multiplicar detalles.
CREATE OR ALTER PROCEDURE dbo.Sp_Sel_IntegrationCRMTickets_v5_prueba
    @IdPais INT,
    @FechaCorte DATETIME2 = NULL,
    @PageSize INT = 0,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- @FechaCorte permanece sin uso por compatibilidad.
    DECLARE @BaseUrl VARCHAR(100) =
        'https://sterenstorage.blob.core.windows.net/images/magentoimages/';
    DECLARE @FechaHoy DATE = CONVERT(DATE, GETDATE());
    DECLARE @FechaInicio DATE = DATEADD(DAY, -1, @FechaHoy);

    IF @PageSize IS NULL OR @PageSize <= 0 OR @PageSize > 10000
        SET @PageSize = 10000;
    IF @PageNumber IS NULL OR @PageNumber < 1
        SET @PageNumber = 1;

    DECLARE @Offset BIGINT =
        (CONVERT(BIGINT, @PageNumber) - 1) * @PageSize;
    DECLARE @TotalRecords INT;
    DECLARE @TotalPages INT;

    -- 1. Materializar el rango antes de los joins con clientes y detalles.
    -- No filtrar ExternalId del movimiento: el pendiente pertenece al detalle.
    SELECT
        ZM.IDMOV,
        ZM.IDPAIS,
        ZM.IDFRQ,
        ZM.TIPTRJ,
        ZM.CONSEC,
        ZM.NUMDOC
    INTO #MovimientosDia
    FROM dbo.ZMOV AS ZM
    WHERE ZM.IDPAIS = @IdPais
      AND ZM.FECHMOV >= @FechaInicio
      AND ZM.FECHMOV < @FechaHoy
      AND ZM.IDTIPMOV IN (1, 2, 3, 4);

    CREATE UNIQUE CLUSTERED INDEX CX_MovimientosDia_IDMOV
        ON #MovimientosDia (IDMOV);

    -- 2. Resolver tickets elegibles antes de acceder a ZMOVDET.
    SELECT
        MC.IDCTE,
        ZM.IDMOV,
        F.IDFACT,
        F.FECHREG AS TicketDate,
        ZM.NUMDOC AS Bill,
        MF.NOMFRQ AS Store,
        MF.EMAIL AS Email,
        ZM.IDPAIS AS IdCountry
    INTO #TicketsElegibles
    FROM #MovimientosDia AS ZM
    INNER JOIN dbo.MTRJ AS MT
        ON MT.IDFRQ = ZM.IDFRQ
       AND MT.TIPTRJ = ZM.TIPTRJ
       AND MT.CONSEC = ZM.CONSEC
       AND MT.IDPAIS = ZM.IDPAIS
    INNER JOIN dbo.MCTE AS MC
        ON MC.IDCTE = MT.IDCTE
       AND MC.IDPAIS = MT.IDPAIS
    INNER JOIN dbo.MFACT AS F
        ON F.IDMOV = ZM.IDMOV
    INNER JOIN dbo.MFRQ AS MF
        ON MF.IDFRQ = F.FRQFACT
       AND MF.IDPAIS = F.IDPAIS
    WHERE MC.IDPAIS = @IdPais
      AND MC.TELVALIDO = 1
      AND MC.LOEVM = 1
      AND MT.IDESTTRJ IN (2, 4)
      AND EXISTS
      (
          SELECT 1
          FROM [SterenClientes].[dbo].[CLTE] AS CL
          WHERE CL.id_clte = MC.IDBDCTES
      );

    -- No imponer unicidad: conservar la multiplicidad de los joins.
    CREATE CLUSTERED INDEX CX_TicketsElegibles_MovFact
        ON #TicketsElegibles (IDMOV, IDFACT);

    -- 3. Resolver los detalles pendientes y las familias sin truncar MATNR.
    SELECT
        T.IDCTE,
        D.IDDET AS IdRow,
        T.IDFACT AS IdTicket,
        T.TicketDate,
        T.Bill,
        T.IDMOV,
        LEFT('000' + CAST(D.MANDT AS VARCHAR(5)), 6) AS Mandante,
        T.Store,
        T.Email,
        'MXP' AS Divisa,
        T.IdCountry,
        D.IDDET AS IdItem,
        D.MATNR AS Sku,
        D.ExternalId,
        CONCAT(@BaseUrl, D.MATNR) AS UrlImage,
        D.ARKTX AS Descripcion,
        FS.VTEXT AS Family,
        FS.MATKL AS CodeSubFamily,
        FS.WGBEZ60 AS SubFamily,
        D.KWMENG AS Quantity,
        ABS(D.TOTALPOSICIONCONIVA) AS PriceUnity
    INTO #TicketItems
    FROM #TicketsElegibles AS T
    INNER JOIN dbo.ZMOVDET AS D
        ON D.IDMOV = T.IDMOV
       AND D.IDFACT = T.IDFACT
    INNER JOIN dbo.FamSubFam AS FS
        ON FS.MATNR = D.MATNR
    WHERE D.MATNR IS NOT NULL
      AND D.MATNR <> ''
      AND (D.ExternalId IS NULL OR D.ExternalId = N'');

    SET @TotalRecords = @@ROWCOUNT;

    -- Capturar el total antes del CREATE INDEX, que modifica @@ROWCOUNT.
    -- No es UNIQUE: conserva posibles repeticiones de IdRow por otros joins.
    -- No incluir textos ni nvarchar(max): mantener estrecha la clave ordenada.
    CREATE NONCLUSTERED INDEX IX_TicketItems_IdRow
        ON #TicketItems (IdRow);
    SET @TotalPages = CONVERT(
        INT,
        (CONVERT(BIGINT, @TotalRecords) + @PageSize - 1) / @PageSize
    );

    SELECT
        IDCTE, IdRow, IdTicket, TicketDate, Bill, IDMOV,
        Mandante, Store, Email, Divisa, IdCountry, IdItem,
        Sku, ExternalId, UrlImage, Descripcion, Family, CodeSubFamily,
        SubFamily, Quantity, PriceUnity,
        @TotalRecords AS TotalRecords,
        @TotalPages AS TotalPages
    FROM #TicketItems WITH (INDEX(IX_TicketItems_IdRow))
    ORDER BY IdRow
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
