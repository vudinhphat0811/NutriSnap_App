using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using NutriSnap.Models;

namespace NutriSnap.Data;

public class AppDbContext : IdentityDbContext<AppUser, IdentityRole<int>, int>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<SavedRecipe> SavedRecipes => Set<SavedRecipe>();
    public DbSet<MealLog> MealLogs => Set<MealLog>();
    public DbSet<DailyWaterLog> DailyWaterLogs => Set<DailyWaterLog>();
    public DbSet<DailyAiReview> DailyAiReviews => Set<DailyAiReview>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Tạo Index Unique cho User và Ngày uống nước
        builder.Entity<DailyWaterLog>()
            .HasIndex(w => new { w.UserId, w.LogDate })
            .IsUnique();

        // Index cho MealLog phục vụ truy vấn 30 ngày và xóa tự động
        builder.Entity<MealLog>()
            .HasIndex(m => new { m.UserId, m.LoggedDate });

        // Index Unique cho Đánh giá AI cố định theo User, Ngày, Mốc thời gian và Ngôn ngữ
        builder.Entity<DailyAiReview>()
            .HasIndex(r => new { r.UserId, r.ReviewDate, r.Period, r.Lang })
            .IsUnique();
    }
}