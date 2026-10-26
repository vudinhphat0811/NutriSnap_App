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
    private readonly BarcodeNutritionService _barcodeNutritionService;

    public RecipesController(
        RecipeService recipeService,
        RecipeCrawlerService recipeCrawlerService,
        TranslationService translationService,
        AiVisionService aiVisionService,
        MealDbSyncService mealDbSyncService,
        BarcodeNutritionService barcodeNutritionService)
    {
        _recipeService = recipeService;
        _recipeCrawlerService = recipeCrawlerService;
        _translationService = translationService;
        _aiVisionService = aiVisionService;
        _mealDbSyncService = mealDbSyncService;
        _barcodeNutritionService = barcodeNutritionService;
    }

    /// <summary>
    /// KIỂM TRA TRẠNG THÁI AI (GET /api/recipes/ai-status)
    /// Cho biết Local AI (LM Studio Qwen2.5-VL) hay Cloud AI đang hoạt động
    /// </summary>
    [HttpGet("ai-status")]
    public async Task<IActionResult> GetAiStatus()
    {
        bool isLocalAvailable = await _aiVisionService.CheckLmStudioAvailableAsync();
        return Ok(new
        {
            activeProvider = isLocalAvailable ? "LM Studio Local (Qwen2.5-VL)" : "Cloud AI Fallback",
            isLocalAi = isLocalAvailable,
            model = "qwen2.5-vl-3b-instruct",
            localEndpoint = "http://localhost:1234/v1",
            status = isLocalAvailable ? "Online (Running)" : "Offline (Using Cloud Backup)"
        });
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
    public async Task<IActionResult> GetMealDetail(string idMeal, [FromQuery] string lang = "vi", [FromQuery] bool forceAi = false)
    {
        var meal = await _recipeService.GetMealDetailAsync(idMeal, lang, forceAi);
        if (meal == null)
        {
            return NotFound(new { message = "Không tìm thấy công thức món ăn này." });
        }
        return Ok(meal);
    }

    /// <summary>
    /// BỘ LỌC AI DỊCH THUẬT CÔNG THỨC TRỰC TIẾP TRƯỚC HOẶC KHI MỞ
    /// POST /api/recipes/ai-filter-recipe
    /// </summary>
    [HttpPost("ai-filter-recipe")]
    public async Task<IActionResult> AiFilterRecipe([FromBody] AiFilterRecipeRequestDto request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.IdMeal))
        {
            return BadRequest(new { message = "IdMeal không được để trống." });
        }

        var meal = await _recipeService.GetMealDetailAsync(request.IdMeal, "vi", forceAi: true);
        if (meal == null)
        {
            return NotFound(new { message = $"Không tìm thấy món ăn {request.IdMeal}." });
        }
        return Ok(meal);
    }

    /// <summary>
    /// API DỊCH THUẬT VĂN BẢN TỰ ĐỘNG
    /// POST /api/recipes/translate
    /// </summary>
    [HttpPost("translate")]
    public async Task<IActionResult> TranslateText([FromBody] TranslateRequestDto request, [FromQuery] bool forceAi = false)
    {
        if (string.IsNullOrWhiteSpace(request.Text))
        {
            return BadRequest(new { message = "Nội dung cần dịch không được để trống." });
        }

        var translated = await _translationService.TranslateAsync(request.Text, request.TargetLang ?? "vi", request.SourceLang ?? "en", forceAi);
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
            request.Limit > 0 ? request.Limit : 25,
            request.Goal,
            request.DietType,
            request.RemainingCalories,
            request.TargetCalories);
        return Ok(meals);
    }

    /// <summary>
    /// TÌM KIẾM MÓN ĂN KHỚP NHIỀU NGUYÊN LIỆU (GET /api/recipes/match-multiple)
    /// </summary>
    [HttpGet("match-multiple")]
    public async Task<IActionResult> MatchMultipleGet(
        [FromQuery] string ingredients,
        [FromQuery] string? goal = null,
        [FromQuery] string? dietType = null,
        [FromQuery] int remainingCalories = 0,
        [FromQuery] int targetCalories = 0,
        [FromQuery] string lang = "vi",
        [FromQuery] int limit = 25)
    {
        if (string.IsNullOrWhiteSpace(ingredients))
        {
            return BadRequest(new { message = "Danh sách nguyên liệu không được để trống." });
        }
        var list = ingredients.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
        var meals = await _recipeService.GetMealsByMultipleIngredientsAsync(
            list,
            lang,
            limit,
            goal,
            dietType,
            remainingCalories,
            targetCalories);
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
    /// DANH SÁCH BỘ PHẬN NGUYÊN LIỆU CHI TIẾT CHO GYMER & TẬP LUYỆN (GET /api/recipes/ingredient-cuts)
    /// Ví dụ: Ức gà không da, Đùi gà góc tư, Thăn bò phi lê, Bắp bò hoa, Nạc thăn heo...
    /// </summary>
    [HttpGet("ingredient-cuts")]
    public IActionResult GetIngredientCuts([FromQuery] string? category = null, [FromQuery] string? q = null)
    {
        if (!string.IsNullOrWhiteSpace(q))
        {
            var searchResults = IngredientCutCatalog.Search(q);
            return Ok(new
            {
                success = true,
                total = searchResults.Count,
                data = searchResults
            });
        }

        var cuts = IngredientCutCatalog.GetByCategory(category);
        return Ok(new
        {
            success = true,
            total = cuts.Count,
            data = cuts
        });
    }

    /// <summary>
    /// CHI TIẾT BỘ PHẬN NGUYÊN LIỆU THEO ID (GET /api/recipes/ingredient-cuts/{id})
    /// </summary>
    [HttpGet("ingredient-cuts/{id}")]
    public IActionResult GetIngredientCutDetail(string id)
    {
        var cut = IngredientCutCatalog.GetById(id);
        if (cut == null)
        {
            return NotFound(new { message = "Không tìm thấy bộ phận nguyên liệu này." });
        }
        return Ok(cut);
    }

    /// <summary>
    /// TÍNH TOÁN MACRO & CALO THEO TRỌNG LƯỢNG GRAM CHO BỘ PHẬN NGUYÊN LIỆU (POST /api/recipes/calculate-cut-macros)
    /// </summary>
    [HttpPost("calculate-cut-macros")]
    public IActionResult CalculateCutMacros([FromBody] CalculateCutMacroRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CutId))
        {
            return BadRequest(new { message = "Mã bộ phận nguyên liệu không được để trống." });
        }

        var result = IngredientCutCatalog.CalculateMacros(request.CutId, request.WeightG);
        return Ok(result);
    }

    /// <summary>
    /// TRA CỨU SẢN PHẨM & CALO THEO MÃ VẠCH / MÃ QR (GET /api/recipes/barcode?code=... hoặc /api/recipes/barcode/{**code})
    /// Hỗ trợ EAN-13, Tem Cân Siêu Thị, và Mã QR Truy Xuất Nguồn Gốc (Traceability URLs)
    /// </summary>
    [HttpGet("barcode")]
    [HttpGet("barcode/{**code}")]
    public async Task<IActionResult> LookupBarcode([FromQuery(Name = "code")] string? queryCode, [FromRoute(Name = "code")] string? pathCode)
    {
        var rawCode = !string.IsNullOrWhiteSpace(queryCode) ? queryCode : pathCode;
        if (string.IsNullOrWhiteSpace(rawCode))
        {
            return BadRequest(new { success = false, message = "Mã vạch hoặc mã QR không được để trống." });
        }
        var result = await _barcodeNutritionService.LookupBarcodeAsync(rawCode);
        if (!result.Success && result.Product == null)
        {
            return NotFound(result);
        }
        return Ok(result);
    }

    /// <summary>
    /// QUÉT MÃ VẠCH / TEM CÂN TỪ HÌNH ẢNH BẰNG AI VISION (POST /api/recipes/scan-barcode-image)
    /// </summary>
    [HttpPost("scan-barcode-image")]
    public async Task<IActionResult> ScanBarcodeImage([FromBody] AnalyzeImageRequest jsonBody)
    {
        if (jsonBody == null || string.IsNullOrWhiteSpace(jsonBody.ImageBase64))
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp chuỗi Base64 của ảnh." });
        }

        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(jsonBody.ImageBase64);
        }
        catch
        {
            return BadRequest(new { success = false, message = "Chuỗi Base64 hình ảnh không hợp lệ." });
        }

        string contentType = !string.IsNullOrWhiteSpace(jsonBody.ContentType) ? jsonBody.ContentType : "image/jpeg";
        var result = await _barcodeNutritionService.ScanBarcodeFromImageAsync(bytes, contentType);
        return Ok(result);
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
    [HttpGet("masterchef")]
    public IActionResult GetMasterChefRecipes()
    {
        var recipes = MasterChefRecipeCatalog.GetRecipes();
        return Ok(new
        {
            success = true,
            total = recipes.Count,
            message = "Bộ sưu tập món ăn kinh điển Vua Đầu Bếp Việt Nam & MasterChef Quốc Tế",
            data = recipes
        });
    }

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

public class AiFilterRecipeRequestDto
{
    public string IdMeal { get; set; } = "";
}