using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using triosuite_invoice_erp_api.Models;

namespace triosuite_invoice_erp_api.Data;

public sealed class DatabaseService(IConfiguration configuration)
{
    private readonly string _connectionString = configuration.GetConnectionString("SalesInvoiceDB")
        ?? throw new InvalidOperationException("Connection string 'SalesInvoiceDB' is missing.");

    public async Task<UserWithPassword?> GetUserForLoginAsync(string username)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Auth_GetUserByUsername");
        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = username;

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        return new UserWithPassword(
            reader.GetInt32(reader.GetOrdinal("Id")),
            reader.GetString(reader.GetOrdinal("Username")),
            reader.GetString(reader.GetOrdinal("PasswordHash")),
            reader.GetString(reader.GetOrdinal("FullNameAr")),
            reader.GetString(reader.GetOrdinal("FullNameEn")));
    }

    public async Task CreateRefreshTokenAsync(
        int userId,
        string tokenHash,
        Guid familyId,
        DateTime expiresAt)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Auth_CreateRefreshToken");
        command.Parameters.Add("@UserId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@TokenHash", SqlDbType.Char, 64).Value = tokenHash;
        command.Parameters.Add("@FamilyId", SqlDbType.UniqueIdentifier).Value = familyId;
        command.Parameters.Add("@ExpiresAt", SqlDbType.DateTime2).Value = expiresAt;
        await command.ExecuteNonQueryAsync();
    }

    public async Task<UserWithPassword?> RotateRefreshTokenAsync(
        string currentTokenHash,
        string newTokenHash,
        DateTime newExpiresAt)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Auth_RotateRefreshToken");
        command.Parameters.Add("@CurrentTokenHash", SqlDbType.Char, 64).Value = currentTokenHash;
        command.Parameters.Add("@NewTokenHash", SqlDbType.Char, 64).Value = newTokenHash;
        command.Parameters.Add("@NewExpiresAt", SqlDbType.DateTime2).Value = newExpiresAt;

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        return new UserWithPassword(
            reader.GetInt32(reader.GetOrdinal("Id")),
            reader.GetString(reader.GetOrdinal("Username")),
            string.Empty,
            reader.GetString(reader.GetOrdinal("FullNameAr")),
            reader.GetString(reader.GetOrdinal("FullNameEn")));
    }

    public async Task RevokeRefreshTokenFamilyAsync(string tokenHash)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Auth_RevokeRefreshTokenFamily");
        command.Parameters.Add("@TokenHash", SqlDbType.Char, 64).Value = tokenHash;
        await command.ExecuteNonQueryAsync();
    }

    public async Task<LookupsDto> GetLookupsAsync()
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Lookups_GetAll");
        await using var reader = await command.ExecuteReaderAsync();
        var result = new LookupsDto();

        while (await reader.ReadAsync())
        {
            result.Customers.Add(new CustomerDto(
                reader.GetInt32(0), reader.GetString(1), reader.GetString(2), reader.GetString(3)));
        }

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.Items.Add(ReadItem(reader));
        }

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.Currencies.Add(new CurrencyDto(
                reader.GetInt32(0), reader.GetString(1), reader.GetString(2), reader.GetString(3),
                reader.IsDBNull(4) ? null : reader.GetString(4), reader.GetBoolean(5)));
        }

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.Units.Add(new UnitDto(
                reader.GetInt32(0), reader.GetString(1), reader.GetString(2), reader.GetString(3)));
        }

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            result.TaxModes.Add(new TaxModeDto(
                reader.GetInt32(0), reader.GetString(1), reader.GetString(2), reader.GetString(3)));
        }

        return result;
    }

    public async Task<ItemDto?> GetItemByBarcodeAsync(string barcode)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Item_GetByBarcode");
        command.Parameters.Add("@Barcode", SqlDbType.NVarChar, 100).Value = barcode;
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync() ? ReadItem(reader) : null;
    }

    public async Task<SettingsDto?> GetSettingsAsync()
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Settings_Get");
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        return new SettingsDto
        {
            Id = reader.GetInt32(0),
            CompanyNameAr = reader.GetString(1),
            CompanyNameEn = reader.GetString(2),
            DefaultCurrencyId = reader.GetInt32(3),
            DefaultCurrencyCode = reader.GetString(4),
            InvoicePrefix = reader.GetString(5)
        };
    }

    public async Task<SettingsDto> SaveSettingsAsync(SaveSettingsRequest request)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_Settings_Save");
        command.Parameters.Add("@CompanyNameAr", SqlDbType.NVarChar, 200).Value = request.CompanyNameAr;
        command.Parameters.Add("@CompanyNameEn", SqlDbType.NVarChar, 200).Value = request.CompanyNameEn;
        command.Parameters.Add("@DefaultCurrencyId", SqlDbType.Int).Value = request.DefaultCurrencyId;
        command.Parameters.Add("@InvoicePrefix", SqlDbType.NVarChar, 20).Value = request.InvoicePrefix;
        await using var reader = await command.ExecuteReaderAsync();
        await reader.ReadAsync();

        return new SettingsDto
        {
            Id = reader.GetInt32(0),
            CompanyNameAr = reader.GetString(1),
            CompanyNameEn = reader.GetString(2),
            DefaultCurrencyId = reader.GetInt32(3),
            DefaultCurrencyCode = reader.GetString(4),
            InvoicePrefix = reader.GetString(5)
        };
    }

    public async Task<List<InvoiceListItemDto>> GetInvoicesAsync(string? status, string? search)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_SalesInvoice_List");
        command.Parameters.Add("@Status", SqlDbType.NVarChar, 50).Value = DbValue(status);
        command.Parameters.Add("@Search", SqlDbType.NVarChar, 200).Value = DbValue(search);
        await using var reader = await command.ExecuteReaderAsync();
        var invoices = new List<InvoiceListItemDto>();

        while (await reader.ReadAsync())
        {
            invoices.Add(new InvoiceListItemDto(
                reader.GetInt32(0), reader.GetString(1), reader.GetDateTime(2), reader.GetInt32(3),
                reader.GetString(4), reader.GetString(5), reader.GetString(6), reader.GetString(7),
                reader.GetString(8), reader.GetDecimal(9)));
        }

        return invoices;
    }

    public async Task<InvoiceDetailsDto?> GetInvoiceAsync(int id)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_SalesInvoice_GetById");
        command.Parameters.Add("@Id", SqlDbType.Int).Value = id;
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        var invoice = new InvoiceDetailsDto
        {
            Id = reader.GetInt32(0),
            InvoiceNumber = reader.GetString(1),
            InvoiceDate = reader.GetDateTime(2),
            CustomerId = reader.GetInt32(3),
            CustomerNameAr = reader.GetString(4),
            CustomerNameEn = reader.GetString(5),
            CurrencyId = reader.GetInt32(6),
            CurrencyCode = reader.GetString(7),
            ExchangeRate = reader.GetDecimal(8),
            TaxMode = reader.GetString(9),
            Status = reader.GetString(10),
            SubTotal = reader.GetDecimal(11),
            TaxAmount = reader.GetDecimal(12),
            TotalAmount = reader.GetDecimal(13),
            BaseCurrencyTotal = reader.GetDecimal(14),
            NotesAr = reader.IsDBNull(15) ? null : reader.GetString(15),
            NotesEn = reader.IsDBNull(16) ? null : reader.GetString(16),
            CreatedAt = reader.GetDateTime(17),
            ApprovedAt = reader.IsDBNull(18) ? null : reader.GetDateTime(18),
            CancelledAt = reader.IsDBNull(19) ? null : reader.GetDateTime(19),
            CancellationReasonAr = reader.IsDBNull(20) ? null : reader.GetString(20),
            CancellationReasonEn = reader.IsDBNull(21) ? null : reader.GetString(21)
        };

        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            invoice.Items.Add(new InvoiceItemDto(
                reader.GetInt32(0), reader.GetInt32(1), reader.GetString(2), reader.GetString(3),
                reader.GetString(4), reader.IsDBNull(5) ? null : reader.GetString(5), reader.GetInt32(6),
                reader.GetString(7), reader.GetDecimal(8), reader.GetDecimal(9), reader.GetDecimal(10),
                reader.GetDecimal(11), reader.GetDecimal(12), reader.GetDecimal(13)));
        }

        return invoice;
    }

    public async Task<SavedInvoiceDto> SaveInvoiceAsync(int? id, SaveInvoiceRequest request, int userId)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, "dbo.usp_SalesInvoice_Save");
        command.Parameters.Add("@Id", SqlDbType.Int).Value = id.HasValue ? id.Value : DBNull.Value;
        command.Parameters.Add("@InvoiceDate", SqlDbType.DateTime2).Value = request.InvoiceDate;
        command.Parameters.Add("@CustomerId", SqlDbType.Int).Value = request.CustomerId;
        command.Parameters.Add("@CurrencyId", SqlDbType.Int).Value = request.CurrencyId;
        command.Parameters.Add("@ExchangeRate", SqlDbType.Decimal).WithPrecision(18, 6).Value = request.ExchangeRate;
        command.Parameters.Add("@TaxModeCode", SqlDbType.NVarChar, 50).Value = request.TaxMode;
        command.Parameters.Add("@NotesAr", SqlDbType.NVarChar, 500).Value = DbValue(request.NotesAr);
        command.Parameters.Add("@NotesEn", SqlDbType.NVarChar, 500).Value = DbValue(request.NotesEn);
        command.Parameters.Add("@ItemsJson", SqlDbType.NVarChar, -1).Value = JsonSerializer.Serialize(request.Items);
        command.Parameters.Add("@UserId", SqlDbType.Int).Value = userId;

        await using var reader = await command.ExecuteReaderAsync();
        await reader.ReadAsync();
        return new SavedInvoiceDto(reader.GetInt32(0), reader.GetString(1));
    }

    public Task ApproveInvoiceAsync(int id, int userId) =>
        ExecuteInvoiceActionAsync("dbo.usp_SalesInvoice_Approve", id, userId);

    public Task CancelInvoiceAsync(int id, int userId, CancelInvoiceRequest request) =>
        ExecuteInvoiceActionAsync("dbo.usp_SalesInvoice_Cancel", id, userId, request);

    private async Task ExecuteInvoiceActionAsync(
        string procedure,
        int id,
        int userId,
        CancelInvoiceRequest? cancellation = null)
    {
        await using var connection = await OpenConnectionAsync();
        await using var command = StoredProcedure(connection, procedure);
        command.Parameters.Add("@Id", SqlDbType.Int).Value = id;
        command.Parameters.Add("@UserId", SqlDbType.Int).Value = userId;
        if (cancellation is not null)
        {
            command.Parameters.Add("@ReasonAr", SqlDbType.NVarChar, 500).Value = cancellation.ReasonAr;
            command.Parameters.Add("@ReasonEn", SqlDbType.NVarChar, 500).Value = DbValue(cancellation.ReasonEn);
        }

        await command.ExecuteNonQueryAsync();
    }

    private async Task<SqlConnection> OpenConnectionAsync()
    {
        var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
        return connection;
    }

    private static SqlCommand StoredProcedure(SqlConnection connection, string name) =>
        new(name, connection) { CommandType = CommandType.StoredProcedure };

    private static object DbValue(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();

    private static ItemDto ReadItem(SqlDataReader reader) => new(
        reader.GetInt32(0), reader.GetString(1), reader.GetString(2), reader.GetString(3),
        reader.IsDBNull(4) ? null : reader.GetString(4), reader.GetInt32(5), reader.GetString(6),
        reader.GetDecimal(7), reader.GetDecimal(8));
}

internal static class SqlParameterExtensions
{
    public static SqlParameter WithPrecision(this SqlParameter parameter, byte precision, byte scale)
    {
        parameter.Precision = precision;
        parameter.Scale = scale;
        return parameter;
    }
}
