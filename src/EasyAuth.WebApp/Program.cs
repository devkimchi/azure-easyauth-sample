using EasyAuth.Components.Services;
using EasyAuth.Handlers;
using EasyAuth.WebApp.Components;
using EasyAuth.WebApp.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
                .AddInteractiveServerComponents();

builder.Services.AddHttpContextAccessor();

builder.Services.AddHttpClient<IRequestService, RequestService>((sp, client) =>
{
    var httpContextAccessor = sp.GetRequiredService<IHttpContextAccessor>();
    var httpContext = httpContextAccessor.HttpContext;
    var request = httpContext!.Request;
    var baseUrl = $"{request.Scheme}://{request.Host}";

    client.BaseAddress = new Uri(baseUrl);
});

builder.Services.AddAuthentication(EasyAuthAuthenticationHandler.EASY_AUTH_SCHEME_NAME)
                .AddAzureEasyAuthHandler();
builder.Services.AddAuthorization();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseAntiforgery();

app.MapStaticAssets();

app.MapRazorComponents<App>()
   .AddInteractiveServerRenderMode();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
