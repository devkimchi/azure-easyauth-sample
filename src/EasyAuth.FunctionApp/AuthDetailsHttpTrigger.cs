using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace EasyAuth.FunctionApp;

public class AuthDetailsHttpTrigger
{
    private static readonly JsonSerializerOptions options = new()
    {
        WriteIndented = true
    };

    private readonly ILogger<AuthDetailsHttpTrigger> _logger;

    public AuthDetailsHttpTrigger(ILogger<AuthDetailsHttpTrigger> logger)
    {
        _logger = logger;
    }

    [Function("GetHeaders")]
    public async Task<IActionResult> GetHeaders([HttpTrigger(AuthorizationLevel.Anonymous, "GET", Route = "headers")] HttpRequest req)
    {
        var headers = JsonSerializer.Serialize(req.Headers, options);

        return await Task.FromResult(new OkObjectResult(headers));
    }

    [Function("GetQueries")]
    public async Task<IActionResult> GetQueries([HttpTrigger(AuthorizationLevel.Anonymous, "GET", Route = "queries")] HttpRequest req)
    {
        var queries = JsonSerializer.Serialize(req.Query, options);

        return await Task.FromResult(new OkObjectResult(queries));
    }

    [Function("GetCookies")]
    public async Task<IActionResult> GetCookies([HttpTrigger(AuthorizationLevel.Anonymous, "GET", Route = "cookies")] HttpRequest req)
    {
        var cookies = JsonSerializer.Serialize(req.Cookies, options);

        return await Task.FromResult(new OkObjectResult(cookies));
    }

    [Function("GetPayload")]
    public async Task<IActionResult> GetPayload([HttpTrigger(AuthorizationLevel.Anonymous, "POST", Route = "payload")] HttpRequest req)
    {
        var body = default(string);
        using (var reader = new StreamReader(req.Body))
        {
            body = await reader.ReadToEndAsync();
        }

        return await Task.FromResult(new OkObjectResult(body));
    }

    [Function("GetClientPrincipal")]
    public async Task<IActionResult> GetClientPrincipal([HttpTrigger(AuthorizationLevel.Anonymous, "GET", Route = "client-principal")] HttpRequest req)
    {
        var encoded = req.Headers["X-MS-CLIENT-PRINCIPAL"];
        if (string.IsNullOrWhiteSpace(encoded))
        {
            return new OkObjectResult("No client principal found");
        }

        var decoded = Convert.FromBase64String(encoded!);
        using var stream = new MemoryStream(decoded);
        var clientPrincipal = JsonSerializer.Serialize(await JsonSerializer.DeserializeAsync<object>(stream), options);

        return new OkObjectResult(clientPrincipal);
    }
}
