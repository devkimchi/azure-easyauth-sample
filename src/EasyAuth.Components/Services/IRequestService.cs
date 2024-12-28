namespace EasyAuth.Components.Services;

public interface IRequestService
{
    Task<string> GetHeaders();

    Task<string> GetQueries();

    Task<string> GetCookies();

    Task<string> GetPayload();

    Task<string> GetAuthMe();

    Task<string> GetClientPrincipal();
}
