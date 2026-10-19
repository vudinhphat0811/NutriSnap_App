namespace NutriSnap.Models;

/// <summary>
/// DTO chứa chi tiết một nguyên liệu được phát hiện từ AI
/// </summary>
public class DetectedIngredientDto
{
    public string Name { get; set; } = "Nguyên liệu";
    public string EnglishName { get; set; } = "Chicken";
    public string Calories { get; set; } = "100 kcal";
    public int CalorieNumber { get; set; } = 100;
    public string Weight { get; set; } = "~100g";
    public string Protein { get; set; } = "10g Protein";
    public string Carbs { get; set; } = "5g Carbs";
    public string Fat { get; set; } = "2g Fat";
    public string NutritionComment { get; set; } = "";
}

/// <summary>
/// DTO trả về kết quả phân tích nguyên liệu cho Frontend hiển thị
/// </summary>
public class IngredientAnalysisResultDto
{
    public bool IsIngredient { get; set; } = true;
    public string? RejectReason { get; set; }
    public string Name { get; set; } = "";
    public string EnglishName { get; set; } = "";
    public string Calories { get; set; } = "";
    public int CalorieNumber { get; set; } = 0;
    public string Weight { get; set; } = "";
    public string NutritionComment { get; set; } = "";
    public string Protein { get; set; } = "";
    public string Carbs { get; set; } = "";
    public string Fat { get; set; } = "";
    public string Context { get; set; } = "";
    public string? ProviderName { get; set; }
    public List<DetectedIngredientDto> Ingredients { get; set; } = new();

    public static IngredientAnalysisResultDto Rejected(string reason, string? provider = null)
    {
        return new IngredientAnalysisResultDto
        {
            IsIngredient = false,
            RejectReason = reason,
            ProviderName = provider,
            Ingredients = new List<DetectedIngredientDto>()
        };
    }
}

public class AnalyzeImageRequest
{
    public string? ImageBase64 { get; set; }
    public string? ContentType { get; set; }
}

public class SocialAuthRequest
{
    public string Provider { get; set; } = "google"; // "google" or "facebook"
    public string Email { get; set; } = "";
    public string Name { get; set; } = "";
    public string? ProviderId { get; set; }
    public string? AvatarUrl { get; set; }
    public string? IdToken { get; set; }
    public string? Token { get; set; }
}

public class LinkSocialRequest
{
    public string Provider { get; set; } = "google"; // "google" or "facebook"
    public string AccountIdentifier { get; set; } = ""; // email for google, name/id for facebook
}

public class GuestStatusResponse
{
    public bool IsGuest { get; set; }
    public DateTime? GuestCreatedAt { get; set; }
    public int UsageDays { get; set; }
    public bool IsTrialExpired { get; set; }
}
