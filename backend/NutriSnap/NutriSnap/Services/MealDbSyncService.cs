using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using NutriSnap.Data;
using NutriSnap.Models;

namespace NutriSnap.Services;

/// <summary>
/// Service đồng bộ và lưu trữ cục bộ công thức món ăn từ TheMealDB vào Database/JSON
/// Cho phép tìm kiếm và khớp ĐA NGUYÊN LIỆU (Multi-Ingredient Search) trên toàn bộ kho món ăn
/// mà không bị giới hạn bởi TheMealDB API miễn phí.
/// </summary>
public class MealDbSyncService
{
    private readonly HttpClient _httpClient;
    private readonly IWebHostEnvironment _env;
    private readonly TranslationService _translationService;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<MealDbSyncService> _logger;

    private static List<RecommendedMealDto>? _memoryCache = null;
    private static readonly object _lock = new();

    public MealDbSyncService(
        HttpClient httpClient,
        IWebHostEnvironment env,
        TranslationService translationService,
        IServiceScopeFactory scopeFactory,
        ILogger<MealDbSyncService> logger)
    {
        _httpClient = httpClient;
        _env = env;
        _translationService = translationService;
        _scopeFactory = scopeFactory;
        _logger = logger;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "NutriSnapApp/1.0");
    }

    /// <summary>
    /// Lấy danh sách toàn bộ món ăn đã lưu trong Database cục bộ.
    /// Nếu chưa có, tự động tải và đồng bộ từ TheMealDB (hơn 300+ món ăn đầy đủ nguyên liệu).
    /// </summary>
    public async Task<List<RecommendedMealDto>> GetOrSyncLocalRecipesAsync(bool forceRefresh = false)
    {
        if (!forceRefresh && _memoryCache != null && _memoryCache.Count > 50)
        {
            return _memoryCache;
        }

        string filePath = GetDatabaseFilePath();

        // 1. Đọc từ file JSON Database nếu đã tồn tại
        if (!forceRefresh && File.Exists(filePath))
        {
            try
            {
                var jsonText = await File.ReadAllTextAsync(filePath);
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var list = JsonSerializer.Deserialize<List<RecommendedMealDto>>(jsonText, options);
                if (list != null && list.Count > 50)
                {
                    lock (_lock)
                    {
                        _memoryCache = list;
                    }
                    _logger.LogInformation("Đã nạp {Count} công thức TheMealDB từ cơ sở dữ liệu cục bộ.", list.Count);
                    return list;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể đọc file database cục bộ, tiến hành tải mới từ TheMealDB.");
            }
        }

        // 2. Tải và đồng bộ từ TheMealDB với các chữ cái phổ biến nhất
        return await SyncFromMealDbAsync(filePath);
    }

    /// <summary>
    /// Thực hiện đồng bộ hàng loạt các món ăn từ TheMealDB với đầy đủ 20 nguyên liệu
    /// </summary>
    public async Task<List<RecommendedMealDto>> SyncFromMealDbAsync(string? targetFilePath = null)
    {
        _logger.LogInformation("Bắt đầu đồng bộ cơ sở dữ liệu món ăn TheMealDB...");
        var letters = new[] { 'b', 'c', 's', 'p', 't', 'm', 'e', 'f' };
        var allMeals = new Dictionary<string, RecommendedMealDto>(StringComparer.OrdinalIgnoreCase);

        foreach (var letter in letters)
        {
            try
            {
                string url = $"https://www.themealdb.com/api/json/v1/1/search.php?f={letter}";
                var response = await _httpClient.GetStringAsync(url);
                var node = JsonNode.Parse(response);
                var mealsArray = node?["meals"]?.AsArray();

                if (mealsArray != null)
                {
                    foreach (var item in mealsArray)
                    {
                        if (item == null) continue;
                        string id = item["idMeal"]?.ToString() ?? "";
                        if (string.IsNullOrEmpty(id) || allMeals.ContainsKey(id)) continue;

                        var ings = new List<string>();
                        var meas = new List<string>();
                        var ingsVi = new List<string>();

                        for (int i = 1; i <= 20; i++)
                        {
                            var ing = item[$"strIngredient{i}"]?.ToString()?.Trim();
                            var mea = item[$"strMeasure{i}"]?.ToString()?.Trim();
                            if (!string.IsNullOrEmpty(ing))
                            {
                                ings.Add(ing);
                                meas.Add(mea ?? "");
                                ingsVi.Add(TranslateIngredientQuick(ing));
                            }
                        }

                        string title = item["strMeal"]?.ToString() ?? "";
                        string category = item["strCategory"]?.ToString() ?? "";

                        var meal = new RecommendedMealDto
                        {
                            IdMeal = id,
                            StrMeal = title,
                            StrMealVi = TranslateTitleQuick(title, category),
                            StrMealThumb = item["strMealThumb"]?.ToString() ?? "",
                            StrCategory = category,
                            StrArea = item["strArea"]?.ToString(),
                            StrInstructions = item["strInstructions"]?.ToString(),
                            StrYoutube = item["strYoutube"]?.ToString(),
                            Ingredients = ings,
                            Measures = meas,
                            IngredientsVi = ingsVi,
                            MeasuresVi = meas
                        };

                        CalculateNutrition(meal);
                        allMeals[id] = meal;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Lỗi khi đồng bộ chữ cái '{Letter}' từ TheMealDB", letter);
            }
        }

        var resultList = allMeals.Values.ToList();
        _logger.LogInformation("Đã thu thập thành công {Count} món ăn đầy đủ nguyên liệu từ TheMealDB.", resultList.Count);

        // 3. Lưu vào file cơ sở dữ liệu JSON cục bộ
        string savePath = targetFilePath ?? GetDatabaseFilePath();
        try
        {
            var dir = Path.GetDirectoryName(savePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            };
            var json = JsonSerializer.Serialize(resultList, options);
            await File.WriteAllTextAsync(savePath, json);
            _logger.LogInformation("Đã lưu cơ sở dữ liệu công thức vào: {Path}", savePath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi ghi file database cục bộ.");
        }

        // 4. Đồng bộ vào SQL Server AppDbContext nếu kết nối thành công
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var existingIds = await db.SavedRecipes
                    .Where(r => r.ExternalMealId != null)
                    .Select(r => r.ExternalMealId)
                    .ToListAsync();

                var toAdd = resultList
                    .Where(r => !existingIds.Contains(r.IdMeal))
                    .Take(150)
                    .Select(r => new SavedRecipe
                    {
                        ExternalMealId = r.IdMeal,
                        Title = r.StrMealVi ?? r.StrMeal,
                        ImageUrl = r.StrMealThumb,
                        YoutubeUrl = r.StrYoutube,
                        TotalCalories = r.EstimatedCalories,
                        ProteinG = r.EstimatedProtein,
                        CarbsG = r.EstimatedCarbs,
                        FatG = r.EstimatedFat,
                        Instructions = r.StrInstructionsVi ?? r.StrInstructions
                    })
                    .ToList();

                if (toAdd.Count > 0)
                {
                    db.SavedRecipes.AddRange(toAdd);
                    await db.SaveChangesAsync();
                    _logger.LogInformation("Đã lưu {Count} món vào SQL Server SavedRecipes.", toAdd.Count);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Không thể lưu vào SQL Server (sử dụng JSON Database cục bộ): {Message}", ex.Message);
            }
        });

        lock (_lock)
        {
            _memoryCache = resultList;
        }

        return resultList;
    }

    private string GetDatabaseFilePath()
    {
        return Path.Combine(_env.ContentRootPath, "Data", "mealdb_recipes.json");
    }

    private void CalculateNutrition(RecommendedMealDto meal)
    {
        string name = meal.StrMeal.ToLower();
        string cat = (meal.StrCategory ?? "").ToLower();
        int seed = Math.Abs((meal.IdMeal ?? "1").GetHashCode()) % 40;

        if (cat.Contains("chicken") || name.Contains("chicken") || name.Contains("gà"))
        {
            meal.EstimatedCalories = 380 + (seed * 5);
            meal.EstimatedProtein = 32 + (seed % 16);
            meal.EstimatedCarbs = 14 + (seed % 20);
            meal.EstimatedFat = 10 + (seed % 10);
        }
        else if (cat.Contains("beef") || name.Contains("beef") || name.Contains("steak") || name.Contains("bò"))
        {
            meal.EstimatedCalories = 460 + (seed * 6);
            meal.EstimatedProtein = 34 + (seed % 18);
            meal.EstimatedCarbs = 16 + (seed % 20);
            meal.EstimatedFat = 18 + (seed % 14);
        }
        else if (cat.Contains("seafood") || name.Contains("fish") || name.Contains("salmon") || name.Contains("prawn") || name.Contains("cá"))
        {
            meal.EstimatedCalories = 320 + (seed * 4);
            meal.EstimatedProtein = 28 + (seed % 14);
            meal.EstimatedCarbs = 12 + (seed % 18);
            meal.EstimatedFat = 9 + (seed % 9);
        }
        else if (cat.Contains("vegetarian") || name.Contains("salad") || name.Contains("vegetable") || name.Contains("chay"))
        {
            meal.EstimatedCalories = 260 + (seed * 4);
            meal.EstimatedProtein = 14 + (seed % 12);
            meal.EstimatedCarbs = 36 + (seed % 24);
            meal.EstimatedFat = 7 + (seed % 8);
        }
        else if (cat.Contains("pasta") || name.Contains("pasta") || name.Contains("spaghetti") || name.Contains("mì"))
        {
            meal.EstimatedCalories = 480 + (seed * 5);
            meal.EstimatedProtein = 18 + (seed % 12);
            meal.EstimatedCarbs = 64 + (seed % 24);
            meal.EstimatedFat = 12 + (seed % 12);
        }
        else
        {
            meal.EstimatedCalories = 370 + (seed * 5);
            meal.EstimatedProtein = 24 + (seed % 14);
            meal.EstimatedCarbs = 28 + (seed % 20);
            meal.EstimatedFat = 12 + (seed % 10);
        }
    }

    private static string TranslateIngredientQuick(string raw)
    {
        string lower = raw.Trim().ToLower();
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["chicken stock"] = "Nước dùng gà",
            ["chicken broth"] = "Nước hầm gà",
            ["chicken bouillon"] = "Hạt nêm gà",
            ["beef stock"] = "Nước dùng bò",
            ["beef broth"] = "Nước hầm bò",
            ["beef bouillon"] = "Hạt nêm bò",
            ["fish sauce"] = "Nước mắm",
            ["oyster sauce"] = "Dầu hào",
            ["soy sauce"] = "Nước tương",
            ["minced beef"] = "Thịt bò băm",
            ["beef steak"] = "Thịt bò bít tết",
            ["beef"] = "Thịt bò",
            ["chicken breast"] = "Ức gà",
            ["chicken thighs"] = "Đùi gà",
            ["chicken"] = "Thịt gà",
            ["pork chops"] = "Sườn heo",
            ["pork"] = "Thịt heo",
            ["bacon"] = "Thịt xông khói",
            ["egg"] = "Trứng",
            ["eggs"] = "Trứng gà",
            ["tomato puree"] = "Sốt cà chua",
            ["tomato paste"] = "Cà chua cô đặc",
            ["tomato"] = "Cà chua",
            ["tomatoes"] = "Cà chua",
            ["broccoli"] = "Bông cải xanh",
            ["carrot"] = "Cà rốt",
            ["carrots"] = "Cà rốt",
            ["onion"] = "Hành tây",
            ["onions"] = "Hành tây",
            ["red onion"] = "Hành tím",
            ["garlic clove"] = "Tép tỏi",
            ["garlic"] = "Tỏi",
            ["ginger"] = "Gừng",
            ["mushroom"] = "Nấm tươi",
            ["mushrooms"] = "Nấm",
            ["potato"] = "Khoai tây",
            ["potatoes"] = "Khoai tây",
            ["salmon"] = "Cá hồi",
            ["fish"] = "Cá tươi",
            ["prawns"] = "Tôm tươi",
            ["shrimp"] = "Tôm",
            ["tofu"] = "Đậu phụ",
            ["rice"] = "Gạo / Cơm",
            ["pasta"] = "Mì Ý / Pasta",
            ["spaghetti"] = "Mì Ý",
            ["olive oil"] = "Dầu ô liu",
            ["butter"] = "Bơ",
            ["cheese"] = "Phô mai",
            ["milk"] = "Sữa tươi",
            ["sugar"] = "Đường",
            ["salt"] = "Muối",
            ["black pepper"] = "Tiêu đen",
            ["pepper"] = "Tiêu"
        };

        foreach (var entry in map.OrderByDescending(x => x.Key.Length))
        {
            if (lower == entry.Key || lower.Contains(entry.Key))
            {
                return entry.Value;
            }
        }
        return raw;
    }

    private static string TranslateTitleQuick(string title, string category)
    {
        string t = title;
        if (t.Contains("Beef and Broccoli", StringComparison.OrdinalIgnoreCase)) return "Bò Xào Bông Cải Xanh";
        if (t.Contains("Beef Bourguignon", StringComparison.OrdinalIgnoreCase)) return "Bò Hầm Rượu Vang Kiểu Pháp";
        if (t.Contains("Beef Stroganoff", StringComparison.OrdinalIgnoreCase)) return "Bò Xào Sốt Kem Nấm Stroganoff";
        if (t.Contains("Beef Sunday Roast", StringComparison.OrdinalIgnoreCase)) return "Thịt Bò Nướng Rau Củ";
        if (t.Contains("Spaghetti Bolognese", StringComparison.OrdinalIgnoreCase)) return "Mì Ý Sốt Bò Băm Cà Chua";
        if (t.Contains("Chicken Alfredo", StringComparison.OrdinalIgnoreCase)) return "Mì Ý Gà Sốt Kem Alfredo";
        if (t.Contains("Chicken Breast", StringComparison.OrdinalIgnoreCase)) return "Ức Gà Nướng Thảo Mộc";
        if (t.Contains("Chicken Fajita", StringComparison.OrdinalIgnoreCase)) return "Gà Xào Ớt Chuông Hành Tây";
        if (t.Contains("Chicken and Mushroom", StringComparison.OrdinalIgnoreCase)) return "Gà Hầm Nấm Tươi";
        if (t.Contains("Pork Chops", StringComparison.OrdinalIgnoreCase)) return "Sườn Heo Nướng Sốt Táo";
        if (t.Contains("Salmon", StringComparison.OrdinalIgnoreCase)) return "Cá Hồi Áp Chảo Rau Củ";
        if (t.Contains("Broccoli Soup", StringComparison.OrdinalIgnoreCase)) return "Súp Bông Cải Xanh Thanh Đạm";
        if (t.Contains("Tomato Soup", StringComparison.OrdinalIgnoreCase)) return "Súp Cà Chua Thơm Dịu";

        return title;
    }
}
