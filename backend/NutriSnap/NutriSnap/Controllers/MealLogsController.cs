using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NutriSnap.Data;
using NutriSnap.Models;
using NutriSnap.Services;
using System.Security.Claims;

namespace NutriSnap.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class MealLogsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly AiNutritionAdvisorService _advisorService;

    public MealLogsController(AppDbContext context, AiNutritionAdvisorService advisorService)
    {
        _context = context;
        _advisorService = advisorService;
    }

    [HttpPost("log")]
    public async Task<IActionResult> LogMeal([FromBody] CreateMealLogDto dto)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        // 1. Tự động dọn dẹp bữa ăn cũ hơn 30 ngày của user này
        var cutoffDate = DateOnly.FromDateTime(DateTime.Now.AddDays(-30));
        await _context.MealLogs
            .Where(m => m.UserId == userId && m.LoggedDate < cutoffDate)
            .ExecuteDeleteAsync();

        // 2. Chuyển từ DTO sang MealLog Entity để lưu vào DB
        var log = new MealLog
        {
            UserId = userId,
            MealTitle = dto.MealTitle,
            MealType = dto.MealType,
            Calories = dto.Calories,
            ProteinG = dto.ProteinG,
            CarbsG = dto.CarbsG,
            FatG = dto.FatG,
            LoggedDate = dto.LoggedDate ?? DateOnly.FromDateTime(DateTime.Now),
            CreatedAt = DateTime.UtcNow
        };

        _context.MealLogs.Add(log);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Đã lưu vào nhật ký!", id = log.Id });
    }
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteMealLog(int id)
    {
        // 1. Lấy UserId từ Token để đảm bảo người dùng chỉ xóa được món của chính mình
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        // 2. Tìm bản ghi bữa ăn theo ID và đúng UserId đó
        var mealLog = await _context.MealLogs
            .FirstOrDefaultAsync(m => m.Id == id && m.UserId == userId);

        if (mealLog == null)
        {
            return NotFound(new { message = "Không tìm thấy món ăn hoặc bạn không có quyền xóa món này!" });
        }

        // 3. Xóa khỏi database
        _context.MealLogs.Remove(mealLog);
        await _context.SaveChangesAsync();

        return Ok(new { message = $"Đã xóa món '{mealLog.MealTitle}' khỏi nhật ký thành công!" });
    }
    [HttpGet("history")]
    public async Task<IActionResult> GetHistory()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        var cutoffDate = DateOnly.FromDateTime(DateTime.Now.AddDays(-30));
        var history = await _context.MealLogs
            .Where(m => m.UserId == userId && m.LoggedDate >= cutoffDate)
            .OrderByDescending(m => m.LoggedDate)
            .ThenByDescending(m => m.CreatedAt)
            .Select(m => new
            {
                m.Id,
                m.MealTitle,
                m.MealType,
                m.Calories,
                m.ProteinG,
                m.CarbsG,
                m.FatG,
                m.LoggedDate
            })
            .ToListAsync();

        return Ok(history);
    }

    [HttpGet("ai-review")]
    public async Task<IActionResult> GetAiReview(
        [FromQuery] string period = "yesterday",
        [FromQuery] bool forceRefresh = false,
        [FromQuery] string lang = "vi")
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr)) return Unauthorized();
        int userId = int.Parse(userIdStr);

        var review = await _advisorService.GetNutritionReviewAsync(userId, period, forceRefresh, lang);
        return Ok(review);
    }
}