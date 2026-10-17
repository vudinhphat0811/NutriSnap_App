using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using NutriSnap.Data;
using NutriSnap.Models;
using NutriSnap.Services;

// Cho phép Npgsql hỗ trợ mọi kiểu DateTime (không bắt buộc UTC)
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

LoadDotEnv();

var builder = WebApplication.CreateBuilder(args);

// 1. Cấu hình Database (Tự động nhận diện PostgreSQL hoặc SQL Server)
var rawConn = builder.Configuration["DATABASE_URL"]
    ?? builder.Configuration["POSTGRES_CONNECTION"]
    ?? builder.Configuration["DEFAULT_CONNECTION"]
    ?? builder.Configuration.GetConnectionString("DefaultConnection")
    ?? Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
    ?? "";

builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (IsPostgres(rawConn))
    {
        var pgConn = ParsePostgresConnectionString(rawConn);
        options.UseNpgsql(pgConn);
    }
    else
    {
        options.UseSqlServer(rawConn);
    }
});

// 2. Kích hoạt Identity (chỉ dùng UserManager / SignInManager)
builder.Services.AddIdentity<AppUser, IdentityRole<int>>(options =>
{
    options.User.RequireUniqueEmail = true;
    options.Password.RequireDigit = false;
    options.Password.RequiredLength = 6;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequireUppercase = false;

    options.SignIn.RequireConfirmedAccount = false;
    options.SignIn.RequireConfirmedEmail = false;
})
.AddEntityFrameworkStores<AppDbContext>()
.AddDefaultTokenProviders();

// 3. Cấu hình JWT Authentication
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = builder.Configuration["JWT_SECRET"]
    ?? Environment.GetEnvironmentVariable("JWT_SECRET")
    ?? jwtSettings["SecretKey"]
    ?? "NutriSnap@SuperSecretKey_ChangeInProduction_2026!";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization();

// 4. Đăng ký các Services
builder.Services.AddTransient<IEmailSender<AppUser>, EmailSender>();
builder.Services.AddScoped<JwtService>();
builder.Services.AddHttpClient<MealDbSyncService>();
builder.Services.AddHttpClient<RecipeService>();
builder.Services.AddHttpClient<RecipeCrawlerService>();
builder.Services.AddHttpClient<TranslationService>();
builder.Services.AddHttpClient<AiVisionService>();
builder.Services.AddMemoryCache();

// 5. Cấu hình CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// 6. Cấu hình Swagger với hỗ trợ JWT Bearer
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Nhập Access Token vào đây: "
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// Tự động kiểm tra và khởi tạo Database Schema (Bảng Users, Roles, Logs...) khi chạy
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();
    }
    catch (Exception ex)
    {
        var log = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        log.LogWarning("Khởi tạo cấu trúc Database schema: {Message}", ex.Message);
    }
}

// 7. Pipeline xử lý Request
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseStaticFiles();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// Tự động nạp trước cơ sở dữ liệu TheMealDB cục bộ chạy nền
_ = Task.Run(async () =>
{
    try
    {
        using var scope = app.Services.CreateScope();
        var sync = scope.ServiceProvider.GetRequiredService<MealDbSyncService>();
        await sync.GetOrSyncLocalRecipesAsync(false);
    }
    catch (Exception ex)
    {
        var log = app.Services.GetRequiredService<ILogger<Program>>();
        log.LogWarning("Không thể tải trước TheMealDB cục bộ: {Message}", ex.Message);
    }
});

app.Run();

// ==========================================
// HÀM HỖ TRỢ TỰ ĐỘNG ĐỌC FILE .ENV CỦA DỰ ÁN
// ==========================================
static void LoadDotEnv()
{
    var current = new DirectoryInfo(Directory.GetCurrentDirectory());
    FileInfo? target = null;
    while (current != null)
    {
        var path = Path.Combine(current.FullName, ".env");
        if (File.Exists(path))
        {
            target = new FileInfo(path);
            break;
        }
        current = current.Parent;
    }

    if (target == null)
    {
        var baseDir = new DirectoryInfo(AppContext.BaseDirectory);
        while (baseDir != null)
        {
            var path = Path.Combine(baseDir.FullName, ".env");
            if (File.Exists(path))
            {
                target = new FileInfo(path);
                break;
            }
            baseDir = baseDir.Parent;
        }
    }

    if (target != null && target.Exists)
    {
        foreach (var line in File.ReadAllLines(target.FullName))
        {
            var trimmed = line.Trim();
            if (string.IsNullOrWhiteSpace(trimmed) || trimmed.StartsWith("#")) continue;
            var idx = trimmed.IndexOf('=');
            if (idx > 0)
            {
                var key = trimmed.Substring(0, idx).Trim();
                var val = trimmed.Substring(idx + 1).Trim();
                if ((val.StartsWith("\"") && val.EndsWith("\"")) || (val.StartsWith("'") && val.EndsWith("'")))
                {
                    val = val.Substring(1, val.Length - 2);
                }
                Environment.SetEnvironmentVariable(key, val);
            }
        }
    }
}

static bool IsPostgres(string conn)
{
    if (string.IsNullOrWhiteSpace(conn)) return false;
    var lower = conn.ToLowerInvariant();
    return lower.StartsWith("postgres://") ||
           lower.StartsWith("postgresql://") ||
           lower.Contains("host=") ||
           lower.Contains("sslmode=") ||
           lower.Contains("port=5432") ||
           lower.Contains("port=6543");
}

static string ParsePostgresConnectionString(string raw)
{
    if (string.IsNullOrWhiteSpace(raw)) return raw;

    // Chuyển định dạng URL: postgresql://user:password@host:port/database
    if (raw.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) ||
        raw.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        try
        {
            var uri = new Uri(raw);
            var userInfo = uri.UserInfo.Split(':');
            var user = Uri.UnescapeDataString(userInfo[0]);
            var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
            var port = uri.Port > 0 ? uri.Port : 5432;
            var db = uri.AbsolutePath.TrimStart('/');

            return $"Host={uri.Host};Port={port};Database={db};Username={user};Password={pass};SSL Mode=Require;Trust Server Certificate=true;";
        }
        catch
        {
            return raw;
        }
    }

    // Đảm bảo có SSL Mode nếu kết nối cloud
    if (!raw.Contains("SSL Mode", StringComparison.OrdinalIgnoreCase) && !raw.Contains("sslmode", StringComparison.OrdinalIgnoreCase))
    {
        raw = raw.TrimEnd(';') + ";SSL Mode=Require;Trust Server Certificate=true;";
    }

    return raw;
}
