using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace EasyAuth.Components.Models;

public class MsClientPrincipal
{
    private static readonly JsonSerializerOptions options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

    [JsonPropertyName("auth_typ")]
    public string? IdentityProvider { get; set; }

    [JsonPropertyName("name_typ")]
    public string? NameClaimType { get; set; }

    [JsonPropertyName("role_typ")]
    public string? RoleClaimType { get; set; }

    [JsonPropertyName("claims")]
    public IEnumerable<MsClientPrincipalClaim>? Claims { get; set; }

    public static async Task<MsClientPrincipal> ParseMsClientPrincipal(string value)
    {
        var decoded = Convert.FromBase64String(value);
        using var stream = new MemoryStream(decoded);
        var principal = await JsonSerializer.DeserializeAsync<MsClientPrincipal>(stream, options).ConfigureAwait(false);
        if (principal == null)
        {
            throw new InvalidOperationException("Failed to parse client principal");
        }

        return principal;
    }

    public static async Task<ClaimsPrincipal> ParseClaimsPrincipal(string value)
    {
        var principal = await ParseMsClientPrincipal(value).ConfigureAwait(false);
        var identity = new ClaimsIdentity(principal.IdentityProvider, principal.NameClaimType, principal.RoleClaimType);
        if (principal.Claims?.Any() == true)
        {
            identity.AddClaims(principal.Claims!.Select(c => new Claim(c.Type!, c.Value!)));
        }
        
        return new ClaimsPrincipal(identity);
    }
}
