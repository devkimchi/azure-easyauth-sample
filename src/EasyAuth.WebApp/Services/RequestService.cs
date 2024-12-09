using System.Text.Json;

using EasyAuth.Components.Services;

namespace EasyAuth.WebApp.Services;

public class RequestService(IHttpContextAccessor accessor, HttpClient http) : IRequestService
{
    private static readonly JsonSerializerOptions options = new()
    {
        WriteIndented = true
    };

    public async Task<string> GetHeaders()
    {
        var context = accessor.HttpContext;
        var headers = JsonSerializer.Serialize(context!.Request.Headers, options);

        return await Task.FromResult(headers).ConfigureAwait(false);
    }

    public async Task<string> GetQueries()
    {
        var context = accessor.HttpContext;
        var queries = JsonSerializer.Serialize(context!.Request.Query, options);

        return await Task.FromResult(queries).ConfigureAwait(false);
    }

    public async Task<string> GetCookies()
    {
        var context = accessor.HttpContext;
        var cookies = JsonSerializer.Serialize(context!.Request.Cookies, options);

        return await Task.FromResult(cookies).ConfigureAwait(false);
    }

    public async Task<string> GetPayload()
    {
        var context = accessor.HttpContext;
        var body = default(string);
        using (var reader = new StreamReader(context!.Request.Body))
        {
            body = await reader.ReadToEndAsync();
        }

        return body;
    }

    public async Task<string> GetAuthMe()
    {
        var authMe = default(string);
        try
        {
            authMe = await http.GetStringAsync("/.auth/me");
        }
        catch
        {
            authMe = "Not authenticated";
        }

        return authMe;
    }
}
