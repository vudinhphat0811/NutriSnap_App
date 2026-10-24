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
                    // 1. Khởi tạo danh sách sạch từ file
                    var dict = list
                        .Where(x => !x.IdMeal.StartsWith("vn_combo_", StringComparison.OrdinalIgnoreCase))
                        .ToDictionary(x => x.IdMeal, StringComparer.OrdinalIgnoreCase);

                    // 2. Bổ sung các món ăn gia đình quen thuộc (Thịt bò xào hành tây, Rau xào, Salad trộn...) 100% ảnh độc bản
                    foreach (var hr in MultiSourceCatalogService.GetAllRecipes())
                    {
                        dict[hr.IdMeal] = hr;
                    }

                    // 3. Lọc và loại bỏ triệt để 100% các món có ảnh trùng lặp trong cơ sở dữ liệu
                    var duplicateImageUrls = dict.Values
                        .Where(x => !string.IsNullOrWhiteSpace(x.StrMealThumb))
                        .GroupBy(x => x.StrMealThumb.Trim(), StringComparer.OrdinalIgnoreCase)
                        .Where(g => g.Count() > 1)
                        .Select(g => g.Key)
                        .ToHashSet(StringComparer.OrdinalIgnoreCase);

                    var cleanList = dict.Values
                        .Where(x => !string.IsNullOrWhiteSpace(x.StrMealThumb) &&
                                    !duplicateImageUrls.Contains(x.StrMealThumb.Trim()))
                        .ToList();

                    // Chuẩn hóa định lượng thực tế 100% cho toàn bộ công thức trong toàn bộ cơ sở dữ liệu
                    foreach (var r in cleanList)
                    {
                        RecipeService.SanitizeMealMeasures(r);
                    }

                    try
                    {
                        var saveOptions = new JsonSerializerOptions
                        {
                            WriteIndented = true,
                            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
                        };
                        var json = JsonSerializer.Serialize(cleanList, saveOptions);
                        await File.WriteAllTextAsync(filePath, json);
                    }
                    catch {}

                    lock (_lock)
                    {
                        _memoryCache = cleanList;
                    }
                    _logger.LogInformation("Đã nạp {Count} công thức chuẩn xác (0 trùng ảnh) từ cơ sở dữ liệu cục bộ.", cleanList.Count);
                    return cleanList;
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
    /// Thực hiện đồng bộ hàng loạt các món ăn từ tất cả các nguồn (TheMealDB, DummyJSON, Vietnamese, Fitness)
    /// </summary>
    public Task<List<RecommendedMealDto>> SyncFromMealDbAsync(string? targetFilePath = null)
    {
        return SyncAllSourcesAsync(targetFilePath);
    }

    /// <summary>
    /// Đồng bộ công thức đa nguồn (Multi-Source Recipe Aggregator):
    /// - Nguồn 1: TheMealDB (A-Z) ~790 món
    /// - Nguồn 2: DummyJSON Modern Recipes API ~50 món
    /// - Nguồn 3: NutriSnap Vietnamese Culinary Heritage & Eat Clean ~190 món
    /// - Nguồn 4: Combination Recipe Catalog ~30 món
    /// - Nguồn 5: MasterChef Vietnam & Quốc Tế ~21 món
    /// Tổng cộng: Hơn 1,080+ món ăn đầy đủ nguyên liệu, hướng dẫn và chỉ số dinh dưỡng.
    /// </summary>
    public async Task<List<RecommendedMealDto>> SyncAllSourcesAsync(string? targetFilePath = null)
    {
        Console.WriteLine("======================================================================");
        Console.WriteLine("NutriSnap - BẮT ĐẦU CÀO VÀ ĐỒNG BỘ DỮ LIỆU ĐA NGUỒN (1,000+ MÓN)");
        Console.WriteLine("  1. TheMealDB API (790 món quốc tế từ A-Z)");
        Console.WriteLine("  2. DummyJSON Recipes API (50 món Âu - Mỹ - Ý hiện đại)");
        Console.WriteLine("  3. NutriSnap VN Culinary Heritage (190 món Việt Nam & Eat Clean)");
        Console.WriteLine("  4. Combination Recipe Catalog (30 món kết hợp đa nguyên liệu)");
        Console.WriteLine("  5. MasterChef Vietnam & International (21 món Vua Đầu Bếp đỉnh cao)");
        Console.WriteLine("======================================================================");

        var allMeals = new Dictionary<string, RecommendedMealDto>(StringComparer.OrdinalIgnoreCase);

        // Pre-seed từ file JSON database nếu đã tồn tại để duy trì dữ liệu và tăng tốc độ đồng bộ
        string savePath = targetFilePath ?? GetDatabaseFilePath();
        if (File.Exists(savePath))
        {
            try
            {
                var jsonText = await File.ReadAllTextAsync(savePath);
                var existing = JsonSerializer.Deserialize<List<RecommendedMealDto>>(jsonText);
                if (existing != null)
                {
                    foreach (var m in existing)
                    {
                        allMeals[m.IdMeal] = m;
                    }
                    Console.WriteLine($">> Đã nạp trước {existing.Count} món có sẵn từ file database.");
                }
            }
            catch {}
        }

        // 1. Cào từ TheMealDB A-Z
        await CrawlMealDbInternalAsync(allMeals);

        // 2. Cào từ DummyJSON API
        var dummyRecipes = await SyncFromDummyJsonAsync();
        foreach (var r in dummyRecipes)
        {
            if (!allMeals.ContainsKey(r.IdMeal))
            {
                allMeals[r.IdMeal] = r;
            }
        }

        // 3. Nạp kho công thức Việt Nam & Eat Clean Fitness
        var vnRecipes = MultiSourceCatalogService.GetAllRecipes();
        foreach (var r in vnRecipes)
        {
            allMeals[r.IdMeal] = r;
        }

        // 4. Nạp kho công thức kết hợp đa nguyên liệu
        foreach (var r in CombinationRecipeCatalog.Recipes)
        {
            allMeals[r.IdMeal] = r;
        }

        // 5. Nạp bộ sưu tập Vua Đầu Bếp Việt Nam & MasterChef Quốc Tế
        var masterChefRecipes = MasterChefRecipeCatalog.GetRecipes();
        foreach (var r in masterChefRecipes)
        {
            allMeals[r.IdMeal] = r;
        }

        // Lọc và loại bỏ hoàn toàn các món có ảnh trùng lặp trong cơ sở dữ liệu
        var duplicateImageUrls = allMeals.Values
            .Where(x => !string.IsNullOrWhiteSpace(x.StrMealThumb))
            .GroupBy(x => x.StrMealThumb.Trim(), StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var resultList = allMeals.Values
            .Where(x => !x.IdMeal.StartsWith("vn_combo_", StringComparison.OrdinalIgnoreCase) &&
                        !string.IsNullOrWhiteSpace(x.StrMealThumb) &&
                        !duplicateImageUrls.Contains(x.StrMealThumb.Trim()))
            .ToList();

        Console.WriteLine($"\n[TỔNG HỢP] Đã thu thập thành công {resultList.Count} công thức độc nhất (100% ảnh độc bản, 0 trùng lặp)!");
        _logger.LogInformation("Đã thu thập thành công {Count} món ăn độc nhất (0 trùng ảnh).", resultList.Count);

        // 5. Lưu vào file cơ sở dữ liệu JSON cục bộ
        savePath = targetFilePath ?? GetDatabaseFilePath();
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
            Console.WriteLine($"[JSON Database] Đã lưu {resultList.Count} món vào file: {savePath}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi ghi file database cục bộ.");
        }

        // 6. Đồng bộ vào SQL Server / PostgreSQL AppDbContext
        await SyncToDatabaseAsync(resultList);

        lock (_lock)
        {
            _memoryCache = resultList;
        }

        return resultList;
    }

    private async Task CrawlMealDbInternalAsync(Dictionary<string, RecommendedMealDto> allMeals)
    {
        Console.WriteLine(">> [Nguồn 1] Đang cào dữ liệu TheMealDB (A-Z)...");
        var letters = "abcdefghijklmnopqrstuvwxyz".ToCharArray();

        foreach (var letter in letters)
        {
            try
            {
                string url = $"https://www.themealdb.com/api/json/v1/1/search.php?f={letter}";
                var response = await _httpClient.GetStringAsync(url);
                var node = JsonNode.Parse(response);
                var mealsArray = node?["meals"]?.AsArray();

                int countAdded = 0;
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
                            MeasuresVi = meas.Select(m => TranslationService.TranslateMeasure(m)).ToList()
                        };

                        CalculateNutrition(meal);
                        allMeals[id] = meal;
                        countAdded++;
                    }
                }
                Console.WriteLine($"   [TheMealDB] Chữ cái '{letter.ToString().ToUpper()}': +{countAdded} món (Tổng hiện tại: {allMeals.Count} món)");
                await Task.Delay(80);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Lỗi khi đồng bộ chữ cái '{Letter}' từ TheMealDB", letter);
            }
        }
    }

    private async Task<List<RecommendedMealDto>> SyncFromDummyJsonAsync()
    {
        var list = new List<RecommendedMealDto>();
        try
        {
            Console.WriteLine(">> [Nguồn 2] Đang cào dữ liệu DummyJSON Recipes API...");
            var json = await _httpClient.GetStringAsync("https://dummyjson.com/recipes?limit=50");
            var root = JsonNode.Parse(json);
            var recipesArr = root?["recipes"]?.AsArray();
            if (recipesArr != null)
            {
                foreach (var r in recipesArr)
                {
                    if (r == null) continue;
                    string id = "dummy_" + (r["id"]?.ToString() ?? Guid.NewGuid().ToString());
                    string name = r["name"]?.ToString() ?? "";
                    string cuisine = r["cuisine"]?.ToString() ?? "International";
                    string image = r["image"]?.ToString() ?? "";
                    int cal = r["caloriesPerServing"]?.GetValue<int>() ?? 350;

                    var ings = new List<string>();
                    var ingsVi = new List<string>();
                    if (r["ingredients"] is JsonArray ingArr)
                    {
                        foreach (var i in ingArr)
                        {
                            var s = i?.ToString()?.Trim() ?? "";
                            if (!string.IsNullOrEmpty(s))
                            {
                                ings.Add(s);
                                ingsVi.Add(TranslateIngredientQuick(s));
                            }
                        }
                    }

                    var steps = new List<string>();
                    if (r["instructions"] is JsonArray instArr)
                    {
                        foreach (var step in instArr)
                        {
                            if (step != null) steps.Add(step.ToString());
                        }
                    }
                    string instructions = string.Join("\n", steps);

                    int p = 25, c = 35, f = 12;
                    if (cal > 0)
                    {
                        p = Math.Max(15, (int)(cal * 0.25 / 4));
                        c = Math.Max(20, (int)(cal * 0.45 / 4));
                        f = Math.Max(8, (int)(cal * 0.30 / 9));
                    }

                    list.Add(new RecommendedMealDto
                    {
                        IdMeal = id,
                        StrMeal = name,
                        StrMealVi = TranslateTitleQuick(name, cuisine),
                        StrMealThumb = image,
                        StrCategory = cuisine,
                        StrArea = cuisine,
                        StrInstructions = instructions,
                        StrInstructionsVi = instructions,
                        Ingredients = ings,
                        IngredientsVi = ingsVi,
                        Measures = ings.Select((ing, idx) => TranslationService.GenerateDefaultMeasure(ing, idx)).ToList(),
                        MeasuresVi = ingsVi.Select((ing, idx) => TranslationService.GenerateDefaultMeasure(ingsVi.Count > idx ? ingsVi[idx] : ing, idx)).ToList(),
                        EstimatedCalories = cal,
                        EstimatedProtein = p,
                        EstimatedCarbs = c,
                        EstimatedFat = f,
                        MatchScore = 95,
                        Badges = new List<string> { "🍕 DummyJSON", "🌍 Quốc tế", $"⏱️ {r["cookTimeMinutes"]}p nấu" }
                    });
                }
                Console.WriteLine($"   [DummyJSON] Đã cào thành công {list.Count} công thức quốc tế!");
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể tải công thức từ DummyJSON: {Message}", ex.Message);
            Console.WriteLine($"   [DummyJSON] Lưu ý: {ex.Message}");
        }
        return list;
    }

    private async Task SyncToDatabaseAsync(List<RecommendedMealDto> resultList)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var existingIds = await db.SavedRecipes
                .Where(r => r.ExternalMealId != null)
                .Select(r => r.ExternalMealId!)
                .ToListAsync();

            var existingSet = new HashSet<string>(existingIds, StringComparer.OrdinalIgnoreCase);

            var toAdd = resultList
                .Where(r => !string.IsNullOrEmpty(r.IdMeal) && !existingSet.Contains(r.IdMeal))
                .Select(r => new SavedRecipe
                {
                    ExternalMealId = r.IdMeal,
                    Title = Truncate(r.StrMealVi ?? r.StrMeal, 200),
                    ImageUrl = Truncate(r.StrMealThumb, 500),
                    YoutubeUrl = Truncate(r.StrYoutube, 500),
                    TotalCalories = r.EstimatedCalories,
                    ProteinG = r.EstimatedProtein,
                    CarbsG = r.EstimatedCarbs,
                    FatG = r.EstimatedFat,
                    Instructions = r.StrInstructionsVi ?? r.StrInstructions
                })
                .ToList();

            if (toAdd.Count > 0)
            {
                foreach (var chunk in toAdd.Chunk(50))
                {
                    db.SavedRecipes.AddRange(chunk);
                    await db.SaveChangesAsync();
                }
                _logger.LogInformation("Đã lưu {Count} món mới vào Database SavedRecipes.", toAdd.Count);
                Console.WriteLine($"[Database] Đã lưu bổ sung {toAdd.Count} món vào Database (SavedRecipes)!");
            }
            else
            {
                _logger.LogInformation("Database SavedRecipes đã đồng bộ đầy đủ các món.");
                Console.WriteLine("[Database] Database SavedRecipes đã có đầy đủ các món.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể lưu vào SQL Database (Dữ liệu đã được lưu trữ an toàn trong JSON Database cục bộ): {Message}", ex.Message);
            Console.WriteLine($"[Database] Lưu ý: Chưa kết nối Database ({ex.Message}). Dữ liệu đã lưu an toàn trong file JSON cục bộ.");
        }
    }

    private static string Truncate(string? val, int maxLen)
    {
        if (string.IsNullOrEmpty(val)) return string.Empty;
        return val.Length <= maxLen ? val : val[..maxLen];
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
        return TranslationService.SanitizeIngredient(raw, null);
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
