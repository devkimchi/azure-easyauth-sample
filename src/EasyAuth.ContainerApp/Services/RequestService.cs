using System.Text.Json;

using EasyAuth.Components.Services;
using EasyAuth.Handlers;

namespace EasyAuth.ContainerApp.Services;

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
        var context = accessor.HttpContext;
        var request = context!.Request;
        var headers = request.Headers;
        var authMe = default(string);
        try
        {
            http.DefaultRequestHeaders.Clear();
            foreach (var header in headers)
            {
                http.DefaultRequestHeaders.Add(header.Key, header.Value.ToArray());
            }
            authMe = JsonSerializer.Serialize(await http.GetFromJsonAsync<object>("/.auth/me"), options);
        }
        catch (Exception ex)
        {
            authMe = ex.Message;
        }

        return authMe;
    }

    public async Task<string> GetClientPrincipal()
    {
        var context = accessor.HttpContext;
        var request = context!.Request;
        var headers = request.Headers;

        var encoded = headers["X-MS-CLIENT-PRINCIPAL"];
        if (string.IsNullOrWhiteSpace(encoded))
        {
            return "No client principal found";
        }

        var principal = await MsClientPrincipal.ParseMsClientPrincipal(encoded!).ConfigureAwait(false);
        var serialised = JsonSerializer.Serialize(principal, options);

        return serialised;
    }
}
