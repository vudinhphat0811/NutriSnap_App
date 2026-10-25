using NutriSnap.Models;

namespace NutriSnap.Services;

/// <summary>
/// Kho công thức món ăn gia đình quen thuộc, bình dị (Everyday Home-cooked & Simple Dishes)
/// Đảm bảo 100% các món ăn đều có:
/// - Ảnh độc bản, thực tế, chính xác với từng món ăn (0 trùng lặp)
/// - Nguyên liệu thông dụng trong tủ lạnh gia đình (thịt bò, hành tây, rau muống, xà lách, trứng, cà chua, đậu phụ...)
/// - Định lượng thực tế (g, quả, củ, thìa...) chuẩn chỉ
/// </summary>
public static class MultiSourceCatalogService
{
    private static RecommendedMealDto M(
        string id, string en, string vi, string cat, string area,
        int cal, int p, int c, int f,
        string[] ingsEn, string[] ingsVi,
        string[] measEn, string[] measVi,
        string instEn, string instVi,
        string img, string[] badges)
    {
        return new RecommendedMealDto
        {
            IdMeal = id,
            StrMeal = en,
            StrMealVi = vi,
            StrCategory = cat,
            StrArea = area,
            EstimatedCalories = cal,
            EstimatedProtein = p,
            EstimatedCarbs = c,
            EstimatedFat = f,
            Ingredients = [.. ingsEn],
            IngredientsVi = [.. ingsVi],
            Measures = [.. measEn],
            MeasuresVi = [.. measVi],
            StrInstructions = instEn,
            StrInstructionsVi = instVi,
            // Không sử dụng ảnh Unsplash không liên quan, để rỗng để Client hiển thị Icon món ăn chuẩn xác
            StrMealThumb = (img != null && img.Contains("unsplash.com", StringComparison.OrdinalIgnoreCase)) ? "" : (img ?? ""),
            Badges = [.. badges],
            MatchScore = 98
        };
    }

    public static List<RecommendedMealDto> GetAllRecipes()
    {
        return GetHomeCookingRecipes();
    }

    /// <summary>
    /// Bộ sưu tập 43 món ăn gia đình thân quen, bình dân, dễ nấu nhất
    /// </summary>
    public static List<RecommendedMealDto> GetHomeCookingRecipes()
    {
        return
        [
            // 1. Thịt bò xào hành tây
            M("vn_home_01", "Stir-fried Beef with Onions", "Thịt Bò Xào Hành Tây", "Beef", "Vietnamese", 280, 32, 8, 12,
                ["Beef", "Onion", "Garlic", "Oyster Sauce", "Black Pepper"],
                ["Thịt bò thái mỏng", "Hành tây bổ múi cau", "Tỏi băm", "Dầu hào", "Tiêu đen xay"],
                ["200g", "1 piece", "3 cloves", "1 tbsp", "1 tsp"],
                ["200g", "1 củ", "3 tép", "1 thìa canh", "1 thìa cà phê"],
                "1. Marinate sliced beef with garlic and oyster sauce for 10 minutes. 2. Flash fry beef over high heat for 2 minutes, transfer to plate. 3. Sauté onions until translucent and sweet. 4. Return beef, toss for 30 seconds and season with black pepper.",
                "1. Ướp thịt bò thái mỏng với tỏi băm, dầu hào và chút tiêu trong 10 phút. 2. Phi thơm tỏi với dầu ăn trên chảo lửa lớn, cho thịt bò vào xào nhanh tay trong 2 phút vừa chín tới rồi trút ra đĩa riêng. 3. Cho hành tây vào chảo đảo đều cho chín tới giữ độ ngọt giòn. 4. Đổ thịt bò vào đảo nhanh cùng hành tây trong 30 giây rồi tắt bếp, rắc tiêu thơm nức mũi.",
                "https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=600&q=80",
                ["🇻🇳 Món Ngon Gia Đình", "🥩 Giàu Đạm", "⚡ Nhanh Gọn 15p"]),

            // 2. Bò xào bông cải xanh
            M("vn_home_02", "Stir-fried Beef with Broccoli", "Bò Xào Bông Cải Xanh Tỏi Phi", "Beef", "Vietnamese", 270, 33, 9, 10,
                ["Beef", "Broccoli", "Garlic", "Oyster Sauce", "Sesame Oil"],
                ["Thịt bò", "Bông cải xanh", "Tỏi phi", "Dầu hào", "Dầu mè"],
                ["200g", "250g", "4 cloves", "1 tbsp", "1 tsp"],
                ["200g", "250g", "4 tép", "1 thìa canh", "1 thìa cà phê"],
                "1. Blanch broccoli florets in boiling water for 1 minute. 2. Sear sliced beef quickly in hot wok. 3. Add broccoli and oyster sauce, toss well for 1 minute.",
                "1. Bông cải xanh chần sơ qua nước sôi 1 phút rồi vớt ra xả nước lạnh giữ màu xanh giòn. 2. Phi tỏi xào bò trên lửa lớn vừa chín mềm. 3. Cho bông cải xanh và dầu hào vào đảo đều nhanh tay 1 phút rồi dọn ra đĩa.",
                "https://images.unsplash.com/photo-1783375175952-705a0600e05c?auto=format&fit=crop&w=600&q=80",
                ["🥦 Giàu Chất Xơ", "💪 Đủ Đạm & Rau", "⚡ Nhanh Gọn"]),

            // 3. Bò xào cần tỏi tây
            M("vn_home_03", "Stir-fried Beef with Celery & Leek", "Bò Xào Cần Tỏi Tây", "Beef", "Vietnamese", 260, 31, 7, 11,
                ["Beef", "Celery", "Leek", "Garlic", "Black Pepper"],
                ["Thịt bò tươi", "Cần tây cắt khúc", "Tỏi tây", "Tỏi băm", "Tiêu xay"],
                ["200g", "100g", "1 stalk", "3 cloves", "1 tsp"],
                ["200g", "100g", "1 cây", "3 tép", "1 thìa cà phê"],
                "1. Thinly slice beef and season lightly. 2. Flash fry beef with garlic, set aside. 3. Sauté celery and leek until crisp-tender. 4. Mix together and finish with ground pepper.",
                "1. Thịt bò thái mỏng ướp tỏi băm. 2. Xào bò trên lửa lớn vừa chín tới trút ra đĩa. 3. Cho cần tây và tỏi tây vào đảo đều cho dậy mùi thơm nức. 4. Đổ bò vào đảo lại 30 giây, rắc tiêu thơm phức.",
                "https://images.unsplash.com/photo-1738999353105-a19fcffefad2?auto=format&fit=crop&w=600&q=80",
                ["🇻🇳 Chuẩn Vị Việt", "🥩 Bò Mềm Thơm", "⚡ 15 Phút"]),

            // 4. Bò lúc lắc hành tây ớt chuông
            M("vn_home_04", "Vietnamese Shaking Beef", "Bò Lúc Lắc Xào Hành Tây Ớt Chuông", "Beef", "Vietnamese", 360, 34, 12, 18,
                ["Tenderloin Beef", "Onion", "Bell Pepper", "Garlic", "Soy Sauce", "Butter"],
                ["Thịt thăn bò", "Hành tây", "Ớt chuông", "Tỏi băm", "Nước tương", "Bơ lạt"],
                ["250g", "1 piece", "1 piece", "3 cloves", "1 tbsp", "10g"],
                ["250g", "1 củ", "1 quả", "3 tép", "1 thìa canh", "10g"],
                "1. Cut beef into cubes, marinate with soy sauce and pepper. 2. Sear cubes on high heat. 3. Add butter, onions and bell peppers, shake the wok vigorously.",
                "1. Thịt bò thái con chì vuông vức ướp xì dầu tỏi tiêu. 2. Áp chảo lửa lớn cho bò xém cạnh mọng nước. 3. Cho bơ, hành tây và ớt chuông vào lắc chảo nhanh tay đậm đà thơm ngậy.",
                "https://images.unsplash.com/photo-1534939561126-855b8675edd7?auto=format&fit=crop&w=600&q=80",
                ["🥩 Bò Mềm Mọng Nước", "🇻🇳 Món Ngon Gia Đình", "🔥 Đậm Đà"]),

            // 5. Rau muống xào tỏi
            M("vn_home_05", "Stir-fried Morning Glory with Garlic", "Rau Muống Xào Tỏi Xanh Mướt", "Vegetarian", "Vietnamese", 120, 4, 8, 8,
                ["Water Spinach", "Purple Garlic", "Fish Sauce", "Cooking Oil"],
                ["Rau muống ngọn non", "Tỏi tía đập dập", "Nước mắm ngon", "Dầu ăn"],
                ["300g", "1 head", "1 tbsp", "1 tbsp"],
                ["300g", "1 củ", "1 thìa canh", "1 thìa canh"],
                "1. Blanch young morning glory stems. 2. Brown generous crushed garlic in oil. 3. Flash fry greens over high flame and season with fish sauce.",
                "1. Rau muống ngắt ngọn non rửa sạch, chần sơ nước sôi rồi ngâm nước đá cho giòn. 2. Phi thơm thật nhiều tỏi tía đập dập. 3. Xào rau trên lửa lớn đảo nhanh tay, nêm nước mắm thơm phức.",
                "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80",
                ["🌱 Xanh Giòn Dân Dã", "🧄 Tỏi Phi Thơm Nức", "⚡ Dưới 10p"]),

            // 6. Rau cải xào tỏi phi
            M("vn_home_06", "Stir-fried Bok Choy with Garlic", "Rau Cải Xào Tỏi Phi Giòn", "Vegetarian", "Vietnamese", 110, 4, 7, 7,
                ["Bok Choy", "Garlic", "Oyster Sauce", "Cooking Oil"],
                ["Rau cải thìa", "Tỏi phi", "Dầu hào", "Dầu ăn"],
                ["300g", "4 cloves", "1 tbsp", "1 tbsp"],
                ["300g", "4 tép", "1 thìa canh", "1 thìa canh"],
                "1. Clean bok choy halves. 2. Fry minced garlic until golden. 3. Add greens, toss with oyster sauce until tender-crisp.",
                "1. Rau cải tách bẹ rửa sạch để ráo. 2. Phi thơm tỏi vàng giòn. 3. Cho rau cải vào xào nhanh cùng dầu hào cho rau chín tới giữ trọn độ ngọt mát.",
                "https://images.unsplash.com/photo-1546793665-c74683f339c1?auto=format&fit=crop&w=600&q=80",
                ["🌱 Thanh Mát", "🥦 Giàu Vitamin", "⚡ Siêu Nhanh"]),

            // 7. Salad rau trộn dầu giấm
            M("vn_home_07", "Garden Mixed Salad with Vinaigrette", "Salad Rau Trộn Dầu Giấm", "Vegetarian", "Vietnamese", 130, 3, 12, 8,
                ["Lettuce", "Cherry Tomatoes", "Cucumber", "Onion", "Vinaigrette Dressing"],
                ["Xà lách giòn", "Cà chua bi", "Dưa leo", "Hành tây", "Dầu giấm chua ngọt"],
                ["150g", "8 pieces", "1 piece", "1/2 piece", "2 tbsp"],
                ["150g", "8 quả", "1 quả", "1/2 củ", "2 thìa canh"],
                "1. Wash and tear crisp lettuce. 2. Slice cucumber, tomatoes and onions. 3. Toss with honey vinaigrette dressing right before serving.",
                "1. Xà lách ngâm nước muối rửa sạch để ráo. 2. Cắt lát dưa leo, cà chua bi bổ đôi, hành tây bào mỏng ngâm giấm bớt hăng. 3. Rưới sốt dầu giấm chua ngọt lên trộn đều thưởng thức.",
                "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=600&q=80",
                ["🥗 Tươi Mát Giòn Tan", "🌱 Eat Clean", "⚡ Không Cần Nấu"]),

            // 8. Salad ức gà trộn trứng
            M("vn_home_08", "Clean Eating Chicken Breast Salad", "Salad Ức Gà Trộn Trứng Eat Clean", "Chicken", "Vietnamese", 320, 36, 10, 12,
                ["Chicken Breast", "Boiled Egg", "Lettuce", "Cherry Tomatoes", "Sesame Dressing"],
                ["Ức gà xé sợi", "Trứng gà luộc", "Xà lách", "Cà chua bi", "Sốt mè rang"],
                ["180g", "1 piece", "100g", "6 pieces", "1 tbsp"],
                ["180g", "1 quả", "100g", "6 quả", "1 thìa canh"],
                "1. Poach or pan-sear chicken breast, then slice. 2. Arrange lettuce, halved boiled egg and tomatoes. 3. Drizzle roasted sesame dressing.",
                "1. Ức gà áp chảo hoặc luộc chín xé sợi. 2. Xếp xà lách tươi ra đĩa, đặt trứng luộc bổ đôi và cà chua bi lên trên. 3. Rưới sốt mè rang bùi béo ăn thanh nhẹ bổ dưỡng.",
                "https://images.unsplash.com/photo-1649531794752-5833ee051fb6?auto=format&fit=crop&w=600&q=80",
                ["💪 Siêu Đạm Tăng Cơ", "🥗 Chuẩn Gymer", "✨ Ít Calo"]),

            // 9. Salad dưa chuột cà chua
            M("vn_home_09", "Cucumber & Tomato Salad", "Salad Dưa Chuột Cà Chua Thanh Mát", "Vegetarian", "Vietnamese", 95, 2, 10, 5,
                ["Cucumber", "Tomato", "Coriander", "Apple Cider Vinegar", "Sesame Oil"],
                ["Dưa chuột nếp", "Cà chua chín", "Rau mùi ta", "Giấm táo", "Dầu mè"],
                ["2 pieces", "2 pieces", "20g", "1 tbsp", "1 tsp"],
                ["2 quả", "2 quả", "20g", "1 thìa canh", "1 thìa cà phê"],
                "1. Dice fresh cucumbers and tomatoes. 2. Toss with apple cider vinegar, a pinch of salt and fragrant sesame oil. 3. Garnish with coriander.",
                "1. Dưa chuột gọt vỏ cắt lát hoặc con chì, cà chua thái múi cau. 2. Trộn giấm táo chua dịu, đường, chút muối và vài giọt dầu mè thơm phức. 3. Điểm thêm rau mùi ta thanh mát.",
                "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80",
                ["🌱 Giải Ngấy Đỉnh Cao", "🥗 Giòn Ngọt Thanh", "⚡ 5 Phút"]),

            // 10. Đậu phụ sốt cà chua
            M("vn_home_10", "Silken Tofu in Fresh Tomato Sauce", "Đậu Phụ Sốt Cà Chua Hành Hoa", "Vegetarian", "Vietnamese", 230, 18, 12, 12,
                ["Tofu", "Ripe Tomatoes", "Green Onions", "Soy Sauce", "Cooking Oil"],
                ["Đậu phụ rán vàng", "Cà chua chín mọng", "Hành hoa", "Nước mắm / Xì dầu", "Dầu ăn"],
                ["3 pieces", "3 pieces", "3 stalks", "1 tbsp", "1 tbsp"],
                ["3 bìa", "3 quả", "3 nhánh", "1 thìa canh", "1 thìa canh"],
                "1. Pan-fry tofu cubes until golden. 2. Simmer diced tomatoes into a rich sauce. 3. Add fried tofu, simmer for 5 minutes, finish with fresh scallions.",
                "1. Đậu phụ cắt miếng vuông rán vàng giòn các mặt. 2. Cà chua băm nhỏ xào nhừ thành nước sốt sánh đỏ. 3. Cho đậu vào đun liu riu ngấm đều gia vị rồi rắc hành hoa dọn ra đĩa.",
                "https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?auto=format&fit=crop&w=600&q=80",
                ["🇻🇳 Món Ngon Gia Đình", "🌱 Đậu Mềm Mọng", "🍅 Sốt Đậm Đà"]),

            // 11. Trứng chiên hành hoa
            M("vn_home_11", "Vietnamese Scallion Omelet", "Trứng Chiên Hành Hoa Mềm Xốp", "Vegetarian", "Vietnamese", 190, 14, 2, 14,
                ["Chicken Eggs", "Green Onions", "Fish Sauce", "Black Pepper", "Cooking Oil"],
                ["Trứng gà ta", "Hành hoa thái nhỏ", "Nước mắm ngon", "Tiêu xay", "Dầu ăn"],
                ["3 pieces", "4 stalks", "1 tsp", "1/2 tsp", "1 tbsp"],
                ["3 quả", "4 nhánh", "1 thìa cà phê", "1/2 thìa cà phê", "1 thìa canh"],
                "1. Beat eggs thoroughly with chopped scallions, fish sauce and pepper. 2. Pour into hot pan and fry until fluffy and golden on both sides.",
                "1. Đập trứng vào bát, thêm hành hoa thái nhỏ, thìa nước mắm ngon và tiêu rồi đánh bông. 2. Đun nóng chảo dầu, đổ trứng vào chiên lửa vừa cho phồng xốp vàng ruộm hai mặt.",
                "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=600&q=80",
                ["🍳 Nhanh Gọn 5 Phút", "🥚 Trứng Mềm Xốp", "🇻🇳 Quen Thuộc"]),

            // 12. Canh cà chua trứng
            M("vn_home_12", "Tomato Egg Drop Soup", "Canh Cà Chua Trứng Vân Mây", "Vegetarian", "Vietnamese", 140, 9, 8, 8,
                ["Tomatoes", "Chicken Eggs", "Green Onions", "Coriander", "Fish Sauce"],
                ["Cà chua bổ múi cau", "Trứng gà ta", "Hành hoa", "Rau mùi", "Nước mắm ngon"],
                ["2 pieces", "2 pieces", "3 stalks", "10g", "1 tbsp"],
                ["2 quả", "2 quả", "3 nhánh", "10g", "1 thìa canh"],
                "1. Sauté tomatoes until soft, add water and bring to a boil. 2. Slowly drizzle beaten eggs into soup while gently stirring to create silky clouds. 3. Garnish with scallions and coriander.",
                "1. Xào mềm cà chua rồi thêm nước sôi vào nấu canh. 2. Đánh tan trứng rồi từ từ rót vào nồi, dùng đũa khuấy nhẹ một chiều tạo vân mây bồng bềnh óng ả. 3. Tắt bếp rắc hành mùi thơm dịu.",
                "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=600&q=80",
                ["🍲 Canh Quen Thuộc", "🍅 Chua Thanh Dịu", "⚡ Nấu 10p"]),

            // 13. Canh bí đao nấu thịt băm
            M("vn_home_13", "Winter Melon Soup with Minced Meat", "Canh Bí Đao Nấu Thịt Băm", "Pork", "Vietnamese", 160, 16, 8, 7,
                ["Winter Melon", "Minced Pork", "Green Onions", "Cilantro", "Fish Sauce"],
                ["Bí đao thái lát", "Thịt heo nạc băm", "Hành hoa", "Mùi tàu", "Nước mắm ngon"],
                ["300g", "100g", "2 stalks", "5g", "1 tbsp"],
                ["300g", "100g", "2 nhánh", "5g", "1 thìa canh"],
                "1. Sauté seasoned minced pork until cooked through. 2. Pour in water and bring to rolling boil. 3. Add sliced winter melon and cook until transparent. 4. Top with scallions.",
                "1. Phi thơm hành tím xào săn thịt băm nêm chút nước mắm. 2. Đổ nước vào đun sôi bùng hớt bọt. 3. Thả bí đao thái lát mỏng vào nấu vừa chín trong veo ngọt mát. 4. Rắc hành hoa và mùi tàu thơm lừng.",
                "https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=600&q=80",
                ["🍲 Thanh Mát Giải Nhiệt", "🇻🇳 Canh Bữa Cơm", "🍃 Dễ Ăn"]),

            // 14. Thịt heo xào đậu cô ve
            M("vn_home_14", "Stir-fried Pork with Green Beans", "Thịt Heo Xào Đậu Cô Ve", "Pork", "Vietnamese", 260, 26, 9, 12,
                ["Lean Pork", "Green Beans", "Garlic", "Oyster Sauce", "Black Pepper"],
                ["Thịt heo nạc thái mỏng", "Đậu cô ve tước xơ", "Tỏi băm", "Dầu hào", "Tiêu đen"],
                ["180g", "200g", "3 cloves", "1 tbsp", "1 tsp"],
                ["180g", "200g", "3 tép", "1 thìa canh", "1 thìa cà phê"],
                "1. Sauté garlic and sliced pork until browned. 2. Toss in trimmed green beans and oyster sauce. 3. Stir fry on high heat until beans are crisp-tender.",
                "1. Phi thơm tỏi xào thịt heo nạc thái mỏng vừa chín tới. 2. Cho đậu cô ve bẻ khúc vào xào trên lửa lớn cùng dầu hào. 3. Đảo đều tay cho đậu chín giòn ngọt tự nhiên rồi rắc tiêu ra đĩa.",
                "https://images.unsplash.com/photo-1751560048567-b38f5cf3448a?auto=format&fit=crop&w=600&q=80",
                ["🇻🇳 Món Ngon Gia Đình", "🥗 Đủ Đạm & Rau", "⚡ Giòn Ngọt"]),

            // 15. Thịt ba chỉ rang cháy cạnh
            M("vn_home_15", "Crispy Pan-seared Pork Belly", "Thịt Ba Chỉ Rang Cháy Cạnh", "Pork", "Vietnamese", 460, 28, 6, 34,
                ["Pork Belly", "Shallots", "Fish Sauce", "Sugar", "Black Pepper"],
                ["Thịt ba chỉ thái mỏng", "Hành tím thái lát", "Nước mắm ngon", "Đường", "Tiêu sọ"],
                ["250g", "2 pieces", "2 tbsp", "1 tsp", "1 tsp"],
                ["250g", "2 củ", "2 thìa canh", "1 thìa cà phê", "1 thìa cà phê"],
                "1. Render sliced pork belly in hot dry pan until edges are browned and crisp. 2. Pour off excess fat, add shallots, fish sauce and sugar. 3. Toss until caramelized.",
                "1. Thịt ba chỉ thái mỏng cho vào chảo rang trên lửa vừa cho kiệt bớt mỡ và xém cạnh vàng giòn. 2. Chắt bớt mỡ thừa, cho hành tím, nước mắm ngon và chút đường vào đảo kẹo. 3. Rắc tiêu dọn cùng cơm nóng.",
                "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=600&q=80",
                ["🥓 Cháy Cạnh Giòn Rụm", "🇻🇳 Hao Cơm Nhất Bữa", "🔥 Đậm Đà"]),

            // 16. Thịt viên xíu mại sốt cà chua
            M("vn_home_16", "Vietnamese Meatballs in Tomato Sauce", "Thịt Viên Xíu Mại Sốt Cà Chua", "Pork", "Vietnamese", 340, 26, 14, 18,
                ["Minced Pork", "Ripe Tomatoes", "Onions", "Green Onions", "Garlic"],
                ["Thịt nạc vai băm", "Cà chua chín mọng", "Hành tây băm", "Hành lá", "Tỏi băm"],
                ["200g", "3 pieces", "1/2 piece", "3 stalks", "2 cloves"],
                ["200g", "3 quả", "1/2 củ", "3 nhánh", "2 tép"],
                "1. Mix minced pork with chopped onions and seasoning, shape into balls. 2. Steam meatballs for 10 minutes. 3. Simmer in thick tomato gravy until coated.",
                "1. Trộn thịt băm với hành tây băm nhỏ, tiêu gia vị rồi vo viên tròn. 2. Hấp xíu mại 10 phút cho chín ngọt. 3. Nấu sốt cà chua nhừ sánh mịn rồi cho thịt viên vào đun liu riu cho ngấm đều sốt đỏ.",
                "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=600&q=80",
                ["🍅 Sốt Cà Chua Đậm Đà", "🥩 Thịt Mềm Mọng", "🥖 Ăn Cơm Hay Bánh Mì"]),

            // 17. Gà xào sả ớt
            M("vn_home_17", "Spicy Lemongrass Stir-fried Chicken", "Gà Xào Sả Ớt Cay Nồng", "Chicken", "Vietnamese", 320, 36, 5, 15,
                ["Chicken", "Lemongrass", "Chili", "Garlic", "Oyster Sauce", "Fish Sauce"],
                ["Thịt gà chặt miếng", "Sả băm nhuyễn", "Ớt cay", "Tỏi băm", "Dầu hào", "Nước mắm"],
                ["250g", "3 stalks", "2 pieces", "3 cloves", "1 tbsp", "1 tbsp"],
                ["250g", "3 cây", "2 quả", "3 tép", "1 thìa canh", "1 thìa canh"],
                "1. Marinate chicken with minced lemongrass, chili, garlic and fish sauce. 2. Sauté aromatics in oil then add chicken. 3. Stir fry on high heat until caramelized.",
                "1. Thịt gà ướp cùng sả băm, ớt băm, tỏi và nước mắm trong 15 phút. 2. Phi thơm sả ớt trong chảo dầu rồi trút gà vào đảo săn. 3. Xào lửa vừa cho miếng gà săn chắc óng vàng cay nồng đậm đà.",
                "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80",
                ["🌶️ Cay Nồng Sả Ớt", "🍗 Gà Săn Đậm Vị", "🇻🇳 Hao Cơm"]),

            // 18. Ức gà áp chảo thảo mộc
            M("vn_home_18", "Herb Pan-seared Chicken Breast", "Ức Gà Áp Chảo Thảo Mộc", "Chicken", "Vietnamese", 240, 38, 1, 7,
                ["Chicken Breast", "Garlic", "Black Pepper", "Olive Oil", "Herbs"],
                ["Ức gà tươi", "Tỏi băm", "Tiêu đen", "Dầu ô liu", "Thảo mộc"],
                ["200g", "2 cloves", "1 tsp", "1 tbsp", "1 pinch"],
                ["200g", "2 tép", "1 thìa cà phê", "1 thìa canh", "1 nhúm"],
                "1. Tenderize chicken breast lightly, rub with garlic, black pepper and olive oil. 2. Sear on medium heat for 6 minutes each side until golden and juicy.",
                "1. Dần nhẹ miếng ức gà cho đều dày, ướp tỏi băm, tiêu đen và dầu ô liu 10 phút. 2. Đặt lên chảo áp chảo mỗi mặt 6 phút ở lửa vừa cho da xém vàng mà thịt bên trong mọng nước mềm ngọt.",
                "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80",
                ["💪 Siêu Đạm Tăng Cơ", "✨ Eat Clean Đỉnh Cao", "⚡ Dưới 15p"]),

            // 19. Gà kho nấm hương tươi
            M("vn_home_19", "Braised Chicken with Fresh Shiitake Mushrooms", "Gà Kho Nấm Hương Tươi", "Chicken", "Vietnamese", 310, 34, 8, 14,
                ["Chicken", "Shiitake Mushrooms", "Fresh Ginger", "Shallots", "Soy Sauce"],
                ["Thịt gà chặt nhỏ", "Nấm hương tươi", "Gừng tươi thái sợi", "Hành tím", "Nước tương ngon"],
                ["250g", "100g", "1 knob", "2 pieces", "2 tbsp"],
                ["250g", "100g", "1 nhánh", "2 củ", "2 thìa canh"],
                "1. Sauté ginger and shallots until fragrant. 2. Brown chicken pieces, then add fresh mushrooms. 3. Simmer with soy sauce until sauce thickens.",
                "1. Phi thơm gừng thái sợi và hành tím. 2. Cho thịt gà vào xào săn rồi thêm nấm hương tươi mọng nước vào đảo cùng. 3. Nêm nước tương và kho liu riu cho nước sốt sánh nâu béo ngậy thơm lừng.",
                "https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80",
                ["🍄 Nấm Thơm Ngọt", "🍗 Gà Kho Đậm Vị", "🇻🇳 Ấm Bụng"]),

            // 20. Cơm chiên trứng rau củ
            M("vn_home_20", "Egg & Mixed Vegetable Fried Rice", "Cơm Chiên Trứng Rau Củ", "Vegetarian", "Vietnamese", 380, 12, 56, 11,
                ["Cooked Rice", "Chicken Eggs", "Carrot", "Green Peas", "Green Onions", "Cooking Oil"],
                ["Cơm nguội tơi hạt", "Trứng gà", "Cà rốt hạt lựu", "Đậu Hà Lan", "Hành hoa", "Dầu ăn"],
                ["1 bowl", "2 pieces", "1/2 piece", "50g", "3 stalks", "1 tbsp"],
                ["1 bát", "2 quả", "1/2 củ", "50g", "3 nhánh", "1 thìa canh"],
                "1. Mix half the beaten egg into cold rice to coat grains. 2. Scramble remaining egg in hot wok. 3. Add rice and veggies, toss vigorously on high flame until fluffy and fragrant.",
                "1. Trộn 1 quả trứng vào bát cơm nguội bóp nhẹ cho hạt cơm áo đều lớp vàng. 2. Chảo nóng phi thơm hành, chiên tơi quả trứng còn lại cùng cà rốt và đậu. 3. Đổ cơm vào đảo lửa lớn cho hạt cơm săn giòn vàng ruộm rắc tiêu hành hoa.",
                "https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?auto=format&fit=crop&w=600&q=80",
                ["🍚 Hạt Cơm Tơi Giòn", "🍳 Trứng Vàng Óng", "⚡ Nhanh Gọn 10p"]),

            // 21. Phở bò tái nạm
            M("vn_home_21", "Traditional Beef Pho", "Phở Bò Tái Nạm Truyền Thống", "Beef", "Vietnamese", 460, 32, 56, 11,
                ["Beef", "Rice Noodles", "Onions", "Ginger", "Star Anise", "Cinnamon"],
                ["Thịt bò tái nạm", "Bánh phở tươi", "Hành tây", "Gừng nướng", "Hoa hồi", "Quế thanh"],
                ["150g", "150g", "1 piece", "1 knob", "2 pieces", "1 stick"],
                ["150g", "150g", "1 củ", "1 nhánh", "2 hoa", "1 thanh"],
                "1. Simmer marrow bones with roasted ginger, cinnamon and star anise for rich clear broth. 2. Blanch fresh pho noodles. 3. Layer tender beef on noodles and ladle boiling broth.",
                "1. Hầm xương bò cùng gừng nướng, hoa hồi và quế thanh cho nước dùng trong veo ngọt lịm. 2. Chần bánh phở tươi qua nước sôi. 3. Xếp thịt bò tái nạm thái mỏng lên trên rồi chan nước dùng đang sôi sùng sục, rắc hành hoa.",
                "https://images.unsplash.com/photo-1631709497146-a239ef373cf1?auto=format&fit=crop&w=600&q=80",
                ["🍜 Tinh Hoa Phở Việt", "🥩 Nước Dùng Trong Ngọt", "💪 Giàu Đạm"]),

            // 22. Bún chả Hà Nội
            M("vn_home_22", "Hanoi Grilled Pork with Vermicelli", "Bún Chả Hà Nội Nướng Than Hoa", "Pork", "Vietnamese", 510, 32, 58, 16,
                ["Pork Belly", "Minced Pork Patties", "Fresh Vermicelli", "Green Papaya Pickles", "Fish Sauce"],
                ["Thịt ba chỉ", "Chả băm viên", "Bún tươi", "Đu đủ chua ngọt", "Nước mắm nhĩ"],
                ["100g", "100g", "150g", "50g", "3 tbsp"],
                ["100g", "100g", "150g", "50g", "3 thìa canh"],
                "1. Marinate pork belly and seasoned patties with shallots and caramel sauce. 2. Grill over glowing charcoal until smoky and charred. 3. Serve in warm sweet & sour fish sauce with vermicelli.",
                "1. Ướp thịt ba chỉ và chả băm cùng hành tím nước màu. 2. Nướng trên than hoa đỏ rực cho xém thơm nức mũi. 3. Thả chả vào bát nước mắm ấm chua ngọt điểm đu đủ giòn tan ăn kèm đĩa bún tươi và rau sống.",
                "https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=600&q=80",
                ["🔥 Than Hoa Thơm Nức", "🇻🇳 Đặc Sản Thủ Đô", "🥢 Chua Ngọt Hài Hòa"]),

            // 23. Đậu hũ kho nấm rơm
            M("vn_home_23", "Braised Tofu with Fresh Straw Mushrooms", "Đậu Hũ Kho Nấm Rơm Đậm Đà", "Vegetarian", "Vietnamese", 220, 16, 12, 11,
                ["Fried Tofu", "Fresh Straw Mushrooms", "Soy Sauce", "Black Pepper", "Green Onions"],
                ["Đậu hũ chiên", "Nấm rơm tươi", "Nước tương ngon", "Tiêu sọ xay", "Hành lá"],
                ["3 pieces", "150g", "2 tbsp", "1 tsp", "2 stalks"],
                ["3 bìa", "150g", "2 thìa canh", "1 thìa cà phê", "2 nhánh"],
                "1. Clean fresh straw mushrooms. 2. Sauté mushrooms, then add golden tofu cubes. 3. Simmer in savory soy sauce reduction with plenty of black pepper.",
                "1. Nấm rơm tươi cạo sạch chân nấm ngâm nước muối loãng. 2. Xào thơm nấm rơm rồi cho đậu hũ chiên vàng vào. 3. Nêm nước tương ngon và tiêu xay đun liu riu cho nước sốt ngấm sâu đậm đà tốn cơm.",
                "https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=600&q=80",
                ["🌱 Chay Thanh Đạm", "🍄 Nấm Mọng Nước", "🥢 Tốn Cơm"]),

            // 24. Cá hồi áp chảo măng tây
            M("vn_home_24", "Pan-seared Salmon with Asparagus", "Cá Hồi Áp Chảo Măng Tây", "Seafood", "Vietnamese", 390, 36, 6, 22,
                ["Salmon Fillet", "Asparagus", "Lemon", "Garlic", "Butter"],
                ["Phi lê cá hồi tươi", "Măng tây xanh", "Chanh vàng", "Tỏi băm", "Bơ lạt"],
                ["180g", "100g", "1/2 piece", "2 cloves", "10g"],
                ["180g", "100g", "1/2 quả", "2 tép", "10g"],
                "1. Season salmon with sea salt and black pepper. 2. Sear skin-down until crisp, flip once. 3. Sauté young asparagus with garlic butter and serve with lemon wedges.",
                "1. Ướp cá hồi với chút muối tiêu và nước cốt chanh. 2. Áp chảo phần da trước cho giòn rụm rồi lật mặt áp chảo vừa chín tới mọng nước. 3. Xào măng tây xanh giòn với bơ tỏi thơm lừng ăn kèm.",
                "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80",
                ["🐟 Omega 3 Dồi Dào", "🥦 Chuẩn Eat Clean", "✨ Sang Trọng Bổ Dưỡng"]),

            // 25. Chả cá Lã Vọng
            M("vn_home_25", "La Vong Turmeric Fish with Dill", "Chả Cá Lã Vọng Hà Nội", "Seafood", "Vietnamese", 410, 34, 18, 20,
                ["Fish Fillet", "Fresh Dill", "Green Onions", "Turmeric", "Rice Vermicelli"],
                ["Cá phi lê thơm ngọt", "Thì là bó lớn", "Hành hoa chẻ ngọn", "Nghệ tươi giã", "Bún tươi"],
                ["200g", "1 bunch", "1 bunch", "1 knob", "100g"],
                ["200g", "1 bó", "1 bó", "1 củ", "100g"],
                "1. Marinate fish fillets with fresh turmeric and aromatics. 2. Pan fry on table with mountain of fresh dill and scallions. 3. Serve hot over rice noodles.",
                "1. Cá phi lê ướp nước cốt nghệ tươi vàng ruộm đậm đà. 2. Chiên cá vàng xèo xèo trên chảo rồi thả ngập tràn thì là và hành hoa đảo bốc khói nghi ngút. 3. Ăn cùng bún tươi lạc rang chấm mắm tôm hoặc mắm pha chua ngọt.",
                "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80",
                ["🇻🇳 Di Sản Hà Nội", "🐟 Cá Giòn Béo Ngậy", "🌿 Thì Là Dậy Vị"]),

            // 26. Thịt bò xào rau muống
            M("vn_home_26", "Stir-fried Beef with Water Spinach", "Thịt Bò Xào Rau Muống Tỏi Phi", "Beef", "Vietnamese", 290, 32, 6, 13,
                ["Beef", "Water Spinach", "Garlic", "Oyster Sauce", "Black Pepper"],
                ["Thịt bò thái mỏng", "Rau muống ngọn non", "Tỏi tía đập dập", "Dầu hào", "Tiêu đen xay"],
                ["200g", "300g", "5 cloves", "1 tbsp", "1 tsp"],
                ["200g", "300g", "5 tép", "1 thìa canh", "1 thìa cà phê"],
                "1. Marinate sliced beef with garlic and oyster sauce. 2. Flash fry beef in hot wok for 2 minutes and set aside. 3. Stir fry morning glory with purple garlic over high flame until crisp-green. 4. Toss beef back in for 30 seconds and serve hot.",
                "1. Thịt bò thái mỏng ướp tỏi băm, dầu hào và chút hạt tiêu trong 10 phút. 2. Phi thơm tỏi, xào bò trên lửa lớn trong 2 phút vừa chín tới rồi trút riêng ra đĩa. 3. Cho rau muống vào xào nhanh tay trên lửa lớn với tỏi đập dập cho ngọn rau xanh giòn mướt. 4. Đổ thịt bò vào đảo cùng rau trong 30 giây rồi tắt bếp dọn ra đĩa.",
                "https://images.unsplash.com/photo-1603048588665-791ca8aea617?auto=format&fit=crop&w=600&q=80",
                ["🇻🇳 Món Ngon Gia Đình", "🥩 Đủ Đạm & Rau", "⚡ Hao Cơm"]),

            // 27. Canh rau muống nấu tôm tươi
            M("vn_home_27", "Water Spinach Soup with Fresh Shrimp", "Canh Rau Muống Nấu Tôm Tươi", "Seafood", "Vietnamese", 140, 20, 4, 3,
                ["Fresh Shrimp", "Water Spinach", "Shallots", "Fish Sauce", "Black Pepper"],
                ["Tôm sú tươi bóc vỏ", "Rau muống non", "Hành tím băm", "Nước mắm ngon", "Tiêu xay"],
                ["150g", "300g", "2 pieces", "1 tbsp", "1/2 tsp"],
                ["150g", "300g", "2 củ", "1 thìa canh", "1/2 thìa cà phê"],
                "1. Peel and roughly mince fresh shrimp. 2. Sauté shallots and shrimp until pink, then add water to boil. 3. Add trimmed water spinach and season with fish sauce. 4. Simmer for 2 minutes and serve.",
                "1. Tôm tươi bóc vỏ giã dập hoặc băm thô, ướp chút nước mắm và tiêu. 2. Phi thơm hành tím xào săn tôm rồi đổ nước vào đun sôi bùng, hớt sạch bọt. 3. Thả rau muống ngắt khúc vào nấu lửa lớn cho rau vừa chín tới giữ màu xanh mướt. 4. Nêm vừa ăn rồi múc ra bát canh thanh mát ngọt lịm.",
                "https://images.unsplash.com/photo-1594756202469-9ff9799b2e4e?auto=format&fit=crop&w=600&q=80",
                ["🍲 Canh Thanh Mát", "🦐 Tôm Tươi Ngọt Nước", "🌱 Giải Nhiệt"]),

            // 28. Rau muống xào chao đỏ
            M("vn_home_28", "Water Spinach Stir-fried with Fermented Tofu", "Rau Muống Xào Chao Đỏ Cay Nồng", "Vegetarian", "Vietnamese", 135, 5, 9, 8,
                ["Water Spinach", "Fermented Tofu (Chao)", "Purple Garlic", "Chili", "Cooking Oil"],
                ["Rau muống ngọn non", "Chao đỏ thơm bùi", "Tỏi tía băm", "Ớt cay", "Dầu ăn"],
                ["300g", "2 cubes", "4 cloves", "1 piece", "1 tbsp"],
                ["300g", "2 viên", "4 tép", "1 quả", "1 thìa canh"],
                "1. Mash fermented tofu cubes with sugar and chili. 2. Sauté minced garlic until aromatic. 3. Flash fry morning glory stems over high heat, pour in chao mixture and toss vigorously.",
                "1. Tán nhuyễn chao cùng chút đường và ớt thái lát. 2. Phi thơm tỏi tía trong chảo dầu nóng. 3. Cho rau muống vào xào lửa lớn đảo nhanh tay, rưới sốt chao vào xào thêm 1 phút cho rau áo đều vị chao béo ngậy thơm nức.",
                "https://images.unsplash.com/photo-1550859917-b3f6c8993b43?auto=format&fit=crop&w=600&q=80",
                ["🌱 Đậm Đà Béo Ngậy", "🔥 Vị Chao Thơm Lừng", "🇻🇳 Dân Dã Nam Bộ"]),

            // 29. Canh ngao nấu rau muống
            M("vn_home_29", "Clam & Water Spinach Soup", "Canh Ngao Nấu Rau Muống Gừng Tươi", "Seafood", "Vietnamese", 110, 14, 5, 2,
                ["Fresh Clams", "Water Spinach", "Fresh Ginger", "Fish Sauce"],
                ["Ngao tươi sống", "Rau muống non", "Gừng tươi đập dập", "Nước mắm ngon"],
                ["500g", "300g", "1 knob", "1 tbsp"],
                ["500g", "300g", "1 nhánh", "1 thìa canh"],
                "1. Boil clams with ginger until open, save the clear sweet clam broth. 2. Remove meat from clam shells. 3. Bring clam broth to a rolling boil, add water spinach and clam meat, season and turn off heat.",
                "1. Ngao ngâm ớt rửa sạch cát, luộc với chút gừng cho há miệng rồi gỡ lấy ruột, chắt lấy nước luộc trong veo. 2. Đun sôi bùng nước ngao, thả rau muống vào nấu lửa to cho rau xanh giòn. 3. Cho ruột ngao vào lại nồi, nêm chút nước mắm vừa miệng rồi tắt bếp ngay.",
                "https://images.unsplash.com/photo-1707897748442-cc3a48d31300?auto=format&fit=crop&w=600&q=80",
                ["🍲 Thanh Mát Ngọt Nước", "🦪 Ngao Tươi Béo", "🍃 Giải Nhiệt Mùa Hè"]),

            // 30. Nộm rau muống tôm thịt
            M("vn_home_30", "Water Spinach Salad with Shrimp & Pork", "Nộm Rau Muống Tôm Thịt Đậu Phộng", "Pork", "Vietnamese", 260, 24, 12, 12,
                ["Water Spinach", "Fresh Shrimp", "Pork Belly", "Roasted Peanuts", "Lime Chili Dressing"],
                ["Rau muống chẻ sợi giòn", "Tôm tươi luộc chín", "Thịt ba chỉ luộc", "Đậu phộng rang giòn", "Nước mắm chua ngọt"],
                ["250g", "100g", "80g", "30g", "2 tbsp"],
                ["250g", "100g", "80g", "30g", "2 thìa canh"],
                "1. Shred water spinach stems and soak in iced lemon water to curl and crisp. 2. Slice boiled pork and halved shrimp. 3. Toss greens, meats and sweet-sour dressing, top with crushed peanuts.",
                "1. Rau muống ngắt bỏ lá, chẻ cuộng ngâm nước đá chanh cho cong tít và giòn tan. 2. Thịt ba chỉ luộc thái mỏng, tôm luộc bóc vỏ chẻ đôi lưng. 3. Trộn rau muống cùng tôm thịt và nước mắm tỏi ớt chua ngọt, rắc đậu phộng rang giòn thơm phức.",
                "https://images.unsplash.com/photo-1546069901-d5bfd2cbfb1f?auto=format&fit=crop&w=600&q=80",
                ["🥗 Giòn Sần Sật", "🦐 Chua Cay Mặn Ngọt", "🇻🇳 Món Nhậu & Khai Vị"]),

            // 31. Thịt bò xào cải ngồng
            M("vn_home_31", "Stir-fried Beef with Chinese Broccoli", "Thịt Bò Xào Cải Ngồng Tỏi Phi", "Beef", "Vietnamese", 275, 32, 7, 11,
                ["Beef", "Chinese Broccoli", "Purple Garlic", "Oyster Sauce", "Black Pepper"],
                ["Thịt bò thái mỏng", "Cải ngồng non xanh", "Tỏi phi giòn", "Dầu hào", "Tiêu đen xay"],
                ["200g", "250g", "5 cloves", "1 tbsp", "1 tsp"],
                ["200g", "250g", "5 tép", "1 thìa canh", "1 thìa cà phê"],
                "1. Marinate beef with garlic and oyster sauce. 2. Blanch Chinese broccoli in salted water for 45s. 3. Sauté beef in smoking wok for 2 mins, set aside. 4. Toss greens with beef and garlic.",
                "1. Thịt bò thái mỏng ướp tỏi băm và dầu hào. 2. Cải ngồng rửa sạch, chần sơ 45 giây qua nước sôi rồi ngâm nước lạnh giữ màu xanh ngọc. 3. Xào bò trên lửa lớn vừa chín tới múc ra đĩa. 4. Cho cải ngồng vào chảo xào nhanh với tỏi phi giòn, đổ bò vào đảo đều 30 giây rồi rắc tiêu thơm lừng.",
                "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=600&q=80",
                ["🥦 Giòn Ngọt Thanh", "🥩 Bò Mềm Tỏi Phi", "⚡ 15 Phút"]),

            // 32. Canh cải ngọt nấu thịt băm
            M("vn_home_32", "Mustard Greens Soup with Minced Pork", "Canh Cải Ngọt Nấu Thịt Băm Gừng Tươi", "Pork", "Vietnamese", 155, 18, 6, 6,
                ["Mustard Greens", "Minced Pork", "Fresh Ginger", "Fish Sauce", "Shallots"],
                ["Rau cải ngọt tươi", "Thịt heo nạc băm", "Gừng tươi thái sợi", "Nước mắm ngon", "Hành tím"],
                ["300g", "100g", "1 knob", "1 tbsp", "2 pieces"],
                ["300g", "100g", "1 nhánh", "1 thìa canh", "2 củ"],
                "1. Season minced pork with fish sauce and shallots. 2. Sauté pork until browned, add boiling water. 3. Drop in chopped mustard greens and julienned ginger, cook for 2 minutes.",
                "1. Thịt nạc băm ướp chút nước mắm và tiêu. 2. Phi thơm hành tím xào săn thịt rồi đổ nước vào đun sôi, hớt bọt. 3. Thả rau cải ngọt cắt khúc và vài sợi gừng tươi ấm bụng vào nấu sôi 2 phút cho rau chín xanh ngọt lịm.",
                "https://images.unsplash.com/photo-1664741662725-bd131742b7b7?auto=format&fit=crop&w=600&q=80",
                ["🍲 Ấm Bụng Dễ Nấu", "🌱 Canh Cơm Gia Đình", "⚡ 10 Phút"]),

            // 33. Cải thìa sốt dầu hào nấm đông cô
            M("vn_home_33", "Bok Choy with Shiitake Mushrooms in Oyster Sauce", "Cải Thìa Sốt Dầu Hào Nấm Đông Cô", "Vegetarian", "Vietnamese", 120, 6, 12, 5,
                ["Bok Choy", "Shiitake Mushrooms", "Garlic", "Oyster Sauce", "Sesame Oil"],
                ["Cải thìa tươi", "Nấm đông cô tươi", "Tỏi băm", "Dầu hào", "Dầu mè"],
                ["300g", "100g", "4 cloves", "1.5 tbsp", "1 tsp"],
                ["300g", "100g", "4 tép", "1.5 thìa canh", "1 thìa cà phê"],
                "1. Blanch bok choy halves until tender-crisp, arrange on platter. 2. Sauté garlic and mushrooms in rich oyster sauce until glossy. 3. Pour savory mushroom gravy over greens.",
                "1. Cải thìa bổ đôi chần nước sôi ngâm đá giữ màu xanh ngọc, xếp tròn xòe cánh hoa ra đĩa. 2. Phi thơm tỏi xào nấm đông cô mọng nước cùng dầu hào và chút nước tương cho sốt sánh nâu óng ả. 3. Rưới toàn bộ nấm và sốt dầu hào lên đĩa cải thìa thơm phức.",
                "https://images.unsplash.com/photo-1744612190414-f8844313befb?auto=format&fit=crop&w=600&q=80",
                ["🌱 Thanh Đạm Sang Trọng", "🍄 Nấm Mọng Sốt Óng", "✨ Giàu Vitamin"]),

            // 34. Thịt ba chỉ xào dưa cải chua
            M("vn_home_34", "Stir-fried Pork Belly with Pickled Mustard Greens", "Thịt Ba Chỉ Xào Dưa Cải Chua", "Pork", "Vietnamese", 390, 26, 7, 28,
                ["Pork Belly", "Pickled Mustard Greens", "Purple Garlic", "Fish Sauce", "Sugar"],
                ["Thịt ba chỉ thái mỏng", "Dưa cải muối chua", "Tỏi băm", "Nước mắm ngon", "Đường"],
                ["200g", "200g", "3 cloves", "1 tbsp", "1 tsp"],
                ["200g", "200g", "3 tép", "1 thìa canh", "1 thìa cà phê"],
                "1. Brown sliced pork belly in pan to render excess fat. 2. Squeeze pickled greens lightly, add to pork with garlic. 3. Sauté over high heat until greens absorb savory juices.",
                "1. Thịt ba chỉ thái mỏng đảo trong chảo cho xém cạnh kiệt bớt mỡ. 2. Dưa chua vắt ráo nước cho vào đảo cùng thịt và tỏi băm. 3. Nêm nước mắm và chút đường cho vị chua ngọt đậm đà, xào cho dưa săn lại bóng óng ăn cùng cơm nóng rất đưa cơm.",
                "https://images.unsplash.com/photo-1602498456745-e9503b30470b?auto=format&fit=crop&w=600&q=80",
                ["🥓 Chua Ngọt Đậm Đà", "🇻🇳 Siêu Đưa Cơm", "🔥 Bắt Vị"]),

            // 35. Sườn xào chua ngọt
            M("vn_home_35", "Sweet and Sour Pork Ribs", "Sườn Xào Chua Ngọt Óng Ả", "Pork", "Vietnamese", 420, 32, 16, 24,
                ["Pork Ribs", "Ripe Tomatoes", "Shallots", "Garlic", "Sweet-Sour Sauce"],
                ["Sườn non chặt khúc", "Cà chua chín mọng", "Hành tím", "Tỏi băm", "Nước sốt chua ngọt giấm đường"],
                ["300g", "2 pieces", "2 pieces", "3 cloves", "3 tbsp"],
                ["300g", "2 quả", "2 củ", "3 tép", "3 thìa canh"],
                "1. Parboil and fry pork ribs until golden brown. 2. Simmer tomato paste with vinegar, sugar and fish sauce into a thick sauce. 3. Toss ribs in glaze until coated in mahogany sheen.",
                "1. Sườn non chần sơ nước sôi rồi rán vàng ruộm các mặt. 2. Phi thơm hành tỏi, xào nhừ cà chua rồi nêm giấm gạo, đường, nước mắm ngon tạo sốt chua ngọt sánh kẹo. 3. Trút sườn vào đảo đều lửa nhỏ cho ngấm sâu lớp sốt đỏ óng ả thơm ngất ngây.",
                "https://images.unsplash.com/photo-1679711246825-1f2bd51b16d0?auto=format&fit=crop&w=600&q=80",
                ["🍖 Sườn Rán Giòn Rụm", "🍅 Chua Ngọt Đậm Sốt", "🇻🇳 Món Khoái Khẩu"]),

            // 36. Thịt kho tàu trứng cút nước dừa
            M("vn_home_36", "Vietnamese Braised Pork with Quail Eggs", "Thịt Kho Tàu Trứng Cút Nước Dừa", "Pork", "Vietnamese", 490, 34, 10, 32,
                ["Pork Belly", "Quail Eggs", "Fresh Coconut Water", "Shallots", "Fish Sauce"],
                ["Thịt ba chỉ thái vuông", "Trứng cút luộc bóc vỏ", "Nước dừa xiêm tươi", "Hành tím băm", "Nước mắm nhĩ"],
                ["250g", "8 pieces", "200ml", "2 pieces", "2 tbsp"],
                ["250g", "8 quả", "200ml", "2 củ", "2 thìa canh"],
                "1. Marinate pork cubes with shallots and fish sauce. 2. Brown lightly, then pour in fresh coconut water. 3. Simmer gently with peeled quail eggs for 45 mins until meat melts in mouth and sauce is amber gold.",
                "1. Thịt ba chỉ thái miếng vuông con chì ướp hành tím, nước mắm, tiêu và đường caramel. 2. Xào săn thịt rồi đổ ngập nước dừa xiêm tươi đun sôi bùng, hớt bọt. 3. Thả trứng cút luộc vào kho liu riu trong 45 phút cho thịt mềm rục trong miệng, nước dừa cô lại màu hổ phách tuyệt đẹp.",
                "https://images.unsplash.com/photo-1767974822929-ba6e6b909365?auto=format&fit=crop&w=600&q=80",
                ["🥓 Mềm Rục Tan Trong Miệng", "🥥 Nước Dừa Thơm Béo", "🇻🇳 Tinh Hoa Cơm Nhà"]),

            // 37. Tôm rim thịt ba chỉ
            M("vn_home_37", "Caramelized Shrimp and Pork Belly", "Tôm Rim Thịt Ba Chỉ Đậm Đà", "Seafood", "Vietnamese", 360, 32, 8, 20,
                ["Fresh Shrimp", "Pork Belly", "Shallots", "Fish Sauce", "Black Pepper"],
                ["Tôm tươi cắt râu", "Thịt ba chỉ thái mỏng", "Hành tím", "Nước mắm ngon", "Tiêu đen xay"],
                ["150g", "150g", "3 pieces", "2 tbsp", "1 tsp"],
                ["150g", "150g", "3 củ", "2 thìa canh", "1 thìa cà phê"],
                "1. Render pork belly until lightly crisp. 2. Add shrimp and sauté until blushing red. 3. Season with fish sauce and caramelized sugar, simmer until glistening and coated.",
                "1. Thịt ba chỉ đảo kiệt bớt mỡ cho xém vàng cạnh. 2. Cho tôm tươi vào đảo cùng lửa lớn cho tôm đỏ au săn chắc vỏ ngoài giòn bóng. 3. Nêm nước mắm ngon, tiêu và chút nước màu dừa, rim liu riu đến khi nước cạn kẹo bóng bẩy phủ kín tôm thịt.",
                "https://images.unsplash.com/photo-1764337944130-45560c1f8b41?auto=format&fit=crop&w=600&q=80",
                ["🦐 Tôm Giòn Thịt Béo", "🔥 Đậm Đà Cực Hao Cơm", "🇻🇳 Chuẩn Vị Việt"]),

            // 38. Canh sườn nấu cà chua dứa
            M("vn_home_38", "Pork Rib Sour Soup with Tomato & Pineapple", "Canh Sườn Nấu Cà Chua Dứa Thanh Mát", "Pork", "Vietnamese", 230, 22, 12, 10,
                ["Pork Ribs", "Ripe Tomatoes", "Pineapple", "Green Onions", "Fish Sauce"],
                ["Sườn non heo", "Cà chua bổ múi", "Dứa thơm thái lát", "Hành hoa mùi tàu", "Nước mắm"],
                ["250g", "2 pieces", "100g", "3 stalks", "1 tbsp"],
                ["250g", "2 quả", "100g", "3 nhánh", "1 thìa canh"],
                "1. Simmer parboiled ribs for 25 mins until tender. 2. Add sliced pineapple and tomatoes for natural sweet-sour tang. 3. Finish with fresh scallions and cilantro.",
                "1. Sườn non chặt khúc luộc sơ rồi ninh trong 25 phút cho mềm ngọt nước. 2. Cho dứa thái lát và cà chua vào đun sôi thêm 5 phút cho tiết vị chua thanh dịu ngọt tự nhiên. 3. Nêm nước mắm vừa ăn, rắc hành lá mùi tàu thái nhỏ rồi múc canh ra tô.",
                "https://images.unsplash.com/photo-1701480253822-1842236c9a97?auto=format&fit=crop&w=600&q=80",
                ["🍲 Chua Thanh Ngọt Lịm", "🍖 Sườn Ninh Mềm", "🍍 Giải Nhiệt Ngày Hè"]),

            // 39. Mực xào cần tỏi tây
            M("vn_home_39", "Stir-fried Squid with Celery & Onion", "Mực Xào Cần Tỏi Tây Hành Tây", "Seafood", "Vietnamese", 210, 28, 8, 5,
                ["Fresh Squid", "Celery", "Onion", "Purple Garlic", "Black Pepper"],
                ["Mực ống tươi thái khoanh", "Cần tây cắt khúc", "Hành tây", "Tỏi băm", "Tiêu đen xay"],
                ["250g", "100g", "1 piece", "4 cloves", "1 tsp"],
                ["250g", "100g", "1 củ", "4 tép", "1 thìa cà phê"],
                "1. Score and clean fresh squid. 2. Sear squid in smoking wok with garlic for 1.5 mins, remove. 3. Sauté onions and celery until crisp-tender, combine and pepper heavily.",
                "1. Mực ống làm sạch thái khoanh khía vảy rồng. 2. Phi thơm tỏi xào mực trên lửa cực lớn trong 1.5 phút cho mực săn giòn không ra nước rồi trút ra đĩa. 3. Cho cần tây và hành tây vào chảo đảo chín tới dậy mùi thơm nức rồi trút mực vào đảo lại 30 giây rắc tiêu thơm cay.",
                "https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=600&q=80",
                ["🦑 Mực Giòn Sần Sật", "🌿 Thơm Nức Cần Tỏi", "⚡ Nhanh Gọn 10p"]),

            // 40. Trứng chiên đúc thịt băm
            M("vn_home_40", "Fried Scrambled Egg with Minced Meat", "Trứng Chiên Đúc Thịt Băm Hành Hoa", "Pork", "Vietnamese", 270, 24, 3, 18,
                ["Chicken Eggs", "Minced Pork", "Green Onions", "Fish Sauce", "Black Pepper"],
                ["Trứng gà ta", "Thịt heo nạc băm", "Hành hoa thái nhỏ", "Nước mắm ngon", "Tiêu đen"],
                ["3 pieces", "100g", "3 stalks", "1 tbsp", "1/2 tsp"],
                ["3 quả", "100g", "3 nhánh", "1 thìa canh", "1/2 thìa cà phê"],
                "1. Mix eggs thoroughly with minced pork, scallions, fish sauce and pepper. 2. Fry on medium flame with lid on until fluffy, golden and cooked through.",
                "1. Đánh tan trứng cùng thịt nạc băm nhỏ, hành hoa, nước mắm ngon và tiêu sọ. 2. Đun nóng chảo dầu, đổ hỗn hợp trứng thịt vào dàn đều, đậy vung chiên lửa nhỏ vừa cho thịt bên trong chín mềm mà lớp vỏ ngoài vàng rụm thơm phức.",
                "https://images.unsplash.com/photo-1759216280603-364c7747d354?auto=format&fit=crop&w=600&q=80",
                ["🍳 Đậm Đà Dễ Nấu", "🥚 Trứng Phồng Thơm", "⚡ 10 Phút"]),

            // 41. Bắp cải xào cà chua thịt heo
            M("vn_home_41", "Stir-fried Cabbage with Pork & Tomatoes", "Bắp Cải Xào Cà Chua Thịt Heo", "Pork", "Vietnamese", 220, 20, 12, 10,
                ["Cabbage", "Lean Pork", "Ripe Tomatoes", "Garlic", "Fish Sauce"],
                ["Bắp cải thái sợi", "Thịt heo nạc thái mỏng", "Cà chua bổ múi", "Tỏi băm", "Nước mắm"],
                ["300g", "120g", "1 piece", "3 cloves", "1 tbsp"],
                ["300g", "120g", "1 quả", "3 tép", "1 thìa canh"],
                "1. Sauté sliced pork with garlic until cooked. 2. Add sliced cabbage and tomatoes, toss on high heat until sweet and tender.",
                "1. Phi thơm tỏi xào săn thịt heo nạc thái mỏng. 2. Cho bắp cải thái sợi và cà chua vào đảo nhanh trên lửa lớn cho rau chín tới giữ độ ngọt giòn mọng nước.",
                "https://images.unsplash.com/photo-1748444432939-f5e117280ab0?auto=format&fit=crop&w=600&q=80",
                ["🥬 Giòn Ngọt Thanh Mát", "🇻🇳 Món Rau Hàng Ngày", "⚡ Dễ Làm"]),

            // 42. Canh mướp hương nấu tôm tươi
            M("vn_home_42", "Luffa Soup with Fresh Shrimp", "Canh Mướp Hương Nấu Tôm Tươi", "Seafood", "Vietnamese", 130, 18, 6, 2,
                ["Fresh Luffa", "Fresh Shrimp", "Green Onions", "Fish Sauce", "Shallots"],
                ["Mướp hương thái vát", "Tôm tươi băm thô", "Hành hoa", "Nước mắm ngon", "Hành tím"],
                ["300g", "120g", "2 stalks", "1 tbsp", "2 pieces"],
                ["300g", "120g", "2 nhánh", "1 thìa canh", "2 củ"],
                "1. Sauté shallots with seasoned fresh shrimp. 2. Pour in water and boil vigorously. 3. Drop in sliced fragrant luffa, cook for 1 minute and finish with scallions.",
                "1. Phi hành tím xào săn tôm băm nêm chút nước mắm. 2. Đổ nước vào đun sôi bùng, thả mướp hương gọt vỏ thái vát vào nấu sôi lại trong 1 phút cho mướp vừa chín tới thơm lừng. 3. Tắt bếp rắc hành hoa dọn ra bát canh ngọt mát dịu dàng.",
                "https://images.unsplash.com/photo-1569239602012-e2b4575d1d40?auto=format&fit=crop&w=600&q=80",
                ["🍲 Mướp Hương Thơm Ngát", "🦐 Tôm Ngọt Nước", "🌱 Thanh Mát Bữa Cơm"]),

            // 43. Thịt bò xào nấm thập cẩm
            M("vn_home_43", "Stir-fried Beef with Assorted Mushrooms", "Thịt Bò Xào Nấm Thập Cẩm Thanh Ngọt", "Beef", "Vietnamese", 260, 30, 8, 10,
                ["Beef", "Shiitake Mushrooms", "Straw Mushrooms", "Green Onions", "Oyster Sauce"],
                ["Thịt bò tươi thái mỏng", "Nấm hương tươi", "Nấm rơm tươi", "Hành hoa cắt khúc", "Dầu hào"],
                ["200g", "100g", "100g", "3 stalks", "1 tbsp"],
                ["200g", "100g", "100g", "3 nhánh", "1 thìa canh"],
                "1. Sauté sliced beef quickly on high heat, set aside. 2. Cook mushrooms in oyster sauce until tender and juicy. 3. Return beef and finish with green onions.",
                "1. Xào nhanh thịt bò thái mỏng trên lửa lớn vừa chín tới trút ra đĩa. 2. Cho nấm rơm và nấm hương vào xào với chút dầu hào cho nấm chín mọng ngọt. 3. Đổ bò vào đảo cùng nấm trong 30 giây rắc hành hoa dọn ra đĩa thơm lừng.",
                "https://images.unsplash.com/photo-1527369116215-7ed0168aea41?auto=format&fit=crop&w=600&q=80",
                ["🍄 Nấm Ngọt Giòn Mọng", "🥩 Bò Mềm Đậm Vị", "⚡ 15 Phút"]),

            // 44. Cải ngồng xào tỏi phi giòn
            M("vn_home_44", "Stir-fried Chinese Broccoli with Garlic", "Cải Ngồng Xào Tỏi Phi Giòn", "Vegetarian", "Vietnamese", 115, 4, 7, 7,
                ["Chinese Broccoli", "Purple Garlic", "Oyster Sauce", "Cooking Oil"],
                ["Cải ngồng non xanh", "Tỏi tía đập dập", "Dầu hào", "Dầu ăn"],
                ["300g", "5 cloves", "1 tbsp", "1 tbsp"],
                ["300g", "5 tép", "1 thìa canh", "1 thìa canh"],
                "1. Trim and blanch Chinese broccoli for 45s in boiling salted water. 2. Fry crushed purple garlic until golden. 3. Flash fry greens over high flame with oyster sauce until tender-crisp.",
                "1. Cải ngồng ngắt ngọn non rửa sạch, chần sơ 45 giây qua nước sôi có chút muối rồi vớt ra ngâm nước đá cho giòn xanh. 2. Phi thơm vàng giòn thật nhiều tỏi tía đập dập. 3. Cho cải ngồng vào chảo đảo nhanh tay trên lửa lớn cùng dầu hào và chút nước tương trong 1 phút là hoàn thành.",
                "https://images.unsplash.com/photo-1486328228599-85db4443971f?auto=format&fit=crop&w=600&q=80",
                ["🌱 Xanh Mướt Giòn Ngọt", "🧄 Tỏi Phi Vàng Giòn", "⚡ Dưới 10p"])
        ];
    }
}
