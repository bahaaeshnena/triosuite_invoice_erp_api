using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using triosuite_invoice_erp_api.Models;

namespace triosuite_invoice_erp_api.Services;

public sealed class JwtTokenService(IConfiguration configuration)
{
    public LoginResponse Create(UserWithPassword user, string refreshToken, DateTime refreshTokenExpiresAt)
    {
        var expiryMinutes = configuration.GetValue("Jwt:AccessTokenExpiryMinutes", 15);
        var expiresAt = DateTime.UtcNow.AddMinutes(expiryMinutes);
        var key = configuration["Jwt:Key"]
            ?? throw new InvalidOperationException("Jwt:Key is missing from configuration.");

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.Username),
            new Claim("fullNameAr", user.FullNameAr),
            new Claim("fullNameEn", user.FullNameEn)
        };

        var token = new JwtSecurityToken(
            issuer: configuration["Jwt:Issuer"],
            audience: configuration["Jwt:Audience"],
            claims: claims,
            expires: expiresAt,
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
                SecurityAlgorithms.HmacSha256));

        return new LoginResponse(
            new JwtSecurityTokenHandler().WriteToken(token),
            refreshToken,
            expiresAt,
            refreshTokenExpiresAt,
            user.Id,
            user.Username,
            user.FullNameAr,
            user.FullNameEn);
    }

    public string CreateRefreshToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

    public static string HashRefreshToken(string refreshToken) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(refreshToken)));
}
