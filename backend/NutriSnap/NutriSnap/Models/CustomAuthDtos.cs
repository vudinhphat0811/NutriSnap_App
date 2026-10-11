using System.ComponentModel.DataAnnotations;

namespace NutriSnap.Models;

public class ForgotPasswordDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;
}

public class ResetPasswordDto
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Code { get; set; } = string.Empty; // Mã 4 hoặc 6 số

    [Required]
    public string NewPassword { get; set; } = string.Empty;
}