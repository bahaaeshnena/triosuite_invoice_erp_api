using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using triosuite_invoice_erp_api.Data;
using triosuite_invoice_erp_api.Models;
using triosuite_invoice_erp_api.Services;

namespace triosuite_invoice_erp_api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(
    DatabaseService database,
    PasswordService passwords,
    JwtTokenService tokens,
    IConfiguration configuration) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request)
    {
        var user = await database.GetUserForLoginAsync(request.Username.Trim());
        if (user is null || !passwords.Verify(request.Password, user.PasswordHash))
        {
            return Unauthorized(new { message = "Invalid username or password." });
        }

        var refreshToken = tokens.CreateRefreshToken();
        var refreshTokenExpiresAt = DateTime.UtcNow.AddDays(
            configuration.GetValue("Jwt:RefreshTokenExpiryDays", 30));

        await database.CreateRefreshTokenAsync(
            user.Id,
            JwtTokenService.HashRefreshToken(refreshToken),
            Guid.NewGuid(),
            refreshTokenExpiresAt);

        return Ok(tokens.Create(user, refreshToken, refreshTokenExpiresAt));
    }

    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<ActionResult<LoginResponse>> Refresh(RefreshTokenRequest request)
    {
        var newRefreshToken = tokens.CreateRefreshToken();
        var refreshTokenExpiresAt = DateTime.UtcNow.AddDays(
            configuration.GetValue("Jwt:RefreshTokenExpiryDays", 30));

        var user = await database.RotateRefreshTokenAsync(
            JwtTokenService.HashRefreshToken(request.RefreshToken),
            JwtTokenService.HashRefreshToken(newRefreshToken),
            refreshTokenExpiresAt);

        if (user is null)
        {
            return Unauthorized(new { message = "Refresh token is invalid or expired." });
        }

        return Ok(tokens.Create(user, newRefreshToken, refreshTokenExpiresAt));
    }

    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request)
    {
        await database.RevokeRefreshTokenFamilyAsync(
            JwtTokenService.HashRefreshToken(request.RefreshToken));
        return NoContent();
    }
}
