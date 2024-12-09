using System.Text;

using EasyAuth.Components.Services;

namespace EasyAuth.SwaApp.Services;

public class RequestService(HttpClient http) : IRequestService
{
    public async Task<string> GetHeaders()
    {
        var baseUrl = http.BaseAddress;
        var headers = await http.GetStringAsync("/api/headers").ConfigureAwait(false);

        return headers;
    }

    public async Task<string> GetQueries()
    {
        var queries = await http.GetStringAsync("/api/queries").ConfigureAwait(false);

        return queries;
    }

    public async Task<string> GetCookies()
    {
        var cookies = await http.GetStringAsync("/api/cookies").ConfigureAwait(false);

        return cookies;
    }

    public async Task<string> GetPayload()
    {
        var content = new StringContent("Hello, World!", Encoding.UTF8, "text/plain");
        var result = await http.PostAsync("/api/payload", content);
        var body = default(string);
        using (var reader = new StreamReader(await result.Content.ReadAsStreamAsync()))
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
