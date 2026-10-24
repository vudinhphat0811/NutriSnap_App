namespace NutriSnap.Models;

public class IngredientCutDto
{
    public string Id { get; set; } = "";
    public string Category { get; set; } = "";
    public string CategoryIcon { get; set; } = "🍗";
    public string Name { get; set; } = "";
    public string EnglishName { get; set; } = "";
    public string Description { get; set; } = "";
    public string DefaultPortionName { get; set; } = "100g";
    public double DefaultPortionWeightG { get; set; } = 100.0;
    
    // Chỉ số trên 100g
    public double CaloriesPer100g { get; set; }
    public double ProteinPer100g { get; set; }
    public double CarbsPer100g { get; set; }
    public double FatPer100g { get; set; }
    public double FiberPer100g { get; set; }

    // Dành cho gymer & người tập luyện
    public List<string> SuitableGoals { get; set; } = new();
    public List<string> GymBadges { get; set; } = new();
    public string GymTip { get; set; } = "";
    public string ImageUrl { get; set; } = "";
}

public class CalculateCutMacroRequest
{
    public string CutId { get; set; } = "";
    public double WeightG { get; set; } = 100.0;
}

public class CalculatedCutMacroDto
{
    public string CutId { get; set; } = "";
    public string Name { get; set; } = "";
    public double WeightG { get; set; }
    public double TotalCalories { get; set; }
    public double TotalProtein { get; set; }
    public double TotalCarbs { get; set; }
    public double TotalFat { get; set; }
    public double TotalFiber { get; set; }
    
    // Tỷ lệ % Calo theo Macro (Macro Calorie Breakdown)
    public double ProteinPercent { get; set; }
    public double CarbsPercent { get; set; }
    public double FatPercent { get; set; }
    
    public List<string> GymBadges { get; set; } = new();
    public string GymTip { get; set; } = "";
}
