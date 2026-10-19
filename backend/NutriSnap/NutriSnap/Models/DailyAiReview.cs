using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NutriSnap.Models;

public class DailyAiReview
{
    public int Id { get; set; }
    public int UserId { get; set; }

    public DateOnly ReviewDate { get; set; }

    [MaxLength(20)]
    public string Period { get; set; } = "yesterday";

    [MaxLength(10)]
    public string Lang { get; set; } = "vi";

    public int Score { get; set; }

    [Column(TypeName = "text")]
    public string ReviewJson { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public AppUser? User { get; set; }
}
