using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace EasyAuth.Handlers;

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

    public static async Task<MsClientPrincipal?> ParseMsClientPrincipal(string value)
    {
        var decoded = Convert.FromBase64String(value);
        using var stream = new MemoryStream(decoded);
        var principal = await JsonSerializer.DeserializeAsync<MsClientPrincipal>(stream, options).ConfigureAwait(false);

        return principal;
    }

    public static async Task<ClaimsPrincipal?> ParseClaimsPrincipal(string value)
    {
        var clientPrincipal = await ParseMsClientPrincipal(value).ConfigureAwait(false);
        if (clientPrincipal == null || clientPrincipal.Claims?.Any() == false)
        {
            return null;
        }

        var claims = clientPrincipal.Claims!.Select(claim => new Claim(claim.Type!, claim.Value!));

        // remap "roles" claims from easy auth to the more standard ClaimTypes.Role: "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
        var easyAuthRoleClaims = claims.Where(claim => claim.Type == "roles");
        var claimsAndRoles = claims.Concat(easyAuthRoleClaims.Select(role => new Claim(clientPrincipal.RoleClaimType!, role.Value)));

        var identity = new ClaimsIdentity(claimsAndRoles, clientPrincipal.IdentityProvider, clientPrincipal.NameClaimType, clientPrincipal.RoleClaimType);
        var claimsPrincipal = new ClaimsPrincipal(identity);

        return claimsPrincipal;
    }
}
