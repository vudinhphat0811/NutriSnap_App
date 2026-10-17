using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations;

namespace NutriSnap.Models;

public class AppUser : IdentityUser<int>
{
    [MaxLength(100)]
    public string FullName { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? AvatarUrl { get; set; }

    public int Age { get; set; } = 22;

    [MaxLength(10)]
    public string Gender { get; set; } = "Nam";

    public double HeightCm { get; set; } = 170.0;
    public double WeightKg { get; set; } = 65.0;

    public int TargetCalories { get; set; } = 1950;
    public double TargetProtein { get; set; } = 140.0;
    public double TargetCarbs { get; set; } = 200.0;
    public double TargetFat { get; set; } = 55.0;

    public int DailyWaterGoalMl { get; set; } = 2000;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

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