using Microsoft.AspNetCore.Authentication;

namespace EasyAuth.Handlers;

public class EasyAuthAuthenticationOptions : AuthenticationSchemeOptions
{
    public EasyAuthAuthenticationOptions()
    {
        Events = new object();
    }
}
