using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using triosuite_invoice_erp_api.Data;
using triosuite_invoice_erp_api.Models;

namespace triosuite_invoice_erp_api.Controllers;

[Authorize]
[ApiController]
[Route("api/settings")]
public sealed class SettingsController(DatabaseService database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<SettingsDto>> Get()
    {
        var settings = await database.GetSettingsAsync();
        return settings is null ? NotFound(new { message = "Settings not found." }) : Ok(settings);
    }

    [HttpPut]
    public async Task<ActionResult<SettingsDto>> Save(SaveSettingsRequest request) =>
        Ok(await database.SaveSettingsAsync(request));
}
