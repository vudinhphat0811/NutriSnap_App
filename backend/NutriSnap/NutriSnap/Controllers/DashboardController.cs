using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NutriSnap.Data;
using NutriSnap.Models;
using System.Security.Claims;

namespace NutriSnap.Controllers;

[Authorize] // Bắt buộc phải có Token mới được gọi
[ApiController]
[Route("api/[controller]")]
public class DashboardController : ControllerBase
{
    private readonly AppDbContext _context;

    public DashboardController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("today")]
    public async Task<IActionResult> GetTodayOverview()
    {
        // Tự động lấy UserId từ Token đã đăng nhập
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound("User không tồn tại");

        var today = DateOnly.FromDateTime(DateTime.Now);

        var mealsToday = await _context.MealLogs
            .Where(m => m.UserId == userId && m.LoggedDate == today)
            .ToListAsync();

        var waterLog = await _context.DailyWaterLogs
            .FirstOrDefaultAsync(w => w.UserId == userId && w.LogDate == today);

        return Ok(new
        {
            date = today,
            targetCalories = user.TargetCalories,
            consumedCalories = mealsToday.Sum(m => m.Calories),
            consumedProtein = mealsToday.Sum(m => m.ProteinG),
            consumedCarbs = mealsToday.Sum(m => m.CarbsG),
            consumedFat = mealsToday.Sum(m => m.FatG),
            targetWaterMl = user.DailyWaterGoalMl,
            consumedWaterMl = waterLog?.WaterConsumedMl ?? 0
        });
    }

    [HttpPost("water/add")]
    public async Task<IActionResult> AddWater([FromQuery] int amountMl = 250)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        var today = DateOnly.FromDateTime(DateTime.Now);
        var waterLog = await _context.DailyWaterLogs
            .FirstOrDefaultAsync(w => w.UserId == userId && w.LogDate == today);

        if (waterLog == null)
        {
            waterLog = new DailyWaterLog { UserId = userId, LogDate = today, WaterConsumedMl = amountMl };
            _context.DailyWaterLogs.Add(waterLog);
        }
        else
        {
            waterLog.WaterConsumedMl += amountMl;
            waterLog.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Thêm nước thành công", totalWaterMl = waterLog.WaterConsumedMl });
    }
}