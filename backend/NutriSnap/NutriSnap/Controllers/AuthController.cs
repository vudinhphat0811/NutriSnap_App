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

    public AuthController(
        UserManager<AppUser> userManager,
        SignInManager<AppUser> signInManager,
        JwtService jwtService,
        IMemoryCache cache,
        IEmailSender<AppUser> emailSender)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _jwtService = jwtService;
        _cache = cache;
        _emailSender = emailSender;
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
            fullName = user.FullName
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
