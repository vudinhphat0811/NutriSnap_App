using System.ComponentModel.DataAnnotations;

namespace NutriSnap.Models;

public class RegisterDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(6)]
    public string Password { get; set; } = string.Empty;
}

public class LoginDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}
public class UpdateProfileDto
{
    public string FullName { get; set; } = string.Empty;
    public int Age { get; set; } = 0;
    public string Gender { get; set; } = string.Empty; // "Nam" hoặc "Nu"
    public double HeightCm { get; set; } = 0.0;
    public double WeightKg { get; set; } = 0.0;
    public double TargetWeightKg { get; set; } = 0.0;

    // Người dùng chọn trên App:
    // "LoseWeight" (Giảm cân), "Maintain" (Giữ cân), "GainWeight" (Tăng cân)
    public string Goal { get; set; } = "LoseWeight";

    // "Balanced" (Cân bằng), "HighProtein" (Nhiều đạm), "LowCarb" (Ít tinh bột), "Vegetarian" (Ăn chay)
    public string DietType { get; set; } = "HighProtein";

    // "Sedentary" (Ít vận động), "Moderate" (Vừa phải), "Active" (Nhiều)
    public string ActivityLevel { get; set; } = "Moderate";
}