using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations;

using System.ComponentModel.DataAnnotations.Schema;

namespace NutriSnap.Models;

public class AppUser : IdentityUser<int>
{
    [MaxLength(100)]
    public string? FullName { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? AvatarUrl { get; set; }

    public int Age { get; set; } = 0;

    [MaxLength(10)]
    public string? Gender { get; set; } = string.Empty;

    public double HeightCm { get; set; } = 0.0;
    public double WeightKg { get; set; } = 0.0;
    public double TargetWeightKg { get; set; } = 0.0;

    [MaxLength(50)]
    public string? Goal { get; set; } = "LoseWeight";

    [MaxLength(50)]
    public string? DietType { get; set; } = "HighProtein";

    [MaxLength(50)]
    public string? ActivityLevel { get; set; } = "Moderate";

    public int TargetCalories { get; set; } = 0;
    public double TargetProtein { get; set; } = 0.0;
    public double TargetCarbs { get; set; } = 0.0;
    public double TargetFat { get; set; } = 0.0;

    public int DailyWaterGoalMl { get; set; } = 0;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [NotMapped]
    public bool HasProfile => HeightCm > 0 && WeightKg > 0 && Age > 0;

    [MaxLength(200)]
    public string? GoogleEmail { get; set; }

    [MaxLength(200)]
    public string? FacebookName { get; set; }

    public bool IsGuest { get; set; } = false;
    public DateTime? GuestCreatedAt { get; set; }

    // Quan hệ 1 User có nhiều MealLogs và DailyWaterLogs
    public ICollection<MealLog> MealLogs { get; set; } = new List<MealLog>();
    public ICollection<DailyWaterLog> DailyWaterLogs { get; set; } = new List<DailyWaterLog>();
}