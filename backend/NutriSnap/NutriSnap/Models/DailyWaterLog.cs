namespace NutriSnap.Models;

public class DailyWaterLog
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public DateOnly LogDate { get; set; } = DateOnly.FromDateTime(DateTime.Now);
    public int WaterConsumedMl { get; set; } = 0;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public AppUser? User { get; set; }
}