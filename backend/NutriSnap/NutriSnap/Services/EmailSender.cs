using Microsoft.AspNetCore.Identity;
using NutriSnap.Models;
using System.Net;
using System.Net.Mail;
using System.Web;

namespace NutriSnap.Services;

public class EmailSender : IEmailSender<AppUser>
{
    private readonly IConfiguration _config;

    public EmailSender(IConfiguration config)
    {
        _config = config;
    }

    public Task SendConfirmationLinkAsync(AppUser user, string email, string confirmationLink)
    {
        string body = $@"
            <div style='font-family: Arial, sans-serif; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;'>
                <h2 style='color: #2e7d32;'>NutriSnap - Xác nhận tài khoản</h2>
                <p>Cảm ơn bạn đã đăng ký tài khoản NutriSnap. Vui lòng bấm vào liên kết bên dưới để xác thực:</p>
                <p style='margin: 20px 0;'>
                    <a href='{confirmationLink}' style='background-color: #2e7d32; color: #ffffff; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold;'>Xác nhận ngay</a>
                </p>
                <p style='color: #777; font-size: 12px;'>Nếu nút bấm không hoạt động, copy link sau: {confirmationLink}</p>
            </div>";

        return SendEmailAsync(email, "Xác nhận tài khoản NutriSnap", body);
    }

    // Tự động bóc tách chuỗi code từ URL dài của Identity và đóng khung rõ ràng
    public Task SendPasswordResetLinkAsync(AppUser user, string email, string resetLink)
    {
        string code = resetLink;
        try
        {
            var uri = new Uri(resetLink);
            var query = HttpUtility.ParseQueryString(uri.Query);
            code = query["resetCode"] ?? query["code"] ?? resetLink;
        }
        catch
        {
            // Nếu không parse được URL thì giữ nguyên chuỗi
        }

        string body = $@"
            <div style='font-family: Arial, sans-serif; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;'>
                <h2 style='color: #2e7d32;'>NutriSnap - Đặt lại mật khẩu</h2>
                <p>Bạn vừa yêu cầu đặt lại mật khẩu. Sao chép mã xác nhận dưới đây và dán vào ô <b>resetCode</b>:</p>
                <div style='background-color: #f5f5f5; border: 1px dashed #2e7d32; padding: 14px; font-family: Consolas, monospace; font-size: 15px; font-weight: bold; color: #1b5e20; word-break: break-all; margin: 15px 0;'>
                    {code}
                </div>
                <p style='color: #666; font-size: 13px;'>Nếu bạn không thực hiện yêu cầu này, hãy bỏ qua email.</p>
            </div>";

        return SendEmailAsync(email, "Mã đặt lại mật khẩu NutriSnap", body);
    }

    // Dùng cho trường hợp tự sinh OTP ngắn (4 số / 6 số)
    public Task SendPasswordResetCodeAsync(AppUser user, string email, string resetCode)
    {
        string body = $@"
            <div style='font-family: Arial, sans-serif; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;'>
                <h2 style='color: #2e7d32;'>NutriSnap - Mã OTP đặt lại mật khẩu</h2>
                <p>Mã xác thực OTP của bạn là:</p>
                <div style='font-size: 32px; font-weight: bold; color: #d32f2f; letter-spacing: 6px; padding: 10px 0;'>
                    {resetCode}
                </div>
                <p style='color: #666; font-size: 13px;'>Mã xác thực này có hiệu lực trong vòng <b>5 phút</b>.</p>
            </div>";

        return SendEmailAsync(email, "Mã OTP xác nhận NutriSnap", body);
    }

    private async Task SendEmailAsync(string toEmail, string subject, string message)
    {
        try
        {
            var smtpSection = _config.GetSection("SmtpSettings");
            var host = smtpSection["Server"] ?? "smtp.gmail.com";
            var port = int.Parse(smtpSection["Port"] ?? "587");
            var senderEmail = smtpSection["SenderEmail"];
            var password = smtpSection["Password"];

            if (string.IsNullOrEmpty(senderEmail) || string.IsNullOrEmpty(password))
            {
                Console.WriteLine("[SMTP Warning] Chưa cấu hình SenderEmail hoặc Password trong appsettings.json!");
                return;
            }

            using var client = new SmtpClient(host, port)
            {
                Credentials = new NetworkCredential(senderEmail, password),
                EnableSsl = true
            };

            var mailMessage = new MailMessage
            {
                From = new MailAddress(senderEmail, smtpSection["SenderName"] ?? "NutriSnap Support"),
                Subject = subject,
                Body = message,
                IsBodyHtml = true
            };

            mailMessage.To.Add(toEmail);
            await client.SendMailAsync(mailMessage);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Lỗi gửi mail SMTP]: {ex.Message}");
        }
    }
}