using System.Net;
using System.Net.Http.Headers;
using System.Net.Mail;
using System.Text;
using System.Text.Json;
using System.Web;
using Microsoft.AspNetCore.Identity;
using NutriSnap.Models;

namespace NutriSnap.Services;

public class EmailSender : IEmailSender<AppUser>
{
    private readonly IConfiguration _config;
    private readonly HttpClient _httpClient;

    public EmailSender(IConfiguration config, HttpClient? httpClient = null)
    {
        _config = config;
        _httpClient = httpClient ?? new HttpClient();
    }

    public Task SendConfirmationLinkAsync(AppUser user, string email, string confirmationLink)
    {
        Console.WriteLine($"[EmailSender] LINK XÁC THỰC CHO {email}: {confirmationLink}");

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

        Console.WriteLine($"[EmailSender] MÃ RESET CHO {email}: {code}");

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
        Console.WriteLine($"[EmailSender] MÃ OTP QUÊN MẬT KHẨU CHO {email}: {resetCode}");

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

    // Dùng khi người dùng yêu cầu đổi email đăng ký mới
    public Task SendChangeEmailCodeAsync(string email, string code)
    {
        Console.WriteLine($"[EmailSender] ========================================");
        Console.WriteLine($"[EmailSender] MÃ OTP ĐỔI EMAIL CHO {email}: {code}");
        Console.WriteLine($"[EmailSender] ========================================");

        string body = $@"
            <div style='font-family: Arial, sans-serif; padding: 24px; border: 1px solid #e0e0e0; border-radius: 12px; max-width: 500px; margin: 0 auto;'>
                <div style='text-align: center; margin-bottom: 20px;'>
                    <h2 style='color: #16a34a; margin: 0;'>NutriSnap</h2>
                    <p style='color: #64748b; font-size: 14px;'>Xác nhận thay đổi email đăng ký tài khoản</p>
                </div>
                <p>Xin chào,</p>
                <p>Bạn (hoặc ai đó) vừa yêu cầu đổi địa chỉ email đăng ký trên ứng dụng NutriSnap sang hộp thư này.</p>
                <p>Mã xác nhận OTP của bạn là:</p>
                <div style='background-color: #f0fdf4; border: 2px dashed #16a34a; border-radius: 8px; text-align: center; padding: 16px; margin: 20px 0;'>
                    <span style='font-size: 32px; font-weight: bold; color: #15803d; letter-spacing: 8px;'>{code}</span>
                </div>
                <p style='color: #64748b; font-size: 13px;'>Mã xác thực có hiệu lực trong vòng <b>10 phút</b>. Vui lòng không chia sẻ mã này cho bất kỳ ai.</p>
                <hr style='border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;' />
                <p style='color: #94a3b8; font-size: 11px; text-align: center;'>Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email.</p>
            </div>";

        return SendEmailAsync(email, "NutriSnap - Mã xác nhận thay đổi email đăng ký", body);
    }

    private async Task SendEmailAsync(string toEmail, string subject, string message)
    {
        var smtpSection = _config.GetSection("SmtpSettings");
        var senderEmail = _config["SMTP_SENDER_EMAIL"]
            ?? Environment.GetEnvironmentVariable("SMTP_SENDER_EMAIL")
            ?? smtpSection["SenderEmail"]
            ?? "vphat544@gmail.com";
        var senderName = smtpSection["SenderName"] ?? "NutriSnap Support";

        // 1. ƯU TIÊN GỬI QUA BREVO REST API (HTTPS PORT 443 - HOẠT ĐỘNG HOÀN HẢO TRÊN RENDER CLOUD)
        var brevoApiKey = _config["BREVO_API_KEY"]
            ?? Environment.GetEnvironmentVariable("BREVO_API_KEY")
            ?? smtpSection["BrevoApiKey"]
            ?? "";

        if (!string.IsNullOrWhiteSpace(brevoApiKey))
        {
            try
            {
                var payload = new
                {
                    sender = new { name = senderName, email = senderEmail },
                    to = new[] { new { email = toEmail } },
                    subject = subject,
                    htmlContent = message
                };

                using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
                request.Headers.Add("api-key", brevoApiKey);
                request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

                var response = await _httpClient.SendAsync(request);
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"[Brevo HTTP API] Đã gửi email thành công tới {toEmail} (Status {response.StatusCode})");
                    return;
                }

                var errorBody = await response.Content.ReadAsStringAsync();
                Console.WriteLine($"[Brevo HTTP API Warning] ({response.StatusCode}): {errorBody}. Chuyển sang fallback SMTP...");
            }
            catch (Exception brevoEx)
            {
                Console.WriteLine($"[Brevo HTTP API Exception]: {brevoEx.Message}. Chuyển sang fallback SMTP...");
            }
        }

        // 2. FALLBACK: GỬI QUA SMTP CLIENT TRUYỀN THỐNG (DÙNG CHO MÁY LOCALHOST)
        try
        {
            var host = _config["SMTP_SERVER"] ?? Environment.GetEnvironmentVariable("SMTP_SERVER") ?? smtpSection["Server"] ?? "smtp.gmail.com";
            var port = int.Parse(_config["SMTP_PORT"] ?? Environment.GetEnvironmentVariable("SMTP_PORT") ?? smtpSection["Port"] ?? "587");
            var password = _config["SMTP_PASSWORD"] ?? Environment.GetEnvironmentVariable("SMTP_PASSWORD") ?? smtpSection["Password"];

            if (string.IsNullOrEmpty(senderEmail) || string.IsNullOrEmpty(password))
            {
                Console.WriteLine("[SMTP Warning] Chưa cấu hình SenderEmail hoặc Password trong .env hoặc appsettings.json!");
                return;
            }

            using var client = new SmtpClient(host, port)
            {
                Credentials = new NetworkCredential(senderEmail, password),
                EnableSsl = true,
                Timeout = 10000 // 10s timeout để tránh treo server trên Render
            };

            var mailMessage = new MailMessage
            {
                From = new MailAddress(senderEmail, senderName),
                Subject = subject,
                Body = message,
                IsBodyHtml = true
            };

            mailMessage.To.Add(toEmail);
            await client.SendMailAsync(mailMessage);
            Console.WriteLine($"[SMTP] Đã gửi email thành công tới {toEmail}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Lỗi gửi mail SMTP]: {ex.Message}");
        }
    }
}