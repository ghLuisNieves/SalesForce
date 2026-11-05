USE [SFranquicias_TarjetasCopy];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Baseline con la regla de negocio confirmada: solo ayer por ZMOV.FECHMOV.
-- Conserva joins, NOLOCK, expresiones y COUNT(*) OVER() del original.
-- No es la version optimizada: permite comparar el mismo conjunto de datos.
CREATE OR ALTER PROCEDURE dbo.Sp_Sel_IntegrationCRMTickets_v2_fecha_mov_prueba
    @IdPais INT,
    @FechaCorte DATETIME2 = NULL,
    @PageSize INT = 0,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    -- @FechaCorte se conserva sin uso.
    DECLARE @BaseUrl VARCHAR(100) = 'https://sterenstorage.blob.core.windows.net/images/magentoimages/';
    DECLARE @FechaHoy DATE = CONVERT(DATE, GETDATE());
    DECLARE @FechaInicio DATE = DATEADD(DAY, -1, @FechaHoy);

    IF @PageSize IS NULL OR @PageSize <= 0 OR @PageSize > 10000
        SET @PageSize = 10000;
    IF @PageNumber IS NULL OR @PageNumber < 1
        SET @PageNumber = 1;
    DECLARE @Offset BIGINT = (CONVERT(BIGINT, @PageNumber) - 1) * @PageSize;

    ;WITH Data_CTE AS (
        SELECT
            MC.IDCTE,
            ZMOVDET.IDDET AS IdRow,
            MFACT.IDFACT AS IdTicket,
            MFACT.FECHREG AS TicketDate,
            ZMOV.NUMDOC AS Bill,
            ZMOV.IDMOV,
            LEFT('000'+ CAST(ZMOVDET.MANDT AS varchar(5)),6) AS Mandante,
            MF.NOMFRQ AS Store,
            MF.EMAIL AS Email,
            'MXP' AS Divisa,
            ZMOV.IDPAIS AS IdCountry,

            ZMOVDET.IDDET  IdItem,
            ZMOVDET.MATNR AS Sku,
            ZMOVDET.ExternalId,
            CONCAT(@BaseUrl, ZMOVDET.MATNR) AS UrlImage,
            ZMOVDET.ARKTX AS Descripcion,
            FAMSUBFAM.VTEXT AS Family,
            FAMSUBFAM.MATKL AS CodeSubFamily,
            FAMSUBFAM.WGBEZ60 AS SubFamily,
            ZMOVDET.KWMENG AS Quantity,
            ABS(ZMOVDET.TOTALPOSICIONCONIVA) AS PriceUnity,
            -- Cálculo de total de registros en la misma pasada
            COUNT(*) OVER() AS TotalRecords
        FROM MCTE MC WITH (NOLOCK)
        INNER JOIN MTRJ MT WITH (NOLOCK) ON MC.IDCTE = MT.IDCTE AND MC.IDPAIS = MT.IDPAIS
        INNER JOIN ZMOV WITH(NOLOCK) ON MT.IDFRQ = ZMOV.IDFRQ AND MT.TIPTRJ = ZMOV.TIPTRJ AND MT.CONSEC = ZMOV.CONSEC AND MT.IDPAIS = ZMOV.IDPAIS
        INNER JOIN MFACT WITH(NOLOCK) ON ZMOV.IDMOV = MFACT.IDMOV
        INNER JOIN ZMOVDET WITH (NOLOCK) ON MFACT.IDMOV = ZMOVDET.IDMOV AND MFACT.IDFACT = ZMOVDET.IDFACT
        INNER JOIN FAMSUBFAM WITH(NOLOCK) ON ZMOVDET.MATNR = FAMSUBFAM.MATNR
        INNER JOIN MFRQ MF WITH (NOLOCK) ON MFACT.FRQFACT = MF.IDFRQ AND MFACT.IDPAIS = MF.IDPAIS -- Para obtener solo el del pais
        LEFT JOIN vw_emailduplicate VW WITH (NOLOCK) ON MC.CORREO = VW.CORREO
        WHERE MC.IDPAIS = @IdPais
          AND MC.TELVALIDO = 1
          AND MC.LOEVM = 1
          -- SARGability: Evita funciones en las columnas del WHERE
          AND ZMOV.FECHMOV >= @FechaInicio
          AND ZMOV.FECHMOV <  @FechaHoy
          AND MT.IDESTTRJ IN (2,4)
          AND ZMOV.IDTIPMOV IN (1,2,3,4)
          AND ZMOVDET.MATNR IS NOT NULL
          AND ZMOVDET.MATNR <> ''
          AND (ZMOVDET.ExternalId is null or  ZMOVDET.ExternalId='')
          AND EXISTS (
              SELECT 1 FROM [SterenClientes].[dbo].[CLTE] WITH (NOLOCK)
              WHERE id_clte = MC.IDBDCTES
          )
    )
    SELECT
        IDCTE, IdRow, IdTicket, TicketDate, Bill, IDMOV,
        Mandante, Store, Email, Divisa, IdCountry, IdItem,
        Sku,ExternalId, UrlImage, Descripcion, Family, CodeSubFamily,
        SubFamily, Quantity, PriceUnity,
        TotalRecords,
        -- Cálculo de total de páginas
        CAST(CEILING(CAST(TotalRecords AS FLOAT) / @PageSize) AS INT) AS TotalPages
    FROM Data_CTE
    ORDER BY IdRow
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
