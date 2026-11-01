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

    /// Lấy ngày theo giờ Việt Nam (UTC+7), đảm bảo mốc 0h đổi ngày chính xác
    private static DateOnly GetVietnamDate()
    {
        var vnNow = DateTime.UtcNow.AddHours(7);
        return DateOnly.FromDateTime(vnNow);
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

        var today = GetVietnamDate();

        var mealsToday = await _context.MealLogs
            .Where(m => m.UserId == userId && m.LoggedDate == today)
            .ToListAsync();

        var waterLog = await _context.DailyWaterLogs
            .FirstOrDefaultAsync(w => w.UserId == userId && w.LogDate == today);

        var stepLog = await _context.DailyStepLogs
            .FirstOrDefaultAsync(s => s.UserId == userId && s.LogDate == today);

        return Ok(new
        {
            date = today,
            targetCalories = user.TargetCalories,
            consumedCalories = mealsToday.Sum(m => m.Calories),
            consumedProtein = mealsToday.Sum(m => m.ProteinG),
            consumedCarbs = mealsToday.Sum(m => m.CarbsG),
            consumedFat = mealsToday.Sum(m => m.FatG),
            targetWaterMl = user.DailyWaterGoalMl,
            consumedWaterMl = waterLog?.WaterConsumedMl ?? 0,
            todaySteps = stepLog?.Steps ?? 0,
            burnedCalories = stepLog?.CaloriesBurned ?? 0.0,
            distanceKm = stepLog?.DistanceKm ?? 0.0
        });
    }

    [HttpPost("water/add")]
    public async Task<IActionResult> AddWater([FromQuery] int amountMl = 250)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        var today = GetVietnamDate();
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

    [HttpPost("steps/sync")]
    public async Task<IActionResult> SyncSteps([FromBody] StepSyncDto dto)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        var today = GetVietnamDate();
        if (!string.IsNullOrEmpty(dto.Date) && DateOnly.TryParse(dto.Date, out var clientDate))
        {
            today = clientDate;
        }

        var stepLog = await _context.DailyStepLogs
            .FirstOrDefaultAsync(s => s.UserId == userId && s.LogDate == today);

        if (stepLog == null)
        {
            stepLog = new DailyStepLog
            {
                UserId = userId,
                LogDate = today,
                Steps = Math.Max(0, dto.Steps),
                CaloriesBurned = dto.CaloriesBurned ?? 0.0,
                DistanceKm = dto.DistanceKm ?? 0.0,
                UpdatedAt = DateTime.UtcNow
            };
            _context.DailyStepLogs.Add(stepLog);
        }
        else
        {
            // Bảo toàn bước chân: nếu thiết bị gửi lên lớn hơn thì cập nhật, không làm lùi bước
            if (dto.Steps > stepLog.Steps)
            {
                stepLog.Steps = dto.Steps;
            }
            if (dto.CaloriesBurned.HasValue && dto.CaloriesBurned.Value > stepLog.CaloriesBurned)
            {
                stepLog.CaloriesBurned = dto.CaloriesBurned.Value;
            }
            if (dto.DistanceKm.HasValue && dto.DistanceKm.Value > stepLog.DistanceKm)
            {
                stepLog.DistanceKm = dto.DistanceKm.Value;
            }
            stepLog.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return Ok(new
        {
            message = "Đồng bộ bước chân thành công",
            todaySteps = stepLog.Steps,
            burnedCalories = stepLog.CaloriesBurned,
            distanceKm = stepLog.DistanceKm,
            date = stepLog.LogDate
        });
    }
}
