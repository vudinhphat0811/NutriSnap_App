using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Caching.Memory;
using NutriSnap.Models;

namespace NutriSnap.Services;

public class RecipeService
{
    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly TranslationService _translationService;
    private readonly MealDbSyncService _mealDbSyncService;
    private readonly ILogger<RecipeService> _logger;

    public RecipeService(
        HttpClient httpClient,
        IMemoryCache cache,
        TranslationService translationService,
        MealDbSyncService mealDbSyncService,
        ILogger<RecipeService> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
        _translationService = translationService;
        _mealDbSyncService = mealDbSyncService;
        _logger = logger;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "NutriSnapApp/1.0");
    }

    /// 1. Lấy món ngẫu nhiên cho tính năng lắc điện thoại (hỗ trợ dịch thuật và thuật toán tính điểm)
    public async Task<RecommendedMealDto?> GetRandomMealAsync(string lang = "vi")
    {
        try
        {
            var res = await _httpClient.GetStringAsync("https://www.themealdb.com/api/json/v1/1/random.php");
            var node = JsonNode.Parse(res);
            var rawMeal = node?["meals"]?[0]?.AsObject();
            if (rawMeal == null) return null;

            string idMeal = rawMeal["idMeal"]?.ToString() ?? "";
            if (string.IsNullOrEmpty(idMeal)) return null;

            var mealDto = await GetMealDetailAsync(idMeal, lang);
            if (mealDto != null)
            {
                // Thêm huy hiệu lắc rớt món may mắn
                var badges = mealDto.Badges.ToList();
                badges.Insert(0, lang == "vi" ? "🎲 Món lắc may mắn" : "🎲 Lucky Shake");
                mealDto.Badges = badges;
                mealDto.MatchScore = new Random().Next(88, 99);
            }
            return mealDto;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy món ngẫu nhiên cho tính năng lắc");
            return null;
        }
    }

    /// 2. THUẬT TOÁN GỢI Ý MÓN ĂN & XOAY VÒNG THEO NGÀY (Backend Recommendation Algorithm)
    /// Đáp ứng tiêu chí người dùng:
    /// - Tính toán điểm phù hợp (Match Score) dựa trên Goal, Diet, Calo còn lại.
    /// - Mỗi ngày có một bộ thực đơn gợi ý khác nhau, trong đó trùng 1 - 2 món với ngày hôm trước.
    /// - Mỗi lần reload / refresh (refreshCount) sẽ đưa ra các món mới mẻ phù hợp tiếp theo.
    public async Task<List<RecommendedMealDto>> GetDailyRecommendationsAsync(RecommendationRequest req)
    {
        // Xác định danh mục phù hợp theo Chế độ ăn (DietType) hoặc Danh mục người dùng chọn
        List<string> categories = new();
        if (!string.IsNullOrWhiteSpace(req.Category))
        {
            categories.Add(req.Category);
        }
        else
        {
            switch (req.DietType)
            {
                case "Vegetarian":
                    categories.AddRange(new[] { "Vegetarian", "Vegan", "Side" });
                    break;
                case "LowCarb":
                    categories.AddRange(new[] { "Seafood", "Chicken" });
                    break;
                case "HighProtein":
                    categories.AddRange(new[] { "Chicken", "Beef" });
                    break;
                case "Balanced":
                default:
                    categories.AddRange(new[] { "Chicken", "Seafood", "Pasta", "Vegetarian" });
                    break;
            }
        }

        // Tải danh sách ứng viên món ăn
        var candidateMeals = new List<RecommendedMealDto>();
        foreach (var cat in categories)
        {
            var meals = await GetCandidateMealsByCategoryAsync(cat);
            candidateMeals.AddRange(meals);
        }

        // Nếu là Chế độ ăn chay (Vegetarian): TUYỆT ĐỐI LOẠI BỎ 100% CÁC MÓN THỊT / CÁ / HẢI SẢN
        if (req.DietType.Equals("Vegetarian", StringComparison.OrdinalIgnoreCase))
        {
            candidateMeals.RemoveAll(m => IsMeatRecipe(m));

            // Đồng thời nạp toàn bộ các món chay đặc sắc từ CombinationRecipeCatalog
            foreach (var r in CombinationRecipeCatalog.Recipes)
            {
                if (!IsMeatRecipe(r) && !candidateMeals.Any(x => x.IdMeal == r.IdMeal))
                {
                    candidateMeals.Add(r);
                }
            }
        }

        // Lọc trùng theo IdMeal
        candidateMeals = candidateMeals
            .GroupBy(m => m.IdMeal)
            .Select(g => g.First())
            .ToList();

        if (candidateMeals.Count == 0)
        {
            return new List<RecommendedMealDto>();
        }

        // Tính toán dinh dưỡng, điểm phù hợp MatchScore và Gắn Badges cho từng món
        foreach (var meal in candidateMeals)
        {
            CalculateNutrition(meal);
            meal.MatchScore = CalculateMatchScore(meal, req.Goal, req.DietType, req.RemainingCalories);
            meal.Badges = GenerateBadges(meal, req.RemainingCalories);
        }

        // Sắp xếp điểm phù hợp từ cao xuống thấp
        var sortedByScore = candidateMeals
            .OrderByDescending(m => m.MatchScore)
            .ToList();

        // Áp dụng thuật toán xoay vòng theo ngày và lượt refresh
        DateTime targetDate = DateTime.TryParse(req.Date, out var parsedDate) ? parsedDate.Date : DateTime.UtcNow.Date;
        int dayOfYear = targetDate.DayOfYear;

        var rotatedList = ApplyDailyRotationAlgorithm(sortedByScore, req.Limit, dayOfYear, req.RefreshCount);

        // Tự động dịch tên món sang Tiếng Việt cho danh sách trả về
        foreach (var meal in rotatedList)
        {
            meal.StrMealVi = await _translationService.TranslateAsync(meal.StrMeal, "vi", "en");
        }

        return rotatedList;
    }

    /// <summary>
    /// Lấy chi tiết món ăn đầy đủ và tự động dịch 100% sang Tiếng Việt bằng TranslationService
    /// </summary>
    public async Task<RecommendedMealDto?> GetMealDetailAsync(string idMeal, string lang = "vi")
    {
        string cacheKey = $"meal_detail_{idMeal}_{lang}";
        if (_cache.TryGetValue(cacheKey, out RecommendedMealDto? cached) && cached != null)
        {
            return cached;
        }

        try
        {
            string url = $"https://www.themealdb.com/api/json/v1/1/lookup.php?i={idMeal}";
            var response = await _httpClient.GetStringAsync(url);
            var node = JsonNode.Parse(response);
            var rawMeal = node?["meals"]?[0]?.AsObject();
            if (rawMeal == null) return null;

            var ings = new List<string>();
            var meas = new List<string>();

            for (int i = 1; i <= 20; i++)
            {
                var ing = rawMeal[$"strIngredient{i}"]?.ToString()?.Trim();
                var mea = rawMeal[$"strMeasure{i}"]?.ToString()?.Trim();
                if (!string.IsNullOrEmpty(ing))
                {
                    ings.Add(ing);
                    meas.Add(mea ?? "");
                }
            }

            var meal = new RecommendedMealDto
            {
                IdMeal = rawMeal["idMeal"]?.ToString() ?? idMeal,
                StrMeal = rawMeal["strMeal"]?.ToString() ?? "",
                StrMealThumb = rawMeal["strMealThumb"]?.ToString() ?? "",
                StrCategory = rawMeal["strCategory"]?.ToString(),
                StrArea = rawMeal["strArea"]?.ToString(),
                StrInstructions = rawMeal["strInstructions"]?.ToString(),
                StrYoutube = rawMeal["strYoutube"]?.ToString(),
                Ingredients = ings,
                Measures = meas,
            };

            CalculateNutrition(meal);

            if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase))
            {
                meal.StrMealVi = await _translationService.TranslateAsync(meal.StrMeal, "vi", "en");
                if (!string.IsNullOrEmpty(meal.StrInstructions))
                {
                    meal.StrInstructionsVi = await _translationService.TranslateAsync(meal.StrInstructions, "vi", "en");
                }
                meal.IngredientsVi = await _translationService.TranslateBatchAsync(meal.Ingredients, "vi", "en");
                meal.MeasuresVi = await _translationService.TranslateBatchAsync(meal.Measures, "vi", "en");
            }

            _cache.Set(cacheKey, meal, TimeSpan.FromDays(7));
            return meal;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy chi tiết món {IdMeal}", idMeal);
            return null;
        }
    }

    /// Lấy danh sách món theo danh mục (có Cache 1 giờ để tăng tốc độ phản hồi)
    private async Task<List<RecommendedMealDto>> GetCandidateMealsByCategoryAsync(string category)
    {
        string cacheKey = $"mealdb_cat_{category.ToLower()}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cached) && cached != null)
        {
            return cached;
        }

        var list = new List<RecommendedMealDto>();
        try
        {
            string url = $"https://www.themealdb.com/api/json/v1/1/filter.php?c={Uri.EscapeDataString(category)}";
            var response = await _httpClient.GetStringAsync(url);
            var node = JsonNode.Parse(response);
            var mealsArray = node?["meals"]?.AsArray();

            if (mealsArray != null)
            {
                foreach (var item in mealsArray)
                {
                    if (item == null) continue;
                    list.Add(new RecommendedMealDto
                    {
                        IdMeal = item["idMeal"]?.ToString() ?? "",
                        StrMeal = item["strMeal"]?.ToString() ?? "",
                        StrMealThumb = item["strMealThumb"]?.ToString() ?? "",
                        StrCategory = category
                    });
                }
            }

            _cache.Set(cacheKey, list, TimeSpan.FromHours(1));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy danh mục {Category} từ TheMealDB", category);
        }

        return list;
    }

    /// Tính toán dinh dưỡng sát thực tế dựa trên danh mục, tên món và seed idMeal
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

    /// Thuật toán chấm điểm phù hợp (Match Score %: 55% - 98%)
    private int CalculateMatchScore(RecommendedMealDto meal, string goal, string dietType, int remainingCal)
    {
        double score = 72.0;

        // 1. Theo Mục tiêu hình thể
        switch (goal)
        {
            case "LoseWeight":
                if (meal.EstimatedCalories <= 420) score += 15;
                else if (meal.EstimatedCalories <= 520) score += 8;
                else if (meal.EstimatedCalories > 650) score -= 15;

                if (meal.EstimatedProtein >= 28) score += 6;
                if (meal.EstimatedFat <= 15) score += 4;
                break;

            case "GainWeight":
                if (meal.EstimatedCalories >= 520) score += 15;
                else if (meal.EstimatedCalories < 380) score -= 10;

                if (meal.EstimatedProtein >= 32) score += 10;
                if (meal.EstimatedCarbs >= 35) score += 5;
                break;

            case "Maintain":
            default:
                if (meal.EstimatedCalories >= 400 && meal.EstimatedCalories <= 580) score += 12;
                else score += 4;
                if (meal.EstimatedProtein >= 22) score += 6;
                break;
        }

        // 2. Theo Chế độ ăn ưa thích
        switch (dietType)
        {
            case "HighProtein":
                if (meal.EstimatedProtein >= 35) score += 15;
                else if (meal.EstimatedProtein >= 25) score += 8;
                else if (meal.EstimatedProtein < 16) score -= 12;
                break;

            case "LowCarb":
                if (meal.EstimatedCarbs <= 20) score += 15;
                else if (meal.EstimatedCarbs <= 32) score += 8;
                else if (meal.EstimatedCarbs > 55) score -= 12;
                break;

            case "Vegetarian":
                if (IsMeatRecipe(meal))
                {
                    return 0; // Tuyệt đối 0 điểm cho món thịt khi ăn chay
                }
                string c = (meal.StrCategory ?? "").ToLower();
                string n = meal.StrMeal.ToLower();
                if (c.Contains("vegetarian") || c.Contains("vegan") || c.Contains("side") || n.Contains("salad") || n.Contains("vegetable") || n.Contains("chay"))
                {
                    score += 20;
                }
                break;

            case "Balanced":
            default:
                if (meal.EstimatedProtein >= 20 && meal.EstimatedCarbs >= 20) score += 10;
                break;
        }

        // 3. Theo Calo còn lại trong ngày
        if (remainingCal > 0)
        {
            if (meal.EstimatedCalories <= remainingCal)
            {
                score += 6;
                double ratio = (double)meal.EstimatedCalories / remainingCal;
                if (ratio >= 0.35 && ratio <= 0.85) score += 5;
            }
            else
            {
                score -= 10;
            }
        }

        return Math.Clamp((int)Math.Round(score), 55, 98);
    }

    private List<string> GenerateBadges(RecommendedMealDto meal, int remainingCal)
    {
        var badges = new List<string>();
        if (meal.EstimatedProtein >= 30) badges.Add("HighProtein");
        if (meal.EstimatedCalories <= 420) badges.Add("LowCal");
        if (meal.EstimatedCarbs <= 20) badges.Add("LowCarb");
        if (remainingCal > 0 && meal.EstimatedCalories <= remainingCal) badges.Add("FitsTarget");
        return badges;
    }

    /// Thuật toán xoay vòng theo ngày:
    /// - Giữ lại 1 - 2 món trùng khớp từ ngày hôm trước (dayOfYear - 1)
    /// - Các vị trí còn lại chọn món mới mẻ dựa trên seed ngày hiện tại (dayOfYear)
    /// - Khi người dùng bấm reload / refresh, tăng refreshCount để xoay sang các món kế tiếp
    private List<RecommendedMealDto> ApplyDailyRotationAlgorithm(
        List<RecommendedMealDto> sortedMeals,
        int limit,
        int dayOfYear,
        int refreshCount)
    {
        if (sortedMeals.Count <= limit)
        {
            return sortedMeals;
        }

        var result = new List<RecommendedMealDto>();
        var usedIds = new HashSet<string>();

        // 1. Chọn 1 hoặc 2 món trùng với ngày hôm trước (dayOfYear - 1) từ top 10 món phù hợp nhất
        int topPoolSize = Math.Min(10, sortedMeals.Count);
        int overlapCount = limit <= 4 ? 1 : 2;

        int yesterdaySeed1 = Math.Abs((dayOfYear - 1) * 7) % topPoolSize;
        var overlapMeal1 = sortedMeals[yesterdaySeed1];
        result.Add(overlapMeal1);
        usedIds.Add(overlapMeal1.IdMeal);

        if (overlapCount > 1)
        {
            int yesterdaySeed2 = Math.Abs((dayOfYear - 1) * 13 + 3) % topPoolSize;
            if (yesterdaySeed2 == yesterdaySeed1)
            {
                yesterdaySeed2 = (yesterdaySeed1 + 1) % topPoolSize;
            }
            var overlapMeal2 = sortedMeals[yesterdaySeed2];
            if (!usedIds.Contains(overlapMeal2.IdMeal))
            {
                result.Add(overlapMeal2);
                usedIds.Add(overlapMeal2.IdMeal);
            }
        }

        // 2. Chọn các món còn lại: Kết hợp giữa điểm số cao và hàm xoay vòng theo ngày + lượt refresh
        // Điều này đảm bảo:
        // - Ngày hôm nay khác ngày hôm trước
        // - Mỗi lần reload/refresh người dùng nhận được các món mới
        // - Luôn ưu tiên các món có MatchScore cao
        var remainingCandidates = sortedMeals
            .Where(m => !usedIds.Contains(m.IdMeal))
            .Select(m =>
            {
                int itemHash = Math.Abs(m.IdMeal.GetHashCode());
                // Độ ưu tiên kết hợp MatchScore (trọng số 80%) và pseudo-random hash theo ngày + lượt refresh (20%)
                int rotationSalt = Math.Abs((itemHash * 17) + (dayOfYear * 31) + (refreshCount * 19)) % 30;
                int combinedPriority = (m.MatchScore * 10) + rotationSalt;
                return new { Meal = m, Priority = combinedPriority };
            })
            .OrderByDescending(x => x.Priority)
            .Select(x => x.Meal)
            .ToList();

        foreach (var meal in remainingCandidates)
        {
            if (result.Count >= limit) break;
            result.Add(meal);
            usedIds.Add(meal.IdMeal);
        }

        // Sắp xếp lại danh sách kết quả cuối cùng theo MatchScore để hiển thị đẹp mắt
        return result.OrderByDescending(m => m.MatchScore).ToList();
    }

    /// <summary>
    /// <summary>
    /// 3. Lấy danh sách món ăn theo nguyên liệu đơn (chuyển tiếp sang thuật toán đa nguyên liệu)
    /// </summary>
    public async Task<List<RecommendedMealDto>> GetMealsByIngredientAsync(string rawIngredient, string lang = "vi")
    {
        return await GetMealsByMultipleIngredientsAsync(new List<string> { rawIngredient }, lang, 20);
    }

    /// <summary>
    /// 3b. THUẬT TOÁN KHỚP ĐA NGUYÊN LIỆU THÔNG MINH (Smart Multi-Ingredient Matching Engine)
    /// Giải quyết triệt để vấn đề: Khi chọn kết hợp THỊT + RAU CỦ QUẢ (ví dụ Bò + Cà chua, Heo + Bông cải):
    /// - Không bao giờ để danh sách thịt lấn át mất rau củ quả.
    /// - Ưu tiên tuyệt đối các món kết hợp có ĐỦ CẢ THỊT VÀ RAU CỦ lên đầu tiên (MatchScore 95 - 99%).
    /// - Trả về công thức đầy đủ cả tiếng Việt, hình ảnh, bước nấu chi tiết và dinh dưỡng.
    /// </summary>
    public async Task<List<RecommendedMealDto>> GetMealsByMultipleIngredientsAsync(List<string> rawIngredients, string lang = "vi", int limit = 25)
    {
        if (rawIngredients == null || rawIngredients.Count == 0)
        {
            return new List<RecommendedMealDto>();
        }

        // 1. Chuẩn hóa và phân loại từng nguyên liệu người dùng đã chọn
        var classifiedList = new List<IngredientInfo>();
        foreach (var raw in rawIngredients)
        {
            if (string.IsNullOrWhiteSpace(raw)) continue;
            var info = ClassifyIngredient(raw);
            if (!classifiedList.Any(c => c.CleanKey == info.CleanKey))
            {
                classifiedList.Add(info);
            }
        }

        if (classifiedList.Count == 0)
        {
            return new List<RecommendedMealDto>();
        }

        // Tạo cache key theo tập hợp các nguyên liệu
        string cacheKeysJoined = string.Join("_", classifiedList.Select(c => c.CleanKey).OrderBy(x => x));
        string cacheKey = $"meals_multi_ing_{cacheKeysJoined}_{lang}_{limit}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cached) && cached != null)
        {
            return cached;
        }

        bool hasMeat = classifiedList.Any(c => c.IsMeat);
        bool hasVeggie = classifiedList.Any(c => c.IsVeggie);
        bool userWantsCombination = hasMeat && hasVeggie;
        int totalSelected = classifiedList.Count;

        var candidatePool = new Dictionary<string, RecommendedMealDto>(StringComparer.OrdinalIgnoreCase);

        // 2. TẬP HỢP KHO CÔNG THỨC MẪU VIỆT NAM + CƠ SỞ DỮ LIỆU THEMEALDB ĐÃ ĐỒNG BỘ
        var masterRecipes = new List<RecommendedMealDto>();
        masterRecipes.AddRange(CombinationRecipeCatalog.Recipes);

        try
        {
            var localMealDb = await _mealDbSyncService.GetOrSyncLocalRecipesAsync(false);
            if (localMealDb != null && localMealDb.Count > 0)
            {
                foreach (var m in localMealDb)
                {
                    if (!masterRecipes.Any(x => x.IdMeal == m.IdMeal))
                    {
                        masterRecipes.Add(m);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể tải cơ sở dữ liệu TheMealDB cục bộ: {Message}", ex.Message);
        }

        // 3. ĐỐI SOÁT & XẾP HẠNG MÓN ĂN THEO NGUYÊN LIỆU TRÊN TOÀN BỘ KHO CÔNG THỨC CỤC BỘ
        foreach (var catMeal in masterRecipes)
        {
            int matchCount = 0;
            var matchedIngs = new List<IngredientInfo>();

            foreach (var ing in classifiedList)
            {
                if (RecipeContainsIngredient(catMeal, ing))
                {
                    matchCount++;
                    matchedIngs.Add(ing);
                }
            }

            if (matchCount > 0)
            {
                // Nhân bản DTO để tính điểm và gắn badge riêng biệt
                var cloned = new RecommendedMealDto
                {
                    IdMeal = catMeal.IdMeal,
                    StrMeal = catMeal.StrMeal,
                    StrMealVi = catMeal.StrMealVi,
                    StrMealThumb = catMeal.StrMealThumb,
                    StrCategory = catMeal.StrCategory,
                    StrArea = catMeal.StrArea,
                    StrInstructions = catMeal.StrInstructions,
                    StrInstructionsVi = catMeal.StrInstructionsVi,
                    Ingredients = new(catMeal.Ingredients),
                    IngredientsVi = new(catMeal.IngredientsVi),
                    Measures = new(catMeal.Measures),
                    MeasuresVi = new(catMeal.MeasuresVi),
                    EstimatedCalories = catMeal.EstimatedCalories,
                    EstimatedProtein = catMeal.EstimatedProtein,
                    EstimatedCarbs = catMeal.EstimatedCarbs,
                    EstimatedFat = catMeal.EstimatedFat,
                    Badges = new(catMeal.Badges)
                };

                bool matchedUserMeat = matchedIngs.Any(i => i.IsMeat);
                bool matchedUserVeggie = matchedIngs.Any(i => i.IsVeggie);
                bool matchedBothUserCategories = matchedUserMeat && matchedUserVeggie;
                bool isMeatDish = IsMeatRecipe(cloned);

                if (userWantsCombination)
                {
                    if (matchedBothUserCategories)
                    {
                        // Món khớp cả thịt lẫn rau củ mà người dùng đã chọn: Điểm cao nhất tuyệt đối (96 - 99%)
                        cloned.MatchScore = Math.Min(99, 94 + (matchCount * 2));
                        cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp"));
                        cloned.Badges.Insert(0, $"✨ Khớp {matchCount}/{totalSelected} NL (Thịt & Rau)");
                        if (!cloned.Badges.Contains("🥗 Cân bằng Dinh dưỡng"))
                        {
                            cloned.Badges.Add("🥗 Cân bằng Dinh dưỡng");
                        }
                    }
                    else
                    {
                        // Chỉ khớp 1 phía (chỉ thịt hoặc chỉ rau): Hạ điểm (68-74%) để các món kết hợp luôn ở trên đầu
                        cloned.MatchScore = 65 + (matchCount * 4);
                        cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp"));
                        cloned.Badges.Insert(0, $"Khớp {matchCount}/{totalSelected} NL");
                    }
                }
                else if (hasVeggie && !hasMeat)
                {
                    // >>> Người dùng CHỈ CHỌN RAU CỦ (không chọn thịt)!
                    if (!isMeatDish)
                    {
                        // 1. Món Chay / Thuần Rau Củ: Điểm cao nhất tuyệt đối (92 - 99%)
                        cloned.MatchScore = Math.Min(99, 92 + (matchCount * 3));
                        cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp"));
                        cloned.Badges.Insert(0, $"🌱 Món Chay / Rau Củ ({matchCount}/{totalSelected} NL)");
                        if (!cloned.Badges.Contains("🥦 Rau Củ Món Chính"))
                        {
                            cloned.Badges.Add("🥦 Rau Củ Món Chính");
                        }
                    }
                    else
                    {
                        // 2. Món có thịt (người dùng không hề chọn thịt):
                        // Hạ điểm xuống (52 - 65%) và gắn nhãn "Cần thêm thịt", không để chèn lên món rau
                        cloned.MatchScore = Math.Min(65, 52 + (matchCount * 3));
                        cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp"));
                        cloned.Badges.Insert(0, $"🥩 Cần thêm thịt ({matchCount}/{totalSelected} NL)");
                    }
                }
                else
                {
                    cloned.MatchScore = Math.Min(98, 80 + (matchCount * 8));
                    if (matchCount > 1)
                    {
                        cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp"));
                        cloned.Badges.Insert(0, $"✨ Khớp {matchCount}/{totalSelected} NL");
                    }
                }

                candidatePool[cloned.IdMeal] = cloned;
            }
        }

        // 4. SẮP XẾP DANH SÁCH MÓN ĂN THEO ĐỘ PHÙ HỢP
        // Khi người dùng chỉ chọn rau: Món thuần rau củ / món chay BẮT BUỘC lên đầu 100%
        var sorted = candidatePool.Values
            .OrderByDescending(m => (hasVeggie && !hasMeat) ? (!IsMeatRecipe(m) ? 1 : 0) : 0)
            .ThenByDescending(m => m.MatchScore)
            .ThenByDescending(m => m.Badges.Count)
            .Take(limit)
            .ToList();

        // 5. TỰ ĐỘNG DỊCH TIẾNG VIỆT CHO CÁC MÓN CHƯA CÓ BẢN DỊCH
        if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var m in sorted)
            {
                if (string.IsNullOrWhiteSpace(m.StrMealVi))
                {
                    m.StrMealVi = await _translationService.TranslateAsync(m.StrMeal, "vi", "en");
                }
            }
        }

        _cache.Set(cacheKey, sorted, TimeSpan.FromHours(1));
        return sorted;
    }

    private static bool IsMeatRecipe(RecommendedMealDto meal)
    {
        string cat = (meal.StrCategory ?? "").ToLower();
        string name = (meal.StrMeal ?? "").ToLower();
        string nameVi = (meal.StrMealVi ?? "").ToLower();

        // 1. Nếu danh mục chính thức là Vegetarian hoặc Vegan thì ưu tiên kiểm tra
        if (cat.Contains("vegetarian") || cat.Contains("vegan"))
        {
            // Kiểm tra xem có phải tên món thịt thật không
            bool hasRealMeat = name.Contains("chicken") || name.Contains("beef") || name.Contains("pork") || name.Contains("bacon");
            if (!hasRealMeat) return false;
        }

        // 2. Danh mục chứa thịt / cá / hải sản / gia cầm
        if (cat.Contains("beef") || cat.Contains("pork") || cat.Contains("chicken") || 
            cat.Contains("seafood") || cat.Contains("lamb") || cat.Contains("goat")) return true;

        // 3. Tên tiếng Anh chứa thịt / cá / hải sản
        if (name.Contains("beef") || name.Contains("pork") || name.Contains("chicken") || 
            name.Contains("fish") || name.Contains("shrimp") || name.Contains("prawn") || 
            name.Contains("lamb") || name.Contains("mutton") || name.Contains("bacon") || 
            name.Contains("sausage") || name.Contains("duck") || name.Contains("meat") || 
            name.Contains("salmon") || name.Contains("tuna") || name.Contains("clam") || 
            name.Contains("squid") || name.Contains("crab") || name.Contains("ham") ||
            name.Contains("steak") || name.Contains("turkey")) return true;

        // 4. Tên tiếng Việt chứa thịt / cá / hải sản (loại trừ trường hợp "nấm đùi gà", "nước dùng gà")
        string cleanNameVi = nameVi.Replace("nấm đùi gà", "").Replace("nước dùng gà", "").Replace("hạt nêm gà", "");
        if (cleanNameVi.Contains("bò") || cleanNameVi.Contains("heo") || cleanNameVi.Contains("lợn") || 
            cleanNameVi.Contains("gà") || cleanNameVi.Contains("vịt") || cleanNameVi.Contains("cá") || 
            cleanNameVi.Contains("tôm") || cleanNameVi.Contains("mực") || cleanNameVi.Contains("cua") || 
            cleanNameVi.Contains("thịt") || cleanNameVi.Contains("sườn") || cleanNameVi.Contains("chả lụa") ||
            cleanNameVi.Contains("xúc xích") || cleanNameVi.Contains("ba rọi")) return true;

        // 5. Nguyên liệu chứa thịt / cá / hải sản thật
        return meal.Ingredients.Any(i =>
        {
            string lower = i.ToLower();
            if (lower.Contains("mushroom") || lower.Contains("sauce") || lower.Contains("stock") || lower.Contains("cube")) return false;
            return lower.Contains("beef") || lower.Contains("pork") || lower.Contains("chicken") ||
                   lower.Contains("shrimp") || lower.Contains("prawn") || lower.Contains("fish") ||
                   lower.Contains("lamb") || lower.Contains("bacon") || lower.Contains("sausage") ||
                   lower.Contains("salmon") || lower.Contains("tuna") || lower.Contains("meat") ||
                   lower.Contains("squid") || lower.Contains("crab");
        });
    }

    private static bool RecipeContainsIngredient(RecommendedMealDto recipe, IngredientInfo ing)
    {
        // 1. Kiểm tra nguyên liệu tiếng Anh (loại bỏ nước dùng / hạt nêm gà, bò)
        if (recipe.Ingredients.Any(i =>
        {
            string lower = i.ToLower();
            if (ing.CleanKey == "chicken" && (lower.Contains("stock") || lower.Contains("broth") || lower.Contains("bouillon") || lower.Contains("cube") || lower.Contains("powder")))
            {
                return false;
            }
            if (ing.CleanKey == "beef" && (lower.Contains("stock") || lower.Contains("broth") || lower.Contains("bouillon") || lower.Contains("cube") || lower.Contains("powder")))
            {
                return false;
            }
            return lower.Equals(ing.CleanKey, StringComparison.OrdinalIgnoreCase) ||
                   lower.Contains(ing.CleanKey, StringComparison.OrdinalIgnoreCase) ||
                   lower.Contains(ing.Raw.ToLower(), StringComparison.OrdinalIgnoreCase);
        }))
        {
            return true;
        }

        // 2. Kiểm tra danh mục
        if ((recipe.StrCategory ?? "").Equals(ing.CleanKey, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // 3. Kiểm tra tên món
        if (recipe.StrMeal.Contains(ing.CleanKey, StringComparison.OrdinalIgnoreCase) ||
            (recipe.StrMealVi ?? "").Contains(ing.ViKey, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // 4. Kiểm tra nguyên liệu tiếng Việt (loại bỏ nấm đùi gà, trứng gà, nước dùng gà/bò bị tính là thịt)
        foreach (var viIng in recipe.IngredientsVi)
        {
            string lowerIng = viIng.ToLower();
            if (ing.CleanKey == "chicken" && (lowerIng.Contains("nấm") || lowerIng.Contains("trứng") || lowerIng.Contains("nước dùng") || lowerIng.Contains("hạt nêm")))
            {
                continue;
            }
            if (ing.CleanKey == "beef" && (lowerIng.Contains("nước dùng") || lowerIng.Contains("hạt nêm")))
            {
                continue;
            }
            if (lowerIng.Contains(ing.ViKey, StringComparison.OrdinalIgnoreCase) ||
                lowerIng.Contains(ing.Raw.ToLower(), StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsVeggieRecipe(RecommendedMealDto meal)
    {
        string cat = (meal.StrCategory ?? "").ToLower();
        string name = (meal.StrMeal ?? "").ToLower();
        string nameVi = (meal.StrMealVi ?? "").ToLower();

        if (cat.Contains("vegetable") || cat.Contains("vegetarian")) return true;
        if (name.Contains("tomato") || name.Contains("broccoli") || name.Contains("mushroom") || name.Contains("carrot") || name.Contains("potato") || name.Contains("onion") || name.Contains("tofu")) return true;
        if (nameVi.Contains("cà chua") || nameVi.Contains("bông cải") || nameVi.Contains("nấm") || nameVi.Contains("cà rốt") || nameVi.Contains("khoai tây") || nameVi.Contains("hành") || nameVi.Contains("đậu phụ")) return true;

        return meal.Ingredients.Any(i => i.Contains("tomato", StringComparison.OrdinalIgnoreCase) ||
                                         i.Contains("broccoli", StringComparison.OrdinalIgnoreCase) ||
                                         i.Contains("mushroom", StringComparison.OrdinalIgnoreCase) ||
                                         i.Contains("carrot", StringComparison.OrdinalIgnoreCase) ||
                                         i.Contains("potato", StringComparison.OrdinalIgnoreCase) ||
                                         i.Contains("onion", StringComparison.OrdinalIgnoreCase) ||
                                         i.Contains("tofu", StringComparison.OrdinalIgnoreCase));
    }

    private record IngredientInfo(string Raw, string CleanKey, string ViKey, bool IsMeat, bool IsVeggie);

    private static IngredientInfo ClassifyIngredient(string raw)
    {
        string lower = raw.Trim().ToLower();
        string clean = CleanIngredientKeyword(raw);

        bool isMeat = false;
        bool isVeggie = false;
        string viKey = lower;

        if (lower.Contains("trứng") || clean.Contains("egg"))
        {
            clean = "egg";
            viKey = "trứng";
            isMeat = true;
        }
        else if (lower.Contains("bò") || clean.Contains("beef"))
        {
            clean = "beef";
            viKey = "bò";
            isMeat = true;
        }
        else if (lower.Contains("heo") || lower.Contains("lợn") || clean.Contains("pork"))
        {
            clean = "pork";
            viKey = "heo";
            isMeat = true;
        }
        else if (lower.Contains("gà") || clean.Contains("chicken"))
        {
            clean = "chicken";
            viKey = "gà";
            isMeat = true;
        }
        else if (lower.Contains("tôm") || clean.Contains("shrimp") || clean.Contains("prawn"))
        {
            clean = "shrimp";
            viKey = "tôm";
            isMeat = true;
        }
        else if (lower.Contains("cá") || clean.Contains("fish") || clean.Contains("salmon"))
        {
            clean = "fish";
            viKey = "cá";
            isMeat = true;
        }
        else if (lower.Contains("cà chua") || clean.Contains("tomato"))
        {
            clean = "tomato";
            viKey = "cà chua";
            isVeggie = true;
        }
        else if (lower.Contains("bông cải") || lower.Contains("súp lơ") || clean.Contains("broccoli"))
        {
            clean = "broccoli";
            viKey = "bông cải";
            isVeggie = true;
        }
        else if (lower.Contains("cà rốt") || clean.Contains("carrot"))
        {
            clean = "carrot";
            viKey = "cà rốt";
            isVeggie = true;
        }
        else if (lower.Contains("nấm") || clean.Contains("mushroom"))
        {
            clean = "mushroom";
            viKey = "nấm";
            isVeggie = true;
        }
        else if (lower.Contains("khoai tây") || clean.Contains("potato"))
        {
            clean = "potato";
            viKey = "khoai tây";
            isVeggie = true;
        }
        else if (lower.Contains("hành tây") || lower.Contains("hành") || clean.Contains("onion"))
        {
            clean = "onion";
            viKey = "hành tây";
            isVeggie = true;
        }
        else if (lower.Contains("đậu phụ") || lower.Contains("đậu hũ") || clean.Contains("tofu"))
        {
            clean = "tofu";
            viKey = "đậu phụ";
            isVeggie = true;
        }
        else
        {
            isVeggie = true;
        }

        return new IngredientInfo(raw, clean, viKey, isMeat, isVeggie);
    }

    /// <summary>
    /// 4. Tìm kiếm món ăn theo từ khóa
    /// </summary>
    public async Task<List<RecommendedMealDto>> SearchMealsAsync(string query, string lang = "vi")
    {
        string cleanQuery = MapSearchQuery(query);
        string cacheKey = $"meals_search_{cleanQuery.ToLower()}_{lang}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cached) && cached != null)
        {
            return cached;
        }

        var results = new List<RecommendedMealDto>();
        try
        {
            string url = $"https://www.themealdb.com/api/json/v1/1/search.php?s={Uri.EscapeDataString(cleanQuery)}";
            var response = await _httpClient.GetStringAsync(url);
            var node = JsonNode.Parse(response);
            var mealsArray = node?["meals"]?.AsArray();

            // Nếu không ra kết quả, thử filter theo category
            if (mealsArray == null || mealsArray.Count == 0)
            {
                string catUrl = $"https://www.themealdb.com/api/json/v1/1/filter.php?c={Uri.EscapeDataString(cleanQuery)}";
                try
                {
                    var catResp = await _httpClient.GetStringAsync(catUrl);
                    var catNode = JsonNode.Parse(catResp);
                    mealsArray = catNode?["meals"]?.AsArray();
                }
                catch { }
            }

            if (mealsArray != null)
            {
                foreach (var item in mealsArray)
                {
                    if (item == null) continue;
                    var meal = new RecommendedMealDto
                    {
                        IdMeal = item["idMeal"]?.ToString() ?? "",
                        StrMeal = item["strMeal"]?.ToString() ?? "",
                        StrMealThumb = item["strMealThumb"]?.ToString() ?? "",
                        StrCategory = item["strCategory"]?.ToString() ?? cleanQuery
                    };
                    CalculateNutrition(meal);
                    results.Add(meal);
                }

                if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase))
                {
                    foreach (var m in results.Take(20))
                    {
                        m.StrMealVi = await _translationService.TranslateAsync(m.StrMeal, "vi", "en");
                    }
                }

                _cache.Set(cacheKey, results, TimeSpan.FromHours(1));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi tìm món với từ khóa {Query}", query);
        }

        return results;
    }

    /// <summary>
    /// 5. Lấy danh sách món theo danh mục
    /// </summary>
    public async Task<List<RecommendedMealDto>> GetMealsByCategoryAsync(string category, string lang = "vi")
    {
        var candidates = await GetCandidateMealsByCategoryAsync(category);
        foreach (var m in candidates)
        {
            CalculateNutrition(m);
            if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase) && string.IsNullOrEmpty(m.StrMealVi))
            {
                m.StrMealVi = await _translationService.TranslateAsync(m.StrMeal, "vi", "en");
            }
        }
        return candidates;
    }

    /// <summary>
    /// 6. Tra cứu dinh dưỡng nguyên liệu (Backend Nutrition Database)
    /// </summary>
    public async Task<DetectedIngredientDto> LookupIngredientNutritionAsync(string name)
    {
        string lower = name.Trim().ToLower();

        // Tra cứu trong từ điển dinh dưỡng
        foreach (var entry in NutritionDictionary)
        {
            if (lower == entry.Key || lower.Contains(entry.Key) || entry.Key.Contains(lower))
            {
                return entry.Value;
            }
        }

        // Tự động dịch sang tiếng Anh và ước tính
        string englishName = await _translationService.TranslateAsync(name, "en", "vi");
        return new DetectedIngredientDto
        {
            Name = name.Trim(),
            EnglishName = englishName,
            Calories = "65 kcal",
            CalorieNumber = 65,
            Weight = "~100g",
            Protein = "3g Protein",
            Carbs = "8g Carbs",
            Fat = "1g Fat",
            NutritionComment = "Nguyên liệu tươi tự nhiên, cung cấp năng lượng và vi chất thiết yếu cho cơ thể."
        };
    }

    public List<string> GetQuickSuggestions()
    {
        return new List<string>
        {
            "🥩 Thịt heo nạc",
            "🥩 Thịt bò phi lê",
            "🍗 Ức gà",
            "🥚 Trứng gà",
            "🐟 Cá hồi",
            "🦐 Tôm tươi",
            "🥦 Bông cải xanh",
            "🥕 Cà rốt",
            "🍅 Cà chua",
            "🍄 Nấm tươi",
            "🥔 Khoai tây",
            "🧅 Hành tây",
            "🫘 Đậu phụ"
        };
    }

    private static string CleanIngredientKeyword(string raw)
    {
        string clean = raw.ToLower().Trim().Replace('-', '_').Replace(' ', '_');
        var map = new Dictionary<string, string>
        {
            ["thịt_gà"] = "chicken",
            ["gà"] = "chicken",
            ["ức_gà"] = "chicken_breast",
            ["thịt_bò"] = "beef",
            ["bò"] = "beef",
            ["thịt_heo"] = "pork",
            ["thịt_lợn"] = "pork",
            ["heo"] = "pork",
            ["trứng"] = "egg",
            ["trứng_gà"] = "egg",
            ["cà_chua"] = "tomato",
            ["khoai_tây"] = "potato",
            ["cá_hồi"] = "salmon",
            ["cá"] = "fish",
            ["tôm"] = "prawns",
            ["nấm"] = "mushrooms",
            ["hành_tây"] = "onion",
            ["cà_rốt"] = "carrot",
            ["bông_cải"] = "broccoli",
            ["súp_lơ"] = "cauliflower",
            ["tỏi"] = "garlic",
            ["phô_mai"] = "cheese",
            ["bơ"] = "butter"
        };
        return map.TryGetValue(clean, out var mapped) ? mapped : clean;
    }

    private static string GetFallbackKeyword(string keyword)
    {
        if (keyword.Contains("chicken")) return "chicken";
        if (keyword.Contains("beef")) return "beef";
        if (keyword.Contains("egg")) return "egg";
        if (keyword.Contains("tomato")) return "tomato";
        if (keyword.Contains("fish") || keyword.Contains("salmon")) return "salmon";
        if (keyword.Contains("pork")) return "pork";
        if (keyword.Contains("potato")) return "potato";
        return keyword;
    }

    private static string MapSearchQuery(string query)
    {
        string q = query.Trim().ToLower();
        var map = new Dictionary<string, string>
        {
            ["thịt gà"] = "chicken",
            ["ức gà"] = "chicken",
            ["gà"] = "chicken",
            ["thịt bò"] = "beef",
            ["bò"] = "beef",
            ["bít tết"] = "steak",
            ["thịt heo"] = "pork",
            ["thịt lợn"] = "pork",
            ["heo"] = "pork",
            ["cá hồi"] = "salmon",
            ["cá"] = "fish",
            ["hải sản"] = "seafood",
            ["tôm"] = "prawn",
            ["trứng"] = "egg",
            ["mỳ ý"] = "pasta",
            ["mì"] = "noodle",
            ["cơm"] = "rice",
            ["chay"] = "vegetarian",
            ["rau"] = "vegetable",
            ["salad"] = "salad",
            ["súp"] = "soup",
            ["canh"] = "soup",
            ["bánh"] = "cake",
            ["tráng miệng"] = "dessert",
            ["nấm"] = "mushroom",
            ["khoai"] = "potato",
            ["cà chua"] = "tomato"
        };
        foreach (var entry in map)
        {
            if (q == entry.Key || q.Contains(entry.Key)) return entry.Value;
        }
        return q;
    }

    private static readonly Dictionary<string, DetectedIngredientDto> NutritionDictionary = new(StringComparer.OrdinalIgnoreCase)
    {
        ["thịt heo"] = new DetectedIngredientDto { Name = "Thịt heo nạc", EnglishName = "Pork", Calories = "240 kcal", CalorieNumber = 240, Weight = "~150g", Protein = "26g Protein", Carbs = "0g Carbs", Fat = "14g Fat", NutritionComment = "Thịt heo nạc cung cấp lượng đạm dồi dào, vitamin nhóm B (đặc biệt là B1) và khoáng chất cần thiết." },
        ["thịt lợn"] = new DetectedIngredientDto { Name = "Thịt heo nạc", EnglishName = "Pork", Calories = "240 kcal", CalorieNumber = 240, Weight = "~150g", Protein = "26g Protein", Carbs = "0g Carbs", Fat = "14g Fat", NutritionComment = "Thịt heo nạc cung cấp lượng đạm dồi dào, vitamin nhóm B và khoáng chất." },
        ["heo"] = new DetectedIngredientDto { Name = "Thịt heo tươi", EnglishName = "Pork", Calories = "240 kcal", CalorieNumber = 240, Weight = "~150g", Protein = "26g Protein", Carbs = "0g Carbs", Fat = "14g Fat", NutritionComment = "Cung cấp năng lượng cao, thích hợp luộc, kho hoặc xào cùng rau củ." },
        ["thịt bò"] = new DetectedIngredientDto { Name = "Thịt bò phi lê", EnglishName = "Beef", Calories = "250 kcal", CalorieNumber = 250, Weight = "~150g", Protein = "28g Protein", Carbs = "0g Carbs", Fat = "15g Fat", NutritionComment = "Nguồn sắt heme dồi dào giúp phòng ngừa thiếu máu, tăng cường sức mạnh cơ bắp." },
        ["bò"] = new DetectedIngredientDto { Name = "Thịt bò tươi", EnglishName = "Beef", Calories = "250 kcal", CalorieNumber = 250, Weight = "~150g", Protein = "28g Protein", Carbs = "0g Carbs", Fat = "15g Fat", NutritionComment = "Rất giàu kẽm, sắt và protein cho người tập luyện thể thao." },
        ["thịt gà"] = new DetectedIngredientDto { Name = "Ức gà phi lê", EnglishName = "Chicken", Calories = "165 kcal", CalorieNumber = 165, Weight = "~150g", Protein = "31g Protein", Carbs = "0g Carbs", Fat = "3.6g Fat", NutritionComment = "Thực phẩm vàng cho người giảm mỡ tăng cơ với lượng đạm cao và cực ít chất béo xấu." },
        ["ức gà"] = new DetectedIngredientDto { Name = "Ức gà không da", EnglishName = "Chicken", Calories = "165 kcal", CalorieNumber = 165, Weight = "~150g", Protein = "31g Protein", Carbs = "0g Carbs", Fat = "3.6g Fat", NutritionComment = "Hàm lượng đạm tinh khiết, dễ tiêu hóa và hấp thụ." },
        ["gà"] = new DetectedIngredientDto { Name = "Thịt gà tươi", EnglishName = "Chicken", Calories = "190 kcal", CalorieNumber = 190, Weight = "~150g", Protein = "27g Protein", Carbs = "0g Carbs", Fat = "8g Fat", NutritionComment = "Nguồn protein chất lượng cao phổ biến trong bữa cơm gia đình." },
        ["trứng"] = new DetectedIngredientDto { Name = "Trứng gà ta", EnglishName = "Egg", Calories = "140 kcal", CalorieNumber = 140, Weight = "2 quả (~100g)", Protein = "13g Protein", Carbs = "1g Carbs", Fat = "9.5g Fat", NutritionComment = "Siêu thực phẩm chứa đầy đủ các axit amin thiết yếu, choline tốt cho não bộ." },
        ["trứng gà"] = new DetectedIngredientDto { Name = "Trứng gà ta", EnglishName = "Egg", Calories = "140 kcal", CalorieNumber = 140, Weight = "2 quả (~100g)", Protein = "13g Protein", Carbs = "1g Carbs", Fat = "9.5g Fat", NutritionComment = "Chứa protein sinh học hoàn hảo, giàu vitamin A, D, E và chất béo lành mạnh." },
        ["cá hồi"] = new DetectedIngredientDto { Name = "Cá hồi Na Uy", EnglishName = "Salmon", Calories = "208 kcal", CalorieNumber = 208, Weight = "~150g", Protein = "22g Protein", Carbs = "0g Carbs", Fat = "13g Fat", NutritionComment = "Chứa axit béo Omega-3 dồi dào, kháng viêm, tốt cho tim mạch và làn da." },
        ["cá"] = new DetectedIngredientDto { Name = "Cá tươi", EnglishName = "Fish", Calories = "130 kcal", CalorieNumber = 130, Weight = "~150g", Protein = "22g Protein", Carbs = "0g Carbs", Fat = "4.5g Fat", NutritionComment = "Đạm trắng dễ hấp thụ, giàu canxi và phốt pho cho xương khớp." },
        ["tôm"] = new DetectedIngredientDto { Name = "Tôm tươi lột vỏ", EnglishName = "Shrimp", Calories = "99 kcal", CalorieNumber = 99, Weight = "~100g", Protein = "24g Protein", Carbs = "0.2g Carbs", Fat = "0.3g Fat", NutritionComment = "Lượng protein cao kỷ lục trên mỗi đơn vị calo, giàu canxi và selen." },
        ["cà chua"] = new DetectedIngredientDto { Name = "Cà chua chín", EnglishName = "Tomato", Calories = "25 kcal", CalorieNumber = 25, Weight = "~120g", Protein = "1.2g Protein", Carbs = "5g Carbs", Fat = "0.2g Fat", NutritionComment = "Hợp chất Lycopene chống oxy hóa mạnh, kích hoạt khi nấu chín cùng chút dầu ăn." },
        ["cà rốt"] = new DetectedIngredientDto { Name = "Cà rốt tươi", EnglishName = "Carrot", Calories = "41 kcal", CalorieNumber = 41, Weight = "~100g", Protein = "1g Protein", Carbs = "10g Carbs", Fat = "0.2g Fat", NutritionComment = "Hàm lượng Beta-carotene dồi dào tốt cho mắt và tăng cường miễn dịch." },
        ["bông cải"] = new DetectedIngredientDto { Name = "Bông cải xanh (Súp lơ)", EnglishName = "Broccoli", Calories = "34 kcal", CalorieNumber = 34, Weight = "~150g", Protein = "2.8g Protein", Carbs = "7g Carbs", Fat = "0.4g Fat", NutritionComment = "Rau họ cải giàu sulforaphane, chất xơ và vitamin C giúp thanh lọc cơ thể." },
        ["khoai tây"] = new DetectedIngredientDto { Name = "Khoai tây củ", EnglishName = "Potato", Calories = "110 kcal", CalorieNumber = 110, Weight = "~130g", Protein = "2.5g Protein", Carbs = "26g Carbs", Fat = "0.1g Fat", NutritionComment = "Nguồn tinh bột phức hợp lành mạnh, giàu kali hơn cả chuối." },
        ["nấm"] = new DetectedIngredientDto { Name = "Nấm tươi", EnglishName = "Mushroom", Calories = "28 kcal", CalorieNumber = 28, Weight = "~100g", Protein = "3g Protein", Carbs = "3.3g Carbs", Fat = "0.3g Fat", NutritionComment = "Vị ngọt umami tự nhiên, tăng cường hệ miễn dịch và không chứa cholesterol." },
        ["hành tây"] = new DetectedIngredientDto { Name = "Hành tây trắng", EnglishName = "Onion", Calories = "40 kcal", CalorieNumber = 40, Weight = "~100g", Protein = "1.1g Protein", Carbs = "9g Carbs", Fat = "0.1g Fat", NutritionComment = "Quercetin trong hành tây có tác dụng kháng viêm và bảo vệ tim mạch." },
        ["đậu phụ"] = new DetectedIngredientDto { Name = "Đậu phụ non", EnglishName = "Tofu", Calories = "76 kcal", CalorieNumber = 76, Weight = "~100g", Protein = "8g Protein", Carbs = "1.9g Carbs", Fat = "4.8g Fat", NutritionComment = "Đạm thực vật lành mạnh, chứa canxi và isoflavone tốt cho hormone." },
        ["gạo"] = new DetectedIngredientDto { Name = "Gạo tẻ / Cơm", EnglishName = "Rice", Calories = "130 kcal", CalorieNumber = 130, Weight = "1 chén (~100g cơm)", Protein = "2.7g Protein", Carbs = "28g Carbs", Fat = "0.3g Fat", NutritionComment = "Nguồn cung cấp năng lượng chủ đạo, dễ hấp thu." },
        ["cơm"] = new DetectedIngredientDto { Name = "Cơm trắng", EnglishName = "Rice", Calories = "130 kcal", CalorieNumber = 130, Weight = "1 chén (~100g cơm)", Protein = "2.7g Protein", Carbs = "28g Carbs", Fat = "0.3g Fat", NutritionComment = "Nguồn năng lượng carb lành mạnh, dễ hấp thu." }
    };
}