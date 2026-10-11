using System.ComponentModel.DataAnnotations;

namespace NutriSnap.Models;

public class CreateMealLogDto
{
    [Required]
    public string MealTitle { get; set; } = string.Empty;

    public string MealType { get; set; } = "Lunch"; // Breakfast, Lunch, Dinner, Snack

    public int Calories { get; set; } = 0;

    public double ProteinG { get; set; } = 0;

    public double CarbsG { get; set; } = 0;

    public double FatG { get; set; } = 0;
}