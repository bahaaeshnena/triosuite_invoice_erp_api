using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using triosuite_invoice_erp_api.Data;
using triosuite_invoice_erp_api.Models;

namespace triosuite_invoice_erp_api.Controllers;

[Authorize]
[ApiController]
[Route("api/lookups")]
public sealed class LookupsController(DatabaseService database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<LookupsDto>> GetAll() => Ok(await database.GetLookupsAsync());

    [HttpGet("items/barcode/{barcode}")]
    public async Task<ActionResult<ItemDto>> GetItemByBarcode(string barcode)
    {
        var item = await database.GetItemByBarcodeAsync(barcode);
        return item is null ? NotFound(new { message = "Item not found." }) : Ok(item);
    }
}
