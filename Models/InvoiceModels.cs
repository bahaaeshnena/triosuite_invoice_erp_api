using System.ComponentModel.DataAnnotations;

namespace triosuite_invoice_erp_api.Models;

public sealed class SaveInvoiceRequest
{
    [Required]
    public DateTime InvoiceDate { get; set; } = DateTime.UtcNow;

    [Range(1, int.MaxValue)]
    public int CustomerId { get; set; }

    [Range(1, int.MaxValue)]
    public int CurrencyId { get; set; }

    [Range(typeof(decimal), "0.000001", "999999999999.999999")]
    public decimal ExchangeRate { get; set; } = 1;

    [Required]
    [RegularExpression("INCLUSIVE|EXCLUSIVE")]
    public string TaxMode { get; set; } = "EXCLUSIVE";

    public string? NotesAr { get; set; }
    public string? NotesEn { get; set; }

    [Required, MinLength(1)]
    public List<SaveInvoiceItemRequest> Items { get; set; } = [];
}

public sealed class SaveInvoiceItemRequest
{
    [Range(1, int.MaxValue)]
    public int ItemId { get; set; }

    [Range(1, int.MaxValue)]
    public int UnitId { get; set; }

    [Range(typeof(decimal), "0.001", "999999999999.999")]
    public decimal Quantity { get; set; }

    [Range(typeof(decimal), "0", "999999999999999.999")]
    public decimal UnitPrice { get; set; }

    [Range(typeof(decimal), "0", "100")]
    public decimal TaxRate { get; set; }
}

public sealed class CancelInvoiceRequest
{
    [Required, MaxLength(500)]
    public string ReasonAr { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? ReasonEn { get; set; }
}

public sealed record SavedInvoiceDto(int Id, string InvoiceNumber);

public sealed record InvoiceListItemDto(
    int Id,
    string InvoiceNumber,
    DateTime InvoiceDate,
    int CustomerId,
    string CustomerNameAr,
    string CustomerNameEn,
    string CurrencyCode,
    string TaxMode,
    string Status,
    decimal TotalAmount);

public sealed class InvoiceDetailsDto
{
    public int Id { get; init; }
    public string InvoiceNumber { get; init; } = string.Empty;
    public DateTime InvoiceDate { get; init; }
    public int CustomerId { get; init; }
    public string CustomerNameAr { get; init; } = string.Empty;
    public string CustomerNameEn { get; init; } = string.Empty;
    public int CurrencyId { get; init; }
    public string CurrencyCode { get; init; } = string.Empty;
    public decimal ExchangeRate { get; init; }
    public string TaxMode { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public decimal SubTotal { get; init; }
    public decimal TaxAmount { get; init; }
    public decimal TotalAmount { get; init; }
    public decimal BaseCurrencyTotal { get; init; }
    public string? NotesAr { get; init; }
    public string? NotesEn { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime? ApprovedAt { get; init; }
    public DateTime? CancelledAt { get; init; }
    public string? CancellationReasonAr { get; init; }
    public string? CancellationReasonEn { get; init; }
    public List<InvoiceItemDto> Items { get; init; } = [];
}

public sealed record InvoiceItemDto(
    int Id,
    int ItemId,
    string ItemCode,
    string ItemNameAr,
    string ItemNameEn,
    string? Barcode,
    int UnitId,
    string UnitCode,
    decimal Quantity,
    decimal UnitPrice,
    decimal TaxRate,
    decimal TaxAmount,
    decimal LineSubTotal,
    decimal LineTotal);
