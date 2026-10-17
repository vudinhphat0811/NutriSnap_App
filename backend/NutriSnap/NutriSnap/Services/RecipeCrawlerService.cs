using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace NutriSnap.Services;

public class RecipeCrawlerService
{
    private readonly HttpClient _httpClient;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<RecipeCrawlerService> _logger;

    private static readonly string[] TargetUrls =
    [
        "https://www.foodnetwork.com/recipes/recipes-a-z/xyz",
        "https://www.foodnetwork.com/recipes/photos/easy-chicken-recipes",
        "https://www.foodnetwork.com/recipes/photos/quick-and-easy-dinner-recipes"
    ];

    public RecipeCrawlerService(HttpClient httpClient, IWebHostEnvironment env, ILogger<RecipeCrawlerService> logger)
    {
        _httpClient = httpClient;
        _env = env;
        _logger = logger;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36");
        _httpClient.DefaultRequestHeaders.Add("Accept-Language", "en-US,en;q=0.9");
    }

    public async Task<List<string>> GetRecipeLinksAsync()
    {
        var links = new List<string>();

        foreach (var targetUrl in TargetUrls)
        {
            _logger.LogInformation("Đang quét trang danh mục công thức: {TargetUrl}", targetUrl);
            try
            {
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
                var res = await _httpClient.GetStringAsync(targetUrl, cts.Token);

                // Regex tìm các thẻ a có href chứa link công thức
                var matches = Regex.Matches(res, @"href\s*=\s*[""'](?<url>[^""']+)[""']", RegexOptions.IgnoreCase);
                foreach (Match m in matches)
                {
                    var href = m.Groups["url"].Value;
                    if (href.Contains("/recipes/") && href.EndsWith(".html") && !href.Contains("/photos/"))
                    {
                        var fullUrl = href.StartsWith("http") ? href : $"https:{href}";
                        if (!links.Contains(fullUrl))
                        {
                            links.Add(fullUrl);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Không thể tải danh mục {TargetUrl}: {Message}", targetUrl, ex.Message);
            }
        }

        return links;
    }

    public async Task<JsonObject?> ParseRecipeAsync(string url, int index)
    {
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            var html = await _httpClient.GetStringAsync(url, cts.Token);

            // Tìm tất cả các thẻ <script type="application/ld+json">
            var scriptMatches = Regex.Matches(html, @"<script[^>]*type\s*=\s*[""']application/ld\+json[""'][^>]*>(?<json>[\s\S]*?)</script>", RegexOptions.IgnoreCase);

            JsonObject? recipeData = null;

            foreach (Match match in scriptMatches)
            {
                var jsonStr = match.Groups["json"].Value.Trim();
                if (string.IsNullOrWhiteSpace(jsonStr)) continue;

                try
                {
                    var parsed = JsonNode.Parse(jsonStr);
                    if (parsed is JsonArray arr)
                    {
                        foreach (var item in arr)
                        {
                            if (item is JsonObject obj && obj["@type"]?.ToString() == "Recipe")
                            {
                                recipeData = obj;
                                break;
                            }
                        }
                    }
                    else if (parsed is JsonObject obj && obj["@type"]?.ToString() == "Recipe")
                    {
                        recipeData = obj;
                    }
                }
                catch
                {
                    continue;
                }

                if (recipeData != null) break;
            }

            if (recipeData == null) return null;

            // 1. Trích xuất ảnh
            string imageUrl = "";
            var imgNode = recipeData["image"];
            if (imgNode is JsonArray imgArr && imgArr.Count > 0)
            {
                imageUrl = imgArr[0] is JsonObject imgObj ? imgObj["url"]?.ToString() ?? "" : imgArr[0]?.ToString() ?? "";
            }
            else if (imgNode is JsonObject imgObj)
            {
                imageUrl = imgObj["url"]?.ToString() ?? "";
            }
            else if (imgNode != null)
            {
                imageUrl = imgNode.ToString();
            }

            // 2. Trích xuất Calories
            int cal = 380;
            var nutriNode = recipeData["nutrition"];
            if (nutriNode is JsonObject nutriObj && nutriObj["calories"] != null)
            {
                var calStr = nutriObj["calories"]!.ToString().Split(' ')[0];
                if (int.TryParse(calStr, out int parsedCal))
                {
                    cal = parsedCal;
                }
            }

            // 3. Trích xuất các bước nấu (Steps)
            var steps = new JsonArray();
            var instructionsNode = recipeData["recipeInstructions"];
            if (instructionsNode is JsonArray instArr)
            {
                foreach (var step in instArr)
                {
                    if (step is JsonObject stepObj && stepObj["text"] != null)
                    {
                        steps.Add(stepObj["text"]!.ToString().Trim());
                    }
                    else if (step != null)
                    {
                        steps.Add(step.ToString().Trim());
                    }
                }
            }

            // 4. Nguyên liệu (Ingredients)
            var ingredients = new JsonArray();
            var ingNode = recipeData["recipeIngredient"];
            if (ingNode is JsonArray ingArr)
            {
                foreach (var ing in ingArr)
                {
                    if (ing != null) ingredients.Add(ing.ToString().Trim());
                }
            }

            var title = recipeData["name"]?.ToString() ?? $"Recipe {index}";
            var desc = recipeData["description"]?.ToString() ?? title;
            var timeCook = (recipeData["totalTime"]?.ToString() ?? "25 mins")
                .Replace("PT", "")
                .Replace("M", " mins");

            var result = new JsonObject
            {
                ["id"] = index.ToString(),
                ["title"] = new JsonObject { ["en"] = title, ["vi"] = title },
                ["description"] = new JsonObject { ["en"] = desc, ["vi"] = desc },
                ["cook_time"] = new JsonObject { ["en"] = timeCook, ["vi"] = timeCook },
                ["calories"] = cal,
                ["protein"] = 35,
                ["carbs"] = 25,
                ["fat"] = 12,
                ["image_url"] = imageUrl,
                ["ingredients"] = ingredients,
                ["steps"] = new JsonObject { ["en"] = steps.DeepClone(), ["vi"] = steps.DeepClone() },
                ["chef_advice"] = new JsonObject
                {
                    ["en"] = "Follow the cooking time carefully for best results.",
                    ["vi"] = "Canh chuẩn thời gian nấu để món ăn giữ được độ mềm mọng."
                }
            };

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Lỗi đọc công thức tại {Url}: {Message}", url, ex.Message);
            return null;
        }
    }

    public async Task<JsonArray> CrawlAndSaveAsync(int limit = 20, string? customOutputPath = null)
    {
        var links = await GetRecipeLinksAsync();
        JsonArray recipes;

        if (links.Count == 0)
        {
            _logger.LogInformation("FoodNetwork từ chối truy cập (WAF/AntiBot). Tự động tạo dữ liệu mẫu chuẩn...");
            recipes = GetSampleRecipes();
        }
        else
        {
            _logger.LogInformation("Đã tìm thấy {Count} công thức. Tiến hành bóc tách dữ liệu...", links.Count);
            recipes = new JsonArray();
            int count = Math.Min(limit, links.Count);

            for (int i = 0; i < count; i++)
            {
                var link = links[i];
                _logger.LogInformation("[{Current}/{Total}] Đang cào: {Link}", i + 1, count, link);
                var item = await ParseRecipeAsync(link, i + 1);
                if (item != null && !string.IsNullOrWhiteSpace(item["image_url"]?.ToString()))
                {
                    recipes.Add(item);
                }
                await Task.Delay(1000); // Tránh spam server
            }

            if (recipes.Count == 0)
            {
                recipes = GetSampleRecipes();
            }
        }

        // Lưu ra file JSON
        await SaveRecipesJsonAsync(recipes, customOutputPath);

        return recipes;
    }

    public async Task<JsonArray> GetSavedOrCrawledRecipesAsync()
    {
        var outputPath = GetDefaultOutputPath();
        if (File.Exists(outputPath))
        {
            try
            {
                var jsonText = await File.ReadAllTextAsync(outputPath);
                var node = JsonNode.Parse(jsonText);
                if (node is JsonArray arr && arr.Count > 0)
                {
                    return arr;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Không thể đọc file recipes.json: {Message}", ex.Message);
            }
        }

        return await CrawlAndSaveAsync();
    }

    private async Task SaveRecipesJsonAsync(JsonArray recipes, string? customPath)
    {
        var targetPath = customPath ?? GetDefaultOutputPath();
        var dir = Path.GetDirectoryName(targetPath);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }

        var options = new JsonSerializerOptions
        {
            WriteIndented = true,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        };

        var jsonStr = recipes.ToJsonString(options);
        await File.WriteAllTextAsync(targetPath, jsonStr);
        _logger.LogInformation("Đã lưu thành công dữ liệu công thức vào: {TargetPath}", targetPath);

        // Đồng bộ lưu sang frontend nếu tồn tại thư mục frontend/assets/data
        var frontendPath = GetFrontendAssetsPath();
        if (!string.IsNullOrEmpty(frontendPath) && frontendPath != targetPath)
        {
            try
            {
                var fDir = Path.GetDirectoryName(frontendPath);
                if (!string.IsNullOrEmpty(fDir) && !Directory.Exists(fDir))
                {
                    Directory.CreateDirectory(fDir);
                }
                await File.WriteAllTextAsync(frontendPath, jsonStr);
                _logger.LogInformation("Đã đồng bộ sang thư mục Frontend Assets: {FrontendPath}", frontendPath);
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Không thể đồng bộ sang Frontend Assets: {Message}", ex.Message);
            }
        }
    }

    private string GetDefaultOutputPath()
    {
        // Ưu tiên lưu trong thư mục Data của backend
        return Path.Combine(_env.ContentRootPath, "Data", "recipes.json");
    }

    private string? GetFrontendAssetsPath()
    {
        // Tìm đường dẫn frontend/assets/data/recipes.json tương đối từ backend
        var currentDir = new DirectoryInfo(_env.ContentRootPath);
        while (currentDir != null)
        {
            var candidate = Path.Combine(currentDir.FullName, "frontend", "assets", "data", "recipes.json");
            if (Directory.Exists(Path.Combine(currentDir.FullName, "frontend")))
            {
                return candidate;
            }
            currentDir = currentDir.Parent;
        }
        return null;
    }

    private static JsonArray GetSampleRecipes()
    {
        return new JsonArray
        {
            new JsonObject
            {
                ["id"] = "1",
                ["title"] = new JsonObject { ["en"] = "Pan-Seared Herb Chicken", ["vi"] = "Ức gà áp chảo sốt thảo mộc" },
                ["description"] = new JsonObject { ["en"] = "Juicy chicken breast with crispy skin.", ["vi"] = "Ức gà mọng nước áp chảo ít dầu." },
                ["cook_time"] = new JsonObject { ["en"] = "20 mins", ["vi"] = "20 phút" },
                ["calories"] = 380,
                ["protein"] = 42,
                ["carbs"] = 12,
                ["fat"] = 8,
                ["image_url"] = "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80",
                ["ingredients"] = new JsonArray { "Ức gà 200g", "Tiêu đen", "Dầu ô liu", "Bông cải xanh" },
                ["steps"] = new JsonObject
                {
                    ["en"] = new JsonArray { "Season chicken with pepper and salt.", "Sear both sides for 5 minutes." },
                    ["vi"] = new JsonArray { "Ướp ức gà với tiêu và muối.", "Áp chảo mỗi mặt 5 phút." }
                },
                ["chef_advice"] = new JsonObject
                {
                    ["en"] = "Do not overcook.",
                    ["vi"] = "Không nấu quá lửa để tránh bị khô."
                }
            },
            new JsonObject
            {
                ["id"] = "2",
                ["title"] = new JsonObject { ["en"] = "Scrambled Eggs with Tomato", ["vi"] = "Trứng xào cà chua" },
                ["description"] = new JsonObject { ["en"] = "Simple and nutritious home-style dish.", ["vi"] = "Món ăn gia đình thanh đạm, giàu đạm." },
                ["cook_time"] = new JsonObject { ["en"] = "10 mins", ["vi"] = "10 phút" },
                ["calories"] = 250,
                ["protein"] = 18,
                ["carbs"] = 8,
                ["fat"] = 14,
                ["image_url"] = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80",
                ["ingredients"] = new JsonArray { "2 quả trứng", "1 quả cà chua", "Hành lá", "Gia vị" },
                ["steps"] = new JsonObject
                {
                    ["en"] = new JsonArray { "Whisk eggs.", "Sauté tomatoes until soft, then pour in eggs." },
                    ["vi"] = new JsonArray { "Đánh đều trứng.", "Xào mềm cà chua rồi đổ trứng vào đảo đều." }
                },
                ["chef_advice"] = new JsonObject
                {
                    ["en"] = "Cook eggs on low heat.",
                    ["vi"] = "Đảo trứng trên lửa nhỏ để trứng mềm mượt."
                }
            }
        };
    }
}
