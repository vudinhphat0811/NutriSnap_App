using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using NutriSnap.Models;

namespace NutriSnap.Services;

public class AiVisionService
{
    private const string SystemPrompt =
        "Bạn là chuyên gia thẩm định và phân tích nguyên liệu thực phẩm dinh dưỡng.\n" +
        "QUY TẮC PHÂN TÍCH QUAN TRỌNG NHẤT:\n" +
        "1. Nếu bức ảnh KHÔNG PHẢI là nguyên liệu thực phẩm, thức ăn, rau củ quả, thịt cá tươi sống " +
        "(ví dụ: người, thú cưng, đồ điện tử, màn hình, xe cộ, đồ đạc phòng ốc, sách vở, logo, đồ chơi...):\n" +
        "BẮT BUỘC trả về duy nhất chuỗi JSON sau:\n" +
        "{\n" +
        "  \"isIngredient\": false,\n" +
        "  \"rejectReason\": \"Ảnh không phải nguyên liệu thực phẩm. Vui lòng chụp ảnh nguyên liệu tươi sống (thịt, cá, trứng, rau, củ, quả...)!\"\n" +
        "}\n\n" +
        "2. Nếu bức ảnh ĐÚNG LÀ NGUYÊN LIỆU THỰC PHẨM:\n" +
        "Hãy quan sát toàn bộ bức ảnh và NHẬN DIỆN TẤT CẢ các nguyên liệu thực phẩm xuất hiện trong ảnh (không chỉ lấy 1 cái to nhất).\n" +
        "Nếu ảnh có nhiều nguyên liệu (ví dụ: thịt heo, cà rốt, nấm, trứng...), hãy liệt kê đầy đủ từng loại vào mảng \"ingredients\".\n" +
        "BẮT BUỘC trả về duy nhất chuỗi JSON theo đúng định dạng sau:\n" +
        "{\n" +
        "  \"isIngredient\": true,\n" +
        "  \"name\": \"Tên tổng hợp hoặc tên nguyên liệu chính (ví dụ: Thịt & Rau củ tươi, hoặc Thịt bò phi lê)\",\n" +
        "  \"englishName\": \"Tên tiếng Anh của nguyên liệu chính nổi bật nhất để tìm món (ví dụ: Pork, Beef, Chicken, Salmon, Egg...)\",\n" +
        "  \"calories\": \"Tổng lượng calo của tất cả nguyên liệu trong ảnh (ví dụ: 320 kcal)\",\n" +
        "  \"calorieNumber\": 320,\n" +
        "  \"weight\": \"Tổng khối lượng ước tính (ví dụ: ~350g)\",\n" +
        "  \"nutritionComment\": \"Nhận xét chi tiết, khoa học và giàu chuyên môn dinh dưỡng về tổng thể các nguyên liệu này: cân bằng vi chất, năng lượng và lưu ý chế biến tốt nhất.\",\n" +
        "  \"protein\": \"Tổng lượng đạm (ví dụ: 28g Protein)\",\n" +
        "  \"carbs\": \"Tổng lượng tinh bột (ví dụ: 12g Carbs)\",\n" +
        "  \"fat\": \"Tổng lượng chất béo (ví dụ: 10g Fat)\",\n" +
        "  \"context\": \"Mô tả ngắn bối cảnh ảnh (ví dụ: Thịt tươi và rau củ trên bàn bếp)\",\n" +
        "  \"ingredients\": [\n" +
        "    {\n" +
        "      \"name\": \"Tên nguyên liệu 1 (tiếng Việt, ví dụ: Thịt heo nạc)\",\n" +
        "      \"englishName\": \"Pork\",\n" +
        "      \"calories\": \"220 kcal\",\n" +
        "      \"calorieNumber\": 220,\n" +
        "      \"weight\": \"~150g\",\n" +
        "      \"protein\": \"26g Protein\",\n" +
        "      \"carbs\": \"0g Carbs\",\n" +
        "      \"fat\": \"8g Fat\",\n" +
        "      \"nutritionComment\": \"Giàu protein và vitamin B1.\"\n" +
        "    }\n" +
        "  ]\n" +
        "}\n" +
        "TUYỆT ĐỐI không chèn mã markdown ```json, không viết thêm bất kỳ văn bản nào ngoài chuỗi JSON.";

    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly ILogger<AiVisionService> _logger;

    private static int _globalProviderIndex = 0;
    private static readonly object _lockObj = new();

    public AiVisionService(HttpClient httpClient, IConfiguration config, ILogger<AiVisionService> logger)
    {
        _httpClient = httpClient;
        _config = config;
        _logger = logger;
    }

    /// <summary>
    /// Phân tích ảnh với cơ chế luân phiên đa nhà cung cấp (Gemini -> Groq -> Cloudflare)
    /// </summary>
    public async Task<IngredientAnalysisResultDto> AnalyzeIngredientImageAsync(byte[] imageBytes, string contentType = "image/jpeg")
    {
        var providers = new (string Name, Func<byte[], string, Task<string>> Call)[]
        {
            ("Google Gemini", CallGeminiVisionAsync),
            ("Groq AI", CallGroqVisionAsync),
            ("Cloudflare Workers AI", CallCloudflareVisionAsync)
        };

        int total = providers.Length;
        int startIndex;
        lock (_lockObj)
        {
            startIndex = _globalProviderIndex % total;
        }

        var errors = new List<string>();

        for (int i = 0; i < total; i++)
        {
            int currentIndex = (startIndex + i) % total;
            var provider = providers[currentIndex];
            _logger.LogInformation("Đang thử AI Vision Provider [{Index}]: {Name}...", currentIndex, provider.Name);

            try
            {
                string rawJson = await provider.Call(imageBytes, contentType);
                if (!string.IsNullOrWhiteSpace(rawJson))
                {
                    lock (_lockObj)
                    {
                        _globalProviderIndex = (currentIndex + 1) % total;
                    }

                    var parsed = ParseAiResponse(rawJson, provider.Name);
                    if (parsed != null)
                    {
                        _logger.LogInformation("Phân tích thành công bằng AI Vision: {Name}", provider.Name);
                        return parsed;
                    }
                }
            }
            catch (Exception ex)
            {
                string err = $"{provider.Name} thất bại: {ex.Message}";
                _logger.LogWarning(err);
                errors.Add(err);
            }
        }

        _logger.LogError("Toàn bộ các AI Provider đều gặp sự cố: {Errors}", string.Join(" | ", errors));
        return IngredientAnalysisResultDto.Rejected(
            "Tất cả các dịch vụ AI nhận diện ảnh đều đang quá tải hoặc gặp sự cố kết nối. Vui lòng thử lại sau giây lát!",
            "Fallback Error"
        );
    }

    private async Task<string> CallGeminiVisionAsync(byte[] imageBytes, string contentType)
    {
        string apiKey = _config["GEMINI_API_KEY"]
            ?? _config["AiKeys:GeminiApiKey"]
            ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey))
        {
            throw new Exception("GEMINI_API_KEY chưa được cấu hình trong .env hoặc biến môi trường.");
        }

        string[] models = { "gemini-flash-latest", "gemini-2.5-flash-lite", "gemini-3.8-flash" };
        string base64 = Convert.ToBase64String(imageBytes);

        foreach (var model in models)
        {
            try
            {
                string url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}";
                var payload = new
                {
                    contents = new[]
                    {
                        new
                        {
                            parts = new object[]
                            {
                                new
                                {
                                    text = $"{SystemPrompt}\n\nQuan sát kỹ ảnh: Nếu KHÔNG PHẢI nguyên liệu thực phẩm hãy từ chối. Nếu là nguyên liệu thì trả về đầy đủ JSON."
                                },
                                new
                                {
                                    inline_data = new
                                    {
                                        mime_type = contentType,
                                        data = base64
                                    }
                                }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        temperature = 0.1,
                        maxOutputTokens = 1000
                    }
                };

                using var request = new HttpRequestMessage(HttpMethod.Post, url)
                {
                    Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
                };

                using var response = await _httpClient.SendAsync(request);
                if (response.IsSuccessStatusCode)
                {
                    var responseStr = await response.Content.ReadAsStringAsync();
                    var doc = JsonNode.Parse(responseStr);
                    var text = doc?["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(text)) return text;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Gemini ({Model}) lỗi: {Msg}", model, ex.Message);
            }
        }

        throw new Exception("Gemini không phản hồi hoặc hết hạn ngạch.");
    }

    private async Task<string> CallGroqVisionAsync(byte[] imageBytes, string contentType)
    {
        string apiKey = _config["GROQ_API_KEY"]
            ?? _config["AiKeys:GroqApiKey"]
            ?? Environment.GetEnvironmentVariable("GROQ_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey))
        {
            throw new Exception("GROQ_API_KEY chưa được cấu hình trong .env hoặc biến môi trường.");
        }

        const string model = "qwen/qwen3.8-27b";
        string base64 = Convert.ToBase64String(imageBytes);

        string url = "https://api.groq.com/openai/v1/chat/completions";
        var payload = new
        {
            model = model,
            messages = new object[]
            {
                new { role = "system", content = SystemPrompt },
                new
                {
                    role = "user",
                    content = new object[]
                    {
                        new
                        {
                            type = "image_url",
                            image_url = new { url = $"data:{contentType};base64,{base64}" }
                        },
                        new
                        {
                            type = "text",
                            text = "Kiểm tra ảnh này: Nếu không phải nguyên liệu thực phẩm hãy từ chối. Nếu là nguyên liệu hãy nhận diện đầy đủ JSON."
                        }
                    }
                }
            },
            temperature = 0.1,
            max_tokens = 800
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
        request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        using var response = await _httpClient.SendAsync(request);
        if (response.IsSuccessStatusCode)
        {
            var responseStr = await response.Content.ReadAsStringAsync();
            var doc = JsonNode.Parse(responseStr);
            var text = doc?["choices"]?[0]?["message"]?["content"]?.ToString();
            if (!string.IsNullOrWhiteSpace(text)) return text;
        }

        throw new Exception($"Groq trả về lỗi HTTP {response.StatusCode}");
    }

    private async Task<string> CallCloudflareVisionAsync(byte[] imageBytes, string contentType)
    {
        string apiToken = _config["CLOUDFLARE_API_TOKEN"]
            ?? _config["AiKeys:CloudflareApiToken"]
            ?? Environment.GetEnvironmentVariable("CLOUDFLARE_API_TOKEN")
            ?? "";
        string accountId = _config["CLOUDFLARE_ACCOUNT_ID"]
            ?? _config["AiKeys:CloudflareAccountId"]
            ?? Environment.GetEnvironmentVariable("CLOUDFLARE_ACCOUNT_ID")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiToken) || string.IsNullOrWhiteSpace(accountId))
        {
            throw new Exception("CLOUDFLARE_API_TOKEN hoặc CLOUDFLARE_ACCOUNT_ID chưa được cấu hình trong .env hoặc biến môi trường.");
        }

        const string model = "@cf/meta/llama-3.2-11b-vision-instruct";

        string url = $"https://api.cloudflare.com/client/v4/accounts/{accountId}/ai/run/{model}";
        var payload = new
        {
            prompt = $"{SystemPrompt}\n\nPhân tích ảnh: Kiểm tra xem có phải nguyên liệu thực phẩm không. Trả về DUY NHẤT một chuỗi JSON hợp lệ.",
            image = imageBytes.Select(b => (int)b).ToArray(),
            max_tokens = 800
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken);
        request.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");
        request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        using var response = await _httpClient.SendAsync(request);
        if (response.IsSuccessStatusCode)
        {
            var responseStr = await response.Content.ReadAsStringAsync();
            var doc = JsonNode.Parse(responseStr);
            var text = doc?["result"]?["response"]?.ToString();
            if (!string.IsNullOrWhiteSpace(text)) return text;
        }

        throw new Exception($"Cloudflare trả về lỗi HTTP {response.StatusCode}");
    }

    private IngredientAnalysisResultDto? ParseAiResponse(string rawText, string providerName)
    {
        try
        {
            int start = rawText.IndexOf('{');
            int end = rawText.LastIndexOf('}');
            if (start == -1 || end == -1 || end <= start) return null;

            string cleanJson = rawText.Substring(start, end - start + 1);
            var node = JsonNode.Parse(cleanJson)?.AsObject();
            if (node == null) return null;

            bool isIngredient = true;
            if (node.ContainsKey("isIngredient"))
            {
                isIngredient = node["isIngredient"]?.GetValue<bool>() ?? true;
            }

            if (!isIngredient)
            {
                string reason = node["rejectReason"]?.ToString() ??
                    "Hình ảnh không phải là nguyên liệu thực phẩm. Vui lòng chụp lại ảnh thịt, cá, trứng, rau, củ hoặc trái cây!";
                return IngredientAnalysisResultDto.Rejected(reason, providerName);
            }

            var result = new IngredientAnalysisResultDto
            {
                IsIngredient = true,
                ProviderName = providerName,
                Name = node["name"]?.ToString() ?? "Nguyên liệu tươi",
                EnglishName = node["englishName"]?.ToString() ?? "Chicken",
                Calories = node["calories"]?.ToString() ?? "150 kcal",
                Weight = node["weight"]?.ToString() ?? "~150g",
                NutritionComment = node["nutritionComment"]?.ToString() ??
                                   node["calorieAdvice"]?.ToString() ??
                                   "Nguyên liệu tươi ngon, cung cấp nguồn năng lượng và dưỡng chất thiết yếu cho cơ thể.",
                Protein = node["protein"]?.ToString() ?? "20g Protein",
                Carbs = node["carbs"]?.ToString() ?? "5g Carbs",
                Fat = node["fat"]?.ToString() ?? "3g Fat",
                Context = node["context"]?.ToString() ?? ""
            };

            // Parse CalorieNumber
            if (node.ContainsKey("calorieNumber") && int.TryParse(node["calorieNumber"]?.ToString(), out int calNum))
            {
                result.CalorieNumber = calNum;
            }
            else
            {
                var match = Regex.Match(result.Calories, @"\d+");
                result.CalorieNumber = match.Success ? int.Parse(match.Value) : 150;
            }

            // Parse danh sách ingredients nếu AI phát hiện nhiều nguyên liệu
            var ingArray = node["ingredients"]?.AsArray();
            if (ingArray != null && ingArray.Count > 0)
            {
                foreach (var item in ingArray)
                {
                    if (item == null) continue;
                    var itemObj = item.AsObject();
                    string cal = itemObj["calories"]?.ToString() ?? "100 kcal";
                    int cNum = 100;
                    if (itemObj.ContainsKey("calorieNumber") && int.TryParse(itemObj["calorieNumber"]?.ToString(), out int parsedC))
                    {
                        cNum = parsedC;
                    }
                    else
                    {
                        var m = Regex.Match(cal, @"\d+");
                        if (m.Success) cNum = int.Parse(m.Value);
                    }

                    result.Ingredients.Add(new DetectedIngredientDto
                    {
                        Name = itemObj["name"]?.ToString() ?? "Nguyên liệu",
                        EnglishName = itemObj["englishName"]?.ToString() ?? "Chicken",
                        Calories = cal,
                        CalorieNumber = cNum,
                        Weight = itemObj["weight"]?.ToString() ?? "~100g",
                        Protein = itemObj["protein"]?.ToString() ?? "15g Protein",
                        Carbs = itemObj["carbs"]?.ToString() ?? "5g Carbs",
                        Fat = itemObj["fat"]?.ToString() ?? "2g Fat",
                        NutritionComment = itemObj["nutritionComment"]?.ToString() ?? ""
                    });
                }
            }

            if (result.Ingredients.Count == 0)
            {
                result.Ingredients.Add(new DetectedIngredientDto
                {
                    Name = result.Name,
                    EnglishName = result.EnglishName,
                    Calories = result.Calories,
                    CalorieNumber = result.CalorieNumber,
                    Weight = result.Weight,
                    Protein = result.Protein,
                    Carbs = result.Carbs,
                    Fat = result.Fat,
                    NutritionComment = result.NutritionComment
                });
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể parse JSON từ AI Response: {Msg}", ex.Message);
            return null;
        }
    }
}
