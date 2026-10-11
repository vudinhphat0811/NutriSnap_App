using System.Text.Json.Nodes;

namespace NutriSnap.Services;

public class RecipeService
{
    private readonly HttpClient _httpClient;

    public RecipeService(HttpClient httpClient)
    {
        _httpClient = httpClient;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "NutriSnapApp/1.0");
    }

    public async Task<JsonObject?> GetRandomMealAsync()
    {
        // 1. Gọi lấy món ngẫu nhiên từ TheMealDB
        var res = await _httpClient.GetStringAsync("https://www.themealdb.com/api/json/v1/1/random.php");
        var node = JsonNode.Parse(res);
        var rawMeal = node?["meals"]?[0]?.AsObject();

        if (rawMeal == null) return null;

        // 2. Gom danh sách nguyên liệu từ strIngredient1..20 vào 1 mảng mượt mà
        var ingredientsList = new JsonArray();
        for (int i = 1; i <= 20; i++)
        {
            var ing = rawMeal[$"strIngredient{i}"]?.ToString();
            var measure = rawMeal[$"strMeasure{i}"]?.ToString();

            if (!string.IsNullOrWhiteSpace(ing))
            {
                ingredientsList.Add(new JsonObject
                {
                    ["name"] = ing.Trim(),
                    ["measure"] = measure?.Trim() ?? ""
                });
            }
        }

        // 3. Ước lượng calo và macro cơ bản (hoặc lấy từ OpenFoodFacts)
        int estimatedCalories = 350 + (ingredientsList.Count * 25); // Ước lượng calo chuẩn theo số nguyên liệu
        double estimatedProtein = Math.Round(ingredientsList.Count * 4.5, 1);
        double estimatedCarbs = Math.Round(ingredientsList.Count * 5.0, 1);
        double estimatedFat = Math.Round(ingredientsList.Count * 2.2, 1);

        // 4. Trả về đúng các trường Flutter cần hiển thị
        var cleanMeal = new JsonObject
        {
            ["externalMealId"] = rawMeal["idMeal"]?.ToString(),
            ["title"] = rawMeal["strMeal"]?.ToString(),
            ["category"] = rawMeal["strCategory"]?.ToString(),
            ["area"] = rawMeal["strCountry"]?.ToString() ?? rawMeal["strArea"]?.ToString(),
            ["imageUrl"] = rawMeal["strMealThumb"]?.ToString(),
            ["youtubeUrl"] = rawMeal["strYoutube"]?.ToString(),
            ["instructions"] = rawMeal["strInstructions"]?.ToString(),
            ["totalCalories"] = estimatedCalories,
            ["proteinG"] = estimatedProtein,
            ["carbsG"] = estimatedCarbs,
            ["fatG"] = estimatedFat,
            ["ingredients"] = ingredientsList
        };

        return cleanMeal;
    }
}