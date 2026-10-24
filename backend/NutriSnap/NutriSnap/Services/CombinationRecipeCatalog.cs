using NutriSnap.Models;

namespace NutriSnap.Services;

/// <summary>
/// Danh mục công thức món ăn kết hợp phong phú (Combination Recipe Catalog)
/// Đã được lọc sạch toàn bộ các món sử dụng ảnh trùng lặp để đảm bảo 100% món ăn có ảnh độc bản.
/// </summary>
public static class CombinationRecipeCatalog
{
    public static readonly List<RecommendedMealDto> Recipes = new();
}
