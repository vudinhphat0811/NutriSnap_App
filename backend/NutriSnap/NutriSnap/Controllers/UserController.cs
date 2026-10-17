using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using NutriSnap.Data;
using NutriSnap.Models;
using NutriSnap.Services;
using System.Security.Claims;

namespace NutriSnap.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UserController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly UserManager<AppUser> _userManager;
    private readonly IMemoryCache _cache;
    private readonly EmailSender _emailSender;
    private readonly JwtService _jwtService;

    public UserController(
        AppDbContext context,
        UserManager<AppUser> userManager,
        IMemoryCache cache,
        EmailSender emailSender,
        JwtService jwtService)
    {
        _context = context;
        _userManager = userManager;
        _cache = cache;
        _emailSender = emailSender;
        _jwtService = jwtService;
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

    [HttpPost("avatar")]
    public async Task<IActionResult> UploadAvatar(IFormFile file)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized();
        }

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "Không tìm thấy file ảnh tải lên." });
        }

        var uploadFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "avatars");
        if (!Directory.Exists(uploadFolder))
        {
            Directory.CreateDirectory(uploadFolder);
        }

        var extension = Path.GetExtension(file.FileName);
        if (string.IsNullOrEmpty(extension)) extension = ".jpg";
        var uniqueFileName = $"user_{userId}_{Guid.NewGuid():N}{extension}";
        var filePath = Path.Combine(uploadFolder, uniqueFileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var relativeUrl = $"/uploads/avatars/{uniqueFileName}";
        user.AvatarUrl = relativeUrl;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tải lên ảnh đại diện thành công!",
            avatarUrl = relativeUrl
        });
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

    /// <summary>
    /// LIÊN KẾT TÀI KHOẢN MẠNG XÃ HỘI (POST /api/user/link-social)
    /// </summary>
    [HttpPost("link-social")]
    public async Task<IActionResult> LinkSocial([FromBody] LinkSocialRequest req)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized();
        }

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (req.Provider.Equals("google", StringComparison.OrdinalIgnoreCase))
        {
            user.GoogleEmail = req.AccountIdentifier;
        }
        else if (req.Provider.Equals("facebook", StringComparison.OrdinalIgnoreCase))
        {
            user.FacebookName = req.AccountIdentifier;
        }
        else
        {
            return BadRequest(new { message = "Nhà cung cấp không hợp lệ (hỗ trợ google hoặc facebook)." });
        }

        // Nếu là khách mà liên kết tài khoản thì mở khóa thành tài khoản chính thức
        if (user.IsGuest)
        {
            user.IsGuest = false;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Liên kết tài khoản {req.Provider} thành công!",
            user.GoogleEmail,
            user.FacebookName,
            user.IsGuest
        });
    }

    /// <summary>
    /// HỦY LIÊN KẾT TÀI KHOẢN MẠNG XÃ HỘI (POST /api/user/unlink-social)
    /// </summary>
    [HttpPost("unlink-social")]
    public async Task<IActionResult> UnlinkSocial([FromBody] LinkSocialRequest req)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized();
        }

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (req.Provider.Equals("google", StringComparison.OrdinalIgnoreCase))
        {
            user.GoogleEmail = null;
        }
        else if (req.Provider.Equals("facebook", StringComparison.OrdinalIgnoreCase))
        {
            user.FacebookName = null;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã hủy liên kết tài khoản {req.Provider}.",
            user.GoogleEmail,
            user.FacebookName
        });
    }

    /// <summary>
    /// KIỂM TRA TRẠNG THÁI CHẾ ĐỘ KHÁCH 7 NGÀY (GET /api/user/guest-status)
    /// </summary>
    [HttpGet("guest-status")]
    public async Task<IActionResult> GetGuestStatus()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized();
        }

        var user = await _context.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (!user.IsGuest)
        {
            return Ok(new GuestStatusResponse
            {
                IsGuest = false,
                UsageDays = 0,
                IsTrialExpired = false
            });
        }

        var createdAt = user.GuestCreatedAt ?? user.CreatedAt;
        int daysUsed = (DateTime.UtcNow.Date - createdAt.Date).Days + 1;
        bool isExpired = daysUsed >= 7;

        return Ok(new GuestStatusResponse
        {
            IsGuest = true,
            GuestCreatedAt = createdAt,
            UsageDays = daysUsed,
            IsTrialExpired = isExpired
        });
    }

    /// <summary>
    /// GỬI MÃ OTP ĐỔI EMAIL ĐĂNG KÝ (POST /api/user/request-change-email)
    /// - Không áp dụng cho Google Email liên kết, mà áp dụng cho Email đăng ký chính của tài khoản
    /// </summary>
    [HttpPost("request-change-email")]
    public async Task<IActionResult> RequestChangeEmail([FromBody] RequestChangeEmailDto dto)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized(new { message = "Phiên đăng nhập không hợp lệ hoặc đã hết hạn." });
        }

        var user = await _userManager.FindByIdAsync(userIdStr);
        if (user == null) return NotFound(new { message = "Không tìm thấy thông tin tài khoản người dùng." });

        if (string.IsNullOrWhiteSpace(dto.NewEmail) || !dto.NewEmail.Contains("@"))
        {
            return BadRequest(new { message = "Địa chỉ email mới không hợp lệ." });
        }

        var newEmail = dto.NewEmail.Trim().ToLowerInvariant();

        // 1. Email mới không được trùng với email hiện tại
        if (string.Equals(user.Email, newEmail, StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "Email mới không được trùng với email đăng ký hiện tại của bạn." });
        }

        // 2. Email mới chưa được dùng bởi tài khoản khác
        var existingUser = await _userManager.FindByEmailAsync(newEmail);
        if (existingUser != null && existingUser.Id != user.Id)
        {
            return BadRequest(new { message = "Địa chỉ email này đã được sử dụng bởi một tài khoản khác trên hệ thống!" });
        }

        // 3. Tạo mã OTP 6 số ngẫu nhiên
        string otpCode = Random.Shared.Next(100000, 999999).ToString();

        // 4. Lưu mã vào MemoryCache trong 10 phút
        string cacheKey = $"CHANGE_EMAIL_OTP_{user.Id}_{newEmail}";
        _cache.Set(cacheKey, otpCode, TimeSpan.FromMinutes(10));

        // 5. Gửi email xác thực tới địa chỉ email mới
        await _emailSender.SendChangeEmailCodeAsync(newEmail, otpCode);

        return Ok(new
        {
            message = $"Mã xác thực 6 số đã được gửi tới '{newEmail}'. Vui lòng kiểm tra hộp thư (kể cả Spam/Quảng cáo)!",
            email = newEmail
        });
    }

    /// <summary>
    /// XÁC NHẬN MÃ OTP VÀ HOÀN TẤT ĐỔI EMAIL ĐĂNG KÝ (POST /api/user/confirm-change-email)
    /// </summary>
    [HttpPost("confirm-change-email")]
    public async Task<IActionResult> ConfirmChangeEmail([FromBody] ConfirmChangeEmailDto dto)
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized(new { message = "Phiên đăng nhập không hợp lệ hoặc đã hết hạn." });
        }

        var user = await _userManager.FindByIdAsync(userIdStr);
        if (user == null) return NotFound(new { message = "Không tìm thấy thông tin tài khoản người dùng." });

        var newEmail = dto.NewEmail.Trim().ToLowerInvariant();
        var code = dto.OtpCode.Trim();

        // 1. Kiểm tra mã OTP trong cache
        string cacheKey = $"CHANGE_EMAIL_OTP_{user.Id}_{newEmail}";
        if (!_cache.TryGetValue(cacheKey, out string? cachedOtp) || cachedOtp != code)
        {
            return BadRequest(new { message = "Mã xác thực OTP không chính xác hoặc đã hết hạn (có hiệu lực trong 10 phút)!" });
        }

        // 2. Kiểm tra lại trùng lặp trước khi ghi nhận
        var existingUser = await _userManager.FindByEmailAsync(newEmail);
        if (existingUser != null && existingUser.Id != user.Id)
        {
            return BadRequest(new { message = "Địa chỉ email này đã được tài khoản khác đăng ký." });
        }

        // 3. Cập nhật email tài khoản
        string oldEmail = user.Email ?? "";
        user.Email = newEmail;
        user.NormalizedEmail = _userManager.NormalizeEmail(newEmail);
        user.EmailConfirmed = true;

        if (string.IsNullOrEmpty(user.UserName) || user.UserName.Contains("@") || user.IsGuest)
        {
            user.UserName = newEmail;
            user.NormalizedUserName = _userManager.NormalizeName(newEmail);
            user.IsGuest = false;
        }

        var updateResult = await _userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return BadRequest(new
            {
                message = "Cập nhật email không thành công.",
                errors = updateResult.Errors.Select(e => e.Description)
            });
        }

        // 4. Xóa OTP sau khi đổi thành công
        _cache.Remove(cacheKey);

        // 5. Cấp JWT Token mới với claim email mới
        var roles = await _userManager.GetRolesAsync(user);
        var newToken = _jwtService.GenerateToken(user, roles);

        return Ok(new
        {
            message = "Đổi email đăng ký thành công!",
            oldEmail,
            newEmail = user.Email,
            token = newToken
        });
    }
}