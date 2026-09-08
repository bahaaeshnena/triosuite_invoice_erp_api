using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using triosuite_invoice_erp_api.Data;
using triosuite_invoice_erp_api.Models;

namespace triosuite_invoice_erp_api.Controllers;

[Authorize]
[ApiController]
[Route("api/invoices")]
public sealed class InvoicesController(DatabaseService database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<InvoiceListItemDto>>> GetAll(
        [FromQuery] string? status,
        [FromQuery] string? search) =>
        Ok(await database.GetInvoicesAsync(status, search));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<InvoiceDetailsDto>> GetById(int id)
    {
        var invoice = await database.GetInvoiceAsync(id);
        return invoice is null ? NotFound(new { message = "Invoice not found." }) : Ok(invoice);
    }

    [HttpPost]
    public async Task<ActionResult<SavedInvoiceDto>> Create(SaveInvoiceRequest request)
    {
        var saved = await database.SaveInvoiceAsync(null, request, CurrentUserId());
        return CreatedAtAction(nameof(GetById), new { id = saved.Id }, saved);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<SavedInvoiceDto>> Update(int id, SaveInvoiceRequest request) =>
        Ok(await database.SaveInvoiceAsync(id, request, CurrentUserId()));

    [HttpPost("{id:int}/approve")]
    public async Task<IActionResult> Approve(int id)
    {
        await database.ApproveInvoiceAsync(id, CurrentUserId());
        return NoContent();
    }

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id, CancelInvoiceRequest request)
    {
        await database.CancelInvoiceAsync(id, CurrentUserId(), request);
        return NoContent();
    }

    private int CurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(value, out var userId)
            ? userId
            : throw new UnauthorizedAccessException("User id is missing from token.");
    }
}
