using System.ComponentModel.DataAnnotations;

namespace triosuite_invoice_erp_api.Models;

public sealed class LoginRequest
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}

public sealed record LoginResponse(
    string Token,
    string RefreshToken,
    DateTime ExpiresAt,
    DateTime RefreshTokenExpiresAt,
    int Id,
    string Username,
    string FullNameAr,
    string FullNameEn);

public sealed class RefreshTokenRequest
{
    [Required]
    public string RefreshToken { get; set; } = string.Empty;
}

public sealed class LogoutRequest
{
    [Required]
    public string RefreshToken { get; set; } = string.Empty;
}

public sealed record UserWithPassword(
    int Id,
    string Username,
    string PasswordHash,
    string FullNameAr,
    string FullNameEn);
