using System.Text.Encodings.Web;

using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace EasyAuth.Handlers;

public class EasyAuthAuthenticationHandler(IOptionsMonitor<EasyAuthAuthenticationOptions> options, ILoggerFactory logger, UrlEncoder encoder)
    : AuthenticationHandler<EasyAuthAuthenticationOptions>(options, logger, encoder)
{
    public const string EASY_AUTH_SCHEME_NAME = "EasyAuth";

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        try
        {
            var easyAuthProvider = Context.Request.Headers["X-MS-CLIENT-PRINCIPAL-IDP"].FirstOrDefault() ?? "aad";
            var encoded = Context.Request.Headers["X-MS-CLIENT-PRINCIPAL"].FirstOrDefault();
            if (string.IsNullOrWhiteSpace(encoded) == true)
            {
                return AuthenticateResult.NoResult();
            }

            var principal = await MsClientPrincipal.ParseClaimsPrincipal(encoded!).ConfigureAwait(false);
            if (principal == null)
            {
                return AuthenticateResult.NoResult();
            }

            var ticket = new AuthenticationTicket(principal, easyAuthProvider);
            var success = AuthenticateResult.Success(ticket);

            this.Context.User = principal;

            return success;
        }
        catch (Exception ex)
        {
            return AuthenticateResult.Fail(ex);
        }
    }
}