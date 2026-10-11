using System.ComponentModel.DataAnnotations;

namespace NutriSnap.Models;

public class SavedRecipe
{
    public int Id { get; set; }

    [MaxLength(50)]
    public string? ExternalMealId { get; set; }

    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? ImageUrl { get; set; }

    [MaxLength(500)]
    public string? YoutubeUrl { get; set; }

    public int TotalCalories { get; set; } = 0;
    public double ProteinG { get; set; } = 0;
    public double CarbsG { get; set; } = 0;
    public double FatG { get; set; } = 0;

    public string? Instructions { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}