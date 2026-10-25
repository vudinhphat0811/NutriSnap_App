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
        "Bạn là chuyên gia thị giác và dinh dưỡng ẩm thực.\n" +
        "NHIỆM VỤ: Phân tích khách quan hình ảnh để nhận diện các nguyên liệu thực phẩm tươi sống dùng trong nấu ăn.\n\n" +
        "QUY TẮC:\n" +
        "1. TỪ CHỐI ẢNH KHÔNG PHẢI NGUYÊN LIỆU:\n" +
        "Nếu bức ảnh KHÔNG PHẢI là thực phẩm hoặc nguyên liệu nấu ăn (ví dụ: con người, quần áo, thiết bị điện tử, đồ đạc, thú cưng...):\n" +
        "BẮT BUỘC trả về duy nhất chuỗi JSON sau:\n" +
        "{\n" +
        "  \"isIngredient\": false,\n" +
        "  \"rejectReason\": \"Ảnh không phải nguyên liệu thực phẩm. Vui lòng chụp ảnh nguyên liệu tươi sống (thịt, cá, trứng, rau, củ, quả...)!\"\n" +
        "}\n\n" +
        "2. NHẬN DIỆN KHÁCH QUAN:\n" +
        "- Quan sát kỹ hình dạng, màu sắc tự nhiên, thớ thịt hoặc bề mặt lá củ để xác định chính xác.\n" +
        "- \"name\": Đúng DUY NHẤT một tên tiếng Việt chuẩn của nguyên liệu (2 đến 4 từ). TUYỆT ĐỐI KHÔNG dùng dấu ngoặc đơn, KHÔNG dùng dấu gạch chéo, KHÔNG ghép nhiều tên bí danh khác nhau.\n" +
        "- \"englishName\": Tên danh từ tiếng Anh ẩm thực chuẩn của nguyên liệu (viết đơn lẻ, không dấu câu thừa).\n" +
        "- \"weight\": Khối lượng khẩu phần thực tế trong nấu ăn (ví dụ một mớ rau hay phần thịt khoảng 200g-300g).\n" +
        "- \"calories\": Ước tính calo hợp lý kèm đơn vị \"kcal\".\n" +
        "- \"ingredients\": Danh sách từng nguyên liệu riêng biệt. Nếu chỉ có 1 nguyên liệu thì mảng CHỈ CHỨA đúng 1 phần tử.\n\n" +
        "Trả về DUY NHẤT một chuỗi JSON hợp lệ theo cấu trúc sau:\n" +
        "{\n" +
        "  \"isIngredient\": true,\n" +
        "  \"visualObservation\": \"<Mô tả ngắn gọn quan sát thị giác thực tế>\",\n" +
        "  \"name\": \"<Tên nguyên liệu tiếng Việt súc tích, không dấu ngoặc>\",\n" +
        "  \"englishName\": \"<Tên tiếng Anh chuẩn>\",\n" +
        "  \"calories\": \"<Tổng lượng calo ước tính kèm kcal>\",\n" +
        "  \"calorieNumber\": 100,\n" +
        "  \"weight\": \"<Tổng khối lượng ước tính kèm g>\",\n" +
        "  \"nutritionComment\": \"<1 câu nhận xét giá trị dinh dưỡng bằng tiếng Việt>\",\n" +
        "  \"protein\": \"<Lượng đạm kèm g>\",\n" +
        "  \"carbs\": \"<Lượng tinh bột kèm g>\",\n" +
        "  \"fat\": \"<Lượng chất béo kèm g>\",\n" +
        "  \"context\": \"<Mô tả bối cảnh ngắn gọn>\",\n" +
        "  \"ingredients\": [\n" +
        "    {\n" +
        "      \"name\": \"<Tên nguyên liệu tiếng Việt>\",\n" +
        "      \"englishName\": \"<Tên tiếng Anh>\",\n" +
        "      \"calories\": \"<Calo kèm kcal>\",\n" +
        "      \"calorieNumber\": 50,\n" +
        "      \"weight\": \"<Khối lượng kèm g>\",\n" +
        "      \"protein\": \"<Đạm kèm g>\",\n" +
        "      \"carbs\": \"<Tinh bột kèm g>\",\n" +
        "      \"fat\": \"<Chất béo kèm g>\",\n" +
        "      \"nutritionComment\": \"<Nhận xét dinh dưỡng>\"\n" +
        "    }\n" +
        "  ]\n" +
        "}\n" +
        "TUYỆT ĐỐI không chèn mã markdown ```json, không viết thêm bất kỳ văn bản nào ngoài chuỗi JSON.";

    private const string LmStudioVisionOnlyPrompt =
        "You are an expert culinary vision analyst.\n" +
        "TASK: Identify the raw cooking ingredients visible in the photo.\n\n" +
        "RULES:\n" +
        "1. NON-FOOD REJECTION:\n" +
        "If the photo does NOT show food or raw cooking ingredients (e.g. human face, clothing, electronics, pets, furniture):\n" +
        "Return strictly: {\"isIngredient\": false, \"rejectReason\": \"Ảnh không phải nguyên liệu thực phẩm. Vui lòng chụp ảnh nguyên liệu tươi sống (thịt, cá, trứng, rau, củ, quả...)!\"}\n\n" +
        "2. RAW INGREDIENT RECOGNITION (VISION ONLY):\n" +
        "- Inspect the image: shape, cut, natural color, leaves, meat grain.\n" +
        "- \"name\": Exactly ONE concise Vietnamese culinary name (2 to 4 words). Do NOT use parentheses, do NOT use slashes, do NOT append alternate names.\n" +
        "- \"englishName\": Standard culinary English name of the ingredient (e.g. \"Water Spinach\", \"Beef\", \"Pork\", \"Egg\").\n" +
        "- \"weight\": Approximate visual portion with unit (e.g. \"~250g\" for greens, \"~300g\" for meats).\n" +
        "- \"ingredients\": List EACH distinct ingredient visible with its name, englishName, and weight.\n" +
        "- STRICTLY FORBIDDEN: Do NOT generate calories, protein, carbs, fat, or nutrition comments. Only name and weight.\n\n" +
        "Return strictly valid JSON:\n" +
        "{\n" +
        "  \"isIngredient\": true,\n" +
        "  \"name\": \"<concise Vietnamese food name>\",\n" +
        "  \"englishName\": \"<English ingredient name>\",\n" +
        "  \"weight\": \"<weight with g>\",\n" +
        "  \"ingredients\": [\n" +
        "    {\n" +
        "      \"name\": \"<concise Vietnamese ingredient name>\",\n" +
        "      \"englishName\": \"<English ingredient name>\",\n" +
        "      \"weight\": \"<weight with g>\"\n" +
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
    /// Kiểm tra LM Studio Server cục bộ có đang hoạt động hay không
    /// </summary>
    public async Task<bool> CheckLmStudioAvailableAsync()
    {
        try
        {
            string baseUrl = _config["LmStudio:BaseUrl"] ?? "http://127.0.0.1:1234/v1";
            string url = $"{baseUrl.TrimEnd('/')}/models";
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(3));
            using var response = await _httpClient.GetAsync(url, cts.Token);
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Kiểm tra LM Studio thất bại: {Message}", ex.Message);
            return false;
        }
    }

    /// <summary>
    /// Phân tích ảnh với ưu tiên số 1 là Local AI (LM Studio Qwen2.5-VL),
    /// tự động dự phòng sang Cloud (Gemini -> Groq -> Cloudflare) nếu LM Studio chưa bật hoặc gặp lỗi.
    /// </summary>
    public async Task<IngredientAnalysisResultDto> AnalyzeIngredientImageAsync(byte[] imageBytes, string contentType = "image/jpeg")
    {
        bool lmStudioEnabled = _config.GetValue<bool>("LmStudio:Enabled", true);
        if (lmStudioEnabled)
        {
            string modelName = _config["LmStudio:Model"] ?? "qwen2.5-vl-3b-instruct";
            _logger.LogInformation("Đang phân tích bằng Local AI (LM Studio: {Model})...", modelName);
            try
            {
                string rawJson = await CallLmStudioVisionAsync(imageBytes, contentType);
                if (!string.IsNullOrWhiteSpace(rawJson))
                {
                    var parsed = ParseAiResponse(rawJson, "LM Studio Local (Qwen2.5-VL)");
                    if (parsed != null)
                    {
                        if (!parsed.IsIngredient)
                        {
                            _logger.LogInformation("Local AI từ chối: ảnh không phải nguyên liệu thực phẩm.");
                            return parsed;
                        }

                        _logger.LogInformation("Local AI (LM Studio Qwen2.5-VL) nhận diện thành công: {Name} ({En}) - {Weight}. Đang chuyển giao cho AI API làm giàu dinh dưỡng & nhận xét tiếng Việt...", parsed.Name, parsed.EnglishName, parsed.Weight);

                        // Tách bạch trách nhiệm: Local AI nhận diện ảnh xong, AI API đảm nhận toàn bộ tính toán dinh dưỡng & nhận xét
                        await EnrichNutritionWithCloudAiAsync(parsed);
                        return parsed;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Local AI (LM Studio) không phản hồi hoặc lỗi ({Msg}). Đang tự động chuyển tiếp sang AI Cloud dự phòng...", ex.Message);
            }
        }

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
                        if (!parsed.IsIngredient) return parsed;

                        // Đảm bảo dinh dưỡng và nhận xét hoàn toàn bằng tiếng Việt và không có chuỗi template
                        EnsureVietnameseNutrition(parsed);
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

    /// <summary>
    /// Gọi Local AI Vision qua LM Studio (OpenAI-compatible /chat/completions với Qwen2.5-VL)
    /// CHỈ ĐẢM NHẬN NHẬN DIỆN THỊ GIÁC (Visual Recognition Only)
    /// </summary>
    private async Task<string> CallLmStudioVisionAsync(byte[] imageBytes, string contentType)
    {
        string baseUrl = _config["LmStudio:BaseUrl"] ?? "http://127.0.0.1:1234/v1";
        string model = _config["LmStudio:Model"] ?? "qwen2.5-vl-3b-instruct";
        int timeoutSec = int.TryParse(_config["LmStudio:TimeoutSeconds"], out int t) ? t : 60;

        string base64 = Convert.ToBase64String(imageBytes);
        string url = $"{baseUrl.TrimEnd('/')}/chat/completions";

        var payload = new
        {
            model = model,
            messages = new object[]
            {
                new
                {
                    role = "system",
                    content = LmStudioVisionOnlyPrompt
                },
                new
                {
                    role = "user",
                    content = new object[]
                    {
                        new
                        {
                            type = "image_url",
                            image_url = new
                            {
                                url = $"data:{contentType};base64,{base64}"
                            }
                        },
                        new
                        {
                            type = "text",
                            text = "Identify what raw cooking ingredients are visible in this image. Return valid JSON containing isIngredient, name, englishName, weight, ingredients."
                        }
                    }
                }
            },
            temperature = 0.1,
            max_tokens = 400
        };

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSec));
        using var request = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };

        using var response = await _httpClient.SendAsync(request, cts.Token);
        if (response.IsSuccessStatusCode)
        {
            var responseStr = await response.Content.ReadAsStringAsync(cts.Token);
            var doc = JsonNode.Parse(responseStr);
            var text = doc?["choices"]?[0]?["message"]?["content"]?.ToString();
            if (!string.IsNullOrWhiteSpace(text)) return text;
        }

        throw new Exception($"LM Studio trả về HTTP {response.StatusCode}");
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

    /// <summary>
    /// AI API (Cloud AI): Đảm nhận 100% việc tính toán calo, dưỡng chất (Protein, Carbs, Fat)
    /// và sinh nhận xét dinh dưỡng, bối cảnh bằng 100% Tiếng Việt tự nhiên, súc tích.
    /// </summary>
    public async Task EnrichNutritionWithCloudAiAsync(IngredientAnalysisResultDto result)
    {
        try
        {
            // Thử gọi Groq Text API (qwen/qwen3.8-27b) hoặc Gemini Text API
            bool enriched = await TryEnrichWithGroqTextAsync(result);
            if (!enriched)
            {
                enriched = await TryEnrichWithGeminiTextAsync(result);
            }

            if (!enriched)
            {
                _logger.LogWarning("Cloud AI Text API không khả dụng, tự động áp dụng công thức dinh dưỡng chuẩn hóa offline.");
                EnrichWithStandardNutrition(result);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Lỗi khi gọi AI API làm giàu dinh dưỡng ({Msg}), chuyển sang công thức dinh dưỡng tiêu chuẩn.", ex.Message);
            EnrichWithStandardNutrition(result);
        }
    }

    private async Task<bool> TryEnrichWithGroqTextAsync(IngredientAnalysisResultDto result)
    {
        string apiKey = _config["GROQ_API_KEY"]
            ?? _config["AiKeys:GroqApiKey"]
            ?? Environment.GetEnvironmentVariable("GROQ_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey)) return false;

        string prompt = BuildNutritionEnrichmentPrompt(result);
        string url = "https://api.groq.com/openai/v1/chat/completions";
        var payload = new
        {
            model = "qwen/qwen3.8-27b",
            messages = new object[]
            {
                new { role = "system", content = "Bạn là chuyên gia dinh dưỡng ẩm thực NutriSnap hàng đầu Việt Nam. Luôn phản hồi bằng DUY NHẤT một chuỗi JSON hợp lệ 100% tiếng Việt, không chèn markdown." },
                new { role = "user", content = prompt }
            },
            temperature = 0.2,
            max_tokens = 600
        };

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Headers.Add("User-Agent", "NutriSnap/1.0");
        request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        using var response = await _httpClient.SendAsync(request, cts.Token);
        if (!response.IsSuccessStatusCode) return false;

        var responseStr = await response.Content.ReadAsStringAsync(cts.Token);
        var doc = JsonNode.Parse(responseStr);
        var text = doc?["choices"]?[0]?["message"]?["content"]?.ToString();
        if (string.IsNullOrWhiteSpace(text)) return false;

        return ApplyEnrichedNutritionJson(result, text, "LM Studio Local (Thị giác) + Groq AI (Dinh dưỡng)");
    }

    private async Task<bool> TryEnrichWithGeminiTextAsync(IngredientAnalysisResultDto result)
    {
        string apiKey = _config["GEMINI_API_KEY"]
            ?? _config["AiKeys:GeminiApiKey"]
            ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey)) return false;

        string prompt = BuildNutritionEnrichmentPrompt(result);
        string[] models = { "gemini-flash-latest", "gemini-2.5-flash-lite" };

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
                            parts = new[]
                            {
                                new { text = prompt }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        temperature = 0.2,
                        maxOutputTokens = 600
                    }
                };

                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
                using var request = new HttpRequestMessage(HttpMethod.Post, url)
                {
                    Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
                };

                using var response = await _httpClient.SendAsync(request, cts.Token);
                if (!response.IsSuccessStatusCode) continue;

                var responseStr = await response.Content.ReadAsStringAsync(cts.Token);
                var doc = JsonNode.Parse(responseStr);
                var text = doc?["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return ApplyEnrichedNutritionJson(result, text, "LM Studio Local (Thị giác) + Gemini AI (Dinh dưỡng)");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Gemini Text Enrichment ({Model}) lỗi: {Msg}", model, ex.Message);
            }
        }
        return false;
    }

    private static string BuildNutritionEnrichmentPrompt(IngredientAnalysisResultDto result)
    {
        var itemsDesc = string.Join("; ", result.Ingredients.Select(i => $"{i.Name} ({i.Weight})"));
        return
            "Bạn là chuyên gia dinh dưỡng ẩm thực NutriSnap hàng đầu Việt Nam.\n" +
            "Hệ thống thị giác máy tính cục bộ vừa nhận diện được các nguyên liệu tươi sống:\n" +
            $"- Tên chính: {result.Name} ({result.EnglishName})\n" +
            $"- Khối lượng: {result.Weight}\n" +
            $"- Danh sách thành phần: {itemsDesc}\n\n" +
            "NHIỆM VỤ: Hãy tính toán calo, chất đạm (Protein), tinh bột (Carbs), chất béo (Fat) và cung cấp nhận xét giá trị dinh dưỡng.\n" +
            "YÊU CẦU NGHIÊM NGẶT:\n" +
            "1. Toàn bộ 'nutritionComment' và 'context' BẮT BUỘC viết bằng 100% TIẾNG VIỆT tự nhiên, súc tích, chuyên nghiệp. TUYỆT ĐỐI KHÔNG dùng tiếng Anh trong nhận xét.\n" +
            "2. 'calories': ghi kèm 'kcal' (vd: '50 kcal', '220 kcal').\n" +
            "3. 'protein', 'carbs', 'fat': ghi kèm 'g' và tên dưỡng chất (vd: '4g Protein', '8g Carbs', '0.5g Fat').\n" +
            "4. 'nutritionComment': 1 câu duy nhất nêu rõ tác dụng cho sức khỏe bằng tiếng Việt.\n" +
            "5. 'context': 1 câu ngắn gợi ý cách sơ chế/chế biến phù hợp bằng tiếng Việt.\n" +
            "6. 'ingredients': Cập nhật calo, protein, carbs, fat, nutritionComment cho từng nguyên liệu trong danh sách.\n\n" +
            "Trả về DUY NHẤT một JSON hợp lệ theo định dạng sau (không chèn ```json, không thêm chữ nào ngoài JSON):\n" +
            "{\n" +
            "  \"calories\": \"50 kcal\",\n" +
            "  \"calorieNumber\": 50,\n" +
            "  \"protein\": \"4g Protein\",\n" +
            "  \"carbs\": \"7g Carbs\",\n" +
            "  \"fat\": \"0.5g Fat\",\n" +
            "  \"nutritionComment\": \"Rau muống giàu chất xơ, vitamin C và sắt, giúp thanh nhiệt, kích thích tiêu hóa và hỗ trợ kiểm soát đường huyết.\",\n" +
            "  \"context\": \"Rau muống tươi non, lý tưởng cho các món xào tỏi hoặc nấu canh thanh mát.\",\n" +
            "  \"ingredients\": [\n" +
            "    {\n" +
            "      \"name\": \"" + result.Name + "\",\n" +
            "      \"calories\": \"50 kcal\",\n" +
            "      \"calorieNumber\": 50,\n" +
            "      \"protein\": \"4g Protein\",\n" +
            "      \"carbs\": \"7g Carbs\",\n" +
            "      \"fat\": \"0.5g Fat\",\n" +
            "      \"nutritionComment\": \"Giàu chất xơ và vi chất tự nhiên, thanh lọc cơ thể.\"\n" +
            "    }\n" +
            "  ]\n" +
            "}";
    }

    private bool ApplyEnrichedNutritionJson(IngredientAnalysisResultDto result, string rawText, string providerName)
    {
        try
        {
            int start = rawText.IndexOf('{');
            int end = rawText.LastIndexOf('}');
            if (start == -1 || end == -1 || end <= start) return false;

            string cleanJson = rawText.Substring(start, end - start + 1);
            var node = JsonNode.Parse(cleanJson)?.AsObject();
            if (node == null) return false;

            result.ProviderName = providerName;

            if (node.ContainsKey("calories"))
            {
                result.Calories = SanitizeMacro(node["calories"]?.ToString(), result.Calories);
            }
            if (node.ContainsKey("calorieNumber") && int.TryParse(node["calorieNumber"]?.ToString(), out int calNum) && calNum > 0)
            {
                result.CalorieNumber = calNum;
            }
            else
            {
                var m = Regex.Match(result.Calories, @"\d+");
                if (m.Success) result.CalorieNumber = int.Parse(m.Value);
            }

            result.Protein = SanitizeMacro(node["protein"]?.ToString(), result.Protein);
            result.Carbs = SanitizeMacro(node["carbs"]?.ToString(), result.Carbs);
            result.Fat = SanitizeMacro(node["fat"]?.ToString(), result.Fat);

            string? nutComment = node["nutritionComment"]?.ToString();
            if (!string.IsNullOrWhiteSpace(nutComment) && !nutComment.Contains('<') && !nutComment.Contains("estimated") && !IsEnglishText(nutComment))
            {
                result.NutritionComment = nutComment.Trim();
            }

            string? ctx = node["context"]?.ToString();
            if (!string.IsNullOrWhiteSpace(ctx) && !ctx.Contains('<') && !ctx.Contains("estimated") && !IsEnglishText(ctx))
            {
                result.Context = ctx.Trim();
            }

            // Cập nhật cho từng thành phần trong ingredients
            var ingArray = node["ingredients"]?.AsArray();
            if (ingArray != null && ingArray.Count > 0)
            {
                for (int i = 0; i < ingArray.Count && i < result.Ingredients.Count; i++)
                {
                    var itemNode = ingArray[i]?.AsObject();
                    if (itemNode == null) continue;

                    var ing = result.Ingredients[i];
                    if (itemNode.ContainsKey("calories"))
                    {
                        ing.Calories = SanitizeMacro(itemNode["calories"]?.ToString(), ing.Calories);
                    }
                    if (itemNode.ContainsKey("calorieNumber") && int.TryParse(itemNode["calorieNumber"]?.ToString(), out int iCal) && iCal > 0)
                    {
                        ing.CalorieNumber = iCal;
                    }
                    else
                    {
                        var m = Regex.Match(ing.Calories, @"\d+");
                        if (m.Success) ing.CalorieNumber = int.Parse(m.Value);
                    }

                    ing.Protein = SanitizeMacro(itemNode["protein"]?.ToString(), ing.Protein);
                    ing.Carbs = SanitizeMacro(itemNode["carbs"]?.ToString(), ing.Carbs);
                    ing.Fat = SanitizeMacro(itemNode["fat"]?.ToString(), ing.Fat);

                    string? iNut = itemNode["nutritionComment"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(iNut) && !iNut.Contains('<') && !iNut.Contains("estimated") && !IsEnglishText(iNut))
                    {
                        ing.NutritionComment = iNut.Trim();
                    }
                }
            }

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Lỗi phân giải JSON dinh dưỡng từ Cloud AI: {Msg}", ex.Message);
            return false;
        }
    }

    /// <summary>
    /// Bổ sung dinh dưỡng chuẩn hóa hoàn toàn bằng 100% Tiếng Việt khi Cloud AI ngoại tuyến
    /// </summary>
    public static void EnrichWithStandardNutrition(IngredientAnalysisResultDto result)
    {
        result.ProviderName = "LM Studio Local (Thị giác) + Dinh dưỡng tiêu chuẩn NutriSnap";

        foreach (var ing in result.Ingredients)
        {
            ApplyFoodTypeNutrition(ing, ing.Name, ing.Weight);
        }

        if (result.Ingredients.Count > 0)
        {
            var primary = result.Ingredients[0];
            int totalCal = result.Ingredients.Sum(i => i.CalorieNumber);
            result.CalorieNumber = totalCal > 0 ? totalCal : primary.CalorieNumber;
            result.Calories = $"{result.CalorieNumber} kcal";
            result.Protein = primary.Protein;
            result.Carbs = primary.Carbs;
            result.Fat = primary.Fat;
            result.NutritionComment = primary.NutritionComment;
            result.Context = $"Nguyên liệu {result.Name.ToLower()} tươi sạch, sẵn sàng cho các công thức chế biến hấp dẫn.";
        }
    }

    public static void EnsureVietnameseNutrition(IngredientAnalysisResultDto result)
    {
        result.Protein = SanitizeMacro(result.Protein, "15g Protein");
        result.Carbs = SanitizeMacro(result.Carbs, "5g Carbs");
        result.Fat = SanitizeMacro(result.Fat, "2g Fat");
        result.Calories = SanitizeMacro(result.Calories, "150 kcal");

        foreach (var ing in result.Ingredients)
        {
            ing.Protein = SanitizeMacro(ing.Protein, "15g Protein");
            ing.Carbs = SanitizeMacro(ing.Carbs, "5g Carbs");
            ing.Fat = SanitizeMacro(ing.Fat, "2g Fat");
            ing.Calories = SanitizeMacro(ing.Calories, "150 kcal");

            if (IsEnglishText(ing.NutritionComment) || ing.NutritionComment.Contains('<') || ing.NutritionComment.Contains("estimated", StringComparison.OrdinalIgnoreCase) || string.IsNullOrWhiteSpace(ing.NutritionComment))
            {
                ApplyFoodTypeNutrition(ing, ing.Name, ing.Weight);
            }
        }

        if (IsEnglishText(result.NutritionComment) || result.NutritionComment.Contains('<') || result.NutritionComment.Contains("estimated", StringComparison.OrdinalIgnoreCase) || string.IsNullOrWhiteSpace(result.NutritionComment))
        {
            if (result.Ingredients.Count > 0)
            {
                result.NutritionComment = result.Ingredients[0].NutritionComment;
            }
            else
            {
                var temp = new DetectedIngredientDto();
                ApplyFoodTypeNutrition(temp, result.Name, result.Weight);
                result.NutritionComment = temp.NutritionComment;
            }
        }

        if (IsEnglishText(result.Context) || result.Context.Contains('<') || result.Context.Contains("estimated", StringComparison.OrdinalIgnoreCase) || string.IsNullOrWhiteSpace(result.Context))
        {
            result.Context = $"Nguyên liệu {result.Name.ToLower()} tươi ngon, phù hợp cho nhiều món ăn bổ dưỡng.";
        }
    }

    private static void ApplyFoodTypeNutrition(DetectedIngredientDto ing, string name, string weightStr)
    {
        int grams = 200;
        var m = Regex.Match(weightStr ?? "", @"\d+");
        if (m.Success && int.TryParse(m.Value, out int g)) grams = g;
        if (grams <= 0) grams = 200;
        double factor = grams / 100.0;

        string lower = name.ToLower();

        // 1. Rau củ quả lá xanh
        if (lower.Contains("muống") || lower.Contains("cải") || lower.Contains("rau") || lower.Contains("xà lách") || lower.Contains("spinach") || lower.Contains("lá"))
        {
            int cal = (int)Math.Round(22 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 45;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(2.5 * factor)}g Protein";
            ing.Carbs = $"{(int)Math.Round(3.5 * factor)}g Carbs";
            ing.Fat = "0.3g Fat";
            ing.NutritionComment = $"{name} rất giàu chất xơ tự nhiên, vitamin A, C và sắt, giúp thanh nhiệt, hỗ trợ tiêu hóa và kiểm soát calo.";
            return;
        }

        // 2. Thịt bò
        if (lower.Contains("bò") || lower.Contains("beef") || lower.Contains("steak"))
        {
            int cal = (int)Math.Round(240 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 480;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(26 * factor)}g Protein";
            ing.Carbs = "0g Carbs";
            ing.Fat = $"{(int)Math.Round(15 * factor)}g Fat";
            ing.NutritionComment = $"{name} cung cấp nguồn đạm hoàn chỉnh cao cấp, dồi dào sắt heme và kẽm, hỗ trợ tái tạo cơ bắp và năng lượng bền bỉ.";
            return;
        }

        // 3. Thịt heo
        if (lower.Contains("heo") || lower.Contains("lợn") || lower.Contains("pork") || lower.Contains("ba chỉ") || lower.Contains("sườn"))
        {
            int cal = (int)Math.Round(230 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 460;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(21 * factor)}g Protein";
            ing.Carbs = "0g Carbs";
            ing.Fat = $"{(int)Math.Round(16 * factor)}g Fat";
            ing.NutritionComment = $"{name} giàu vitamin B1 (thiamine) và protein chất lượng cao, giúp tăng cường chuyển hóa năng lượng cho cơ thể.";
            return;
        }

        // 4. Thịt gà / gia cầm
        if (lower.Contains("gà") || lower.Contains("chicken") || lower.Contains("vịt") || lower.Contains("ức"))
        {
            int cal = (int)Math.Round(165 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 330;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(31 * factor)}g Protein";
            ing.Carbs = "0g Carbs";
            ing.Fat = $"{(int)Math.Round(3.6 * factor)}g Fat";
            ing.NutritionComment = $"{name} là nguồn protein nạc hàng đầu, ít chất béo bão hòa, lý tưởng cho chế độ ăn tăng cơ giảm mỡ.";
            return;
        }

        // 5. Trứng
        if (lower.Contains("trứng") || lower.Contains("egg"))
        {
            int cal = (int)Math.Round(145 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 145;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(13 * factor)}g Protein";
            ing.Carbs = "1g Carbs";
            ing.Fat = $"{(int)Math.Round(10 * factor)}g Fat";
            ing.NutritionComment = $"{name} là tiêu chuẩn vàng về protein sinh học, giàu choline và lecithin tốt cho não bộ và thị lực.";
            return;
        }

        // 6. Cá & Thủy hải sản
        if (lower.Contains("cá") || lower.Contains("tôm") || lower.Contains("mực") || lower.Contains("hải sản") || lower.Contains("fish") || lower.Contains("shrimp") || lower.Contains("salmon"))
        {
            int cal = (int)Math.Round(150 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 300;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(22 * factor)}g Protein";
            ing.Carbs = "0g Carbs";
            ing.Fat = $"{(int)Math.Round(5 * factor)}g Fat";
            ing.NutritionComment = $"{name} giàu axit béo Omega-3 tự nhiên và đạm dễ hấp thu, hỗ trợ sức khỏe tim mạch và chống viêm hiệu quả.";
            return;
        }

        // 7. Đậu hũ / Đậu nành
        if (lower.Contains("đậu") || lower.Contains("tofu") || lower.Contains("đỗ"))
        {
            int cal = (int)Math.Round(80 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 160;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(8 * factor)}g Protein";
            ing.Carbs = $"{(int)Math.Round(2 * factor)}g Carbs";
            ing.Fat = $"{(int)Math.Round(4 * factor)}g Fat";
            ing.NutritionComment = $"{name} là nguồn đạm thực vật lành mạnh, giàu canxi và isoflavone, hoàn toàn không chứa cholesterol xấu.";
            return;
        }

        // 8. Tinh bột / Củ
        if (lower.Contains("khoai") || lower.Contains("bắp") || lower.Contains("ngô") || lower.Contains("potato") || lower.Contains("corn"))
        {
            int cal = (int)Math.Round(95 * factor);
            ing.CalorieNumber = cal > 0 ? cal : 190;
            ing.Calories = $"{ing.CalorieNumber} kcal";
            ing.Protein = $"{(int)Math.Round(2 * factor)}g Protein";
            ing.Carbs = $"{(int)Math.Round(22 * factor)}g Carbs";
            ing.Fat = "0.2g Fat";
            ing.NutritionComment = $"{name} bổ sung carbohydrate chuyển hóa chậm cùng chất xơ và kali, cung cấp năng lượng ổn định.";
            return;
        }

        // Mặc định thực phẩm tươi
        int defCal = (int)Math.Round(100 * factor);
        ing.CalorieNumber = defCal > 0 ? defCal : 150;
        ing.Calories = $"{ing.CalorieNumber} kcal";
        ing.Protein = $"{(int)Math.Round(5 * factor)}g Protein";
        ing.Carbs = $"{(int)Math.Round(10 * factor)}g Carbs";
        ing.Fat = "2g Fat";
        ing.NutritionComment = $"{name} tươi sạch, cung cấp các dưỡng chất thiết yếu và năng lượng lành mạnh cho cơ thể.";
    }

    private static bool IsEnglishText(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return false;
        string s = text.Trim();
        bool hasEnglishWords = Regex.IsMatch(s, @"\b(the|is|are|rich|source|with|displayed|fresh|leaves|minerals|vitamins|ingredient|addition|healthy|culinary)\b", RegexOptions.IgnoreCase);
        bool hasVietnameseDiacritics = Regex.IsMatch(s, @"[àáảãạăắằẳẵặâấầẩẫậđèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵ]");
        return hasEnglishWords && !hasVietnameseDiacritics;
    }

    public static string SanitizeMacro(string? raw, string fallback)
    {
        if (string.IsNullOrWhiteSpace(raw)) return fallback;
        string s = raw.Trim();
        if (s.Contains('<') || s.Contains('>') || s.Contains("estimated", StringComparison.OrdinalIgnoreCase))
        {
            return fallback;
        }
        return s;
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

            string engName = "Beef";
            if (node.ContainsKey("englishName"))
            {
                if (node["englishName"] is JsonArray arr && arr.Count > 0)
                {
                    engName = arr[0]?.ToString() ?? "Beef";
                }
                else
                {
                    engName = node["englishName"]?.ToString() ?? "Beef";
                }
            }

            string calStr = "150 kcal";
            if (node.ContainsKey("calories"))
            {
                if (node["calories"] is JsonObject cObj && cObj.ContainsKey("total"))
                {
                    calStr = $"{cObj["total"]} kcal";
                }
                else
                {
                    calStr = node["calories"]?.ToString() ?? "150 kcal";
                }
            }

            string nutComment = "Nguyên liệu tươi ngon, cung cấp nguồn năng lượng và dưỡng chất thiết yếu cho cơ thể.";
            if (node.ContainsKey("nutritionComment"))
            {
                if (node["nutritionComment"] is JsonArray nArr && nArr.Count > 0)
                {
                    nutComment = nArr[0]?.ToString() ?? nutComment;
                }
                else
                {
                    nutComment = node["nutritionComment"]?.ToString() ?? nutComment;
                }
            }

            string ExtractField(string key, string defVal)
            {
                if (!node.ContainsKey(key)) return defVal;
                var n = node[key];
                if (n == null) return defVal;
                if (n is JsonValue) return n.ToString();
                if (n is JsonObject obj && obj.Count > 0)
                {
                    return obj.FirstOrDefault().Value?.ToString() ?? defVal;
                }
                return n.ToString();
            }

            string rawName = node["name"]?.ToString() ?? "Nguyên liệu tươi";
            var (cleanName, cleanEngName) = ResolveStandardFoodName(rawName, engName);
            string cleanWeight = NormalizeWeight(ExtractField("weight", "~200g"), cleanName);

            var result = new IngredientAnalysisResultDto
            {
                IsIngredient = true,
                ProviderName = providerName,
                Name = cleanName,
                EnglishName = cleanEngName,
                Calories = SanitizeMacro(calStr, "150 kcal"),
                Weight = cleanWeight,
                NutritionComment = nutComment,
                Protein = SanitizeMacro(ExtractField("protein", "15g Protein"), "15g Protein"),
                Carbs = SanitizeMacro(ExtractField("carbs", "5g Carbs"), "5g Carbs"),
                Fat = SanitizeMacro(ExtractField("fat", "2g Fat"), "2g Fat"),
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
            if (ingArray == null && node.ContainsKey("englishName") && node["englishName"] is JsonArray)
            {
                ingArray = node["englishName"]?.AsArray();
            }
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

                    string rawItemName = itemObj["name"]?.ToString() ?? cleanName;
                    string rawItemEng = itemObj["englishName"]?.ToString() ?? cleanEngName;
                    var (cItemName, cItemEng) = ResolveStandardFoodName(rawItemName, rawItemEng);
                    string cItemWeight = NormalizeWeight(itemObj["weight"]?.ToString() ?? "~150g", cItemName);

                    // Tránh trùng lặp tên nguyên liệu trong danh sách
                    if (!result.Ingredients.Any(i => i.Name.Equals(cItemName, StringComparison.OrdinalIgnoreCase)))
                    {
                        result.Ingredients.Add(new DetectedIngredientDto
                        {
                            Name = cItemName,
                            EnglishName = cItemEng,
                            Calories = SanitizeMacro(cal, "100 kcal"),
                            CalorieNumber = cNum,
                            Weight = cItemWeight,
                            Protein = SanitizeMacro(itemObj["protein"]?.ToString(), "15g Protein"),
                            Carbs = SanitizeMacro(itemObj["carbs"]?.ToString(), "5g Carbs"),
                            Fat = SanitizeMacro(itemObj["fat"]?.ToString(), "2g Fat"),
                            NutritionComment = itemObj["nutritionComment"]?.ToString() ?? ""
                        });
                    }
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
            else if (result.Ingredients.Count == 1)
            {
                // Đồng bộ tên gốc với nguyên liệu duy nhất
                result.Name = result.Ingredients[0].Name;
                result.EnglishName = result.Ingredients[0].EnglishName;
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể parse JSON từ AI Response: {Msg}", ex.Message);
            return null;
        }
    }

    /// <summary>
    /// Chuẩn hóa và làm sạch tên nguyên liệu (loại bỏ ngoặc đơn, bí danh ghép, ký tự lạ...)
    /// </summary>
    public static string CleanFoodName(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return "Nguyên liệu tươi";

        string cleaned = raw.Trim();

        // 1. Nếu có ngoặc đơn hoặc ngoặc vuông (ví dụ: "Rau muống (Cải xanh)" hoặc "Thịt bò (Beef)"):
        int parenIdx = cleaned.IndexOf('(');
        if (parenIdx > 0)
        {
            cleaned = cleaned.Substring(0, parenIdx).Trim();
        }
        int bracketIdx = cleaned.IndexOf('[');
        if (bracketIdx > 0)
        {
            cleaned = cleaned.Substring(0, bracketIdx).Trim();
        }

        // 2. Nếu có dấu xẹt / phân cách nhiều tên (ví dụ: "Rau muống / Cải xanh"):
        int slashIdx = cleaned.IndexOf('/');
        if (slashIdx > 0)
        {
            cleaned = cleaned.Substring(0, slashIdx).Trim();
        }

        // 3. Loại bỏ các tiền tố thường gặp do AI sinh ra
        string[] prefixes = { "Tên:", "Món:", "Nguyên liệu:", "Đây là", "Ảnh chụp" };
        foreach (var p in prefixes)
        {
            if (cleaned.StartsWith(p, StringComparison.OrdinalIgnoreCase))
            {
                cleaned = cleaned.Substring(p.Length).Trim();
            }
        }

        // 4. Bỏ dấu nháy và ký tự đặc biệt thừa
        cleaned = cleaned.Trim('"', '\'', '`', '.', ',', ':', '-', ' ');

        return string.IsNullOrWhiteSpace(cleaned) ? "Nguyên liệu tươi" : cleaned;
    }

    /// <summary>
    /// Đối soát tên tiếng Việt với englishName và từ điển ẩm thực chuẩn
    /// </summary>
    public static (string CleanName, string CleanEnglishName) ResolveStandardFoodName(string rawVi, string rawEn)
    {
        string vi = CleanFoodName(rawVi);
        string en = CleanFoodName(rawEn);

        if (en.Contains('(')) en = en.Substring(0, en.IndexOf('(')).Trim();
        if (en.Contains('/')) en = en.Substring(0, en.IndexOf('/')).Trim();

        string viLower = vi.ToLower();
        string enLower = en.ToLower();

        // 1. Bỏ các tiền tố động từ chế biến (ví dụ: "xào rau xanh", "luộc rau muống", "nấu canh thịt bò"...)
        string[] cookingVerbs = { "xào", "nấu", "luộc", "kho", "hấp", "chiên", "nướng", "hầm", "canh" };
        foreach (var verb in cookingVerbs)
        {
            if (viLower.StartsWith(verb + " "))
            {
                vi = vi.Substring(verb.Length + 1).Trim();
                viLower = vi.ToLower();
                break;
            }
        }

        // 2. Tra cứu đối soát với từ điển ẩm thực chuẩn
        string? mappedVi = null;
        if (enLower.Contains("chinese broccoli") || enLower.Contains("gai lan") || enLower.Contains("kai lan") || enLower.Contains("choy sum") || enLower.Contains("choi sum"))
        {
            mappedVi = "Cải ngồng";
        }
        else if (enLower.Contains("chinese cabbage") || enLower.Contains("napa cabbage"))
        {
            mappedVi = "Cải thảo";
        }
        else if (enLower.Contains("water spinach") || enLower.Contains("morning glory") || enLower.Contains("spinach"))
        {
            mappedVi = "Rau muống";
        }
        else if (enLower.Contains("bok choy") || enLower.Contains("pak choi"))
        {
            mappedVi = "Cải thìa";
        }
        else if (enLower.Contains("mustard"))
        {
            mappedVi = "Cải xanh";
        }
        else if (enLower.Contains("broccoli"))
        {
            mappedVi = "Bông cải xanh";
        }
        else if (TranslationService.QuickDictionary.TryGetValue(enLower, out string? dictMatch) && !string.IsNullOrWhiteSpace(dictMatch))
        {
            mappedVi = dictMatch;
        }
        else if (enLower.Contains("cabbage"))
        {
            mappedVi = "Bắp cải";
        }
        else if (enLower.Contains("lettuce"))
        {
            mappedVi = "Xà lách";
        }
        else if (enLower.Contains("beef"))
        {
            mappedVi = "Thịt bò";
        }
        else if (enLower.Contains("pork"))
        {
            mappedVi = "Thịt heo";
        }
        else if (enLower.Contains("chicken"))
        {
            mappedVi = "Thịt gà";
        }
        else if (enLower.Contains("egg"))
        {
            mappedVi = "Trứng";
        }
        else if (enLower.Contains("tomato"))
        {
            mappedVi = "Cà chua";
        }
        else if (enLower.Contains("garlic"))
        {
            mappedVi = "Tỏi";
        }
        else if (enLower.Contains("onion"))
        {
            mappedVi = "Hành tây";
        }

        // 3. Quyết định tên tiếng Việt:
        // Nếu AI trả về tên tiếng Việt chứa từ lạ/ảo/rác do model nhỏ bị ảo giác ngữ cảnh
        // (ví dụ: "xuống cua", "xuống rau", "lá non", "cây xanh", "rau xanh", "nguyên liệu"...)
        // hoặc tên tiếng Việt không chứa từ khóa ẩm thực chuẩn của mappedVi,
        // thì BẮT BUỘC thay thế bằng mappedVi chuẩn từ từ điển ẩm thực!
        if (!string.IsNullOrWhiteSpace(mappedVi))
        {
            bool isViSuspicious = viLower.StartsWith("xuống") ||
                                  (viLower.Contains("cua") && !enLower.Contains("crab")) ||
                                  viLower == "lá non" || viLower == "cây xanh" || viLower == "rau" ||
                                  viLower == "rau xanh" || viLower == "rau tươi" || viLower == "rau củ" ||
                                  viLower == "thực phẩm" || viLower == "nguyên liệu" || viLower == "nguyên liệu tươi" ||
                                  viLower.Length < 3;

            if (isViSuspicious ||
                (!viLower.Contains("cải") && mappedVi.Contains("Cải")) ||
                (!viLower.Contains("bò") && mappedVi.Contains("bò")) ||
                (!viLower.Contains("heo") && !viLower.Contains("lợn") && mappedVi.Contains("heo")) ||
                (!viLower.Contains("muống") && mappedVi.Contains("muống")))
            {
                vi = mappedVi;
            }
        }
        else
        {
            if (viLower.Contains("rau muống") || viLower.Contains("muống"))
            {
                en = "Water Spinach";
            }
            else if (viLower.Contains("cải thìa") || viLower.Contains("cải chíp"))
            {
                en = "Bok Choy";
            }
            else if (viLower.Contains("cải ngồng"))
            {
                en = "Choy Sum";
            }
            else if (viLower.Contains("cải ngọt") || viLower.Contains("cải xanh"))
            {
                en = "Mustard Greens";
            }
            else if (viLower.Contains("thịt bò") || viLower == "bò")
            {
                en = "Beef";
            }
            else if (viLower.Contains("thịt heo") || viLower.Contains("thịt lợn") || viLower.Contains("ba chỉ"))
            {
                en = "Pork";
            }
            else if (viLower.Contains("thịt gà") || viLower == "gà")
            {
                en = "Chicken";
            }
        }

        return (vi, en);
    }

    /// <summary>
    /// Chuẩn hóa phần khẩu phần (weight) thực tế theo ẩm thực bếp ăn
    /// </summary>
    public static string NormalizeWeight(string rawWeight, string foodName)
    {
        string w = rawWeight?.Trim() ?? "";
        var match = Regex.Match(w, @"\d+");
        if (match.Success && int.TryParse(match.Value, out int grams))
        {
            string lower = foodName.ToLower();
            bool isVeg = lower.Contains("rau") || lower.Contains("cải") || lower.Contains("muống");
            bool isMeat = lower.Contains("thịt") || lower.Contains("bò") || lower.Contains("heo") || lower.Contains("gà");

            if (isVeg && grams < 50) return "~250g";
            if (isMeat && grams < 50) return "~200g";
            return $"~{grams}g";
        }
        return string.IsNullOrWhiteSpace(w) ? "~200g" : w;
    }
}
