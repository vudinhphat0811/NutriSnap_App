using Microsoft.AspNetCore.Mvc;
using NutriSnap.Models;
using NutriSnap.Services;

namespace NutriSnap.Controllers;

[ApiController]
[Route("api/[controller]")]
public class RecipesController : ControllerBase
{
    private readonly RecipeService _recipeService;
    private readonly RecipeCrawlerService _recipeCrawlerService;
    private readonly TranslationService _translationService;
    private readonly AiVisionService _aiVisionService;
    private readonly MealDbSyncService _mealDbSyncService;

    public RecipesController(
        RecipeService recipeService,
        RecipeCrawlerService recipeCrawlerService,
        TranslationService translationService,
        AiVisionService aiVisionService,
        MealDbSyncService mealDbSyncService)
    {
        _recipeService = recipeService;
        _recipeCrawlerService = recipeCrawlerService;
        _translationService = translationService;
        _aiVisionService = aiVisionService;
        _mealDbSyncService = mealDbSyncService;
    }

    [HttpGet("shake")]
    public async Task<IActionResult> Shake([FromQuery] string lang = "vi")
    {
        var meal = await _recipeService.GetRandomMealAsync(lang);
        return meal != null ? Ok(meal) : NotFound();
    }

    /// <summary>
    /// THUẬT TOÁN GỢI Ý MÓN ĂN TẠI BACKEND (POST /api/recipes/recommendations)
    /// Tính MatchScore, xoay vòng theo ngày và lượt refresh.
    /// </summary>
    [HttpPost("recommendations")]
    public async Task<IActionResult> GetRecommendations([FromBody] RecommendationRequest request)
    {
        var meals = await _recipeService.GetDailyRecommendationsAsync(request);
        return Ok(new
        {
            success = true,
            total = meals.Count,
            data = meals
        });
    }

    /// <summary>
    /// GỢI Ý MÓN ĂN HÀNG NGÀY CHO TAB HỒ SƠ (GET /api/recipes/daily-matched)
    /// </summary>
    [HttpGet("daily-matched")]
    public async Task<IActionResult> GetDailyMatched(
        [FromQuery] string dietType = "HighProtein",
        [FromQuery] string goal = "LoseWeight",
        [FromQuery] int remainingCalories = 1200,
        [FromQuery] int refreshCount = 0,
        [FromQuery] int limit = 4,
        [FromQuery] string? category = null)
    {
        var request = new RecommendationRequest
        {
            DietType = dietType,
            Goal = goal,
            RemainingCalories = remainingCalories,
            RefreshCount = refreshCount,
            Limit = limit,
            Category = category
        };

        var meals = await _recipeService.GetDailyRecommendationsAsync(request);
        return Ok(meals);
    }

    /// <summary>
    /// CHI TIẾT MÓN ĂN ĐƯỢC DỊCH TỰ ĐỘNG BẰNG AI / TRANSLATION SERVICE
    /// GET /api/recipes/detail/{idMeal}?lang=vi
    /// </summary>
    [HttpGet("detail/{idMeal}")]
    public async Task<IActionResult> GetMealDetail(string idMeal, [FromQuery] string lang = "vi")
    {
        var meal = await _recipeService.GetMealDetailAsync(idMeal, lang);
        if (meal == null)
        {
            return NotFound(new { message = "Không tìm thấy công thức món ăn này." });
        }
        return Ok(meal);
    }

    /// <summary>
    /// API DỊCH THUẬT VĂN BẢN TỰ ĐỘNG
    /// POST /api/recipes/translate
    /// </summary>
    [HttpPost("translate")]
    public async Task<IActionResult> TranslateText([FromBody] TranslateRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Text))
        {
            return BadRequest(new { message = "Nội dung cần dịch không được để trống." });
        }

        var translated = await _translationService.TranslateAsync(request.Text, request.TargetLang ?? "vi", request.SourceLang ?? "en");
        return Ok(new
        {
            original = request.Text,
            translated = translated,
            targetLang = request.TargetLang ?? "vi"
        });
    }

    [HttpGet("all")]
    public async Task<IActionResult> GetAllRecipes()
    {
        var recipes = await _recipeCrawlerService.GetSavedOrCrawledRecipesAsync();
        return Ok(recipes);
    }

    [HttpPost("crawl")]
    public async Task<IActionResult> CrawlRecipes([FromQuery] int limit = 20)
    {
        var recipes = await _recipeCrawlerService.CrawlAndSaveAsync(limit);
        return Ok(new
        {
            message = $"Đã thu thập và lưu thành công {recipes.Count} công thức.",
            total = recipes.Count,
            data = recipes
        });
    }

    /// <summary>
    /// PHÂN TÍCH NGUYÊN LIỆU TỪ ẢNH BẰNG AI VISION BACKEND (POST /api/recipes/analyze-image)
    /// Nhận chuỗi JSON Base64 (Chuẩn gửi từ Flutter Frontend)
    /// </summary>
    [HttpPost("analyze-image")]
    public async Task<IActionResult> AnalyzeImage([FromBody] AnalyzeImageRequest jsonBody)
    {
        if (jsonBody == null || string.IsNullOrWhiteSpace(jsonBody.ImageBase64))
        {
            return BadRequest(new { message = "Vui lòng cung cấp chuỗi Base64 của ảnh." });
        }

        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(jsonBody.ImageBase64);
        }
        catch
        {
            return BadRequest(new { message = "Chuỗi Base64 hình ảnh không hợp lệ." });
        }

        string contentType = !string.IsNullOrWhiteSpace(jsonBody.ContentType) ? jsonBody.ContentType : "image/jpeg";
        var result = await _aiVisionService.AnalyzeIngredientImageAsync(bytes, contentType);
        return Ok(result);
    }

    /// <summary>
    /// PHÂN TÍCH NGUYÊN LIỆU TỪ FILE TẢI LÊN (POST /api/recipes/analyze-image-upload)
    /// Hỗ trợ kiểm thử trực tiếp trên giao diện Swagger UI
    /// </summary>
    [HttpPost("analyze-image-upload")]
    public async Task<IActionResult> AnalyzeImageUpload(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "Vui lòng cung cấp file ảnh tải lên." });
        }

        using var ms = new MemoryStream();
        await file.CopyToAsync(ms);
        var bytes = ms.ToArray();
        string contentType = file.ContentType ?? "image/jpeg";

        var result = await _aiVisionService.AnalyzeIngredientImageAsync(bytes, contentType);
        return Ok(result);
    }

    /// <summary>
    /// TÌM KIẾM MÓN ĂN THEO NGUYÊN LIỆU (GET /api/recipes/by-ingredient)
    /// </summary>
    [HttpGet("by-ingredient")]
    public async Task<IActionResult> GetByIngredient([FromQuery] string ingredient, [FromQuery] string lang = "vi")
    {
        if (string.IsNullOrWhiteSpace(ingredient))
        {
            return BadRequest(new { message = "Tên nguyên liệu không được để trống." });
        }
        var meals = await _recipeService.GetMealsByIngredientAsync(ingredient, lang);
        return Ok(meals);
    }

    /// <summary>
    /// TÌM KIẾM MÓN ĂN KHỚP NHIỀU NGUYÊN LIỆU (POST /api/recipes/match-multiple)
    /// </summary>
    [HttpPost("match-multiple")]
    public async Task<IActionResult> MatchMultiple([FromBody] MatchIngredientsRequest request)
    {
        if (request.Ingredients == null || request.Ingredients.Count == 0)
        {
            return BadRequest(new { message = "Danh sách nguyên liệu không được để trống." });
        }
        var meals = await _recipeService.GetMealsByMultipleIngredientsAsync(
            request.Ingredients,
            request.Lang ?? "vi",
            request.Limit > 0 ? request.Limit : 25);
        return Ok(meals);
    }

    /// <summary>
    /// TÌM KIẾM MÓN ĂN KHỚP NHIỀU NGUYÊN LIỆU (GET /api/recipes/match-multiple)
    /// </summary>
    [HttpGet("match-multiple")]
    public async Task<IActionResult> MatchMultipleGet(
        [FromQuery] string ingredients,
        [FromQuery] string lang = "vi",
        [FromQuery] int limit = 25)
    {
        if (string.IsNullOrWhiteSpace(ingredients))
        {
            return BadRequest(new { message = "Danh sách nguyên liệu không được để trống." });
        }
        var list = ingredients.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
        var meals = await _recipeService.GetMealsByMultipleIngredientsAsync(list, lang, limit);
        return Ok(meals);
    }

    /// <summary>
    /// TÌM KIẾM MÓN ĂN THEO TỪ KHÓA (GET /api/recipes/search)
    /// </summary>
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string q, [FromQuery] string lang = "vi")
    {
        if (string.IsNullOrWhiteSpace(q))
        {
            return BadRequest(new { message = "Từ khóa tìm kiếm không được để trống." });
        }
        var meals = await _recipeService.SearchMealsAsync(q, lang);
        return Ok(meals);
    }

    /// <summary>
    /// LẤY DANH SÁCH MÓN ĂN THEO DANH MỤC (GET /api/recipes/category/{category})
    /// </summary>
    [HttpGet("category/{category}")]
    public async Task<IActionResult> GetByCategory(string category, [FromQuery] string lang = "vi")
    {
        var meals = await _recipeService.GetMealsByCategoryAsync(category, lang);
        return Ok(meals);
    }

    /// <summary>
    /// TRA CỨU THÔNG TIN DINH DƯỠNG NGUYÊN LIỆU NHẬP TAY (GET /api/recipes/ingredient-lookup)
    /// </summary>
    [HttpGet("ingredient-lookup")]
    public async Task<IActionResult> LookupIngredient([FromQuery] string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return BadRequest(new { message = "Tên nguyên liệu không được để trống." });
        }
        var info = await _recipeService.LookupIngredientNutritionAsync(name);
        return Ok(info);
    }

    /// <summary>
    /// LẤY DANH SÁCH GỢI Ý NGUYÊN LIỆU NHANH (GET /api/recipes/quick-suggestions)
    /// </summary>
    [HttpGet("quick-suggestions")]
    public IActionResult GetQuickSuggestions()
    {
        return Ok(_recipeService.GetQuickSuggestions());
    }

    /// <summary>
    /// ĐỒNG BỘ CÔNG THỨC TỪ THEMEALDB VÀO DATABASE CỤC BỘ (POST /api/recipes/sync-mealdb)
    /// </summary>
    [HttpPost("sync-mealdb")]
    public async Task<IActionResult> SyncMealDb([FromQuery] bool force = false)
    {
        var recipes = await _mealDbSyncService.SyncFromMealDbAsync();
        return Ok(new
        {
            success = true,
            total = recipes.Count,
            message = $"Đã đồng bộ thành công {recipes.Count} công thức TheMealDB vào cơ sở dữ liệu."
        });
    }

    /// <summary>
    /// KIỂM TRA TRẠNG THÁI DATABASE CÔNG THỨC (GET /api/recipes/database-status)
    /// </summary>
    [HttpGet("database-status")]
    public async Task<IActionResult> GetDatabaseStatus()
    {
        var local = await _mealDbSyncService.GetOrSyncLocalRecipesAsync(false);
        return Ok(new
        {
            totalLocalMealDbRecipes = local.Count,
            totalCombinationRecipes = CombinationRecipeCatalog.Recipes.Count,
            totalCombinedPool = local.Count + CombinationRecipeCatalog.Recipes.Count
        });
    }
}

public class TranslateRequestDto
{
    public string Text { get; set; } = "";
    public string? TargetLang { get; set; } = "vi";
    public string? SourceLang { get; set; } = "en";
}