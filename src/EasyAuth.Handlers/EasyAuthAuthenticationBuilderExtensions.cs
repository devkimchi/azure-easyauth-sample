using Microsoft.AspNetCore.Authentication;

namespace EasyAuth.Handlers;

public static class EasyAuthAuthenticationBuilderExtensions
{
    public static AuthenticationBuilder AddAzureEasyAuthHandler(this AuthenticationBuilder builder, Action<EasyAuthAuthenticationOptions>? configure = null)
    {
        if (configure == null)
        {
            configure = o => { };
        }

        return builder.AddScheme<EasyAuthAuthenticationOptions, EasyAuthAuthenticationHandler>(
            EasyAuthAuthenticationHandler.EASY_AUTH_SCHEME_NAME,
            EasyAuthAuthenticationHandler.EASY_AUTH_SCHEME_NAME,
            configure);
    }
}
