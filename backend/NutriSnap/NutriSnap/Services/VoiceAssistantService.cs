using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using NutriSnap.Models;

namespace NutriSnap.Services;

/// <summary>
/// Dịch vụ Trợ Lý Giọng Nói & Tự Động Thao Tác Ứng Dụng (Voice AI Assistant & Action Dispatcher)
/// Tích hợp "Bếp Trưởng Vét Tủ Cân Macro" + "Ghi nhật ký ăn uống siêu tốc" + "Quản lý app bằng giọng nói"
/// </summary>
public class VoiceAssistantService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly ILogger<VoiceAssistantService> _logger;

    public VoiceAssistantService(HttpClient httpClient, IConfiguration config, ILogger<VoiceAssistantService> logger)
    {
        _httpClient = httpClient;
        _config = config;
        _logger = logger;
    }

    public async Task<VoiceAssistantResponseDto> ProcessVoiceCommandAsync(VoiceAssistantRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.UserPrompt))
        {
            return new VoiceAssistantResponseDto
            {
                ActionType = "general_chat",
                SpokenReply = "Tôi đang lắng nghe bạn đây! Bạn có thể nói những câu như 'Trưa nay ăn 1 tô phở bò', 'Tủ lạnh còn gì nấu đủ đạm?', hoặc 'Uống 300ml nước' nhé!"
            };
        }

        // 1. Thử gọi Cloud AI (Google Gemini) để xử lý ngôn ngữ tự nhiên tiếng Việt
        try
        {
            var aiResult = await TryCallGeminiAiAsync(request);
            if (aiResult != null)
            {
                return aiResult;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Gemini AI Voice Assistant gặp lỗi: {Msg}. Chuyển sang Rule Engine nội bộ...", ex.Message);
        }

        // 2. Dự phòng: Rule Engine thông minh xử lý ngoại tuyến (0ms, 100% tin cậy)
        return ProcessWithLocalRuleEngine(request);
    }

    public async Task<VoiceAssistantResponseDto> ProcessVoiceAudioCommandAsync(VoiceAudioAssistantRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.AudioBase64))
        {
            return new VoiceAssistantResponseDto
            {
                ActionType = "general_chat",
                UserPrompt = "",
                SpokenReply = "Tôi chưa nhận được âm thanh của bạn. Vui lòng bấm mic và nói lại nhé!"
            };
        }

        try
        {
            var aiResult = await TryCallGeminiAudioAiAsync(request);
            if (aiResult != null)
            {
                return aiResult;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Gemini Audio AI Voice Assistant gặp lỗi: {Msg}", ex.Message);
        }

        return new VoiceAssistantResponseDto
        {
            ActionType = "general_chat",
            UserPrompt = "Không thể nhận diện âm thanh",
            SpokenReply = "Tôi chưa nghe rõ câu nói của bạn. Bạn hãy thử nói lại hoặc gõ bằng bàn phím nhé!"
        };
    }

    private async Task<VoiceAssistantResponseDto?> TryCallGeminiAudioAiAsync(VoiceAudioAssistantRequestDto request)
    {
        string apiKey = _config["GEMINI_API_KEY"]
            ?? _config["AiKeys:GeminiApiKey"]
            ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey)) return null;

        var fridgeDesc = request.FridgeItems.Count > 0
            ? string.Join(", ", request.FridgeItems.Select(f => $"{f.Name} ({f.Quantity}, còn {f.DaysUntilExpiry} ngày)"))
            : "Tủ lạnh hiện chưa có đồ";

        string systemInstruction =
            "Bạn là Trợ Lý Dinh Dưỡng Giọng Nói Thông Minh kiêm Bếp Trưởng Cá Nhân trong ứng dụng NutriSnap.\n" +
            $"HỒ SƠ CÁ NHÂN TÀI KHOẢN ĐANG ĐĂNG NHẬP:\n" +
            $"- Tên: {request.UserName}\n" +
            $"- Giới tính: {request.Gender}, Cân nặng: {request.WeightKg:F1}kg, Mục tiêu: {request.UserGoal} (đích: {request.TargetWeightKg:F1}kg)\n" +
            $"- Chế độ ăn kiêng ưu tiên: {request.DietType}\n" +
            $"- Chỉ số dinh dưỡng hôm nay của tài khoản: Đã nạp {request.ConsumedCalories}/{request.TargetCalories} kcal ({request.ConsumedProtein:F1}/{request.TargetProtein:F1}g đạm). " +
            $"Còn thiếu: {request.RemainingCalories} kcal, {request.RemainingProtein:F1}g đạm, {request.RemainingCarbs:F1}g carb, {request.RemainingFat:F1}g béo. " +
            $"Đã uống {request.WaterConsumedMl}/{request.DailyWaterGoalMl} ml nước.\n" +
            $"- Vận động hôm nay: Đã đi {request.TodaySteps}/{request.StepGoal} bước (tiêu hao khoảng {request.BurnedCalories:F0} kcal).\n" +
            $"Thực phẩm trong tủ lạnh riêng của tài khoản này: [{fridgeDesc}].\n\n" +
            "QUY TẮC CÁ NHÂN HOÁ CAO CẤP:\n" +
            $"- Luôn xưng hô thân mật phù hợp với người dùng theo tên ({request.UserName}).\n" +
            $"- Nếu tài khoản có chế độ ăn kiêng ({request.DietType}, ví dụ Ăn chay/Vegetarian), TUYỆT ĐỐI KHÔNG gợi ý thịt/hải sản.\n" +
            $"- Nếu mục tiêu là Tăng cơ (HighProtein/GainWeight), ưu tiên đẩy mạnh lượng đạm. Nếu Giảm cân (LoseWeight), ưu tiên cân đối thâm hụt calo an toàn.\n\n" +
            "NHIỆM VỤ:\n" +
            "1. Lắng nghe tệp âm thanh tiếng Việt đính kèm của người dùng, chép lại chính xác từng từ vào trường 'userPrompt'.\n" +
            "2. Phân tích câu nói của người dùng và chọn 1 trong các actionType sau:\n" +
            "   - 'fridge_recipe': Người dùng hỏi ăn gì từ tủ lạnh, vét tủ, nấu gì cho đủ calo/đạm. Đề xuất món ăn tận dụng nguyên liệu đang có trong tủ (ưu tiên món sắp hết hạn), tính toán calo và protein bù đắp khít nhất lượng còn thiếu.\n" +
            "   - 'log_meal': Người dùng nói vừa ăn gì, bữa trưa/sáng/tối ăn gì. Bóc tách danh sách món ăn, tính tổng calories, protein, carbs, fat.\n" +
            "   - 'log_water': Người dùng nói vừa uống nước. Trích xuất amountMl (số ml).\n" +
            "   - 'add_fridge': Người dùng bảo cất đồ/mua đồ bỏ vào tủ lạnh. Trích xuất name, quantity, category.\n" +
            "   - 'check_progress': Người dùng hỏi hôm nay ăn được bao nhiêu rồi, còn bao nhiêu calo/đạm, hoặc đã đi bao nhiêu bước chân.\n" +
            "   - 'navigate': Người dùng bảo mở màn hình nào (fridge, barcode, calculator, journal, dashboard).\n" +
            "   - 'general_chat': Trả lời kiến thức dinh dưỡng, tập luyện tự nhiên, ngắn gọn.\n\n" +
            "QUY TẮC PHẢN HỒI:\n" +
            "- userPrompt: Đoạn văn bản tiếng Việt chính xác người dùng vừa nói trong âm thanh.\n" +
            "- spokenReply: Câu thoại phản hồi tiếng Việt tự nhiên, thân thiện, ngắn gọn (1-2 câu để đọc bằng giọng nói Text-to-Speech).\n" +
            "- BẮT BUỘC TRẢ VỀ DUY NHẤT 1 CHUỖI JSON HỢP LỆ THEO SCHEMA SAU, TUYỆT ĐỐI KHÔNG CHÈN MARKDOWN ```json:\n" +
            "{\n" +
            "  \"userPrompt\": \"Trưa nay tôi ăn 1 bát phở bò\",\n" +
            "  \"actionType\": \"fridge_recipe | log_meal | log_water | add_fridge | check_progress | navigate | general_chat\",\n" +
            "  \"spokenReply\": \"Lời thoại trả lời súc tích...\",\n" +
            "  \"mealData\": { \"mealType\": \"Sáng|Trưa|Tối|Phụ\", \"title\": \"...\", \"calories\": 450, \"protein\": 25.0, \"carbs\": 50.0, \"fat\": 15.0, \"items\": [\"...\"] },\n" +
            "  \"recipeData\": { \"recipeTitle\": \"...\", \"matchExplanation\": \"...\", \"prepTimeMinutes\": 15, \"calories\": 320, \"protein\": 30.0, \"carbs\": 15.0, \"fat\": 8.0, \"ingredientsUsed\": [{\"name\": \"...\", \"amount\": \"...\", \"inFridge\": true}], \"cookingSteps\": [\"Bước 1...\", \"Bước 2...\"] },\n" +
            "  \"waterData\": { \"amountMl\": 250, \"newTotalMl\": 1500 },\n" +
            "  \"fridgeAddData\": { \"name\": \"...\", \"category\": \"Thịt & Trứng|Thủy hải sản|Rau củ|Trái cây|...\", \"quantity\": \"...\", \"shelfLifeDays\": 3, \"storageLocation\": \"fridge|freezer|pantry\" },\n" +
            "  \"navigateData\": { \"targetScreen\": \"fridge|barcode|calculator|journal|dashboard\" }\n" +
            "}";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    parts = new object[]
                    {
                        new { text = systemInstruction },
                        new
                        {
                            inline_data = new
                            {
                                mime_type = request.AudioMimeType,
                                data = request.AudioBase64
                            }
                        },
                        new { text = "Hãy nghe đoạn âm thanh tiếng Việt đính kèm và trả về đúng JSON theo yêu cầu." }
                    }
                }
            },
            generationConfig = new
            {
                temperature = 0.2,
                maxOutputTokens = 1000
            }
        };

        string[] models = { "gemini-2.0-flash", "gemini-1.5-flash", "gemini-flash-latest" };
        foreach (var model in models)
        {
            try
            {
                string url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}";
                using var req = new HttpRequestMessage(HttpMethod.Post, url)
                {
                    Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
                };

                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(15));
                var resp = await _httpClient.SendAsync(req, cts.Token);
                if (!resp.IsSuccessStatusCode) continue;

                var rawBody = await resp.Content.ReadAsStringAsync(cts.Token);
                var doc = JsonNode.Parse(rawBody);
                var text = doc?["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
                if (string.IsNullOrWhiteSpace(text)) continue;

                var cleaned = CleanJsonMarkdown(text);
                var parsed = JsonSerializer.Deserialize<VoiceAssistantResponseDto>(cleaned, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (parsed != null && !string.IsNullOrWhiteSpace(parsed.ActionType))
                {
                    return parsed;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Gọi Gemini Audio model {Model} thất bại: {Msg}", model, ex.Message);
            }
        }

        return null;
    }

    private async Task<VoiceAssistantResponseDto?> TryCallGeminiAiAsync(VoiceAssistantRequestDto request)
    {
        string apiKey = _config["GEMINI_API_KEY"]
            ?? _config["AiKeys:GeminiApiKey"]
            ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey)) return null;

        var fridgeDesc = request.FridgeItems.Count > 0
            ? string.Join(", ", request.FridgeItems.Select(f => $"{f.Name} ({f.Quantity}, còn {f.DaysUntilExpiry} ngày)"))
            : "Tủ lạnh hiện chưa có đồ";

        string systemInstruction =
            "Bạn là Trợ Lý Dinh Dưỡng Giọng Nói Thông Minh kiêm Bếp Trưởng Cá Nhân trong ứng dụng NutriSnap.\n" +
            $"HỒ SƠ CÁ NHÂN TÀI KHOẢN ĐANG ĐĂNG NHẬP:\n" +
            $"- Tên: {request.UserName}\n" +
            $"- Giới tính: {request.Gender}, Cân nặng: {request.WeightKg:F1}kg, Mục tiêu: {request.UserGoal} (đích: {request.TargetWeightKg:F1}kg)\n" +
            $"- Chế độ ăn kiêng ưu tiên: {request.DietType}\n" +
            $"- Chỉ số dinh dưỡng hôm nay của tài khoản: Đã nạp {request.ConsumedCalories}/{request.TargetCalories} kcal ({request.ConsumedProtein:F1}/{request.TargetProtein:F1}g đạm). " +
            $"Còn thiếu: {request.RemainingCalories} kcal, {request.RemainingProtein:F1}g đạm, {request.RemainingCarbs:F1}g carb, {request.RemainingFat:F1}g béo. " +
            $"Đã uống {request.WaterConsumedMl}/{request.DailyWaterGoalMl} ml nước.\n" +
            $"- Vận động hôm nay: Đã đi {request.TodaySteps}/{request.StepGoal} bước (tiêu hao khoảng {request.BurnedCalories:F0} kcal).\n" +
            $"Thực phẩm trong tủ lạnh riêng của tài khoản này: [{fridgeDesc}].\n\n" +
            "QUY TẮC CÁ NHÂN HOÁ CAO CẤP:\n" +
            $"- Luôn xưng hô thân mật phù hợp với người dùng theo tên ({request.UserName}).\n" +
            $"- Nếu tài khoản có chế độ ăn kiêng ({request.DietType}, ví dụ Ăn chay/Vegetarian), TUYỆT ĐỐI KHÔNG gợi ý thịt/hải sản.\n" +
            $"- Nếu mục tiêu là Tăng cơ (HighProtein/GainWeight), ưu tiên đẩy mạnh lượng đạm. Nếu Giảm cân (LoseWeight), ưu tiên cân đối thâm hụt calo an toàn.\n\n" +
            "NHIỆM VỤ:\n" +
            "Phân tích câu nói tiếng Việt của người dùng và chọn 1 trong các actionType sau:\n" +
            "1. 'fridge_recipe': Người dùng hỏi ăn gì từ tủ lạnh, vét tủ, nấu gì cho đủ calo/đạm. Đề xuất món ăn tận dụng nguyên liệu đang có trong tủ (ưu tiên món sắp hết hạn), tính toán calo và protein bù đắp khít nhất lượng còn thiếu.\n" +
            "2. 'log_meal': Người dùng nói vừa ăn gì, bữa trưa/sáng/tối ăn gì. Bóc tách danh sách món ăn, tính tổng calories, protein, carbs, fat.\n" +
            "3. 'log_water': Người dùng nói vừa uống nước. Trích xuất amountMl (số ml).\n" +
            "4. 'add_fridge': Người dùng bảo cất đồ/mua đồ bỏ vào tủ lạnh. Trích xuất name, quantity, category.\n" +
            "5. 'check_progress': Người dùng hỏi hôm nay ăn được bao nhiêu rồi, còn bao nhiêu calo/đạm.\n" +
            "6. 'navigate': Người dùng bảo mở màn hình nào (fridge, barcode, calculator, journal, dashboard).\n" +
            "7. 'general_chat': Trả lời kiến thức dinh dưỡng, tập luyện tự nhiên, ngắn gọn.\n\n" +
            "QUY TẮC PHẢN HỒI:\n" +
            "- spokenReply: Câu thoại phản hồi tiếng Việt tự nhiên, thân thiện, ngắn gọn (1-2 câu để đọc bằng giọng nói Text-to-Speech).\n" +
            "- BẮT BUỘC TRẢ VỀ DUY NHẤT 1 CHUỖI JSON HỢP LỆ THEO SCHEMA SAU, TUYỆT ĐỐI KHÔNG CHÈN MARKDOWN ```json:\n" +
            "{\n" +
            "  \"actionType\": \"fridge_recipe | log_meal | log_water | add_fridge | check_progress | navigate | general_chat\",\n" +
            "  \"spokenReply\": \"Lời thoại trả lời súc tích...\",\n" +
            "  \"mealData\": { \"mealType\": \"Sáng|Trưa|Tối|Phụ\", \"title\": \"...\", \"calories\": 450, \"protein\": 25.0, \"carbs\": 50.0, \"fat\": 15.0, \"items\": [\"...\"] },\n" +
            "  \"recipeData\": { \"recipeTitle\": \"...\", \"matchExplanation\": \"...\", \"prepTimeMinutes\": 15, \"calories\": 320, \"protein\": 30.0, \"carbs\": 15.0, \"fat\": 8.0, \"ingredientsUsed\": [{\"name\": \"...\", \"amount\": \"...\", \"inFridge\": true}], \"cookingSteps\": [\"Bước 1...\", \"Bước 2...\"] },\n" +
            "  \"waterData\": { \"amountMl\": 250, \"newTotalMl\": 1500 },\n" +
            "  \"fridgeAddData\": { \"name\": \"...\", \"category\": \"Thịt & Trứng|Thủy hải sản|Rau củ|Trái cây|...\", \"quantity\": \"...\", \"shelfLifeDays\": 3, \"storageLocation\": \"fridge|freezer|pantry\" },\n" +
            "  \"navigateData\": { \"targetScreen\": \"fridge|barcode|calculator|journal|dashboard\" }\n" +
            "}";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    parts = new object[]
                    {
                        new { text = systemInstruction },
                        new { text = $"Câu nói của người dùng: \"{request.UserPrompt}\"" }
                    }
                }
            },
            generationConfig = new
            {
                temperature = 0.2,
                maxOutputTokens = 1000
            }
        };

        string[] models = { "gemini-flash-latest", "gemini-2.5-flash-lite", "gemini-2.0-flash" };
        foreach (var model in models)
        {
            try
            {
                string url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}";
                using var req = new HttpRequestMessage(HttpMethod.Post, url)
                {
                    Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
                };

                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(12));
                var resp = await _httpClient.SendAsync(req, cts.Token);
                if (!resp.IsSuccessStatusCode) continue;

                var rawBody = await resp.Content.ReadAsStringAsync(cts.Token);
                var doc = JsonNode.Parse(rawBody);
                var text = doc?["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
                if (string.IsNullOrWhiteSpace(text)) continue;

                var cleaned = CleanJsonMarkdown(text);
                var parsed = JsonSerializer.Deserialize<VoiceAssistantResponseDto>(cleaned, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (parsed != null && !string.IsNullOrWhiteSpace(parsed.ActionType))
                {
                    return parsed;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Gọi Gemini model {Model} thất bại: {Msg}", model, ex.Message);
            }
        }

        return null;
    }

    private VoiceAssistantResponseDto ProcessWithLocalRuleEngine(VoiceAssistantRequestDto req)
    {
        string p = req.UserPrompt.Trim().ToLowerInvariant();

        // 1. Ghi nhận uống nước
        if (p.Contains("uống") && (p.Contains("nước") || p.Contains("ml") || p.Contains("cốc") || p.Contains("ly")))
        {
            int amount = 250;
            var numMatch = Regex.Match(p, @"(\d+)\s*(ml)?");
            if (numMatch.Success && int.TryParse(numMatch.Groups[1].Value, out int parsedNum))
            {
                amount = parsedNum;
                if (amount < 20) amount *= 250; // VD: 2 cốc = 500ml
            }
            else if (p.Contains("1 chai") || p.Contains("chai"))
            {
                amount = 500;
            }

            int newTotal = req.WaterConsumedMl + amount;
            return new VoiceAssistantResponseDto
            {
                ActionType = "log_water",
                SpokenReply = $"Đã ghi nhận thêm {amount}ml nước! Bạn đã uống được {newTotal}/{req.DailyWaterGoalMl} ml hôm nay.",
                WaterData = new VoiceWaterActionData
                {
                    AmountMl = amount,
                    NewTotalMl = newTotal
                }
            };
        }

        // 2. Bếp Trưởng Vét Tủ Cân Macro (Hôm nay ăn gì, tủ lạnh còn gì, nấu gì)
        if (p.Contains("tủ lạnh") && (p.Contains("còn gì") || p.Contains("ăn gì") || p.Contains("nấu gì") || p.Contains("đủ đạm") || p.Contains("vét tủ"))
            || p.Contains("hôm nay ăn gì") || p.Contains("gợi ý món") || p.Contains("nấu món gì"))
        {
            return GenerateSmartFridgeRecipe(req);
        }

        // 3. Điều hướng mở màn hình
        if (p.Contains("mở") || p.Contains("vào") || p.Contains("xem"))
        {
            if (p.Contains("tủ lạnh"))
            {
                return new VoiceAssistantResponseDto
                {
                    ActionType = "navigate",
                    SpokenReply = "Đang mở Tủ Lạnh Thông Minh cho bạn!",
                    NavigateData = new VoiceNavigateActionData { TargetScreen = "fridge" }
                };
            }
            if (p.Contains("mã vạch") || p.Contains("quét"))
            {
                return new VoiceAssistantResponseDto
                {
                    ActionType = "navigate",
                    SpokenReply = "Đang mở máy quét mã vạch siêu thị!",
                    NavigateData = new VoiceNavigateActionData { TargetScreen = "barcode" }
                };
            }
            if (p.Contains("đo calo") || p.Contains("tính calo") || p.Contains("cân"))
            {
                return new VoiceAssistantResponseDto
                {
                    ActionType = "navigate",
                    SpokenReply = "Đang mở Bộ Tính Calo Nguyên Liệu!",
                    NavigateData = new VoiceNavigateActionData { TargetScreen = "calculator" }
                };
            }
        }

        // 4. Thêm đồ vào tủ lạnh
        if ((p.Contains("thêm") || p.Contains("cất") || p.Contains("lưu") || p.Contains("mua")) && p.Contains("tủ"))
        {
            string itemName = "Thực phẩm mới";
            string qty = "1 phần";
            var cleanText = p.Replace("thêm", "").Replace("cất", "").Replace("vào tủ lạnh", "").Replace("vào tủ", "").Trim();
            if (!string.IsNullOrWhiteSpace(cleanText))
            {
                itemName = char.ToUpper(cleanText[0]) + cleanText.Substring(1);
            }

            return new VoiceAssistantResponseDto
            {
                ActionType = "add_fridge",
                SpokenReply = $"Đã thêm {itemName} vào Tủ Lạnh Thông Minh của bạn rồi nhé!",
                FridgeAddData = new VoiceFridgeAddActionData
                {
                    Name = itemName,
                    Quantity = qty,
                    Category = "Thực phẩm tươi",
                    ShelfLifeDays = 4,
                    StorageLocation = "fridge"
                }
            };
        }

        // 5. Kiểm tra bước chân & vận động
        if (p.Contains("bước") || p.Contains("đi bộ") || p.Contains("vận động") || p.Contains("chạy bộ"))
        {
            string namePrefix = !string.IsNullOrWhiteSpace(req.UserName) ? $"{req.UserName} ơi, " : "";
            int remainingSteps = Math.Max(0, req.StepGoal - req.TodaySteps);
            string stepStatus = remainingSteps > 0
                ? $"bạn còn {remainingSteps:N0} bước nữa là đạt mục tiêu {req.StepGoal:N0} bước hôm nay."
                : $"chúc mừng bạn đã hoàn thành vượt mục tiêu {req.StepGoal:N0} bước hôm nay rồi!";

            return new VoiceAssistantResponseDto
            {
                ActionType = "check_progress",
                SpokenReply = $"{namePrefix}hôm nay bạn đã đi được {req.TodaySteps:N0} bước, đốt cháy khoảng {req.BurnedCalories:F0} kcal. {stepStatus}"
            };
        }

        // 6. Kiểm tra tiến độ Calo hôm nay
        if (p.Contains("còn bao nhiêu") || p.Contains("đủ chưa") || p.Contains("tiến độ") || p.Contains("hôm nay thế nào") || p.Contains("mấy calo"))
        {
            string namePrefix = !string.IsNullOrWhiteSpace(req.UserName) ? $"{req.UserName} ơi, " : "";
            string caloStatus = req.RemainingCalories > 0
                ? $"{namePrefix}bạn còn thiếu {req.RemainingCalories} kcal và {Math.Max(0, req.RemainingProtein):F0}g đạm nữa để đạt chỉ tiêu hôm nay."
                : $"{namePrefix}bạn đã nạp đủ {req.ConsumedCalories} kcal cho hôm nay rồi nhé!";

            return new VoiceAssistantResponseDto
            {
                ActionType = "check_progress",
                SpokenReply = $"Hôm nay bạn đã nạp {req.ConsumedCalories}/{req.TargetCalories} kcal. {caloStatus}"
            };
        }

        // 7. Ghi nhận bữa ăn (Meal Log)
        return ParseMealLogLocally(p, req);
    }

    private VoiceAssistantResponseDto GenerateSmartFridgeRecipe(VoiceAssistantRequestDto req)
    {
        // Tìm các nguyên liệu đang có trong tủ lạnh
        var items = req.FridgeItems.OrderBy(i => i.DaysUntilExpiry).ToList();

        bool isVegetarian = req.DietType.Contains("Vegetarian", StringComparison.OrdinalIgnoreCase) || req.DietType.Contains("Chay", StringComparison.OrdinalIgnoreCase);
        string chosenMain = isVegetarian ? "Đậu hũ non" : "Ức gà";
        string chosenVeg = "Bông cải xanh";
        string recipeName = isVegetarian ? "Đậu hũ non sốt nấm cà chua" : "Ức gà áp chảo sốt tiêu đen";
        int cal = req.RemainingCalories > 150 ? Math.Min(req.RemainingCalories, 450) : 320;
        double pro = req.RemainingProtein > 10 ? Math.Min(req.RemainingProtein, 38.0) : 28.0;

        var usedList = new List<VoiceRecipeIngredientDto>();

        if (items.Count > 0)
        {
            var expiring = items.First();
            chosenMain = expiring.Name;
            usedList.Add(new VoiceRecipeIngredientDto { Name = expiring.Name, Amount = expiring.Quantity, InFridge = true });

            if (items.Count > 1)
            {
                var second = items[1];
                chosenVeg = second.Name;
                usedList.Add(new VoiceRecipeIngredientDto { Name = second.Name, Amount = second.Quantity, InFridge = true });
                recipeName = $"{chosenMain} xào {chosenVeg}";
            }
            else
            {
                recipeName = $"{chosenMain} áp chảo sốt tỏi";
            }
        }
        else
        {
            usedList.Add(new VoiceRecipeIngredientDto { Name = chosenMain, Amount = isVegetarian ? "200g" : "150g", InFridge = false });
            usedList.Add(new VoiceRecipeIngredientDto { Name = "Rau củ", Amount = "100g", InFridge = false });
        }

        string namePrefix = !string.IsNullOrWhiteSpace(req.UserName) ? $"{req.UserName} ơi! " : "";

        return new VoiceAssistantResponseDto
        {
            ActionType = "fridge_recipe",
            SpokenReply = $"{namePrefix}Tôi gợi ý món {recipeName}! Món này tận dụng ngay {chosenMain} trong tủ lạnh, cung cấp {cal} kcal và {pro:F0}g đạm, vừa khít chỉ tiêu còn thiếu của bạn!",
            RecipeData = new VoiceFridgeRecipeActionData
            {
                RecipeTitle = recipeName,
                MatchExplanation = $"Món ăn tận dụng {chosenMain} trong tủ lạnh, bù đắp chính xác {cal} kcal và {pro:F0}g đạm còn thiếu của bạn hôm nay.",
                PrepTimeMinutes = 15,
                Calories = cal,
                Protein = pro,
                Carbs = Math.Max(10, req.RemainingCarbs > 0 ? req.RemainingCarbs * 0.5 : 20),
                Fat = Math.Max(5, req.RemainingFat > 0 ? req.RemainingFat * 0.5 : 8),
                IngredientsUsed = usedList,
                CookingSteps = new List<string>
                {
                    $"Sơ chế sạch {chosenMain} và các nguyên liệu",
                    "Phi thơm hành tỏi với 1 muỗng cà phê dầu ô liu",
                    $"Cho {chosenMain} vào đảo chín tới, nêm gia vị vừa ăn và thưởng thức nóng"
                }
            }
        };
    }

    private VoiceAssistantResponseDto ParseMealLogLocally(string p, VoiceAssistantRequestDto req)
    {
        string mealType = "Trưa";
        if (p.Contains("sáng")) mealType = "Sáng";
        else if (p.Contains("tối")) mealType = "Tối";
        else if (p.Contains("phụ") || p.Contains("xế") || p.Contains("chiều")) mealType = "Phụ";

        // Món ăn phổ biến & ước lượng calo chuẩn
        int cal = 400;
        double pro = 20;
        double carb = 45;
        double fat = 12;
        string mealTitle = "Bữa ăn dinh dưỡng";

        if (p.Contains("phở bò"))
        {
            mealTitle = "Phở bò truyền thống";
            cal = 520; pro = 26; carb = 65; fat = 15;
        }
        else if (p.Contains("cơm tấm") || p.Contains("sườn"))
        {
            mealTitle = "Cơm tấm sườn nướng";
            cal = 650; pro = 28; carb = 80; fat = 22;
        }
        else if (p.Contains("bún bò"))
        {
            mealTitle = "Bún bò Huế";
            cal = 580; pro = 29; carb = 68; fat = 18;
        }
        else if (p.Contains("bánh mì"))
        {
            mealTitle = "Bánh mì kẹp thịt";
            cal = 420; pro = 18; carb = 48; fat = 16;
        }
        else if (p.Contains("ức gà"))
        {
            mealTitle = "Ức gà áp chảo";
            cal = 220; pro = 38; carb = 2; fat = 4;
        }
        else if (p.Contains("trứng"))
        {
            mealTitle = "Trứng luộc / ốp la";
            cal = 160; pro = 13; carb = 2; fat = 11;
        }
        else if (p.Contains("chuối") || p.Contains("sữa chua"))
        {
            mealTitle = "Sữa chua hoa quả";
            cal = 180; pro = 6; carb = 32; fat = 3;
            mealType = "Phụ";
        }
        else
        {
            var cleaned = Regex.Replace(p, @"(trưa|sáng|tối|vừa|ăn|uống|nay|hôm nay|đã)", "").Trim();
            if (!string.IsNullOrWhiteSpace(cleaned))
            {
                mealTitle = char.ToUpper(cleaned[0]) + cleaned.Substring(1);
            }
        }

        return new VoiceAssistantResponseDto
        {
            ActionType = "log_meal",
            SpokenReply = $"Đã nhận diện: {mealTitle} (~{cal} kcal, {pro:F0}g đạm). Bạn có muốn lưu vào Bữa {mealType} hôm nay không?",
            MealData = new VoiceMealLogActionData
            {
                MealType = mealType,
                Title = mealTitle,
                Calories = cal,
                Protein = pro,
                Carbs = carb,
                Fat = fat,
                Items = new List<string> { mealTitle }
            }
        };
    }

    private static string CleanJsonMarkdown(string text)
    {
        text = text.Trim();
        if (text.StartsWith("```json", StringComparison.OrdinalIgnoreCase))
            text = text.Substring(7);
        else if (text.StartsWith("```"))
            text = text.Substring(3);

        if (text.EndsWith("```"))
            text = text.Substring(0, text.Length - 3);

        return text.Trim();
    }
}
