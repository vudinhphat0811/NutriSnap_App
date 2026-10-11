using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NutriSnap.Data;
using NutriSnap.Models;
using System.Security.Claims;

namespace NutriSnap.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UserController : ControllerBase
{
    private readonly AppDbContext _context;

    public UserController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("profile")]
    public async Task<IActionResult> GetProfile()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        int userId = int.Parse(userIdStr!);

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        return Ok(user);
    }

    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileDto dto)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        int userId = int.Parse(userIdStr!);

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        user.FullName = dto.FullName;
        user.Age = dto.Age;
        user.Gender = dto.Gender;
        user.HeightCm = dto.HeightCm;
        user.WeightKg = dto.WeightKg;

        // --- BƯỚC 1: Tính BMR (Công thức Mifflin-St Jeor) ---
        double bmr;
        if (dto.Gender.Equals("Nam", StringComparison.OrdinalIgnoreCase))
        {
            bmr = (10 * dto.WeightKg) + (6.25 * dto.HeightCm) - (5 * dto.Age) + 5;
        }
        else
        {
            bmr = (10 * dto.WeightKg) + (6.25 * dto.HeightCm) - (5 * dto.Age) - 161;
        }

        // TDEE: Năng lượng duy trì ở mức vận động nhẹ (BMR x 1.375)
        double tdee = bmr * 1.375;

        // --- BƯỚC 2: Điều chỉnh theo Mục tiêu (Goal) ---
        int targetCalories = (int)tdee;
        if (dto.Goal == "LoseWeight")
        {
            targetCalories -= 400; // Giảm cân: thâm hụt 400 kcal
        }
        else if (dto.Goal == "GainWeight")
        {
            targetCalories += 400; // Tăng cân: dư thừa 400 kcal
        }

        user.TargetCalories = targetCalories;

        // --- BƯỚC 3: Phân bổ Macro (Đạm, Carbs, Fat) theo chế độ ăn ---
        // 1g Protein = 4 kcal, 1g Carbs = 4 kcal, 1g Fat = 9 kcal
        if (dto.DietType == "HighProtein") // Chế độ nhiều đạm (30% Protein, 45% Carbs, 25% Fat)
        {
            user.TargetProtein = Math.Round((targetCalories * 0.30) / 4, 1);
            user.TargetCarbs = Math.Round((targetCalories * 0.45) / 4, 1);
            user.TargetFat = Math.Round((targetCalories * 0.25) / 9, 1);
        }
        else if (dto.DietType == "LowCarb") // Ít tinh bột (25% Protein, 20% Carbs, 55% Fat)
        {
            user.TargetProtein = Math.Round((targetCalories * 0.25) / 4, 1);
            user.TargetCarbs = Math.Round((targetCalories * 0.20) / 4, 1);
            user.TargetFat = Math.Round((targetCalories * 0.55) / 9, 1);
        }
        else // Cân bằng mặc định (20% Protein, 55% Carbs, 25% Fat)
        {
            user.TargetProtein = Math.Round((targetCalories * 0.20) / 4, 1);
            user.TargetCarbs = Math.Round((targetCalories * 0.55) / 4, 1);
            user.TargetFat = Math.Round((targetCalories * 0.25) / 9, 1);
        }

        // Nước: 35ml trên mỗi kg cân nặng
        user.DailyWaterGoalMl = (int)(dto.WeightKg * 35);

        await _context.SaveChangesAsync();
        return Ok(new
        {
            message = "Cập nhật hồ sơ & Mục tiêu dinh dưỡng thành công!",
            user.TargetCalories,
            user.TargetProtein,
            user.TargetCarbs,
            user.TargetFat,
            user.DailyWaterGoalMl
        });
    }
}