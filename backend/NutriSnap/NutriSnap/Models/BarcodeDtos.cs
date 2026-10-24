namespace NutriSnap.Models;

public class BarcodeProductDto
{
    public string Barcode { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string CategoryIcon { get; set; } = "🛒";
    public string BarcodeType { get; set; } = "EAN-13 Tiêu Chuẩn"; // EAN-13 hoặc Tem Cân Siêu Thị
    public double NetWeightG { get; set; } = 100.0;
    public string ServingSize { get; set; } = "100g";
    public double CaloriesPer100g { get; set; }
    public double ProteinPer100g { get; set; }
    public double CarbsPer100g { get; set; }
    public double FatPer100g { get; set; }
    public double FiberPer100g { get; set; }
    public double? SodiumMg { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public string Source { get; set; } = "NutriSnap Supermarket DB";
    public string? CutEquivalentId { get; set; }
    public string Notes { get; set; } = string.Empty;
    public CalculatedCutMacroDto? CalculatedPortionMacros { get; set; }
}

public class BarcodeLookupResponseDto
{
    public bool Success { get; set; }
    public string Barcode { get; set; } = string.Empty;
    public BarcodeProductDto? Product { get; set; }
    public string Message { get; set; } = string.Empty;
    public List<string> Suggestions { get; set; } = new();
}
