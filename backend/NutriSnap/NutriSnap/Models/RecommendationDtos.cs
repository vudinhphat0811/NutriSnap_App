namespace NutriSnap.Models;

public class RecommendationRequest
{
    public string Goal { get; set; } = "LoseWeight"; // LoseWeight, GainWeight, Maintain
    public string DietType { get; set; } = "HighProtein"; // HighProtein, LowCarb, Vegetarian, Balanced
    public int TargetCalories { get; set; } = 1850;
    public int RemainingCalories { get; set; } = 1200;
    public string? Category { get; set; }
    public int Limit { get; set; } = 8;
    public int RefreshCount { get; set; } = 0;
    public string? Date { get; set; }
}

public class RecommendedMealDto
{
    public string IdMeal { get; set; } = "";
    public string StrMeal { get; set; } = "";
    public string StrMealThumb { get; set; } = "";
    public string? StrCategory { get; set; }
    public string? StrArea { get; set; }
    public string? StrInstructions { get; set; }
    public string? StrYoutube { get; set; }
    public List<string> Ingredients { get; set; } = new();
    public List<string> Measures { get; set; } = new();
    public string? StrMealVi { get; set; }
    public string? StrInstructionsVi { get; set; }
    public List<string> IngredientsVi { get; set; } = new();
    public List<string> MeasuresVi { get; set; } = new();
    public int EstimatedCalories { get; set; }
    public int EstimatedProtein { get; set; }
    public int EstimatedCarbs { get; set; }
    public int EstimatedFat { get; set; }
    public int MatchScore { get; set; }
    public List<string> Badges { get; set; } = new();
}

public class MatchIngredientsRequest
{
    public List<string> Ingredients { get; set; } = new();
    public string Lang { get; set; } = "vi";
    public int Limit { get; set; } = 25;
}
