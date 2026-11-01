namespace NutriSnap.Models;

public class DailyStepLog
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public DateOnly LogDate { get; set; }
    public int Steps { get; set; } = 0;
    public double CaloriesBurned { get; set; } = 0.0;
    public double DistanceKm { get; set; } = 0.0;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public AppUser? User { get; set; }
}

public class StepSyncDto
{
    public int Steps { get; set; }
    public double? CaloriesBurned { get; set; }
    public double? DistanceKm { get; set; }
    public string? Date { get; set; }
}
