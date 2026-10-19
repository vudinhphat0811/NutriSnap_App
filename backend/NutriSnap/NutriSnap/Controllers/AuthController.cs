using Google.Apis.Auth;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using NutriSnap.Models;
using NutriSnap.Services;

namespace NutriSnap.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly UserManager<AppUser> _userManager;
    private readonly SignInManager<AppUser> _signInManager;
    private readonly JwtService _jwtService;
    private readonly IMemoryCache _cache;
    private readonly IEmailSender<AppUser> _emailSender;
    private readonly IWebHostEnvironment _env;
    private readonly IConfiguration _configuration;

    public AuthController(
        UserManager<AppUser> userManager,
        SignInManager<AppUser> signInManager,
        JwtService jwtService,
        IMemoryCache cache,
        IEmailSender<AppUser> emailSender,
        IWebHostEnvironment env,
        IConfiguration configuration)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _jwtService = jwtService;
        _cache = cache;
        _emailSender = emailSender;
        _env = env;
        _configuration = configuration;
    }

    // POST /api/auth/register
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        var existingUser = await _userManager.FindByEmailAsync(dto.Email);
        if (existingUser != null)
        {
            return BadRequest(new { message = "Email đã được sử dụng." });
        }

        var user = new AppUser
        {
            UserName = dto.Email,
            Email = dto.Email,
        };

        var result = await _userManager.CreateAsync(user, dto.Password);
        if (!result.Succeeded)
        {
            return BadRequest(new { errors = result.Errors.Select(e => e.Description) });
        }

        var roles = await _userManager.GetRolesAsync(user);
        var token = _jwtService.GenerateToken(user, roles);

        return Ok(new
        {
            message = "Đăng ký thành công!",
            token,
            email = user.Email,
            userId = user.Id
        });
    }

    // POST /api/auth/login
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email);
        if (user == null)
        {
            return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });
        }

        var result = await _signInManager.CheckPasswordSignInAsync(user, dto.Password, lockoutOnFailure: false);
        if (!result.Succeeded)
        {
            return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });
        }

        var roles = await _userManager.GetRolesAsync(user);
        var token = _jwtService.GenerateToken(user, roles);

        return Ok(new
        {
            token,
            email = user.Email,
            userId = user.Id,
            fullName = user.FullName,
            avatarUrl = user.AvatarUrl,
            hasProfile = user.HasProfile,
            age = user.Age,
            gender = user.Gender,
            heightCm = user.HeightCm,
            weightKg = user.WeightKg,
            targetWeightKg = user.TargetWeightKg,
            goal = user.Goal,
            dietType = user.DietType,
            activityLevel = user.ActivityLevel,
            targetCalories = user.TargetCalories,
            targetProtein = user.TargetProtein,
            targetCarbs = user.TargetCarbs,
            targetFat = user.TargetFat,
            dailyWaterGoalMl = user.DailyWaterGoalMl
        });
    }

    // POST /api/auth/social-login
    [HttpPost("social-login")]
    public async Task<IActionResult> SocialLogin([FromBody] SocialAuthRequest req)
    {
        if (req.Provider.Equals("google", StringComparison.OrdinalIgnoreCase))
        {
            string? idToken = !string.IsNullOrWhiteSpace(req.IdToken) ? req.IdToken : req.Token;
            if (!string.IsNullOrWhiteSpace(idToken))
            {
                try
                {
                    var googleClientId = _configuration["Authentication:Google:ClientId"];
                    GoogleJsonWebSignature.ValidationSettings? settings = !string.IsNullOrWhiteSpace(googleClientId)
                        ? new GoogleJsonWebSignature.ValidationSettings { Audience = new[] { googleClientId } }
                        : null;
                    var payload = await GoogleJsonWebSignature.ValidateAsync(idToken, settings);
                    if (payload == null || string.IsNullOrWhiteSpace(payload.Email))
                    {
                        return Unauthorized(new { message = "Google ID Token không hợp lệ." });
                    }

                    req.Email = payload.Email;
                    if (!string.IsNullOrWhiteSpace(payload.Name) && string.IsNullOrWhiteSpace(req.Name))
                    {
                        req.Name = payload.Name;
                    }
                    if (!string.IsNullOrWhiteSpace(payload.Picture) && string.IsNullOrWhiteSpace(req.AvatarUrl))
                    {
                        req.AvatarUrl = payload.Picture;
                    }
                }
                catch (Exception ex)
                {
                    if (!_env.IsDevelopment())
                    {
                        return Unauthorized(new { message = "Xác thực Google ID Token thất bại: " + ex.Message });
                    }
                }
            }
            else if (!_env.IsDevelopment())
            {
                return BadRequest(new { message = "Thiếu Google ID Token để xác thực." });
            }
            else
            {
                if (string.IsNullOrWhiteSpace(req.Email))
                {
                    return BadRequest(new { message = "Email từ tài khoản Google không được để trống." });
                }
            }
        }
        else if (string.IsNullOrWhiteSpace(req.Email))
        {
            return BadRequest(new { message = "Email từ tài khoản mạng xã hội không được để trống." });
        }

        var user = await _userManager.FindByEmailAsync(req.Email);
        bool isNewUser = false;
        if (user == null)
        {
            isNewUser = true;
            user = new AppUser
            {
                UserName = req.Email,
                Email = req.Email,
                FullName = !string.IsNullOrWhiteSpace(req.Name) ? req.Name : req.Email.Split('@')[0],
                AvatarUrl = req.AvatarUrl,
                GoogleEmail = req.Provider.Equals("google", StringComparison.OrdinalIgnoreCase) ? req.Email : null,
                FacebookName = req.Provider.Equals("facebook", StringComparison.OrdinalIgnoreCase) ? (!string.IsNullOrWhiteSpace(req.Name) ? req.Name : req.Email) : null,
                IsGuest = false
            };

            var createRes = await _userManager.CreateAsync(user);
            if (!createRes.Succeeded)
            {
                return BadRequest(new { errors = createRes.Errors.Select(e => e.Description) });
            }
        }
        else
        {
            // Cập nhật thông tin liên kết mạng xã hội nếu chưa có
            bool changed = false;
            if (req.Provider.Equals("google", StringComparison.OrdinalIgnoreCase) && string.IsNullOrEmpty(user.GoogleEmail))
            {
                user.GoogleEmail = req.Email;
                changed = true;
            }
            else if (req.Provider.Equals("facebook", StringComparison.OrdinalIgnoreCase) && string.IsNullOrEmpty(user.FacebookName))
            {
                user.FacebookName = !string.IsNullOrWhiteSpace(req.Name) ? req.Name : req.Email;
                changed = true;
            }

            if (changed)
            {
                await _userManager.UpdateAsync(user);
            }
        }

        var roles = await _userManager.GetRolesAsync(user);
        var token = _jwtService.GenerateToken(user, roles);

        return Ok(new
        {
            message = $"Đăng nhập bằng {req.Provider} thành công!",
            token,
            email = user.Email,
            userId = user.Id,
            fullName = user.FullName,
            avatarUrl = user.AvatarUrl,
            googleEmail = user.GoogleEmail,
            facebookName = user.FacebookName,
            isGuest = user.IsGuest,
            isNewUser,
            hasProfile = user.HasProfile,
            age = user.Age,
            gender = user.Gender,
            heightCm = user.HeightCm,
            weightKg = user.WeightKg,
            targetWeightKg = user.TargetWeightKg,
            goal = user.Goal,
            dietType = user.DietType,
            activityLevel = user.ActivityLevel,
            targetCalories = user.TargetCalories,
            targetProtein = user.TargetProtein,
            targetCarbs = user.TargetCarbs,
            targetFat = user.TargetFat,
            dailyWaterGoalMl = user.DailyWaterGoalMl
        });
    }

    // POST /api/auth/guest-login
    [HttpPost("guest-login")]
    public async Task<IActionResult> GuestLogin()
    {
        string guestEmail = $"guest_{Guid.NewGuid():N}@nutrisnap.app";
        var guestUser = new AppUser
        {
            UserName = guestEmail,
            Email = guestEmail,
            FullName = "Khách Trải Nghiệm",
            IsGuest = true,
            GuestCreatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(guestUser);
        if (!result.Succeeded)
        {
            return BadRequest(new { errors = result.Errors.Select(e => e.Description) });
        }

        var roles = await _userManager.GetRolesAsync(guestUser);
        var token = _jwtService.GenerateToken(guestUser, roles);

        return Ok(new
        {
            message = "Bắt đầu chế độ khách 7 ngày!",
            token,
            email = guestUser.Email,
            userId = guestUser.Id,
            fullName = guestUser.FullName,
            isGuest = true,
            guestCreatedAt = guestUser.GuestCreatedAt
        });
    }

    // POST /api/auth/forgot-password-otp
    [HttpPost("forgot-password-otp")]
    public async Task<IActionResult> ForgotPasswordOtp([FromBody] ForgotPasswordDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email);
        if (user == null)
        {
            // Trả về OK để bảo mật (không lộ tài khoản có tồn tại hay không)
            return Ok(new { message = "Nếu email tồn tại, mã xác thực đã được gửi." });
        }

        // 1. Tạo ngẫu nhiên mã 4 số (từ 1000 đến 9999)
        string otpCode = Random.Shared.Next(1000, 9999).ToString();

        // 2. Lưu OTP vào bộ nhớ Cache trong 5 phút (key: "OTP_email")
        _cache.Set($"OTP_{dto.Email}", otpCode, TimeSpan.FromMinutes(5));

        // 3. Gửi email
        await _emailSender.SendPasswordResetCodeAsync(user, dto.Email, otpCode);

        return Ok(new { message = "Mã xác thực 4 số đã được gửi tới email của bạn." });
    }

    // POST /api/auth/reset-password-otp
    [HttpPost("reset-password-otp")]
    public async Task<IActionResult> ResetPasswordOtp([FromBody] ResetPasswordDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email);
        if (user == null)
        {
            return BadRequest(new { message = "Yêu cầu không hợp lệ." });
        }

        // 1. Kiểm tra mã OTP trong Cache
        if (!_cache.TryGetValue($"OTP_{dto.Email}", out string? cachedOtp) || cachedOtp != dto.Code)
        {
            return BadRequest(new { message = "Mã xác thực không đúng hoặc đã hết hạn!" });
        }

        // 2. Đổi mật khẩu
        var token = await _userManager.GeneratePasswordResetTokenAsync(user);
        var result = await _userManager.ResetPasswordAsync(user, token, dto.NewPassword);

        if (!result.Succeeded)
        {
            return BadRequest(result.Errors);
        }

        // 3. Xóa OTP sau khi đổi mật khẩu thành công
        _cache.Remove($"OTP_{dto.Email}");

        return Ok(new { message = "Đặt lại mật khẩu thành công!" });
    }
}
