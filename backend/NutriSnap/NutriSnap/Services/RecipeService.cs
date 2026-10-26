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

    /// <summary>
    /// Lấy toàn bộ kho công thức món ăn từ Cơ sở dữ liệu cục bộ (1,100+ món đã đồng bộ đa nguồn)
    /// </summary>
    public async Task<List<RecommendedMealDto>> GetAllDatabaseRecipesAsync()
    {
        try
        {
            var local = await _mealDbSyncService.GetOrSyncLocalRecipesAsync(false);
            if (local != null && local.Count > 0)
            {
                return local;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Lỗi khi nạp cơ sở dữ liệu món ăn cục bộ, chuyển sang danh mục dự phòng");
        }

        return MultiSourceCatalogService.GetAllRecipes();
    }

    /// 1. Lấy món ngẫu nhiên cho tính năng lắc điện thoại từ Database cục bộ 1,100+ món
    public async Task<RecommendedMealDto?> GetRandomMealAsync(string lang = "vi")
    {
        try
        {
            var all = await GetAllDatabaseRecipesAsync();
            if (all == null || all.Count == 0) return null;

            int randomIndex = Random.Shared.Next(all.Count);
            var chosen = all[randomIndex];

            var mealDto = await GetMealDetailAsync(chosen.IdMeal, lang);
            if (mealDto != null)
            {
                // Thêm huy hiệu lắc rớt món may mắn
                var badges = mealDto.Badges.ToList();
                badges.Insert(0, lang == "vi" ? "🎲 Món lắc may mắn" : "🎲 Lucky Shake");
                mealDto.Badges = badges;
                mealDto.MatchScore = Random.Shared.Next(88, 99);
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
        DateTime targetDate = DateTime.TryParse(req.Date, out var parsedDate) ? parsedDate.Date : DateTime.UtcNow.Date;
        int dayOfYear = targetDate.DayOfYear;

        string cacheKey = $"daily_recom_{req.DietType}_{req.Goal}_{req.RemainingCalories}_{req.Category}_{req.RefreshCount}_{req.Limit}_{dayOfYear}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cachedList) && cachedList != null)
        {
            return cachedList;
        }

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

        // Tính toán dinh dưỡng, chuẩn hóa định lượng, điểm phù hợp MatchScore và Gắn Badges cho từng món
        foreach (var meal in candidateMeals)
        {
            CalculateNutrition(meal);
            SanitizeMealMeasures(meal);
            meal.MatchScore = CalculateMatchScore(meal, req.Goal, req.DietType, req.RemainingCalories);
            meal.Badges = GenerateBadges(meal, req.RemainingCalories);
        }

        // Sắp xếp điểm phù hợp từ cao xuống thấp
        var sortedByScore = candidateMeals
            .OrderByDescending(m => m.MatchScore)
            .ToList();

        // Áp dụng thuật toán xoay vòng theo ngày và lượt refresh
        var rotatedList = ApplyDailyRotationAlgorithm(sortedByScore, req.Limit, dayOfYear, req.RefreshCount);

        // Tự động dịch tên món sang Tiếng Việt cho danh sách trả về (chạy song song siêu tốc)
        var transTasks = rotatedList
            .Where(m => string.IsNullOrWhiteSpace(m.StrMealVi) || m.StrMealVi == m.StrMeal)
            .Select(async meal =>
            {
                meal.StrMealVi = await _translationService.TranslateAsync(meal.StrMeal, "vi", "en");
            });
        await Task.WhenAll(transTasks);

        _cache.Set(cacheKey, rotatedList, TimeSpan.FromMinutes(30));
        return rotatedList;
    }

    /// <summary>
    /// Lấy chi tiết món ăn đầy đủ từ Cơ sở dữ liệu cục bộ và tự động dịch 100% sang Tiếng Việt bằng TranslationService & AI Filter
    /// </summary>
    public async Task<RecommendedMealDto?> GetMealDetailAsync(string idMeal, string lang = "vi", bool forceAi = false)
    {
        string cacheKey = $"local_meal_detail_{idMeal}_{lang}";
        if (!forceAi && _cache.TryGetValue(cacheKey, out RecommendedMealDto? cached) && cached != null)
        {
            // Đảm bảo nếu lang == "vi", bản dịch cách nấu trong cache thực sự là tiếng Việt
            if (!lang.Equals("vi", StringComparison.OrdinalIgnoreCase) || 
                (TranslationService.IsVietnamese(cached.StrInstructionsVi) && 
                 (cached.IngredientsVi == null || cached.IngredientsVi.All(TranslationService.IsVietnamese))))
            {
                return cached;
            }
        }

        try
        {
            var all = await GetAllDatabaseRecipesAsync();
            var rawMeal = all.FirstOrDefault(m => string.Equals(m.IdMeal, idMeal, StringComparison.OrdinalIgnoreCase));

            if (rawMeal == null && idMeal.StartsWith("vn_home_", StringComparison.OrdinalIgnoreCase))
            {
                rawMeal = MultiSourceCatalogService.GetAllRecipes().FirstOrDefault(m => string.Equals(m.IdMeal, idMeal, StringComparison.OrdinalIgnoreCase));
            }

            if (rawMeal == null)
            {
                return null;
            }

            // Nhân bản đối tượng DTO để an toàn với bộ nhớ đệm
            var meal = new RecommendedMealDto
            {
                IdMeal = rawMeal.IdMeal,
                StrMeal = rawMeal.StrMeal,
                StrMealVi = rawMeal.StrMealVi,
                StrMealThumb = rawMeal.StrMealThumb,
                StrCategory = rawMeal.StrCategory,
                StrArea = rawMeal.StrArea,
                StrInstructions = rawMeal.StrInstructions,
                StrInstructionsVi = rawMeal.StrInstructionsVi,
                StrYoutube = rawMeal.StrYoutube,
                Ingredients = rawMeal.Ingredients != null ? new List<string>(rawMeal.Ingredients) : new List<string>(),
                IngredientsVi = rawMeal.IngredientsVi != null ? new List<string>(rawMeal.IngredientsVi) : new List<string>(),
                Measures = rawMeal.Measures != null ? new List<string>(rawMeal.Measures) : new List<string>(),
                MeasuresVi = rawMeal.MeasuresVi != null ? new List<string>(rawMeal.MeasuresVi) : new List<string>(),
                EstimatedCalories = rawMeal.EstimatedCalories,
                EstimatedProtein = rawMeal.EstimatedProtein,
                EstimatedCarbs = rawMeal.EstimatedCarbs,
                EstimatedFat = rawMeal.EstimatedFat,
                MatchScore = rawMeal.MatchScore,
                Badges = rawMeal.Badges != null ? new List<string>(rawMeal.Badges) : new List<string>()
            };

            if (meal.EstimatedCalories == 0)
            {
                CalculateNutrition(meal);
            }

            if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase))
            {
                bool needsTitleTrans = forceAi ||
                    string.IsNullOrWhiteSpace(meal.StrMealVi) || 
                    meal.StrMealVi == meal.StrMeal || 
                    !TranslationService.IsVietnamese(meal.StrMealVi);

                bool needsInstructionsTrans = forceAi ||
                    string.IsNullOrWhiteSpace(meal.StrInstructionsVi) || 
                    meal.StrInstructionsVi == meal.StrInstructions || 
                    !TranslationService.IsVietnamese(meal.StrInstructionsVi);

                var taskTitle = needsTitleTrans
                    ? _translationService.TranslateAsync(meal.StrMeal, "vi", "en", false)
                    : Task.FromResult(meal.StrMealVi!);

                var taskInstructions = needsInstructionsTrans
                    ? _translationService.TranslateAsync(meal.StrInstructions ?? "", "vi", "en", forceAi)
                    : Task.FromResult(meal.StrInstructionsVi ?? "");

                await Task.WhenAll(taskTitle, taskInstructions);

                meal.StrMealVi = await taskTitle;
                meal.StrInstructionsVi = await taskInstructions;

                // 1. Chuẩn hóa & khắc phục lỗi dịch sai ngữ cảnh cho danh sách nguyên liệu
                var sanitizedIngredients = new List<string>();
                for (int i = 0; i < meal.Ingredients.Count; i++)
                {
                    string en = meal.Ingredients[i];
                    string? currentVi = (meal.IngredientsVi != null && i < meal.IngredientsVi.Count) ? meal.IngredientsVi[i] : null;
                    sanitizedIngredients.Add(TranslationService.SanitizeIngredient(en, currentVi));
                }

                // Chỉ dịch những nguyên liệu thực sự chưa được Việt hóa (vẫn còn nguyên tiếng Anh)
                for (int i = 0; i < sanitizedIngredients.Count; i++)
                {
                    string item = sanitizedIngredients[i];
                    if (!TranslationService.IsVietnamese(item) || string.Equals(item, meal.Ingredients[i], StringComparison.OrdinalIgnoreCase))
                    {
                        sanitizedIngredients[i] = await _translationService.TranslateAsync(meal.Ingredients[i], "vi", "en", false);
                    }
                }
                meal.IngredientsVi = sanitizedIngredients;

                // 2. Chuẩn hóa & định lượng thực tế 100% cho toàn bộ nguyên liệu của mọi món ăn
                SanitizeMealMeasures(meal);
            }

            // Chỉ lưu cache dài 7 ngày nếu đã có bản dịch tiếng Việt hợp lệ
            if (!lang.Equals("vi", StringComparison.OrdinalIgnoreCase) || TranslationService.IsVietnamese(meal.StrInstructionsVi))
            {
                _cache.Set(cacheKey, meal, TimeSpan.FromDays(7));
            }
            else
            {
                _cache.Set(cacheKey, meal, TimeSpan.FromSeconds(30));
            }
            return meal;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy chi tiết món {IdMeal} từ cơ sở dữ liệu cục bộ", idMeal);
            return null;
        }
    }

    /// Lấy danh sách món theo danh mục từ cơ sở dữ liệu cục bộ (có Cache 1 giờ để tăng tốc độ phản hồi)
    private async Task<List<RecommendedMealDto>> GetCandidateMealsByCategoryAsync(string category)
    {
        string cleanCat = category.Trim().ToLower();
        string cacheKey = $"local_cat_{cleanCat}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cached) && cached != null)
        {
            return cached;
        }

        var list = new List<RecommendedMealDto>();
        try
        {
            var all = await GetAllDatabaseRecipesAsync();

            // 1. Khớp theo StrCategory
            var matched = all.Where(m =>
            {
                string c = (m.StrCategory ?? "").ToLower();
                return c == cleanCat || c.Contains(cleanCat) || cleanCat.Contains(c);
            }).ToList();

            // 2. Mở rộng tìm kiếm nếu số lượng ứng viên theo danh mục chưa phong phú
            if (matched.Count < 6)
            {
                var extra = all.Where(m =>
                {
                    if (matched.Any(x => x.IdMeal == m.IdMeal)) return false;
                    string name = m.StrMeal.ToLower();
                    string nameVi = (m.StrMealVi ?? "").ToLower();
                    return name.Contains(cleanCat) || nameVi.Contains(cleanCat);
                }).Take(20);
                matched.AddRange(extra);
            }

            foreach (var item in matched)
            {
                var dto = new RecommendedMealDto
                {
                    IdMeal = item.IdMeal,
                    StrMeal = item.StrMeal,
                    StrMealVi = item.StrMealVi,
                    StrMealThumb = item.StrMealThumb,
                    StrCategory = item.StrCategory ?? category,
                    StrArea = item.StrArea,
                    StrInstructions = item.StrInstructions,
                    StrInstructionsVi = item.StrInstructionsVi,
                    StrYoutube = item.StrYoutube,
                    Ingredients = item.Ingredients != null ? new List<string>(item.Ingredients) : new List<string>(),
                    IngredientsVi = item.IngredientsVi != null ? new List<string>(item.IngredientsVi) : new List<string>(),
                    Measures = item.Measures != null ? new List<string>(item.Measures) : new List<string>(),
                    MeasuresVi = item.MeasuresVi != null ? new List<string>(item.MeasuresVi) : new List<string>(),
                    EstimatedCalories = item.EstimatedCalories,
                    EstimatedProtein = item.EstimatedProtein,
                    EstimatedCarbs = item.EstimatedCarbs,
                    EstimatedFat = item.EstimatedFat
                };
                CalculateNutrition(dto);
                SanitizeMealMeasures(dto);
                list.Add(dto);
            }

            _cache.Set(cacheKey, list, TimeSpan.FromHours(1));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi lấy danh mục {Category} từ cơ sở dữ liệu cục bộ", category);
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

    /// <summary>
    /// Chuẩn hóa định lượng cho toàn bộ nguyên liệu của mọi món ăn, triệt để loại bỏ placeholder 'Khẩu phần tiêu chuẩn' hoặc 'Khẩu phần MasterChef'
    /// </summary>
    public static void SanitizeMealMeasures(RecommendedMealDto meal)
    {
        if (meal == null) return;
        SanitizeMealImage(meal);

        int count = Math.Max(meal.IngredientsVi?.Count ?? 0, meal.Ingredients?.Count ?? 0);
        if (count == 0) return;

        meal.Ingredients ??= new List<string>();
        meal.IngredientsVi ??= new List<string>();
        meal.Measures ??= new List<string>();
        meal.MeasuresVi ??= new List<string>();

        // Đồng bộ số lượng IngredientsVi nếu còn thiếu
        while (meal.IngredientsVi.Count < meal.Ingredients.Count)
        {
            meal.IngredientsVi.Add(TranslationService.SanitizeIngredient(meal.Ingredients[meal.IngredientsVi.Count], null));
        }

        var newMeasuresVi = new List<string>(count);
        var newMeasures = new List<string>(count);

        for (int i = 0; i < count; i++)
        {
            string ingVi = i < meal.IngredientsVi.Count ? meal.IngredientsVi[i] : "";
            string ingEn = i < meal.Ingredients.Count ? meal.Ingredients[i] : "";
            string ingRef = !string.IsNullOrWhiteSpace(ingVi) ? ingVi : ingEn;

            string mVi = i < meal.MeasuresVi.Count ? meal.MeasuresVi[i] : "";
            string mEn = i < meal.Measures.Count ? meal.Measures[i] : "";

            bool isPlaceholderVi = IsPlaceholderMeasure(mVi);
            bool isPlaceholderEn = IsPlaceholderMeasure(mEn);

            if (isPlaceholderVi && isPlaceholderEn)
            {
                string realistic = TranslationService.GenerateDefaultMeasure(ingRef, i);
                newMeasuresVi.Add(realistic);
                newMeasures.Add(realistic);
            }
            else if (isPlaceholderVi && !isPlaceholderEn)
            {
                newMeasures.Add(mEn);
                newMeasuresVi.Add(TranslationService.TranslateMeasure(mEn));
            }
            else if (!isPlaceholderVi && isPlaceholderEn)
            {
                newMeasuresVi.Add(TranslationService.TranslateMeasure(mVi));
                newMeasures.Add(mVi);
            }
            else
            {
                newMeasuresVi.Add(TranslationService.TranslateMeasure(mVi));
                newMeasures.Add(mEn);
            }
        }

        meal.MeasuresVi = newMeasuresVi;
        meal.Measures = newMeasures;
    }

    public static bool IsPlaceholderMeasure(string? m)
    {
        if (string.IsNullOrWhiteSpace(m)) return true;
        string lower = m.Trim().ToLowerInvariant();
        return lower.Contains("tiêu chuẩn") ||
               lower.Contains("tieu chuan") ||
               lower.Contains("khẩu phần") ||
               lower.Contains("khau phan") ||
               lower.Contains("standard portion") ||
               lower.Contains("default portion") ||
               lower.Contains("masterchef");
    }

    /// <summary>
    /// Chuẩn hóa ảnh đại diện cho món ăn, loại bỏ ảnh placeholder sườn nướng BBQ bị lặp lại cho các món xào/mực/rau
    /// </summary>
    public static void SanitizeMealImage(RecommendedMealDto meal)
    {
        if (meal == null) return;
        string current = meal.StrMealThumb ?? "";

        // Giữ nguyên ảnh chụp món gốc từ TheMealDB
        if (current.Contains("themealdb.com", StringComparison.OrdinalIgnoreCase)) return;

        // Tuyệt đối không gán ảnh Unsplash ngẫu nhiên không liên quan (như đĩa than vinyl, búp cải trong đất...)
        // Để chuỗi rỗng để Client hiển thị Icon món ăn chuẩn xác theo nhóm thực phẩm
        if (current.Contains("unsplash.com", StringComparison.OrdinalIgnoreCase))
        {
            meal.StrMealThumb = "";
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
        var usedIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var usedThumbs = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // 1. Chọn 1 hoặc 2 món trùng với ngày hôm trước (dayOfYear - 1) từ top 10 món phù hợp nhất
        int topPoolSize = Math.Min(10, sortedMeals.Count);
        int overlapCount = limit <= 4 ? 1 : 2;

        int yesterdaySeed1 = Math.Abs((dayOfYear - 1) * 7) % topPoolSize;
        var overlapMeal1 = sortedMeals[yesterdaySeed1];
        result.Add(overlapMeal1);
        usedIds.Add(overlapMeal1.IdMeal);
        if (!string.IsNullOrWhiteSpace(overlapMeal1.StrMealThumb)) usedThumbs.Add(overlapMeal1.StrMealThumb);

        if (overlapCount > 1)
        {
            int yesterdaySeed2 = Math.Abs((dayOfYear - 1) * 13 + 3) % topPoolSize;
            if (yesterdaySeed2 == yesterdaySeed1)
            {
                yesterdaySeed2 = (yesterdaySeed1 + 1) % topPoolSize;
            }
            var overlapMeal2 = sortedMeals[yesterdaySeed2];
            if (!usedIds.Contains(overlapMeal2.IdMeal) &&
                (string.IsNullOrWhiteSpace(overlapMeal2.StrMealThumb) || !usedThumbs.Contains(overlapMeal2.StrMealThumb)))
            {
                result.Add(overlapMeal2);
                usedIds.Add(overlapMeal2.IdMeal);
                if (!string.IsNullOrWhiteSpace(overlapMeal2.StrMealThumb)) usedThumbs.Add(overlapMeal2.StrMealThumb);
            }
        }

        // 2. Chọn các món còn lại: Kết hợp giữa điểm số cao và hàm xoay vòng theo ngày + lượt refresh
        // Điều này đảm bảo:
        // - Ngày hôm nay khác ngày hôm trước
        // - Mỗi lần reload/refresh người dùng nhận được các món mới
        // - Luôn ưu tiên các món có MatchScore cao
        // - Tuyệt đối không trùng ảnh hiển thị giữa các món kề nhau
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
            // Chống trùng ảnh: Không cho phép 2 món trong cùng danh sách hiển thị dùng chung 1 ảnh
            if (!string.IsNullOrWhiteSpace(meal.StrMealThumb) && usedThumbs.Contains(meal.StrMealThumb))
            {
                continue;
            }
            result.Add(meal);
            usedIds.Add(meal.IdMeal);
            if (!string.IsNullOrWhiteSpace(meal.StrMealThumb))
            {
                usedThumbs.Add(meal.StrMealThumb);
            }
        }

        // Nếu sau khi lọc trùng ảnh mà danh sách vẫn chưa đủ limit, bù thêm các món còn lại
        if (result.Count < limit)
        {
            foreach (var meal in remainingCandidates)
            {
                if (result.Count >= limit) break;
                if (!usedIds.Contains(meal.IdMeal))
                {
                    result.Add(meal);
                    usedIds.Add(meal.IdMeal);
                }
            }
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
    /// THUẬT TOÁN TÌM KIẾM MÓN ĂN THEO ĐA NGUYÊN LIỆU (C# Backend Multi-Ingredient Ranking)
    /// - Hỗ trợ lọc đồng thời nhiều nguyên liệu (ví dụ: Thịt heo + Cá hồi, hoặc Thịt bò + Hành tây).
    /// - Món kết hợp 2 nguyên liệu trở lên được ưu tiên tuyệt đối lên đầu (Tier 1).
    /// - Món đơn nguyên liệu được xếp hạng công bằng (Round-Robin Interleaved) xen kẽ giữa các nguyên liệu (Tier 2).
    /// - Phạt điểm các món thiếu nhiều nguyên liệu chính (ví dụ: người dùng chỉ có thịt heo thì món Rang Cháy Cạnh, Thịt Luộc xếp trước Canh Bí Đao).
    /// - Tuyệt đối không để Nước Mắm (Fish Sauce) bị nhận nhầm thành Cá / Cá hồi.
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
        string cacheKey = $"meals_multi_ing_v3_{cacheKeysJoined}_{lang}_{limit}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cached) && cached != null)
        {
            return cached;
        }

        bool hasMeat = classifiedList.Any(c => c.IsMeat);
        bool hasVeggie = classifiedList.Any(c => c.IsVeggie);
        bool userWantsCombination = hasMeat && hasVeggie;
        int totalSelected = classifiedList.Count;

        // 2. NẠP TOÀN BỘ KHO CÔNG THỨC CƠ SỞ DỮ LIỆU CỤC BỘ (1,100+ MÓN)
        var masterRecipes = await GetAllDatabaseRecipesAsync();

        // 3. ĐỐI SOÁT & PHÂN NHÓM MÓN ĂN
        var multiMatchList = new List<RecommendedMealDto>();
        var singleMatchPerIngredient = new Dictionary<string, List<RecommendedMealDto>>(StringComparer.OrdinalIgnoreCase);
        foreach (var ing in classifiedList)
        {
            singleMatchPerIngredient[ing.CleanKey] = new List<RecommendedMealDto>();
        }

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

            if (matchCount == 0) continue;

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
            SanitizeMealMeasures(cloned);

            int missingMajor = GetMissingMajorIngredientsCount(cloned, classifiedList);

            if (matchCount >= 2)
            {
                // Tier 1: Món khớp từ 2 nguyên liệu trở lên (Món kết hợp đỉnh cao)
                cloned.MatchScore = Math.Min(99, 94 + (matchCount * 2) - Math.Min(4, missingMajor));
                cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp"));
                cloned.Badges.Insert(0, $"✨ Khớp {matchCount}/{totalSelected} NL");
                if (cloned.IdMeal.StartsWith("vn_home_") || cloned.StrArea == "Vietnamese")
                {
                    if (!cloned.Badges.Contains("🇻🇳 Món Việt")) cloned.Badges.Add("🇻🇳 Món Việt");
                }
                else
                {
                    if (!cloned.Badges.Contains("🌍 TheMealDB")) cloned.Badges.Add("🌍 TheMealDB");
                }
                if (matchedIngs.Any(i => i.IsMeat) && matchedIngs.Any(i => i.IsVeggie) && !cloned.Badges.Contains("🥗 Cân bằng Dinh dưỡng"))
                {
                    cloned.Badges.Add("🥗 Cân bằng Dinh dưỡng");
                }
                multiMatchList.Add(cloned);
            }
            else
            {
                // Tier 2: Món khớp 1 nguyên liệu duy nhất
                var matchedIng = matchedIngs[0];
                // Ưu tiên các món có ít nguyên liệu chính bị thiếu (chỉ cần gia vị bếp là nấu được)
                cloned.MatchScore = Math.Max(70, 95 - (missingMajor * 7));
                cloned.Badges.RemoveAll(b => b.StartsWith("✨ Khớp") || b.StartsWith("Khớp") || b.StartsWith("🐟") || b.StartsWith("🥩") || b.StartsWith("🍗") || b.StartsWith("🌱") || b.StartsWith("🦐"));

                string badgeTitle = GetIngredientBadge(matchedIng);
                cloned.Badges.Insert(0, badgeTitle);

                if (singleMatchPerIngredient.TryGetValue(matchedIng.CleanKey, out var list))
                {
                    list.Add(cloned);
                }
            }
        }

        // 4. SẮP XẾP TỪNG NHÓM
        // Nhóm multi-match: Ưu tiên món Việt Nam, điểm match cao, ít thiếu nguyên liệu
        multiMatchList = multiMatchList
            .OrderByDescending(m => (m.StrArea == "Vietnamese" || m.IdMeal.StartsWith("vn_home_")) ? 1 : 0)
            .ThenBy(m => GetMissingMajorIngredientsCount(m, classifiedList))
            .ThenByDescending(m => m.MatchScore)
            .ToList();

        // Từng nhóm single-match: Phân bổ công bằng và xen kẽ giữa món Việt Nam (vn_home_) và món Quốc Tế TheMealDB
        foreach (var key in singleMatchPerIngredient.Keys.ToList())
        {
            var allItems = singleMatchPerIngredient[key];
            var vnList = allItems
                .Where(m => m.IdMeal.StartsWith("vn_home_") || m.StrArea == "Vietnamese")
                .OrderBy(m => GetMissingMajorIngredientsCount(m, classifiedList))
                .ThenByDescending(m => m.MatchScore)
                .ToList();

            var themealdbList = allItems
                .Where(m => !m.IdMeal.StartsWith("vn_home_") && m.StrArea != "Vietnamese")
                .OrderBy(m => GetMissingMajorIngredientsCount(m, classifiedList))
                .ThenByDescending(m => m.MatchScore)
                .ToList();

            // Gắn nhãn phân biệt nguồn gốc dữ liệu rõ ràng cho người dùng
            foreach (var m in vnList)
            {
                m.Badges.RemoveAll(b => b.Contains("Món Việt") || b.Contains("TheMealDB"));
                m.Badges.Insert(0, "🇻🇳 Món Việt");
            }
            foreach (var m in themealdbList)
            {
                m.Badges.RemoveAll(b => b.Contains("Món Việt") || b.Contains("TheMealDB"));
                m.Badges.Insert(0, "🌍 TheMealDB");
            }

            // Xen kẽ công bằng: 1 món Việt, 1 món TheMealDB quốc tế
            var blended = new List<RecommendedMealDto>();
            int maxItems = Math.Max(vnList.Count, themealdbList.Count);
            for (int i = 0; i < maxItems; i++)
            {
                if (i < vnList.Count) blended.Add(vnList[i]);
                if (i < themealdbList.Count) blended.Add(themealdbList[i]);
            }
            singleMatchPerIngredient[key] = blended;
        }

        // 5. TRỘN KẾT QUẢ CÔNG BẰNG (FAIR ROUND-ROBIN INTERLEAVE)
        var finalResults = new List<RecommendedMealDto>();
        var seenIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Đưa toàn bộ món kết hợp nhiều nguyên liệu lên trước
        foreach (var m in multiMatchList)
        {
            if (seenIds.Add(m.IdMeal))
            {
                finalResults.Add(m);
                if (finalResults.Count >= limit) break;
            }
        }

        // Xen kẽ các món đơn nguyên liệu giữa các nguyên liệu đã chọn (1 món NL 1, 1 món NL 2, 1 món NL 1...)
        if (finalResults.Count < limit && singleMatchPerIngredient.Count > 0)
        {
            int maxPerGroup = singleMatchPerIngredient.Values.Count > 0
                ? singleMatchPerIngredient.Values.Max(v => v.Count)
                : 0;

            for (int round = 0; round < maxPerGroup; round++)
            {
                foreach (var ing in classifiedList)
                {
                    if (singleMatchPerIngredient.TryGetValue(ing.CleanKey, out var groupList))
                    {
                        if (round < groupList.Count)
                        {
                            var meal = groupList[round];
                            if (seenIds.Add(meal.IdMeal))
                            {
                                finalResults.Add(meal);
                                if (finalResults.Count >= limit) break;
                            }
                        }
                    }
                }
                if (finalResults.Count >= limit) break;
            }
        }

        // 6. TỰ ĐỘNG DỊCH TIẾNG VIỆT CHO CÁC MÓN CHƯA CÓ BẢN DỊCH (chạy song song)
        if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase))
        {
            var transTasks = finalResults
                .Where(m => string.IsNullOrWhiteSpace(m.StrMealVi) || m.StrMealVi == m.StrMeal)
                .Select(async m =>
                {
                    m.StrMealVi = await _translationService.TranslateAsync(m.StrMeal, "vi", "en");
                });
            await Task.WhenAll(transTasks);
        }

        _cache.Set(cacheKey, finalResults, TimeSpan.FromHours(1));
        return finalResults;
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
        string rawLower = ing.Raw.Trim().ToLower();
        string cleanKey = ing.CleanKey.ToLower();
        string viKey = ing.ViKey.ToLower();

        // 1. Kiểm tra nguyên liệu tiếng Anh
        if (recipe.Ingredients != null && recipe.Ingredients.Any(i =>
        {
            string lower = i.ToLower();
            if (cleanKey == "chicken" && (lower.Contains("stock") || lower.Contains("broth") || lower.Contains("bouillon") || lower.Contains("cube") || lower.Contains("powder")))
            {
                return false;
            }
            if (cleanKey == "beef" && (lower.Contains("stock") || lower.Contains("broth") || lower.Contains("bouillon") || lower.Contains("cube") || lower.Contains("powder")))
            {
                return false;
            }
            if (ing.IsVeggie && (lower.Contains("stock") || lower.Contains("broth") || lower.Contains("bouillon") || lower.Contains("powder")))
            {
                return false;
            }

            // TUYỆT ĐỐI KHÔNG KHỚP Nước mắm (Fish Sauce), Mắm tôm, Dầu hào khi tìm kiếm Cá hoặc Cá hồi!
            if ((cleanKey == "fish" || cleanKey == "salmon" || viKey == "cá" || viKey == "cá hồi") &&
                (lower.Contains("sauce") || lower.Contains("paste") || lower.Contains("stock") || lower.Contains("broth") || lower.Contains("cube") || lower.Contains("powder")))
            {
                return false;
            }

            // Với Cá hồi: chỉ khớp nếu có chữ salmon hoặc cá hồi
            if (cleanKey == "salmon" || viKey == "cá hồi")
            {
                return lower.Contains("salmon") || lower.Contains("cá hồi");
            }

            // Với Rau muống (Water Spinach / Morning Glory)
            if (cleanKey == "water spinach" || viKey == "rau muống")
            {
                return lower.Contains("water spinach") || lower.Contains("morning glory") || lower.Contains("rau muống");
            }

            // Với Cải ngồng (Chinese Broccoli / Gai Lan)
            if (cleanKey == "chinese broccoli" || viKey == "cải ngồng")
            {
                return lower.Contains("chinese broccoli") || lower.Contains("gai lan") || lower.Contains("cải ngồng");
            }

            if (lower.Equals(cleanKey, StringComparison.OrdinalIgnoreCase) ||
                lower.Contains(cleanKey, StringComparison.OrdinalIgnoreCase) ||
                lower.Contains(rawLower, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            // Hỗ trợ từ đồng nghĩa tiếng Anh
            if (cleanKey == "shrimp" && (lower.Contains("prawn") || lower.Contains("shrimp"))) return true;
            if (cleanKey == "pork" && (lower.Contains("bacon") || lower.Contains("ham") || lower.Contains("pork"))) return true;
            if (cleanKey == "beef" && (lower.Contains("steak") || lower.Contains("beef") || lower.Contains("sirloin"))) return true;
            if (cleanKey == "cheese" && (lower.Contains("cheddar") || lower.Contains("mozzarella") || lower.Contains("parmesan") || lower.Contains("feta") || lower.Contains("cheese"))) return true;
            if (cleanKey == "coconut" && (lower.Contains("coconut") || lower.Contains("coconut milk") || lower.Contains("coconut cream"))) return true;
            if (cleanKey == "squid" && (lower.Contains("squid") || lower.Contains("calamari"))) return true;
            if (cleanKey == "clam" && (lower.Contains("clam") || lower.Contains("mussel"))) return true;

            return false;
        }))
        {
            return true;
        }

        // 2. Kiểm tra danh mục (Category)
        if (!string.IsNullOrEmpty(recipe.StrCategory))
        {
            string catLower = recipe.StrCategory.ToLower();
            if (cleanKey == "salmon" || viKey == "cá hồi")
            {
                // Cá hồi không dùng danh mục chung mà yêu cầu tên hoặc nguyên liệu chính xác
            }
            else if (catLower.Equals(cleanKey, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
            else if (cleanKey == "fish" && catLower.Contains("fish"))
            {
                return true;
            }
        }

        // 3. Kiểm tra tên món
        string mealEn = (recipe.StrMeal ?? "").ToLower();
        string mealVi = (recipe.StrMealVi ?? "").ToLower();
        if (cleanKey == "salmon" || viKey == "cá hồi")
        {
            if (mealEn.Contains("salmon") || (!string.IsNullOrEmpty(mealVi) && mealVi.Contains("cá hồi")))
            {
                return true;
            }
        }
        else if (cleanKey == "water spinach" || viKey == "rau muống")
        {
            if (mealEn.Contains("morning glory") || mealEn.Contains("water spinach") || (!string.IsNullOrEmpty(mealVi) && mealVi.Contains("rau muống")))
            {
                return true;
            }
        }
        else if (cleanKey == "chinese broccoli" || viKey == "cải ngồng")
        {
            if (mealEn.Contains("chinese broccoli") || mealEn.Contains("gai lan") || (!string.IsNullOrEmpty(mealVi) && (mealVi.Contains("cải ngồng") || mealVi.Contains("cải ngọt"))))
            {
                return true;
            }
        }
        else if (mealEn.Contains(cleanKey) || mealEn.Contains(rawLower) ||
            (!string.IsNullOrEmpty(mealVi) && (mealVi.Contains(viKey) || mealVi.Contains(rawLower))))
        {
            return true;
        }

        // 4. Kiểm tra nguyên liệu tiếng Việt
        if (recipe.IngredientsVi != null && recipe.IngredientsVi.Count > 0)
        {
            foreach (var viIng in recipe.IngredientsVi)
            {
                string lowerIng = viIng.ToLower();
                if (cleanKey == "chicken" && (lowerIng.Contains("nấm") || lowerIng.Contains("trứng") || lowerIng.Contains("nước dùng") || lowerIng.Contains("hạt nêm")))
                {
                    continue;
                }
                if (cleanKey == "beef" && (lowerIng.Contains("nước dùng") || lowerIng.Contains("hạt nêm")))
                {
                    continue;
                }

                // TUYỆT ĐỐI KHÔNG KHỚP Nước mắm, mắm ruốc, mắm tôm khi tìm cá / cá hồi!
                if ((cleanKey == "fish" || cleanKey == "salmon" || viKey == "cá" || viKey == "cá hồi") &&
                    (lowerIng.Contains("nước mắm") || lowerIng.Contains("mắm tôm") || lowerIng.Contains("mắm ruốc") || lowerIng.Contains("mắm nêm") || lowerIng.Contains("dầu hào")))
                {
                    continue;
                }

                // Với Cá hồi
                if (cleanKey == "salmon" || viKey == "cá hồi")
                {
                    if (lowerIng.Contains("cá hồi") || lowerIng.Contains("salmon")) return true;
                    continue;
                }

                // Khi tìm kiếm rau củ: TUYỆT ĐỐI LOẠI TRỪ các loại rau thơm/ngò rí/rau răm trang trí và nước hầm rau củ
                if (ing.IsVeggie)
                {
                    bool isAromaticOrBroth = lowerIng.Contains("ngò rí") || lowerIng.Contains("ngò gai") || lowerIng.Contains("rau mùi") ||
                                             lowerIng.Contains("rau răm") || lowerIng.Contains("rau thơm") || lowerIng.Contains("hành lá") ||
                                             lowerIng.Contains("nước hầm") || lowerIng.Contains("nước dùng");
                    if (isAromaticOrBroth && viKey != "ngò" && viKey != "mùi" && viKey != "rau răm" && viKey != "rau thơm" && viKey != "hành")
                    {
                        continue;
                    }
                }

                // Với rau muống: chỉ khớp nếu có chữ "muống" hoặc "water spinach"
                if (viKey == "rau muống" || cleanKey == "water spinach")
                {
                    if (lowerIng.Contains("muống") || lowerIng.Contains("water spinach") || lowerIng.Contains("morning glory"))
                    {
                        return true;
                    }
                    continue;
                }

                // Với cải ngồng: chỉ khớp cải ngồng
                if (viKey == "cải ngồng" || cleanKey == "chinese broccoli")
                {
                    if (lowerIng.Contains("cải ngồng") || lowerIng.Contains("chinese broccoli") || lowerIng.Contains("gai lan"))
                    {
                        return true;
                    }
                    continue;
                }

                if (lowerIng.Contains(viKey) || lowerIng.Contains(rawLower) || (!string.IsNullOrEmpty(cleanKey) && lowerIng.Contains(cleanKey)))
                {
                    return true;
                }
            }
        }

        return false;
    }

    private static bool IsPantryStapleOrSeasoning(string ing)
    {
        if (string.IsNullOrWhiteSpace(ing)) return true;
        string lower = ing.Trim().ToLower();
        return lower.Contains("sauce") || lower.Contains("mắm") || lower.Contains("tương") || lower.Contains("dầu hào") ||
               lower.Contains("oil") || lower.Contains("dầu ăn") || lower.Contains("mỡ") ||
               lower.Contains("salt") || lower.Contains("muối") || lower.Contains("bột canh") || lower.Contains("hạt nêm") ||
               lower.Contains("sugar") || lower.Contains("đường") ||
               lower.Contains("pepper") || lower.Contains("tiêu") ||
               lower.Contains("garlic") || lower.Contains("tỏi") ||
               lower.Contains("shallot") || lower.Contains("hành tím") || lower.Contains("hành khô") ||
               lower.Contains("ginger") || lower.Contains("gừng") ||
               lower.Contains("chili") || lower.Contains("ớt") ||
               lower.Contains("lemon") || lower.Contains("chanh") || lower.Contains("giấm") || lower.Contains("vinegar") ||
               lower.Contains("butter") || lower.Contains("bơ") ||
               lower.Contains("water") || lower.Contains("nước") ||
               lower.Contains("scallion") || lower.Contains("hành hoa") || lower.Contains("hành lá") ||
               lower.Contains("cilantro") || lower.Contains("ngò") || lower.Contains("mùi");
    }

    private static int GetMissingMajorIngredientsCount(RecommendedMealDto recipe, List<IngredientInfo> userIngredients)
    {
        var ings = (recipe.IngredientsVi != null && recipe.IngredientsVi.Count > 0)
            ? recipe.IngredientsVi
            : recipe.Ingredients;

        if (ings == null || ings.Count == 0) return 0;

        int missing = 0;
        foreach (var ing in ings)
        {
            if (IsPantryStapleOrSeasoning(ing)) continue;

            bool matched = false;
            foreach (var userIng in userIngredients)
            {
                string lower = ing.ToLower();
                if (lower.Contains(userIng.ViKey) || lower.Contains(userIng.CleanKey) || lower.Contains(userIng.Raw.ToLower()))
                {
                    matched = true;
                    break;
                }
            }
            if (!matched)
            {
                missing++;
            }
        }
        return missing;
    }

    private static string GetIngredientBadge(IngredientInfo ing)
    {
        string k = ing.CleanKey.ToLower();
        if (k == "salmon") return "🐟 Món từ Cá hồi";
        if (k == "fish") return "🐟 Món từ Cá";
        if (k == "pork") return "🥩 Món từ Thịt heo";
        if (k == "beef") return "🥩 Món từ Thịt bò";
        if (k == "chicken") return "🍗 Món từ Thịt gà";
        if (k == "shrimp") return "🦐 Món từ Tôm";
        if (k == "egg") return "🍳 Món từ Trứng";
        if (k == "squid") return "🦑 Món từ Mực";
        if (k == "crab") return "🦀 Món từ Cua";
        if (ing.IsVeggie) return $"🌱 Món từ {ing.Raw}";
        return $"✨ Món từ {ing.Raw}";
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

        // Trứng
        if (lower.Contains("trứng") || clean.Contains("egg"))
        {
            clean = "egg";
            viKey = "trứng";
            isMeat = true;
        }
        // Thịt bò
        else if (lower.Contains("bò") || clean.Contains("beef"))
        {
            clean = "beef";
            viKey = "bò";
            isMeat = true;
        }
        // Thịt heo / lợn
        else if (lower.Contains("heo") || lower.Contains("lợn") || lower.Contains("ba chỉ") || lower.Contains("ba rọi") || clean.Contains("pork"))
        {
            clean = "pork";
            viKey = "heo";
            isMeat = true;
        }
        // Thịt gà
        else if (lower.Contains("gà") || clean.Contains("chicken"))
        {
            clean = "chicken";
            viKey = "gà";
            isMeat = true;
        }
        // Vịt
        else if (lower.Contains("vịt") || clean.Contains("duck"))
        {
            clean = "duck";
            viKey = "vịt";
            isMeat = true;
        }
        // Cừu
        else if (lower.Contains("cừu") || clean.Contains("lamb"))
        {
            clean = "lamb";
            viKey = "cừu";
            isMeat = true;
        }
        // Sườn
        else if (lower.Contains("sườn") || clean.Contains("rib"))
        {
            clean = "ribs";
            viKey = "sườn";
            isMeat = true;
        }
        // Xúc xích / thịt nguội / giăm bông
        else if (lower.Contains("xúc xích") || lower.Contains("dăm bông") || lower.Contains("giăm bông") || lower.Contains("chả"))
        {
            clean = "sausage";
            viKey = lower;
            isMeat = true;
        }
        // Tôm
        else if (lower.Contains("tôm") || clean.Contains("shrimp") || clean.Contains("prawn"))
        {
            clean = "shrimp";
            viKey = "tôm";
            isMeat = true;
        }
        // Cá hồi
        else if (lower.Contains("cá hồi") || lower.Contains("salmon") || clean.Contains("salmon"))
        {
            clean = "salmon";
            viKey = "cá hồi";
            isMeat = true;
        }
        // Cá chung
        else if (lower.Contains("cá") || clean.Contains("fish"))
        {
            clean = "fish";
            viKey = "cá";
            isMeat = true;
        }
        // Mực
        else if (lower.Contains("mực") || clean.Contains("squid") || clean.Contains("calamari"))
        {
            clean = "squid";
            viKey = "mực";
            isMeat = true;
        }
        // Cua / ghẹ
        else if (lower.Contains("cua") || lower.Contains("ghẹ") || clean.Contains("crab"))
        {
            clean = "crab";
            viKey = "cua";
            isMeat = true;
        }
        // Ngao / nghêu / sò
        else if (lower.Contains("ngao") || lower.Contains("nghêu") || lower.Contains("sò") || clean.Contains("clam") || clean.Contains("mussel"))
        {
            clean = "clam";
            viKey = "ngao";
            isMeat = true;
        }
        // Cà chua
        else if (lower.Contains("cà chua") || clean.Contains("tomato"))
        {
            clean = "tomato";
            viKey = "cà chua";
            isVeggie = true;
        }
        // Bông cải / súp lơ
        else if (lower.Contains("bông cải") || lower.Contains("súp lơ") || clean.Contains("broccoli"))
        {
            clean = "broccoli";
            viKey = "bông cải";
            isVeggie = true;
        }
        // Cà rốt
        else if (lower.Contains("cà rốt") || clean.Contains("carrot"))
        {
            clean = "carrot";
            viKey = "cà rốt";
            isVeggie = true;
        }
        // Nấm
        else if (lower.Contains("nấm") || clean.Contains("mushroom"))
        {
            clean = "mushroom";
            viKey = "nấm";
            isVeggie = true;
        }
        // Khoai tây
        else if (lower.Contains("khoai tây") || clean.Contains("potato"))
        {
            clean = "potato";
            viKey = "khoai tây";
            isVeggie = true;
        }
        // Khoai lang
        else if (lower.Contains("khoai lang"))
        {
            clean = "sweet potato";
            viKey = "khoai lang";
            isVeggie = true;
        }
        // Hành tây / hành
        else if (lower.Contains("hành tây") || lower.Contains("hành lá") || lower.Contains("hành tím") || lower.Contains("hành") || clean.Contains("onion"))
        {
            clean = "onion";
            viKey = "hành";
            isVeggie = true;
        }
        // Tỏi
        else if (lower.Contains("tỏi") || clean.Contains("garlic"))
        {
            clean = "garlic";
            viKey = "tỏi";
            isVeggie = true;
        }
        // Gừng
        else if (lower.Contains("gừng") || clean.Contains("ginger"))
        {
            clean = "ginger";
            viKey = "gừng";
            isVeggie = true;
        }
        // Sả
        else if (lower.Contains("sả") || clean.Contains("lemongrass"))
        {
            clean = "lemongrass";
            viKey = "sả";
            isVeggie = true;
        }
        // Ớt
        else if (lower.Contains("ớt") || clean.Contains("chili"))
        {
            clean = "chili";
            viKey = "ớt";
            isVeggie = true;
        }
        // Chanh
        else if (lower.Contains("chanh") || clean.Contains("lemon") || clean.Contains("lime"))
        {
            clean = "lemon";
            viKey = "chanh";
            isVeggie = true;
        }
        // Cốt dừa
        else if (lower.Contains("cốt dừa") || lower.Contains("nước cốt dừa") || clean.Contains("coconut"))
        {
            clean = "coconut";
            viKey = "cốt dừa";
            isVeggie = true;
        }
        // Măng tây
        else if (lower.Contains("măng tây") || clean.Contains("asparagus"))
        {
            clean = "asparagus";
            viKey = "măng tây";
            isVeggie = true;
        }
        // Đậu phụ / đậu hũ
        else if (lower.Contains("đậu phụ") || lower.Contains("đậu hũ") || clean.Contains("tofu"))
        {
            clean = "tofu";
            viKey = "đậu phụ";
            isVeggie = true;
        }
        // Mướp
        else if (lower.Contains("mướp") || clean.Contains("luffa"))
        {
            clean = "luffa";
            viKey = "mướp";
            isVeggie = true;
        }
        // Rau muống (Water Spinach / Morning Glory)
        else if (lower.Contains("rau muống") || lower.Contains("muống") || clean.Contains("water_spinach") || clean.Contains("morning_glory") || clean.Contains("water spinach"))
        {
            clean = "water spinach";
            viKey = "rau muống";
            isVeggie = true;
        }
        // Cải ngồng (Chinese Broccoli / Gai Lan)
        else if (lower.Contains("cải ngồng") || clean.Contains("chinese_broccoli") || clean.Contains("chinese broccoli") || clean.Contains("gai lan"))
        {
            clean = "chinese broccoli";
            viKey = "cải ngồng";
            isVeggie = true;
        }
        // Rau cải (Cải thìa, cải ngọt, cải xanh, cải chua, bok choy, choy sum)
        else if (lower.Contains("cải thìa") || lower.Contains("cải ngọt") || lower.Contains("cải xanh") || lower.Contains("cải chua") || lower.Contains("cải") || clean.Contains("bok choy") || clean.Contains("pak choi") || clean.Contains("choy sum") || clean.Contains("mustard_greens") || clean.Contains("pickled_greens"))
        {
            clean = "bok choy";
            viKey = "rau cải";
            isVeggie = true;
        }
        // Rau bina / Cải bó xôi (Spinach)
        else if (lower.Contains("bina") || lower.Contains("bó xôi") || lower.Contains("chân vịt") || clean.Contains("spinach"))
        {
            clean = "spinach";
            viKey = "cải bó xôi";
            isVeggie = true;
        }
        // Bắp cải (Cabbage)
        else if (lower.Contains("bắp cải") || clean.Contains("cabbage"))
        {
            clean = "cabbage";
            viKey = "bắp cải";
            isVeggie = true;
        }
        // Xà lách (Lettuce / Salad)
        else if (lower.Contains("xà lách") || clean.Contains("lettuce"))
        {
            clean = "lettuce";
            viKey = "xà lách";
            isVeggie = true;
        }
        // Các loại rau xanh khác
        else if (lower.Contains("rau"))
        {
            clean = "greens";
            viKey = "rau";
            isVeggie = true;
        }
        // Phô mai
        else if (lower.Contains("phô mai") || clean.Contains("cheese"))
        {
            clean = "cheese";
            viKey = "phô mai";
            isVeggie = false;
            isMeat = false;
        }
        // Bơ
        else if (lower.Contains("bơ") || clean.Contains("butter"))
        {
            clean = "butter";
            viKey = "bơ";
            isVeggie = false;
            isMeat = false;
        }
        else
        {
            isVeggie = true;
        }

        return new IngredientInfo(raw, clean, viKey, isMeat, isVeggie);
    }

    /// <summary>
    /// 4. Tìm kiếm món ăn theo từ khóa trên toàn bộ Cơ Sở Dữ Liệu Cục Bộ (1,100+ món)
    /// Hỗ trợ tìm kiếm theo tiếng Việt, tiếng Anh, tên món, danh mục, khu vực và nguyên liệu.
    /// </summary>
    public async Task<List<RecommendedMealDto>> SearchMealsAsync(string query, string lang = "vi")
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return new List<RecommendedMealDto>();
        }

        string rawQuery = query.Trim();
        string cleanQuery = MapSearchQuery(rawQuery).ToLower();
        string lowerQuery = rawQuery.ToLower();

        string cacheKey = $"local_meals_search_{lowerQuery}_{lang}";
        if (_cache.TryGetValue(cacheKey, out List<RecommendedMealDto>? cached) && cached != null)
        {
            return cached;
        }

        var results = new List<RecommendedMealDto>();
        try
        {
            var all = await GetAllDatabaseRecipesAsync();

            // Tính điểm tương đồng cho từng món
            var scoredMeals = new List<(RecommendedMealDto Meal, int Score)>();

            foreach (var item in all)
            {
                int score = 0;
                string mealName = item.StrMeal.ToLower();
                string mealNameVi = (item.StrMealVi ?? "").ToLower();
                string category = (item.StrCategory ?? "").ToLower();
                string area = (item.StrArea ?? "").ToLower();

                // 1. Tên món khớp chính xác hoặc bắt đầu bằng từ khóa
                if (mealName == lowerQuery || mealNameVi == lowerQuery) score += 100;
                else if (mealName.StartsWith(lowerQuery) || mealNameVi.StartsWith(lowerQuery)) score += 80;
                else if (mealName.Contains(lowerQuery) || mealNameVi.Contains(lowerQuery)) score += 60;
                else if (cleanQuery != lowerQuery && (mealName.Contains(cleanQuery) || mealNameVi.Contains(cleanQuery))) score += 50;

                // 2. Danh mục hoặc khu vực ẩm thực khớp
                if (category == lowerQuery || category == cleanQuery) score += 40;
                else if (category.Contains(lowerQuery) || category.Contains(cleanQuery)) score += 30;
                if (area.Contains(lowerQuery) || area.Contains(cleanQuery)) score += 20;

                // 3. Nguyên liệu trong món ăn khớp
                bool ingMatched = (item.Ingredients != null && item.Ingredients.Any(i => i.Contains(lowerQuery, StringComparison.OrdinalIgnoreCase) || i.Contains(cleanQuery, StringComparison.OrdinalIgnoreCase))) ||
                                  (item.IngredientsVi != null && item.IngredientsVi.Any(i => i.Contains(lowerQuery, StringComparison.OrdinalIgnoreCase)));
                if (ingMatched) score += 35;

                // 4. Huy hiệu (Badges) hoặc Mã món khớp (MasterChef, Vua Đầu Bếp, Eat Clean...)
                bool badgeMatched = item.Badges != null && item.Badges.Any(b => b.Contains(lowerQuery, StringComparison.OrdinalIgnoreCase) || b.Contains(cleanQuery, StringComparison.OrdinalIgnoreCase) || b.ToLower().Contains("masterchef") || b.ToLower().Contains("vua đầu bếp"));
                if (badgeMatched && (lowerQuery.Contains("master") || lowerQuery.Contains("chef") || lowerQuery.Contains("đầu bếp") || cleanQuery.Contains("masterchef")))
                {
                    score += 75;
                }
                else if (badgeMatched)
                {
                    score += 30;
                }

                if (item.IdMeal.StartsWith("mc_", StringComparison.OrdinalIgnoreCase) && (lowerQuery.Contains("master") || lowerQuery.Contains("chef") || lowerQuery.Contains("đầu bếp") || cleanQuery.Contains("masterchef")))
                {
                    score += 85;
                }

                if (score > 0)
                {
                    var dto = new RecommendedMealDto
                    {
                        IdMeal = item.IdMeal,
                        StrMeal = item.StrMeal,
                        StrMealVi = item.StrMealVi,
                        StrMealThumb = item.StrMealThumb,
                        StrCategory = item.StrCategory,
                        StrArea = item.StrArea,
                        StrInstructions = item.StrInstructions,
                        StrInstructionsVi = item.StrInstructionsVi,
                        StrYoutube = item.StrYoutube,
                        Ingredients = item.Ingredients != null ? new List<string>(item.Ingredients) : new List<string>(),
                        IngredientsVi = item.IngredientsVi != null ? new List<string>(item.IngredientsVi) : new List<string>(),
                        Measures = item.Measures != null ? new List<string>(item.Measures) : new List<string>(),
                        MeasuresVi = item.MeasuresVi != null ? new List<string>(item.MeasuresVi) : new List<string>(),
                        EstimatedCalories = item.EstimatedCalories,
                        EstimatedProtein = item.EstimatedProtein,
                        EstimatedCarbs = item.EstimatedCarbs,
                        EstimatedFat = item.EstimatedFat
                    };
                    CalculateNutrition(dto);
                    SanitizeMealMeasures(dto);
                    scoredMeals.Add((dto, score));
                }
            }

            results = scoredMeals
                .OrderByDescending(x => x.Score)
                .Select(x => x.Meal)
                .Take(40)
                .ToList();

            if (lang.Equals("vi", StringComparison.OrdinalIgnoreCase))
            {
                foreach (var m in results.Take(25))
                {
                    if (string.IsNullOrWhiteSpace(m.StrMealVi) || m.StrMealVi == m.StrMeal)
                    {
                        m.StrMealVi = await _translationService.TranslateAsync(m.StrMeal, "vi", "en");
                    }
                }
            }

            _cache.Set(cacheKey, results, TimeSpan.FromHours(1));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi tìm món trong cơ sở dữ liệu với từ khóa {Query}", query);
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
            ["đùi_gà"] = "chicken",
            ["cánh_gà"] = "chicken",
            ["thịt_bò"] = "beef",
            ["bò"] = "beef",
            ["thịt_bắp_bò"] = "beef",
            ["bít_tết"] = "steak",
            ["thịt_heo"] = "pork",
            ["thịt_lợn"] = "pork",
            ["heo"] = "pork",
            ["lợn"] = "pork",
            ["ba_chỉ"] = "pork",
            ["ba_rọi"] = "pork",
            ["thịt_băm"] = "pork",
            ["sườn"] = "ribs",
            ["sườn_heo"] = "ribs",
            ["sườn_non"] = "ribs",
            ["vịt"] = "duck",
            ["thịt_vịt"] = "duck",
            ["cừu"] = "lamb",
            ["thịt_cừu"] = "lamb",
            ["xúc_xích"] = "sausage",
            ["thịt_xông_khói"] = "bacon",
            ["dăm_bông"] = "ham",
            ["giăm_bông"] = "ham",
            ["chả"] = "sausage",
            ["trứng"] = "egg",
            ["trứng_gà"] = "egg",
            ["trứng_vịt"] = "egg",
            ["cà_chua"] = "tomato",
            ["khoai_tây"] = "potato",
            ["khoai_lang"] = "sweet_potato",
            ["cá_hồi"] = "salmon",
            ["cá_ngừ"] = "tuna",
            ["cá"] = "fish",
            ["tôm"] = "shrimp",
            ["tôm_sú"] = "shrimp",
            ["tôm_tươi"] = "shrimp",
            ["mực"] = "squid",
            ["mực_ống"] = "squid",
            ["bạch_tuộc"] = "octopus",
            ["cua"] = "crab",
            ["ghẹ"] = "crab",
            ["nghêu"] = "clam",
            ["sò"] = "clam",
            ["nấm"] = "mushroom",
            ["nấm_rơm"] = "mushroom",
            ["nấm_hương"] = "mushroom",
            ["nấm_đông_cô"] = "mushroom",
            ["nấm_kim_châm"] = "mushroom",
            ["nấm_mèo"] = "wood_ear_mushroom",
            ["hành_tây"] = "onion",
            ["hành_lá"] = "spring_onion",
            ["hành_tím"] = "shallot",
            ["hành"] = "onion",
            ["cà_rốt"] = "carrot",
            ["bông_cải"] = "broccoli",
            ["bông_cải_xanh"] = "broccoli",
            ["súp_lơ"] = "cauliflower",
            ["tỏi"] = "garlic",
            ["gừng"] = "ginger",
            ["sả"] = "lemongrass",
            ["ớt"] = "chili",
            ["chanh"] = "lemon",
            ["phô_mai"] = "cheese",
            ["phômai"] = "cheese",
            ["cheese"] = "cheese",
            ["bơ"] = "butter",
            ["bơ_lạt"] = "butter",
            ["trái_bơ"] = "avocado",
            ["cốt_dừa"] = "coconut",
            ["nước_cốt_dừa"] = "coconut",
            ["dừa"] = "coconut",
            ["mật_ong"] = "honey",
            ["măng_tây"] = "asparagus",
            ["bắp_cải"] = "cabbage",
            ["rau_muống"] = "water_spinach",
            ["muống"] = "water_spinach",
            ["cải_ngồng"] = "chinese_broccoli",
            ["cải_ngọt"] = "choy_sum",
            ["cải_thìa"] = "bok_choy",
            ["cải_xanh"] = "mustard_greens",
            ["cải_chua"] = "pickled_greens",
            ["dưa_cải"] = "pickled_greens",
            ["cải_bó_xôi"] = "spinach",
            ["rau_bina"] = "spinach",
            ["mướp"] = "luffa",
            ["ngao"] = "clam",
            ["nghêu"] = "clam",
            ["xà_lách"] = "lettuce",
            ["dưa_leo"] = "cucumber",
            ["dưa_chuột"] = "cucumber",
            ["bí_đỏ"] = "pumpkin",
            ["bí_ngô"] = "pumpkin",
            ["đậu_phụ"] = "tofu",
            ["đậu_hũ"] = "tofu",
            ["đậu_phộng"] = "peanut",
            ["lạc"] = "peanut",
            ["hạt_điều"] = "cashew",
            ["bắp"] = "corn",
            ["ngô"] = "corn",
            ["đậu_hà_lan"] = "peas",
            ["đậu_que"] = "green_beans",
            ["tiêu"] = "pepper",
            ["hạt_tiêu"] = "pepper",
            ["nước_mắm"] = "fish_sauce",
            ["nước_tương"] = "soy_sauce",
            ["xì_dầu"] = "soy_sauce",
            ["dầu_hào"] = "oyster_sauce",
            ["dầu_mè"] = "sesame_oil",
            ["giấm"] = "vinegar",
            ["mì_ý"] = "spaghetti",
            ["mì"] = "noodle",
            ["spaghetti"] = "spaghetti",
            ["pasta"] = "pasta",
            ["bún"] = "vermicelli",
            ["phở"] = "rice_noodle",
            ["cơm"] = "rice",
            ["gạo"] = "rice"
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
            ["cá ngừ"] = "tuna",
            ["cá"] = "fish",
            ["hải sản"] = "seafood",
            ["tôm"] = "shrimp",
            ["mực"] = "squid",
            ["cua"] = "crab",
            ["vịt"] = "duck",
            ["cừu"] = "lamb",
            ["sườn"] = "ribs",
            ["trứng"] = "egg",
            ["mỳ ý"] = "pasta",
            ["mì ý"] = "pasta",
            ["mì"] = "noodle",
            ["bún"] = "vermicelli",
            ["phở"] = "pho",
            ["cơm"] = "rice",
            ["chay"] = "vegetarian",
            ["rau"] = "vegetable",
            ["salad"] = "salad",
            ["súp"] = "soup",
            ["canh"] = "soup",
            ["bánh"] = "cake",
            ["tráng miệng"] = "dessert",
            ["nấm"] = "mushroom",
            ["khoai tây"] = "potato",
            ["khoai"] = "potato",
            ["cà chua"] = "tomato",
            ["tỏi"] = "garlic",
            ["gừng"] = "ginger",
            ["sả"] = "lemongrass",
            ["phô mai"] = "cheese",
            ["bơ"] = "butter",
            ["cốt dừa"] = "coconut",
            ["măng tây"] = "asparagus",
            ["masterchef"] = "masterchef",
            ["vua đầu bếp"] = "masterchef",
            ["gordon ramsay"] = "gordon"
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