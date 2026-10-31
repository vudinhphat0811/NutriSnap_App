namespace NutriSnap.Models;

public class VoiceAssistantRequestDto
{
    public string UserPrompt { get; set; } = string.Empty;
    public int RemainingCalories { get; set; }
    public double RemainingProtein { get; set; }
    public double RemainingCarbs { get; set; }
    public double RemainingFat { get; set; }
    public int ConsumedCalories { get; set; }
    public double ConsumedProtein { get; set; }
    public int TargetCalories { get; set; }
    public double TargetProtein { get; set; }
    public int WaterConsumedMl { get; set; }
    public int DailyWaterGoalMl { get; set; }
    public List<VoiceFridgeItemDto> FridgeItems { get; set; } = new();
    public string UserName { get; set; } = string.Empty;
    public string UserGoal { get; set; } = "LoseWeight";
    public string DietType { get; set; } = "Balanced";
    public string Gender { get; set; } = "";
    public double WeightKg { get; set; }
    public double TargetWeightKg { get; set; }
    public int TodaySteps { get; set; }
    public int StepGoal { get; set; } = 6000;
    public double BurnedCalories { get; set; }
}

public class VoiceFridgeItemDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Quantity { get; set; } = string.Empty;
    public int DaysUntilExpiry { get; set; } = 3;
}

public class VoiceAssistantResponseDto
{
    /// <summary>
    /// Nội dung câu nói của người dùng sau khi trích xuất từ âm thanh
    /// </summary>
    public string? UserPrompt { get; set; }

    /// <summary>
    /// Các loại hành động: fridge_recipe, log_meal, log_water, add_fridge, check_progress, navigate, general_chat
    /// </summary>
    public string ActionType { get; set; } = "general_chat";
    public string SpokenReply { get; set; } = string.Empty;
    public VoiceMealLogActionData? MealData { get; set; }
    public VoiceFridgeRecipeActionData? RecipeData { get; set; }
    public VoiceWaterActionData? WaterData { get; set; }
    public VoiceFridgeAddActionData? FridgeAddData { get; set; }
    public VoiceNavigateActionData? NavigateData { get; set; }
}

public class VoiceAudioAssistantRequestDto : VoiceAssistantRequestDto
{
    public string AudioBase64 { get; set; } = string.Empty;
    public string AudioMimeType { get; set; } = "audio/mp4";
}

public class VoiceMealLogActionData
{
    public string MealType { get; set; } = "Trưa"; // Sáng, Trưa, Tối, Phụ
    public string Title { get; set; } = string.Empty;
    public int Calories { get; set; }
    public double Protein { get; set; }
    public double Carbs { get; set; }
    public double Fat { get; set; }
    public List<string> Items { get; set; } = new();
}

public class VoiceFridgeRecipeActionData
{
    public string RecipeTitle { get; set; } = string.Empty;
    public string MatchExplanation { get; set; } = string.Empty;
    public int PrepTimeMinutes { get; set; } = 15;
    public int Calories { get; set; }
    public double Protein { get; set; }
    public double Carbs { get; set; }
    public double Fat { get; set; }
    public List<VoiceRecipeIngredientDto> IngredientsUsed { get; set; } = new();
    public List<string> CookingSteps { get; set; } = new();
}

public class VoiceRecipeIngredientDto
{
    public string Name { get; set; } = string.Empty;
    public string Amount { get; set; } = string.Empty;
    public bool InFridge { get; set; } = true;
}

public class VoiceWaterActionData
{
    public int AmountMl { get; set; }
    public int NewTotalMl { get; set; }
}

public class VoiceFridgeAddActionData
{
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = "Thực phẩm";
    public string Quantity { get; set; } = "1 phần";
    public int ShelfLifeDays { get; set; } = 3;
    public string StorageLocation { get; set; } = "fridge";
}

public class VoiceNavigateActionData
{
    public string TargetScreen { get; set; } = string.Empty; // fridge, barcode, calculator, journal, dashboard
}
