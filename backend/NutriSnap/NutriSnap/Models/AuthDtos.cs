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
    public int Age { get; set; } = 22;
    public string Gender { get; set; } = "Nam"; // "Nam" hoặc "Nu"
    public double HeightCm { get; set; } = 170.0;
    public double WeightKg { get; set; } = 65.0;

    // Người dùng chọn trên App:
    // "LoseWeight" (Giảm cân), "Maintain" (Giữ cân), "GainWeight" (Tăng cân)
    public string Goal { get; set; } = "LoseWeight";

    // "Balanced" (Cân bằng), "HighProtein" (Nhiều đạm), "LowCarb" (Ít tinh bột)
    public string DietType { get; set; } = "HighProtein";
}