namespace NutriSnap.Models;

public class NutritionReviewResultDto
{
    public int Score { get; set; }
    public string Period { get; set; } = "yesterday";
    public string PeriodLabel { get; set; } = "Hôm qua";
    public bool HasData { get; set; } = true;
    public string Summary { get; set; } = string.Empty;
    public List<string> Strengths { get; set; } = new();
    public List<string> Improvements { get; set; } = new();
    public List<string> ActionableAdvice { get; set; } = new();
    public NutritionReviewMetricsDto Metrics { get; set; } = new();
}

public class NutritionReviewMetricsDto
{
    public int TotalCalories { get; set; }
    public int TargetCalories { get; set; }
    public int DeltaCalories { get; set; }
    public int AvgCaloriesPerDay { get; set; }
    public int AvgProteinG { get; set; }
    public int TargetProteinG { get; set; }
    public int AvgCarbsG { get; set; }
    public int TargetCarbsG { get; set; }
    public int AvgFatG { get; set; }
    public int TargetFatG { get; set; }
    public int MealsCount { get; set; }
    public int DaysCount { get; set; }
}
