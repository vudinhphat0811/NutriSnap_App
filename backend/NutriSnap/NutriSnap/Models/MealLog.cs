using System.ComponentModel.DataAnnotations;

namespace NutriSnap.Models;

public class MealLog
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int? RecipeId { get; set; }

    [MaxLength(200)]
    public string MealTitle { get; set; } = string.Empty;

    [MaxLength(30)]
    public string MealType { get; set; } = "Lunch"; // Breakfast, Lunch, Dinner, Snack

    public int Calories { get; set; } = 0;
    public double ProteinG { get; set; } = 0;
    public double CarbsG { get; set; } = 0;
    public double FatG { get; set; } = 0;

    public DateOnly LoggedDate { get; set; } = DateOnly.FromDateTime(DateTime.Now);
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public AppUser? User { get; set; }
    public SavedRecipe? Recipe { get; set; }
}