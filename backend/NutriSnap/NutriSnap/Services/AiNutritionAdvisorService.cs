using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using NutriSnap.Data;
using NutriSnap.Models;

namespace NutriSnap.Services;

public class AiNutritionAdvisorService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly ILogger<AiNutritionAdvisorService> _logger;
    private readonly IMemoryCache _cache;
    private readonly AppDbContext _context;

    public AiNutritionAdvisorService(
        HttpClient httpClient,
        IConfiguration config,
        ILogger<AiNutritionAdvisorService> logger,
        IMemoryCache cache,
        AppDbContext context)
    {
        _httpClient = httpClient;
        _config = config;
        _logger = logger;
        _cache = cache;
        _context = context;
    }

    public async Task<NutritionReviewResultDto> GetNutritionReviewAsync(
        int userId,
        string period,
        bool forceRefresh = false,
        string lang = "vi")
    {
        var normalizedLang = (lang?.Trim().ToLowerInvariant() == "en") ? "en" : "vi";
        bool isEn = normalizedLang == "en";

        var normalizedPeriod = period?.ToLowerInvariant() switch
        {
            "7days" or "week" => "7days",
            "month" or "30days" => "month",
            _ => "yesterday"
        };

        var today = DateOnly.FromDateTime(DateTime.Now);
        DateOnly startDate;
        DateOnly endDate;
        int daysCount;
        string periodLabel;

        switch (normalizedPeriod)
        {
            case "7days":
                startDate = today.AddDays(-7);
                endDate = today.AddDays(-1);
                daysCount = 7;
                periodLabel = isEn ? "Last 7 days" : "7 ngày qua";
                break;
            case "month":
                startDate = today.AddDays(-30);
                endDate = today.AddDays(-1);
                daysCount = 30;
                periodLabel = isEn ? "Last month" : "Tháng trước";
                break;
            default:
                startDate = today.AddDays(-1);
                endDate = today.AddDays(-1);
                daysCount = 1;
                periodLabel = isEn ? "Yesterday" : "Hôm qua";
                break;
        }

        // 1. Lấy thông tin user
        var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        int targetCalories = user?.TargetCalories > 0 ? user.TargetCalories : 2000;
        int targetProtein = user?.TargetProtein > 0 ? (int)Math.Round(user.TargetProtein) : 90;
        int targetCarbs = user?.TargetCarbs > 0 ? (int)Math.Round(user.TargetCarbs) : 220;
        int targetFat = user?.TargetFat > 0 ? (int)Math.Round(user.TargetFat) : 50;
        string defaultGoal = isEn ? "Healthy maintenance" : "Duy trì sức khỏe";
        string defaultDiet = isEn ? "Balanced standard" : "Tiêu chuẩn";
        string goal = string.IsNullOrWhiteSpace(user?.Goal) ? defaultGoal : user.Goal;
        string dietType = string.IsNullOrWhiteSpace(user?.DietType) ? defaultDiet : user.DietType;

        // 2. Lấy danh sách bữa ăn trong khoảng thời gian
        var meals = await _context.MealLogs
            .AsNoTracking()
            .Where(m => m.UserId == userId && m.LoggedDate >= startDate && m.LoggedDate <= endDate)
            .OrderBy(m => m.LoggedDate)
            .ThenBy(m => m.CreatedAt)
            .ToListAsync();

        int totalCalories = meals.Sum(m => m.Calories);
        double totalProtein = meals.Sum(m => m.ProteinG);
        double totalCarbs = meals.Sum(m => m.CarbsG);
        double totalFat = meals.Sum(m => m.FatG);

        int avgCalories = daysCount > 1 ? (int)Math.Round((double)totalCalories / daysCount) : totalCalories;
        int avgProtein = (int)Math.Round(daysCount > 1 ? totalProtein / daysCount : totalProtein);
        int avgCarbs = (int)Math.Round(daysCount > 1 ? totalCarbs / daysCount : totalCarbs);
        int avgFat = (int)Math.Round(daysCount > 1 ? totalFat / daysCount : totalFat);

        int deltaCalories = avgCalories - targetCalories;

        var metrics = new NutritionReviewMetricsDto
        {
            TotalCalories = totalCalories,
            TargetCalories = targetCalories,
            DeltaCalories = deltaCalories,
            AvgCaloriesPerDay = avgCalories,
            AvgProteinG = avgProtein,
            TargetProteinG = targetProtein,
            AvgCarbsG = avgCarbs,
            TargetCarbsG = targetCarbs,
            AvgFatG = avgFat,
            TargetFatG = targetFat,
            MealsCount = meals.Count,
            DaysCount = daysCount
        };

        // Nếu không có dữ liệu bữa ăn nào (Tài khoản mới hoặc chưa ghi món)
        if (meals.Count == 0)
        {
            return new NutritionReviewResultDto
            {
                Score = 0,
                Period = normalizedPeriod,
                PeriodLabel = periodLabel,
                HasData = false,
                Summary = isEn
                    ? $"You haven't logged any meals for {periodLabel.ToLowerInvariant()}."
                    : $"Bạn chưa ghi lại bữa ăn nào trong khoảng thời gian {periodLabel.ToLowerInvariant()}.",
                Strengths = new List<string>(),
                Improvements = new List<string>(),
                ActionableAdvice = isEn
                    ? new List<string>
                    {
                        "Snap photos or log your meals daily so your AI Coach can analyze your nutrition!",
                        "Consistent meal logging is the most vital first step toward achieving your physique goals."
                    }
                    : new List<string>
                    {
                        "Hãy bắt đầu chụp ảnh hoặc ghi chép bữa ăn mỗi ngày để Huấn luyện viên AI phân tích chi tiết cho bạn!",
                        "Ghi chép đều đặn là bước đầu tiên quan trọng nhất để đạt mục tiêu vóc dáng."
                    },
                Metrics = metrics
            };
        }

        // 1. KIỂM TRA BẢN GHI ĐÃ LƯU CỐ ĐỊNH TRONG CƠ SỞ DỮ LIỆU THEO NGÔN NGỮ
        // (Đảm bảo chỉ đánh giá 1 lần duy nhất trong ngày, cố định theo đúng ngôn ngữ)
        if (!forceRefresh)
        {
            try
            {
                var savedRecord = await _context.DailyAiReviews
                    .AsNoTracking()
                    .FirstOrDefaultAsync(r => r.UserId == userId && r.ReviewDate == today && r.Period == normalizedPeriod && r.Lang == normalizedLang);

                if (savedRecord != null && !string.IsNullOrWhiteSpace(savedRecord.ReviewJson))
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    var fixedResult = JsonSerializer.Deserialize<NutritionReviewResultDto>(savedRecord.ReviewJson, options);
                    if (fixedResult != null && fixedResult.Score > 0)
                    {
                        return fixedResult;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Kiểm tra bản ghi đánh giá cố định: {Message}", ex.Message);
            }
        }

        // 2. Nếu chưa có bản ghi: Gọi AI để đánh giá bằng đúng ngôn ngữ yêu cầu
        NutritionReviewResultDto finalResult;
        try
        {
            var aiResult = await CallAiAdvisorAsync(periodLabel, user, meals, metrics, isEn);
            if (aiResult != null && aiResult.Score > 0)
            {
                aiResult.Period = normalizedPeriod;
                aiResult.PeriodLabel = periodLabel;
                aiResult.Metrics = metrics;
                aiResult.HasData = true;
                finalResult = aiResult;
            }
            else
            {
                finalResult = GenerateSmartFallbackReview(periodLabel, normalizedPeriod, metrics, goal, dietType, meals, isEn);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Gọi AI Advisor thất bại: {Message}. Sử dụng bộ phân tích thuật toán chuyên sâu.", ex.Message);
            finalResult = GenerateSmartFallbackReview(periodLabel, normalizedPeriod, metrics, goal, dietType, meals, isEn);
        }

        // 3. LƯU CỐ ĐỊNH VÀO CƠ SỞ DỮ LIỆU ĐỂ CÁC LẦN MỞ SAU TRONG NGÀY GIỮ NGUYÊN 100%
        try
        {
            var existingRecord = await _context.DailyAiReviews
                .FirstOrDefaultAsync(r => r.UserId == userId && r.ReviewDate == today && r.Period == normalizedPeriod && r.Lang == normalizedLang);

            var jsonToSave = JsonSerializer.Serialize(finalResult);

            if (existingRecord == null)
            {
                _context.DailyAiReviews.Add(new DailyAiReview
                {
                    UserId = userId,
                    ReviewDate = today,
                    Period = normalizedPeriod,
                    Lang = normalizedLang,
                    Score = finalResult.Score,
                    ReviewJson = jsonToSave,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                existingRecord.Score = finalResult.Score;
                existingRecord.ReviewJson = jsonToSave;
                existingRecord.CreatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();
        }
        catch (Exception dbEx)
        {
            _logger.LogWarning("Không thể lưu cố định bản ghi đánh giá AI vào Database: {Message}", dbEx.Message);
        }

        return finalResult;
    }

    private async Task<NutritionReviewResultDto?> CallAiAdvisorAsync(
        string periodLabel,
        AppUser? user,
        List<MealLog> meals,
        NutritionReviewMetricsDto metrics,
        bool isEn)
    {
        string apiKey = _config["GEMINI_API_KEY"]
            ?? _config["AiKeys:GeminiApiKey"]
            ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY")
            ?? "";

        if (string.IsNullOrWhiteSpace(apiKey))
        {
            return null;
        }

        var mealListSummary = string.Join("; ", meals.Take(15).Select(m => $"{m.MealTitle} ({m.MealType}: {m.Calories} kcal, P:{m.ProteinG}g C:{m.CarbsG}g F:{m.FatG}g)"));

        var promptBuilder = new StringBuilder();
        if (isEn)
        {
            promptBuilder.AppendLine("You are a Senior Clinical Nutritionist & Fitness Coach.");
            promptBuilder.AppendLine($"Evaluate the user's dietary intake for the period: {periodLabel}.");
            promptBuilder.AppendLine("--- USER PROFILE ---");
            promptBuilder.AppendLine($"- Goal: {user?.Goal ?? "Healthy Weight Maintenance"}");
            promptBuilder.AppendLine($"- Diet: {user?.DietType ?? "Balanced Standard"}");
            promptBuilder.AppendLine($"- Target Calories/day: {metrics.TargetCalories} kcal");
            promptBuilder.AppendLine($"- Target Protein/day: {metrics.TargetProteinG}g | Carbs: {metrics.TargetCarbsG}g | Fat: {metrics.TargetFatG}g");
            promptBuilder.AppendLine("--- ACTUAL INTAKE METRICS ---");
            promptBuilder.AppendLine($"- Total Meals Logged: {metrics.MealsCount} meals");
            promptBuilder.AppendLine($"- Average Calories/day: {metrics.AvgCaloriesPerDay} kcal (Difference: {metrics.DeltaCalories:+0;-0;0} kcal)");
            promptBuilder.AppendLine($"- Protein: {metrics.AvgProteinG}g/day | Carbs: {metrics.AvgCarbsG}g/day | Fat: {metrics.AvgFatG}g/day");
            promptBuilder.AppendLine($"- Typical Meals: {mealListSummary}");
            promptBuilder.AppendLine("--- EVALUATION REQUIREMENTS ---");
            promptBuilder.AppendLine("Score the nutrition on a 100-point scale and provide empathetic, scientific, inspiring feedback.");
            promptBuilder.AppendLine("ALL TEXT MUST BE IN ENGLISH.");
            promptBuilder.AppendLine("You MUST return ONLY a valid JSON object matching the following structure (no ```json code blocks, no text outside JSON):");
            promptBuilder.AppendLine("{");
            promptBuilder.AppendLine("  \"score\": 85,");
            promptBuilder.AppendLine("  \"summary\": \"1-2 concise, insightful sentences summarizing overall energy and meal quality in English.\",");
            promptBuilder.AppendLine("  \"strengths\": [\"Positive point 1\", \"Positive point 2\"],");
            promptBuilder.AppendLine("  \"improvements\": [\"Area for improvement 1\", \"Area for improvement 2\"],");
            promptBuilder.AppendLine("  \"actionableAdvice\": [\"Specific action 1 for today/tomorrow\", \"Specific action 2\"]");
            promptBuilder.AppendLine("}");
        }
        else
        {
            promptBuilder.AppendLine("Bạn là Chuyên gia Dinh dưỡng lâm sàng & Huấn luyện viên Thể hình cao cấp (Clinical Nutritionist & Fitness Coach).");
            promptBuilder.AppendLine($"Hãy đánh giá chế độ ăn uống của người dùng trong khoảng thời gian: {periodLabel}.");
            promptBuilder.AppendLine("--- THÔNG TIN NGƯỜI DÙNG ---");
            promptBuilder.AppendLine($"- Mục tiêu: {user?.Goal ?? "Giảm cân lành mạnh"}");
            promptBuilder.AppendLine($"- Chế độ ăn: {user?.DietType ?? "Cân bằng tiêu chuẩn"}");
            promptBuilder.AppendLine($"- Mục tiêu Calo/ngày: {metrics.TargetCalories} kcal");
            promptBuilder.AppendLine($"- Mục tiêu Đạm/ngày: {metrics.TargetProteinG}g | Tinh bột: {metrics.TargetCarbsG}g | Chất béo: {metrics.TargetFatG}g");
            promptBuilder.AppendLine("--- SỐ LIỆU THỰC TẾ ---");
            promptBuilder.AppendLine($"- Tổng số bữa ăn ghi nhận: {metrics.MealsCount} bữa");
            promptBuilder.AppendLine($"- Calo trung bình/ngày: {metrics.AvgCaloriesPerDay} kcal (Chênh lệch: {metrics.DeltaCalories:+0;-0;0} kcal)");
            promptBuilder.AppendLine($"- Đạm nạp: {metrics.AvgProteinG}g/ngày | Tinh bột: {metrics.AvgCarbsG}g/ngày | Chất béo: {metrics.AvgFatG}g/ngày");
            promptBuilder.AppendLine($"- Các món ăn tiêu biểu: {mealListSummary}");
            promptBuilder.AppendLine("--- YÊU CẦU ĐÁNH GIÁ ---");
            promptBuilder.AppendLine("Hãy chấm điểm dinh dưỡng trên thang 100 và đưa ra nhận xét khoa học, nhân văn, truyền cảm hứng.");
            promptBuilder.AppendLine("TOÀN BỘ NỘI DUNG PHẢI BẰNG TIẾNG VIỆT.");
            promptBuilder.AppendLine("BẮT BUỘC trả về DUY NHẤT một chuỗi JSON hợp lệ theo định dạng mẫu sau (không dùng ```json, không thêm chữ nào ngoài JSON):");
            promptBuilder.AppendLine("{");
            promptBuilder.AppendLine("  \"score\": 85,");
            promptBuilder.AppendLine("  \"summary\": \"Tóm tắt 1-2 câu nhận xét tổng quan ngắn gọn, sâu sắc về năng lượng và chất lượng bữa ăn bằng tiếng Việt.\",");
            promptBuilder.AppendLine("  \"strengths\": [\"Điểm tích cực 1\", \"Điểm tích cực 2\"],");
            promptBuilder.AppendLine("  \"improvements\": [\"Điểm cần cải thiện 1\", \"Điểm cần cải thiện 2\"],");
            promptBuilder.AppendLine("  \"actionableAdvice\": [\"Hành động cụ thể 1 cho hôm nay/ngày mai\", \"Hành động cụ thể 2\"]");
            promptBuilder.AppendLine("}");
        }

        string[] models = { "gemini-2.5-flash", "gemini-flash-latest" };

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
                                new { text = promptBuilder.ToString() }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        temperature = 0.3,
                        maxOutputTokens = 1000
                    }
                };

                var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
                var response = await _httpClient.PostAsync(url, content);

                if (response.IsSuccessStatusCode)
                {
                    string resBody = await response.Content.ReadAsStringAsync();
                    var node = JsonNode.Parse(resBody);
                    string? rawText = node?["candidates"]?[0]?["content"]?[0]?["parts"]?[0]?["text"]?.ToString()
                        ?? node?["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();

                    if (!string.IsNullOrWhiteSpace(rawText))
                    {
                        var cleanedJson = CleanJsonString(rawText);
                        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                        var parsed = JsonSerializer.Deserialize<NutritionReviewResultDto>(cleanedJson, options);
                        if (parsed != null && parsed.Score > 0)
                        {
                            return parsed;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Thử Gemini model {Model} thất bại: {Message}", model, ex.Message);
            }
        }

        return null;
    }

    private NutritionReviewResultDto GenerateSmartFallbackReview(
        string periodLabel,
        string periodKey,
        NutritionReviewMetricsDto metrics,
        string goal,
        string dietType,
        List<MealLog> meals,
        bool isEn)
    {
        int score = 75;
        var strengths = new List<string>();
        var improvements = new List<string>();
        var advice = new List<string>();

        // 1. Đánh giá Calo
        double caloRatio = metrics.TargetCalories > 0 ? (double)metrics.AvgCaloriesPerDay / metrics.TargetCalories : 1.0;
        if (caloRatio >= 0.85 && caloRatio <= 1.10)
        {
            score += 15;
            strengths.Add(isEn
                ? $"Accurate calorie intake control ({metrics.AvgCaloriesPerDay} / {metrics.TargetCalories} kcal)."
                : $"Kiểm soát mức calo nạp vào rất chuẩn xác ({metrics.AvgCaloriesPerDay} / {metrics.TargetCalories} kcal).");
        }
        else if (caloRatio > 1.25)
        {
            score -= 15;
            improvements.Add(isEn
                ? $"Average calories exceeded goal by +{metrics.DeltaCalories} kcal ({metrics.AvgCaloriesPerDay} kcal vs {metrics.TargetCalories} kcal)."
                : $"Lượng calo trung bình vượt mục tiêu +{metrics.DeltaCalories} kcal ({metrics.AvgCaloriesPerDay} kcal vs {metrics.TargetCalories} kcal).");
            advice.Add(isEn
                ? "Monitor portion sizes for refined carbs and sugary snacks in upcoming meals."
                : "Hãy chú ý kiểm soát khẩu phần tinh bột và đồ ăn vặt nhiều đường trong các bữa tiếp theo.");
        }
        else if (caloRatio < 0.70)
        {
            score -= 10;
            improvements.Add(isEn
                ? $"Significant energy deficit ({-metrics.DeltaCalories} kcal below target), which may cause fatigue."
                : $"Ăn thiếu năng lượng khá nhiều (thấp hơn mục tiêu {-metrics.DeltaCalories} kcal), dễ gây mệt mỏi.");
            advice.Add(isEn
                ? "Add nutrient-dense nuts (walnuts, almonds) or Greek yogurt for clean sustaining energy."
                : "Bổ sung thêm các loại hạt dinh dưỡng (óc chó, hạnh nhân) hoặc sữa chua Hy Lạp để bù năng lượng lành mạnh.");
        }

        // 2. Đánh giá Protein
        if (metrics.AvgProteinG >= (int)(metrics.TargetProteinG * 0.85))
        {
            score += 10;
            strengths.Add(isEn
                ? $"Excellent protein intake ({metrics.AvgProteinG}g / {metrics.TargetProteinG}g) preserving muscle mass."
                : $"Bổ sung đạm rất tốt ({metrics.AvgProteinG}g / {metrics.TargetProteinG}g) giúp duy trì khối cơ.");
        }
        else
        {
            score -= 5;
            improvements.Add(isEn
                ? $"Protein intake is slightly low ({metrics.AvgProteinG}g / {metrics.TargetProteinG}g target)."
                : $"Lượng protein còn hơi thấp ({metrics.AvgProteinG}g / {metrics.TargetProteinG}g mục tiêu).");
            advice.Add(isEn
                ? "Include more eggs, chicken breast, tofu, or fish in your main meals."
                : "Nên bổ sung thêm trứng, ức gà, đậu phụ hoặc cá vào thực đơn chính.");
        }

        // 3. Đánh giá số bữa
        if (metrics.MealsCount >= 3)
        {
            strengths.Add(isEn
                ? $"Consistently logged regular meals ({metrics.MealsCount} meals recorded), building strong dietary discipline."
                : $"Duy trì ghi chép đầy đủ các bữa ({metrics.MealsCount} bữa ghi nhận) tạo thói quen kỷ luật cao.");
        }

        // Đảm bảo score trong khoảng 45-98
        score = Math.Clamp(score, 45, 98);

        string summary;
        if (isEn)
        {
            summary = score >= 85
                ? $"{periodLabel} your nutrition was outstanding! Your body is receiving optimal nutrients aligned with your {goal.ToLowerInvariant()} goal."
                : score >= 70
                    ? $"{periodLabel} your diet was solid. Making minor adjustments to protein and calorie balance will take you even further."
                    : $"{periodLabel} your intake deviated from your target. Don't worry, follow the actionable advice below!";
        }
        else
        {
            summary = score >= 85
                ? $"{periodLabel} bạn đã duy trì dinh dưỡng rất xuất sắc! Cơ thể bạn đang nhận đủ dưỡng chất đúng mục tiêu {goal.ToLowerInvariant()}."
                : score >= 70
                    ? $"{periodLabel} bạn ăn uống tương đối ổn định. Chỉ cần điều chỉnh nhẹ về cân bằng đạm và calo để tối ưu hơn nữa."
                    : $"{periodLabel} chế độ ăn có sự chênh lệch so với mục tiêu. Đừng nản lòng, hãy tập trung vào lời khuyên dưới đây!";
        }

        if (advice.Count == 0)
        {
            advice.Add(isEn
                ? "Drink at least 2 liters of water daily to support metabolism and digestion."
                : "Uống đủ ít nhất 2 lít nước mỗi ngày để hỗ trợ quá trình trao đổi chất và tiêu hóa.");
            advice.Add(isEn
                ? "Keep snapping photos and logging every meal so your AI Coach can provide the best guidance."
                : "Tiếp tục duy trì việc chụp ảnh và ghi chép từng bữa ăn để AI hỗ trợ bạn tốt nhất.");
        }

        return new NutritionReviewResultDto
        {
            Score = score,
            Period = periodKey,
            PeriodLabel = periodLabel,
            HasData = true,
            Summary = summary,
            Strengths = strengths,
            Improvements = improvements,
            ActionableAdvice = advice,
            Metrics = metrics
        };
    }

    private static string CleanJsonString(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return "{}";
        var cleaned = Regex.Replace(text, @"^```(json)?\s*", "", RegexOptions.Multiline);
        cleaned = Regex.Replace(cleaned, @"\s*```$", "", RegexOptions.Multiline);
        int start = cleaned.IndexOf('{');
        int end = cleaned.LastIndexOf('}');
        if (start >= 0 && end >= start)
        {
            return cleaned.Substring(start, end - start + 1).Trim();
        }
        return cleaned.Trim();
    }
}
