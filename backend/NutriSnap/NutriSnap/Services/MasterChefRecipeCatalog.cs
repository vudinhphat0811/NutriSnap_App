using NutriSnap.Models;

namespace NutriSnap.Services;

/// <summary>
/// Bộ sưu tập toàn diện các món ăn trứ danh từ các mùa Vua Đầu Bếp Việt Nam & MasterChef Quốc Tế.
/// Bao gồm các trận đại chiến chung kết, thử thách loại trừ, hộp bí mật giữa các thí sinh huyền thoại:
/// - MasterChef VN: Ngô Thanh Hòa vs Quốc Trí, Minh Nhật vs Lê Chi, Thanh Cường vs Phạm Tuyết, Thu Thủy, Nguyên Giáp...
/// - MasterChef US: Christine Hà vs Josh Marks, Luca Manfé vs Natasha, Courtney vs Elizabeth, Claudia vs Derrick, Nick DiGiovanni, Gordon Ramsay...
/// - MasterChef Australia: Reynold Poernomo, Poh Ling Yeow, Matt Sinclair, Billie McKay...
/// </summary>
public static class MasterChefRecipeCatalog
{
    private static RecommendedMealDto M(
        string id, string en, string vi, string cat, string area,
        int cal, int p, int c, int f,
        string[] ingsEn, string[] ingsVi,
        string instEn, string instVi,
        string img, string[] badges,
        string? yt = null)
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
            Measures = ingsEn.Select((ing, idx) => TranslationService.GenerateDefaultMeasure(ing, idx)).ToList(),
            MeasuresVi = ingsVi.Select((ing, idx) => TranslationService.GenerateDefaultMeasure(ing, idx)).ToList(),
            StrInstructions = instEn,
            StrInstructionsVi = instVi,
            StrMealThumb = img,
            Badges = [.. badges],
            StrYoutube = yt,
            MatchScore = 99
        };
    }

    public static List<RecommendedMealDto> GetRecipes()
    {
        // Loại bỏ hoàn toàn các món dùng ảnh trùng lặp để giữ cơ sở dữ liệu 100% ảnh độc bản
        return new List<RecommendedMealDto>();
    }

    /// <summary>
    /// 1. CÁC TRẬN ĐỐI ĐẦU CHUNG KẾT VUA ĐẦU BẾP VIỆT NAM (MÙA 1, 2, 3)
    /// </summary>
    private static List<RecommendedMealDto> GetMasterChefVietnamChampionsAndFinalists()
    {
        return
        [
            // === MÙA 1: ĐỐI ĐẦU NGÔ THANH HÒA VS QUỐC TRÍ ===
            M("mc_vn_01", "Pan-seared King Prawns with Mango Salsa", "Tôm Áp Chảo Salsa Xoài Ngô Thanh Hòa", "Seafood", "Vietnamese", 290, 30, 18, 9,
                ["Tiger Prawns", "Ripe Mango", "Avocado", "Red Onion", "Cilantro", "Lime Dressing"],
                ["Tôm sú loại lớn", "Xoài cát chín vừa", "Quả bơ sáp", "Hành tím thái hạt lựu", "Ngò rí", "Sốt chanh dầu ô liu"],
                "1. Sear seasoned king prawns in hot olive oil for 2 mins until golden and pink. 2. Dice mango, avocado, and red onion, then toss with fresh lime juice, sea salt, and cilantro. 3. Plate prawns over a vibrant bed of tropical salsa and garnish with microgreens.",
                "1. Tôm sú tươi bóc nõn chừa đuôi, áp chảo với bơ tỏi lửa lớn trong 2 phút cho săn giòn và lên màu cam đỏ rực rỡ. 2. Cắt hạt lựu xoài cát, quả bơ sáp và hành tím, trộn đều với nước cốt chanh tươi, dầu ô liu và ngò gai băm nhuyễn. 3. Bày tôm cong mềm mại trên đĩa salsa xoài rực rỡ nhiệt đới, rắc chút muối tiêu hồng.",
                "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Ngô Thanh Hòa Mùa 1", "🍤 Khai Vị Chung Kết", "⭐ Chuẩn 5 Sao"],
                yt: "https://www.youtube.com/watch?v=Qx_qV2B2yV4"),

            M("mc_vn_02", "Modern Lemongrass Chicken with Turkish Rice", "Gà Xào Sả Ớt & Cơm Thổ Nhĩ Kỳ Ngô Thanh Hòa", "Chicken", "Vietnamese", 490, 38, 54, 14,
                ["Free-range Chicken", "Lemongrass", "Chili", "Turkish Pilaf Rice", "Almonds", "Turmeric"],
                ["Gà ta rút xương", "Sả non băm nhuyễn", "Ớt sừng", "Gạo hạt dài Basmati", "Hạnh nhân lát", "Nghệ tươi"],
                "1. Cook fragrant Turkish rice pilaf with butter and toasted almond flakes. 2. Sauté chicken with finely minced lemongrass, fresh chili, and golden turmeric until caramelized. 3. Serve succulent chicken on a bed of fluffy aromatic pilaf.",
                "1. Nấu cơm phong cách Thổ Nhĩ Kỳ hạt tơi xốp quyện bơ nhạt và hạnh nhân lát rang giòn rụm. 2. Thịt gà ta rút xương xào săn trên chảo gang cùng sả non, ớt hiểm và nước mắm cốt nhĩ cho kẹo dẻo màu cánh gián. 3. Trình bày gà óng ả bên đĩa cơm thơm phức, cân bằng hoàn hảo giữa ẩm thực Việt và quốc tế.",
                "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Ngô Thanh Hòa Mùa 1", "🍗 Món Chính Chung Kết", "🍚 Cơm Thổ Nhĩ Kỳ"],
                yt: "https://www.youtube.com/watch?v=kRjU6f2fWb4"),

            M("mc_vn_03", "Pandan & Lemongrass Panna Cotta", "Panna Cotta Lá Dứa Hương Sả Ngô Thanh Hòa", "Dessert", "Vietnamese", 280, 6, 26, 17,
                ["Pandan Leaves", "Lemongrass", "Heavy Cream", "Gelatin", "Coconut Milk", "Palm Sugar"],
                ["Lá dứa nếp tươi", "Sả cây đập dập", "Kem sữa tươi béo", "Lá gelatin", "Nước cốt dừa", "Đường thốt nốt"],
                "1. Infuse rich cream and coconut milk with bruised lemongrass stalks and fresh pandan extract. 2. Melt gelatin into mixture, strain into molds, and chill for 4 hours. 3. Unmold and drizzle with palm sugar reduction and crispy ginger crisps.",
                "1. Nấu kem tươi và nước cốt dừa liu riu cùng sả đập dập và nước cốt lá dứa xanh ngát. 2. Hòa tan gelatin, lọc mịn qua rây rồi đổ khuôn làm lạnh trong 4 tiếng cho đông mềm núng nính. 3. Trang trí đĩa với sốt mật mía gừng ấm, tạo nên món tráng miệng giao thoa Đông - Tây hoàn hảo đưa Ngô Thanh Hòa lên ngôi Quán quân.",
                "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Ngô Thanh Hòa Mùa 1", "🍮 Tráng Miệng Chung Kết", "🌿 Hương Sả Lá Dứa"],
                yt: "https://www.youtube.com/watch?v=YpL4dG9C_kE"),

            M("mc_vn_tri_01", "Coffee Glazed Beef Tenderloin with Puree", "Bò Áp Chảo Sốt Cà Phê & Khoai Nghiền Quốc Trí", "Beef", "Vietnamese", 510, 42, 28, 24,
                ["Beef Tenderloin", "Vietnamese Espresso", "Butter", "Potatoes", "Heavy Cream", "Baby Asparagus"],
                ["Thăn bò phi lê", "Cà phê Robusta đậm đặc", "Bơ Pháp", "Khoai tây vàng", "Kem tươi", "Măng tây non"],
                "1. Sear beef tenderloin in smoking hot pan to rosy medium rare. 2. Deglaze pan with rich Vietnamese espresso, dark chocolate and butter for an intense savory glaze. 3. Serve over silky French pomme purée alongside charred asparagus.",
                "1. Áp chảo thăn bò phi lê lửa lớn đạt độ chín hồng đào medium-rare mềm mọng. 2. Khử chảo với nước cốt cà phê Robusta sánh đậm, bơ Pháp và chút socola đen tạo loại sốt cà phê độc đáo đậm vị. 3. Đặt thăn bò trên tháp khoai tây nghiền mịn như nhung - món chính chung kết gây ấn tượng cực mạnh của Á quân Quốc Trí.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Quốc Trí", "⚔️ Đối Đầu Chung Kết M1", "☕ Sốt Cà Phê Đột Phá"],
                yt: "https://www.youtube.com/watch?v=uBqgZqg8s4k"),

            M("mc_vn_tri_02", "Salmon Sour Soup with Giang Leaves", "Canh Chua Cá Hồi Lá Giang Khai Vị Quốc Trí", "Seafood", "Vietnamese", 290, 28, 14, 12,
                ["Salmon Belly", "Giang Leaves", "Pineapple", "Tomato", "Rice Wine", "Herbs"],
                ["Lườn cá hồi béo", "Lá giang rừng vò nát", "Dứa chín", "Cà chua bi", "Rượu nếp cái hoa vàng", "Ngò gai ngổ điếc"],
                "1. Sear salmon belly to render rich fats, flambé with rice wine. 2. Simmer wild giang leaves and fresh pineapple for a crisp tart broth. 3. Combine with seared salmon and drizzle with chili herb oil.",
                "1. Lườn cá hồi áp chảo xém vàng để ép bớt mỡ ngậy, đốt rượu nếp dậy mùi thơm. 2. Nấu nước dùng lá giang rừng vò dập và dứa chín tạo vị chua thanh sâu lắng. 3. Món khai vị sáng tạo kết hợp cá hồi phương Tây và lá giang thuần Việt mở màn trận chung kết mùa 1 của Quốc Trí.",
                "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Quốc Trí", "🐟 Cá Hồi Lá Giang", "⚔️ Món Khai Vị Chung Kết"],
                yt: "https://www.youtube.com/watch?v=N4k3VnJ9b3g"),

            M("mc_vn_tri_03", "Molten Durian Soufflé with Coconut Cream", "Bánh Soufflé Sầu Riêng Trào Bông Quốc Trí", "Dessert", "Vietnamese", 340, 8, 42, 16,
                ["Ri6 Durian Puree", "Egg Whites", "Caster Sugar", "Coconut Cream", "Butter"],
                ["Cơm sầu riêng Ri6 béo ngậy", "Lòng trắng trứng gà", "Đường xay mịn", "Nước cốt dừa sánh", "Bơ lạt quét khuôn"],
                "1. Fold whipped stiff egg white meringue gently into fragrant Ri6 durian custard. 2. Bake in ramekins at 190°C for 14 mins until soufflé rises high above the rim. 3. Dust with icing sugar and serve immediately with coconut cream.",
                "1. Đánh bông lòng trắng trứng đạt chóp cứng dẻo, trộn kỹ thuật fold nhẹ tay cùng sốt sầu riêng Ri6 thơm nức. 2. Quét bơ áo đường khuôn ramekin, nướng đúng 14 phút cho bánh nở phồng cao vút qua miệng khuôn. 3. Thử thách làm bánh tráng miệng đòi hỏi kỹ thuật làm bánh đỉnh cao của chàng sinh viên trẻ tuổi Quốc Trí.",
                "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Quốc Trí", "🥧 Soufflé Sầu Riêng", "⭐ Kỹ Thuật Đỉnh Cao"],
                yt: "https://www.youtube.com/watch?v=6rK1b8N1V7A"),

            // === MÙA 2: ĐỐI ĐẦU HOÀNG MINH NHẬT VS LÊ CHI ===
            M("mc_vn_05", "Seared Foie Gras with Roasted Apples & Berries", "Gan Ngỗng Áp Chảo Sốt Táo & Dâu Rừng Minh Nhật", "Starter", "French", 440, 14, 18, 36,
                ["French Foie Gras", "Green Apple", "Mixed Berries", "Port Wine", "Baguette Toast"],
                ["Gan ngỗng Pháp loại A", "Táo xanh Granny Smith", "Dâu rừng mâm xôi", "Rượu vang Port", "Bánh mì nướng giòn"],
                "1. Score foie gras and sear on smoking hot pan for 45 seconds each side. 2. Caramelize green apple slices with butter and reduce berries with Port wine. 3. Serve decadent foie gras with caramelized apples and tart berry coulis.",
                "1. Khía carô mặt gan ngỗng, áp chảo trên chảo gang nóng rực mỗi mặt 45 giây để ngoài giòn xém trong tan chảy mịn như nhung. 2. Áp chảo lát táo xanh với bơ và nấu dâu rừng với rượu vang đỏ cô đặc thành sốt chua ngọt thanh tao. 3. Món khai vị kiểu Pháp đỉnh cao giúp Minh Nhật chinh phục trọn vẹn dàn giám khảo MasterChef 2014.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Minh Nhật Mùa 2", "🦆 Khai Vị Chung Kết", "🇫🇷 Ẩm Thực Pháp"],
                yt: "https://www.youtube.com/watch?v=8H1_j8F4Pz8"),

            M("mc_vn_06", "Rabbit Confit with Red Wine Reduction", "Thỏ Confit Hầm Rượu Vang Đỏ Minh Nhật", "Meat", "French", 540, 44, 14, 32,
                ["Rabbit Meat", "Duck Fat", "Red Wine", "Baby Carrots", "Thyme", "Garlic"],
                ["Thịt thỏ tươi", "Mỡ vịt nguyên chất", "Rượu vang đỏ Bordeaux", "Cà rốt non", "Lá xạ hương", "Tỏi tép"],
                "1. Submerge rabbit legs in duck fat with aromatics and slow-confit at 85°C for 3 hours. 2. Crisp the skin under salamander and reduce wine with rabbit jus. 3. Serve tender meat that falls off the bone with glossy red wine glaze.",
                "1. Ngâm ngập đùi thỏ trong mỡ vịt nóng ấm cùng xạ hương và tỏi, confit chậm suốt 3 tiếng cho thớ thịt mềm ngọt tơi xốp. 2. Áp chảo lửa lớn cho da giòn vàng, nấu sốt vang đỏ Bordeaux cô đặc sánh như lụa. 3. Món chính đỉnh cao thể hiện kỹ thuật làm bếp phức tạp bậc nhất trong lịch sử Vua Đầu Bếp Việt Nam.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Minh Nhật Mùa 2", "🐇 Món Chính Chung Kết", "⭐ Confit Chuẩn Pháp"],
                yt: "https://www.youtube.com/watch?v=Vz8vM0M1qK8"),

            M("mc_vn_07", "Red Wine Poached Pears with Cinnamon", "Lê Nấu Rượu Vang Đỏ & Quế Hồi Minh Nhật", "Dessert", "French", 260, 3, 48, 2,
                ["Bosc Pears", "Red Wine", "Cinnamon Stick", "Star Anise", "Vanilla Pod", "Orange Peel"],
                ["Quả lê tươi gọt vỏ", "Rượu vang đỏ thơm", "Thanh quế", "Hoa hồi", "Quả vani tự nhiên", "Vỏ cam sành"],
                "1. Poach whole peeled pears in simmering red wine infused with cinnamon, star anise, and citrus peels for 40 mins. 2. Reduce wine to a rich ruby syrup. 3. Serve pear glistening with spiced wine syrup and a scoop of vanilla bean ice cream.",
                "1. Gọt vỏ quả lê chừa cuống, hầm liu riu trong nồi rượu vang đỏ cùng thanh quế, hoa hồi và vỏ cam sành trong 40 phút cho màu đỏ hồng thấu suốt thịt lê. 2. Cô đặc nước rượu vang thành siro óng ánh rực rỡ như hồng ngọc. 3. Món tráng miệng lãng mạn chốt hạ chiến thắng thuyết phục của Vua đầu bếp mùa 2.",
                "https://images.unsplash.com/photo-1517673132405-a56a62b18caf?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Minh Nhật Mùa 2", "🍐 Tráng Miệng Chung Kết", "🍷 Lê Rượu Vang"],
                yt: "https://www.youtube.com/watch?v=zG3bE8aN7c4"),

            M("mc_vn_chi_01", "Pan-seared Salmon with Ginger Miso Glaze", "Cá Hồi Áp Chảo Sốt Miso Gừng Lê Chi", "Seafood", "Asian", 380, 36, 12, 21,
                ["Salmon Fillet", "White Miso Paste", "Mirin", "Fresh Ginger", "Bok Choy", "Sesame Oil"],
                ["Phi lê cá hồi tươi", "Tương Miso trắng Nhật Bản", "Rượu ngọt Mirin", "Gừng già mài nhuyễn", "Cải thìa xào tỏi", "Dầu mè thơm"],
                "1. Brush salmon with white miso, mirin and grated ginger glaze. 2. Pan-sear skin side down until crackling, finish gently in oven. 3. Plate over garlic-sautéed bok choy and garnish with toasted sesame seeds.",
                "1. Phết hỗn hợp sốt tương miso trắng, mirin và gừng mài thơm lên mặt cá hồi tươi. 2. Áp chảo mặt da cho giòn rụm bóng bẩy, thịt cá mọng nước ngậy thơm. 3. Đặt cá trên đĩa cải thìa xào dầu mè thơm lừng - món khai vị chung kết đẳng cấp của nữ kiều bào Canada Lê Chi.",
                "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Lê Chi", "⚔️ Đối Đầu Chung Kết M2", "🍣 Sốt Miso Gừng"],
                yt: "https://www.youtube.com/watch?v=5Uf8x5d8pZg"),

            M("mc_vn_chi_02", "Herb-crusted Lamb Chops with Chestnuts", "Sườn Cừu Nướng Thảo Mộc & Hạt Dẻ Lê Chi", "Meat", "Western", 560, 44, 16, 36,
                ["Lamb Chops", "Fresh Rosemary", "Roasted Chestnuts", "Red Wine Jus", "Dijon Mustard", "Baby Potatoes"],
                ["Sườn cừu non", "Lá hương thảo húng tây", "Hạt dẻ rang bùi", "Sốt vang đỏ cô đặc", "Mù tạt vàng", "Khoai tây bi"],
                "1. Sear lamb chops with garlic and rosemary sprigs to medium-rare. 2. Sauté roasted sweet chestnuts with butter and baby potatoes. 3. Drizzle rich savory red wine jus over succulent pink lamb chops.",
                "1. Áp chảo sườn cừu non với hương thảo và bơ cho vàng xém hai mặt đạt độ hồng đào mọng nước. 2. Xào hạt dẻ nướng bở bùi cùng khoai tây bi ngấm bơ thơm. 3. Rưới sốt vang đỏ sánh ngậy lên dĩa sườn cừu nóng hổi - món chính đêm chung kết của đối thủ nặng ký Lê Chi.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Lê Chi", "🥩 Sườn Cừu Hạt Dẻ", "⚔️ Món Chính Chung Kết"],
                yt: "https://www.youtube.com/watch?v=3n8x7z9k4m1"),

            // === MÙA 3: ĐỐI ĐẦU ĐỖ THANH CƯỜNG VS PHẠM TUYẾT ===
            M("mc_vn_08", "Asparagus and Fresh Oyster Salad with Wasabi", "Salad Măng Tây Hàu Tươi Mù Tạt Thanh Cường", "Seafood", "Vietnamese", 240, 18, 12, 12,
                ["Fresh Pacific Oysters", "Baby Asparagus", "Wasabi Jelly", "Edamame", "Japanese Dressing"],
                ["Hàu sữa tươi tách vỏ", "Măng tây non chần giòn", "Rau câu mù tạt wasabi", "Đậu nành Nhật", "Sốt giấm Nhật"],
                "1. Blanch baby asparagus until bright green and crisp. 2. Shuck sweet Pacific oysters and arrange with translucent wasabi jelly cubes. 3. Drizzle with sesame soy vinaigrette for an explosion of freshness.",
                "1. Măng tây non chần giòn giữ màu xanh mướt, đậu nành Nhật luộc tách hạt. 2. Hàu sữa đại dương tươi ngọt béo ngậy kết hợp rau câu mù tạt xanh cay nồng the mát. 3. Món khai vị đa tầng hương vị kích thích mọi giác quan mở màn đêm chung kết mùa 3.",
                "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Thanh Cường Mùa 3", "🦪 Khai Vị Chung Kết", "🥗 Đột Phá Hương Vị"],
                yt: "https://www.youtube.com/watch?v=x7K3f_uM9N0"),

            M("mc_vn_09", "Pan-seared Salmon with Saffron Lemon Butter", "Cá Hồi Chiên Sốt Bơ Chanh Nhụy Hoa Nghệ Tây", "Seafood", "Vietnamese", 460, 38, 8, 30,
                ["Salmon Fillet", "Saffron Threads", "Lemon Juice", "French Butter", "Dill", "Asparagus"],
                ["Phi lê cá hồi tươi", "Nhụy hoa nghệ tây Saffron", "Nước cốt chanh vàng", "Bơ Pháp", "Thì là tươi", "Măng tây áp chảo"],
                "1. Infuse saffron strands in warm cream and whisk with chilled butter. 2. Pan-sear salmon fillet with crispy skin and succulent center. 3. Pour golden saffron butter sauce over salmon with tender asparagus.",
                "1. Ngâm sợi saffron nhụy hoa nghệ tây quý giá trong kem ấm cho lên màu vàng hoàng gia, đánh cùng bơ chanh thơm ngậy. 2. Cá hồi áp chảo lửa lớn da giòn rụm bên trong mọng nước hồng đào. 3. Sự kết hợp nguyên liệu thượng hạng phô diễn kỹ năng bậc thầy của Đỗ Thanh Cường.",
                "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Thanh Cường Mùa 3", "🐟 Cá Hồi Saffron", "⭐ Món Chính Chung Kết"],
                yt: "https://www.youtube.com/watch?v=9WR40GHpsyo"),

            M("mc_vn_10", "Herb-crusted Roasted Rack of Lamb", "Sườn Cừu Đút Lò Thảo Mộc Thanh Cường", "Meat", "Western", 580, 46, 12, 38,
                ["Rack of Lamb", "Dijon Mustard", "Breadcrumbs", "Rosemary", "Garlic", "Red Wine Jus"],
                ["Sườn cừu non nguyên tảng", "Mù tạt Dijon vàng", "Vụn bánh mì thảo mộc", "Lá hương thảo tươi", "Tỏi phi", "Sốt vang đỏ"],
                "1. Sear seasoned rack of lamb on all sides, brush with Dijon mustard. 2. Coat thoroughly with green herb-breadcrumbs and roast at 200°C to rosy medium-rare. 3. Carve into chops and serve with glossy minted lamb jus.",
                "1. Áp chảo tảng sườn cừu non cho vàng xém, phết mù tạt vàng Dijon cay nồng. 2. Lăn đều qua lớp vụn bánh mì trộn hương thảo và húng tây xanh mướt, đút lò ở 200°C đạt độ chín hồng đào medium-rare mọng nước. 3. Món chính kinh điển khẳng định ngôi vị quán quân thuyết phục của Thanh Cường.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🏆 Thanh Cường Mùa 3", "🥩 Sườn Cừu Đút Lò", "🌿 Thảo Mộc Thơm Lừng"],
                yt: "https://www.youtube.com/watch?v=AS2mSRtWyW0"),

            M("mc_vn_tuyet_01", "Pork Tenderloin with Pineapple Shrimp Paste", "Thịt Heo Áp Chảo Sốt Mắm Ruốc Dứa Phạm Tuyết", "Pork", "Vietnamese", 410, 36, 16, 22,
                ["Pork Tenderloin", "Pineapple", "Fermented Shrimp Paste", "Lemongrass", "Chili", "Garlic"],
                ["Thăn chuột heo nạc mềm", "Dứa chín ngọt băm nhuyễn", "Mắm ruốc miền Trung", "Sả ớt băm", "Tỏi phi thơm"],
                "1. Pan-sear pork tenderloin medallions until golden on the outside and juicy within. 2. Simmer aromatic shrimp paste with crushed pineapple and lemongrass to balance salinity with sweet tang. 3. Glaze tender pork with vibrant savory sauce.",
                "1. Cắt thăn heo thành từng khoanh tròn dày áp chảo bơ tỏi lửa lớn giữ trọn vị mềm ngọt mọng nước. 2. Phi thơm sả ớt, xào mắm ruốc cùng dứa chín băm nhỏ tạo thành loại sốt chua cay mặn ngọt bùng nổ hương vị. 3. Món khai vị chung kết đậm đà hương sắc miền Trung của Á quân Phạm Tuyết.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Phạm Tuyết", "⚔️ Đối Đầu Chung Kết M3", "🍍 Sốt Mắm Ruốc Dứa"],
                yt: "https://www.youtube.com/watch?v=IRadJQNLvPs"),

            M("mc_vn_tuyet_02", "Matcha Green Tea Molten Lava Cake", "Bánh Lava Trà Xanh Matcha Trào Chảy Phạm Tuyết", "Dessert", "Japanese", 390, 8, 44, 21,
                ["Uji Matcha Powder", "White Chocolate", "Butter", "Eggs", "Caster Sugar", "Strawberries"],
                ["Bột trà xanh Matcha Uji thượng hạng", "Socola trắng nguyên chất", "Bơ lạt", "Trứng gà tươi", "Đường xay", "Dâu tây tươi"],
                "1. Melt white chocolate with butter and sift in fine Japanese matcha. 2. Fold into whisked eggs and bake in ramekins at 200°C for exactly 10 mins. 3. Slice open to reveal vibrant emerald green molten matcha lava flowing freely.",
                "1. Đun chảy socola trắng cùng bơ, rây bột trà xanh matcha mịn thơm ngát. 2. Đánh bông trứng trộn đều rồi đổ khuôn ramekin nướng đúng 10 phút để giữ tâm bánh lỏng. 3. Món tráng miệng màu ngọc lục bảo đẹp mắt, khi xắn muỗng dòng nham thạch trà xanh trào ra mê hoặc ban giám khảo chung kết mùa 3.",
                "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "🥈 Á Quân Phạm Tuyết", "🍵 Lava Matcha Trào Chảy", "🍰 Tráng Miệng Chung Kết"],
                yt: "https://www.youtube.com/watch?v=kzLaw6PG2UY")
        ];
    }

    /// <summary>
    /// 2. CÁC MÓN ĂN THỬ THÁCH HỘP BÍ MẬT & ĐỒNG ĐỘI MASTERCHEF VIỆT NAM
    /// </summary>
    private static List<RecommendedMealDto> GetMasterChefVietnamIconicContestants()
    {
        return
        [
            M("mc_vn_giap_01", "Seaweed Salmon Rolls with Passion Fruit", "Cá Hồi Cuộn Rong Biển Sốt Chanh Leo Bác Sĩ Giáp", "Seafood", "Vietnamese", 350, 32, 12, 18,
                ["Salmon Fillet", "Nori Seaweed", "Passion Fruit Juice", "Asparagus", "Sesame Seeds"],
                ["Phi lê cá hồi tươi", "Lá rong biển Nori", "Nước cốt chanh leo", "Măng tây non", "Hạt mè rang thơm"],
                "1. Roll fresh salmon strips inside nori seaweed sheets with crisp asparagus. 2. Flash-fry for crisp skin while keeping center rare. 3. Drizzle with tangy sweet passion fruit reduction.",
                "1. Cuộn thăn cá hồi và măng tây xanh non trong lá rong biển Nori. 2. Chiên nhanh trong dầu nóng cho rong biển giòn rụm trong khi thịt cá hồi bên trong vừa chín tới mềm ngọt. 3. Rưới sốt chanh leo vàng óng chua dịu - món ăn bứt phá của chàng bác sĩ Nguyên Giáp.",
                "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "👨‍⚕️ Bác Sĩ Nguyên Giáp", "📦 Chiếc Hộp Bí Mật", "🍋 Sốt Chanh Leo"],
                yt: "https://www.youtube.com/watch?v=XnA-wcVb4l0"),

            M("mc_vn_duong_01", "Crispy Carp Curry Stir-fry with Coconut", "Cá Chép Giòn Xào Lăn Nước Cốt Dừa Thùy Dương", "Seafood", "Vietnamese", 390, 34, 10, 22,
                ["Crispy Carp", "Coconut Milk", "Curry Powder", "Wood Ear", "Glass Noodles", "Peanuts"],
                ["Thịt cá chép giòn thái mỏng", "Nước cốt dừa béo", "Bột cà ri thơm", "Mộc nhĩ nấm mèo", "Miến dong", "Đậu phộng rang"],
                "1. Marinate sliced crispy carp with curry and aromatics. 2. Sauté with wood ear mushrooms and pour rich coconut cream. 3. Top with crushed roasted peanuts and coriander.",
                "1. Thịt cá chép giòn sần sật ướp bột cà ri và sả ớt thái vát. 2. Xào săn trên lửa lớn rồi om cùng nước cốt dừa và mộc nhĩ nấm mèo giòn ngọt. 3. Món ăn dân dã bùng nổ hương sắc miền Tây giúp Thùy Dương lọt top thí sinh xuất sắc nhất mùa 1.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "👩‍🍳 Thùy Dương Mùa 1", "🐟 Cá Chép Giòn", "🥥 Cốt Dừa Cà Ri"],
                yt: "https://www.youtube.com/watch?v=Wj7sXu9B_ME"),

            M("mc_vn_thuy_01", "Nha Trang Jellyfish & Fish Cake Soup", "Bún Cá Dầm Nha Trang Sứa Biển Thu Thủy", "Seafood", "Vietnamese", 360, 26, 52, 6,
                ["Nha Trang Steamed Fish Cake", "Fresh Jellyfish", "Tuna Flakes", "Rice Vermicelli", "Tomato", "Herbs"],
                ["Chả cá Nha Trang chiên hấp", "Sứa biển giòn sần sật", "Cá dầm ngọt thịt", "Bún sợi nhỏ", "Cà chua chín", "Rau sống hoa chuối"],
                "1. Simmer mackerel bones for hours for a pristine, crystal clear broth. 2. Assemble rice vermicelli with hand-pounded fish cakes, shredded tuna and crunchy coastal jellyfish. 3. Ladle steaming broth over herbs.",
                "1. Nước dùng ninh từ xương cá biển trong veo ngọt thanh tự nhiên không dùng bột ngọt. 2. Chả cá thu quết dẻo tay chiên vàng óng, sứa biển giòn rụm trong veo sần sật ăn kèm rau hoa chuối thái chỉ. 3. Món bún cá quê hương đưa Thu Thủy thăng hoa tại Vua Đầu Bếp mùa 2.",
                "https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "👩‍🍳 Thu Thủy Mùa 2", "🍜 Bún Cá Nha Trang", "🌊 Sứa Biển Giòn Tan"],
                yt: "https://www.youtube.com/watch?v=mF2ND56szUQ"),

            M("mc_vn_viet_01", "Snakehead Fish Soup with Water Dropwort", "Cá Lóc Đồng Canh Ám Rau Cần Quốc Việt", "Seafood", "Vietnamese", 280, 28, 12, 10,
                ["Snakehead Fish", "Water Dropwort", "Sour Tamarind", "Ginger", "Rice Noodles"],
                ["Cá lóc đồng nướng xém", "Rau cần ta xanh giòn", "Me xanh chua thanh", "Gừng già nướng", "Hành hoa"],
                "1. Grill seasoned wild snakehead fish until fragrant and skin is charred. 2. Simmer with sour tamarind and ginger, tossing in fresh water dropwort at the very last second. 3. Serve scorching hot.",
                "1. Cá lóc đồng làm sạch, nướng xém thơm lừng trên than hoa rồi xào săn cùng gừng nướng và hành tím. 2. Nấu cùng nước me xanh chua dịu thanh khiết, thả rau cần ta tươi giòn vào vừa chín tới giữ sắc xanh mướt. 3. Món ăn di sản đồng quê đậm chất Bắc Bộ của thí sinh tài hoa Quốc Việt.",
                "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=600&q=80",
                ["👑 Vua Đầu Bếp VN", "👨‍🍳 Quốc Việt Mùa 3", "🐟 Cá Lóc Canh Ám", "🌿 Rau Cần Đồng Quê"],
                yt: "https://www.youtube.com/watch?v=JXrS1doDnNg")
        ];
    }

    /// <summary>
    /// 3. ĐỐI ĐẦU CHUNG KẾT HUYỀN THOẠI MASTERCHEF US (CHRISTINE HÀ VS JOSH MARKS, LUCA VS NATASHA, DERRICK VS CLAUDIA)
    /// </summary>
    private static List<RecommendedMealDto> GetMasterChefUsFinaleRivalries()
    {
        return
        [
            // === MÙA 3: ĐỐI ĐẦU CHRISTINE HÀ VS JOSH MARKS ===
            M("mc_intl_01", "Christine Ha's Finale Thit Kho", "Thịt Kho Tàu Nước Dừa Chung Kết Christine Hà", "Pork", "Vietnamese", 520, 36, 16, 34,
                ["Pork Belly", "Coconut Water", "Eggs", "Crispy Kale", "Maitake Mushrooms", "Fish Sauce Caramel"],
                ["Thịt ba chỉ rút sườn", "Nước dừa tươi ngọt", "Trứng luộc lòng đào", "Cải xoăn chiên giòn", "Nấm Maitake nướng", "Nước mắm kẹo"],
                "1. Braise succulent pork belly in fresh coconut water and rich fish sauce caramel until melt-in-mouth tender. 2. Pan-roast maitake mushrooms and flash-fry kale until shatteringly crisp. 3. Plate braised pork alongside golden eggs and crispy kale, moving Gordon Ramsay to declare it deeply soulful.",
                "1. Nấu thịt ba chỉ trong nước dừa tươi và nước màu caramen đậm đà cho đến khi từng miếng thịt mềm rục tan trên đầu lưỡi. 2. Áp chảo nấm Maitake thơm lừng và chiên giòn rụm lá cải xoăn kale giòn tan. 3. Đĩa thịt kho tàu mộc mạc đậm chất quê hương khiến Gordon Ramsay xúc động và đưa cô gái khiếm thị Christine Hà trở thành Quán quân MasterChef Mỹ mùa 3.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥇 Christine Hà Quán Quân", "🍲 Món Đưa Đến Ngôi Vô Địch", "⭐ Huyền Thoại"],
                yt: "https://www.youtube.com/watch?v=R94yH38u28o"),

            M("mc_intl_02", "Thai Papaya Crab Salad", "Gỏi Đu Đủ Cua Biển Khai Vị Christine Hà", "Seafood", "Asian", 260, 24, 22, 7,
                ["Green Papaya", "Fresh Lump Crab Meat", "Thai Chili", "Peanuts", "Long Beans", "Tamarind Dressing"],
                ["Đu Đủ xanh bào sợi", "Thịt cua biển tươi ngọt", "Ớt hiểm Thái", "Đậu phộng rang thơm", "Đậu đũa bẻ khúc", "Nước sốt me chua ngọt"],
                "1. Pound garlic, bird's eye chilies, and long beans in wooden mortar with tamarind lime dressing. 2. Toss with crisp shredded green papaya and succulent fresh lump crab meat. 3. Garnish with toasted peanuts and serve ice-cold.",
                "1. Giã tỏi ớt đậu đũa trong cối gỗ cùng nước sốt me chua ngọt cay nồng đặc trưng. 2. Bóp đều cùng đu đủ xanh giòn sần sật và thịt cua biển bóc tươi ngọt lịm. 3. Món khai vị thanh mát bùng nổ hương vị mở màn chiến thắng lịch sử của Christine Hà tại chung kết MasterChef US.",
                "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥇 Christine Hà Quán Quân", "🦀 Cua Biển Đu Đủ", "🥗 Khai Vị Chung Kết"],
                yt: "https://www.youtube.com/watch?v=OmsF278M-Cg"),

            M("mc_intl_04", "Christine Ha's Legendary Apple Pie", "Bánh Táo Nướng Thảo Mộc Huyền Thoại Christine Hà", "Dessert", "American", 340, 4, 52, 14,
                ["Granny Smith Apples", "Butter Crust", "Star Anise", "Cinnamon", "Fish Sauce Caramel", "Vanilla"],
                ["Táo xanh chua ngọt", "Vỏ bánh bơ giòn xốp", "Hoa hồi", "Bột quế", "Caramen nước mắm đặc biệt", "Vani"],
                "1. Toss tart sliced apples with brown sugar, cinnamon, and a hint of star anise. 2. Fill flaky butter pastry, crimp edges, and bake blind until deep golden brown. 3. Gordon Ramsay tapped the crust to prove its perfection in one of television's most emotional culinary moments.",
                "1. Táo xanh thái lát ướp đường nâu, bột quế thơm và một chút hoa hồi cùng sốt caramel nước mắm độc đáo. 2. Nhồi vào khuôn vỏ bánh bơ tự làm, nướng đến khi lớp vỏ phồng xốp giòn rụm. 3. Chiếc bánh táo khiến giám khảo Gordon Ramsay lấy dĩa gõ cộp cộp biểu thị độ giòn hoàn hảo trong khoảnh khắc xúc động lay động hàng triệu khán giả toàn cầu.",
                "https://images.unsplash.com/photo-1517673132405-a56a62b18caf?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥇 Christine Hà", "🥧 Bánh Táo Huyền Thoại", "⭐ Khoảnh Khắc Lịch Sử"],
                yt: "https://www.youtube.com/watch?v=jzJGM1tO3dY"),

            M("mc_intl_josh_01", "Butter Poached Lobster with Corn Succotash", "Tôm Hùm Luộc Bơ Sốt Bắp Ngọt Josh Marks", "Seafood", "American", 420, 36, 18, 22,
                ["Maine Lobster Tail", "Sweet Corn", "Crispy Bacon", "Butter", "Tarragon", "Cream"],
                ["Đuôi tôm hùm Maine hảo hạng", "Bắp ngọt non", "Thịt xông khói áp chảo", "Bơ Pháp béo", "Ngải giấm tarragon", "Kem tươi"],
                "1. Gently poach sweet lobster meat in low-temperature emulsion of salted butter. 2. Sauté sweet corn kernels with crispy bacon lardons and heavy cream. 3. Plate tender lobster tail over sweet golden corn succotash.",
                "1. Luộc chậm đuôi tôm hùm Maine hảo hạng trong nhũ tương bơ đun chảy ở nhiệt độ thấp cho thịt ngọt mềm như lụa. 2. Xào bắp ngọt non cùng thịt xông khói giòn rụm và kem sữa tươi tarragon thơm ngậy. 3. Món khai vị chung kết thượng hạng của người khổng lồ hiền lành Josh Marks đối đầu Christine Hà.",
                "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥈 Á Quân Josh Marks", "🦞 Tôm Hùm Sốt Bắp", "⚔️ Món Đối Đầu Chung Kết"],
                yt: "https://www.youtube.com/watch?v=1nAVbfQVWRQ"),

            M("mc_intl_josh_02", "Pecan-crusted Rack of Lamb with Sweet Potato", "Sườn Cừu Lăn Hạt Hồ Đào Nướng Josh Marks", "Meat", "American", 610, 48, 24, 38,
                ["Rack of Lamb", "Toasted Pecans", "Sweet Potato Puree", "Bourbon Glaze", "Rosemary"],
                ["Sườn cừu non tảng", "Hạt hồ đào Pecan nướng giòn", "Khoai lang mật nghiền mịn", "Sốt rượu Bourbon caramen", "Hương thảo"],
                "1. Coat seared lamb rack with crust of crushed roasted pecans and herbs. 2. Roast until core reaches 54°C medium-rare. 3. Slice and serve on velvety sweet potato puree with bourbon pan jus reduction.",
                "1. Áp chảo sườn cừu non rồi lăn qua lớp hạt hồ đào Pecan nướng thơm bùi giòn rụm. 2. Đút lò cho thịt bên trong đạt độ hồng đào mọng nước ngọt ngào. 3. Món chính đêm chung kết mang đậm phong cách miền Nam nước Mỹ của đối thủ lớn nhất của Christine Hà.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥈 Á Quân Josh Marks", "🥩 Sườn Cừu Hạt Hồ Đào", "⚔️ Món Chính Chung Kết"],
                yt: "https://www.youtube.com/watch?v=6R8ffRRJcrg"),

            // === MÙA 4: ĐỐI ĐẦU LUCA MANFÉ VS NATASHA CRNJAC ===
            M("mc_intl_09", "Luca Manfé's Braised Short Ribs with Polenta", "Sườn Bò Hầm Rượu Vang & Polenta Phô Mai Luca Manfé", "Meat", "Italian", 620, 48, 36, 32,
                ["Beef Short Ribs", "Red Wine", "Polenta Cornmeal", "Parmesan Cheese", "Mirepoix", "Veal Stock"],
                ["Dẻ sườn bò rút xương", "Rượu vang đỏ đậm đà", "Bột ngô Polenta Ý", "Phô mai Parmesan hảo hạng", "Cần tây hành tây cà rốt", "Nước dùng bê cô đặc"],
                "1. Brown short ribs deeply and braise with wine and aromatic vegetables for 3.5 hours. 2. Cook creamy yellow polenta with rich butter and aged Parmesan. 3. Spoon falling-apart tender ribs with glossy braising jus over warm polenta.",
                "1. Áp chảo sườn bò cháy xém cạnh rồi hầm chậm cùng rượu vang đỏ và rau củ mirepoix suốt 3.5 tiếng cho mềm tan rục xương. 2. Nấu bột ngô Polenta vàng óng mịn màng quyện bơ và phô mai Parmesan béo bùi. 3. Đĩa sườn bò đẫm sốt đậm chất Ý đưa Luca Manfé từ chàng bồi bàn trở thành Quán quân MasterChef US mùa 4.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🇮🇹 Luca Manfé Mùa 4", "🥩 Sườn Bò Polenta", "⭐ Đậm Chất Ý"],
                yt: "https://www.youtube.com/watch?v=0kFp6G4kE1w"),

            M("mc_intl_natasha_01", "Pan-seared Scallops with Corn Emulsion", "Sò Điệp Áp Chảo Sốt Bắp Ngọt Natasha Crnjac", "Seafood", "American", 320, 30, 16, 14,
                ["Jumbo Sea Scallops", "Sweet Corn Puree", "Chive Oil", "Prosciutto Crisp", "Microgreens"],
                ["Sò điệp cồi lớn đại dương", "Bắp ngọt non xay nhuyễn", "Dầu hẹ xanh ngọc", "Giăm bông Ý chiên giòn", "Rau mầm trang trí"],
                "1. Sear giant sea scallops in brown butter for 90 seconds until deeply caramelized. 2. Strain sweet corn into silky smooth emulsion and swirl with green chive oil. 3. Plate scallops over emulsion with prosciutto dust.",
                "1. Áp chảo sò điệp cồi lớn với bơ nâu trong 90 giây mỗi mặt cho lớp vỏ vàng caramel bóng bẩy trong khi bên trong mềm mọng ngọt ngào. 2. Lọc sốt bắp ngọt non sánh mịn điểm xuyết dầu hẹ xanh mướt. 3. Món khai vị chung kết tinh xảo của á quân kiêu kỳ đầy tài năng Natasha Crnjac.",
                "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥈 Á Quân Natasha Mùa 4", "🦪 Sò Điệp Áp Chảo", "⚔️ Món Đối Đầu Chung Kết"],
                yt: "https://www.youtube.com/watch?v=4vhcOwVBDO4"),

            // === MÙA 6: ĐỐI ĐẦU CLAUDIA SANDOVAL VS DERRICK PELTZ ===
            M("mc_intl_derrick_01", "Squid Ink Risotto with Crispy Skin Salmon", "Cơm Ý Mực Đen Áp Chảo Cá Hồi Derrick Peltz", "Seafood", "Italian", 520, 42, 48, 18,
                ["Arborio Rice", "Squid Ink", "Salmon Fillet", "Parmesan", "White Wine", "Fennel Salad"],
                ["Gạo Ý Arborio", "Mực đen túi mực tươi", "Phi lê cá hồi giòn da", "Phô mai Parmesan", "Vang trắng", "Salad thì là củ"],
                "1. Toast Arborio rice with white wine and ladle fish stock with dark squid ink until creamy. 2. Pan-sear salmon fillet with shatteringly crispy skin. 3. Plate pink salmon against deep black risotto with crunchy fennel salad.",
                "1. Đảo gạo Ý Arborio với rượu vang trắng và nước cốt mực đen tuyền huyền bí cho hạt cơm dẻo quánh chuẩn al dente. 2. Áp chảo cá hồi da giòn rụm màu hồng cam tương phản ngoạn mục trên nền cơm đen tuyền. 3. Tác phẩm nghệ thuật ẩm thực rock-and-roll của tay trống cừ khôi Derrick Peltz.",
                "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🥈 Á Quân Derrick Mùa 6", "🦑 Cơm Ý Mực Đen", "⚔️ Món Chung Kết Rực Lửa"],
                yt: "https://www.youtube.com/watch?v=kYV3t4J1B4I"),

            M("mc_intl_claudia_01", "Grilled Swordfish with Salsa Verde", "Cá Kiếm Nướng Sốt Salsa Verde Claudia Sandoval", "Seafood", "Mexican", 460, 44, 22, 20,
                ["Swordfish Steak", "Tomatillo", "Jalapeno", "Cilantro", "Mexican Red Rice", "Avocado"],
                ["Thịt cá kiếm tươi dày mình", "Cà chua xanh Tomatillo", "Ớt Jalapeno cay nồng", "Ngò gai", "Cơm đỏ cà chua Mexico", "Bơ sáp"],
                "1. Grill thick swordfish steaks over open flame until marked with grill grates. 2. Blend roasted tomatillos, lime, and cilantro into piquant Mexican salsa verde. 3. Serve alongside fragrant tomato red rice and avocado slices.",
                "1. Nướng cá kiếm tươi dày mình trên vỉ than hoa xém cạnh thơm lừng mùi khói. 2. Nướng cà chua xanh tomatillo và ớt jalapeno giã nhuyễn thành sốt Salsa Verde xanh ngọc cay nồng sảng khoái. 3. Món chính Mexico đậm đà đưa bà mẹ đơn thân Claudia đăng quang Quán quân MasterChef US mùa 6.",
                "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🏆 Claudia Quán Quân M6", "🐟 Cá Kiếm Nướng", "🇲🇽 Ẩm Thực Mexico"],
                yt: "https://www.youtube.com/watch?v=vZy-7UyPdjM")
        ];
    }

    /// <summary>
    /// 4. CÁC MÓN ĂN THỬ THÁCH LOẠI TRỪ & THÍ SINH ẤN TƯỢNG MASTERCHEF US
    /// </summary>
    private static List<RecommendedMealDto> GetMasterChefUsMemorableContestants()
    {
        return
        [
            // === HUYỀN THOẠI GORDON RAMSAY ===
            M("mc_intl_05", "Gordon Ramsay's Classic Beef Wellington", "Bò Wellington Huyền Thoại Gordon Ramsay", "Meat", "British", 680, 52, 28, 40,
                ["Beef Fillet Center-Cut", "Puff Pastry", "Mushroom Duxelles", "Prosciutto di Parma", "English Mustard", "Egg Wash"],
                ["Thăn bò trung tâm hảo hạng", "Bột nghìn lớp Puff Pastry", "Nấm xay nhuyễn nướng khô Duxelles", "Thịt nguội Parma Ý", "Mù tạt vàng Anh", "Lòng đỏ trứng gà quét mặt"],
                "1. Sear prime beef fillet, brush with English mustard. 2. Roll tightly in prosciutto and deeply caramelized mushroom duxelles, then wrap in buttery puff pastry. 3. Bake at 200°C for 35 mins until pastry is golden brown and meat is a perfect rosy pink medium-rare.",
                "1. Áp chảo thăn bò thượng hạng cháy cạnh khóa nước thịt, quét mù tạt Anh cay nồng. 2. Trải thịt nguội Parma, trét nấm Duxelles xào cạn nước thơm lừng rồi cuộn chặt thăn bò vào lớp bột bánh nghìn lớp vàng ươm. 3. Nướng ở 200°C trong 35 phút cho vỏ bánh giòn rụm, cắt ra bên trong thịt bò hồng đào mọng nước - món thử thách áp lực kinh điển nhất mọi mùa MasterChef.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["⭐ Gordon Ramsay", "👑 Huyền Thoại MasterChef", "🥩 Bò Wellington", "🔥 Thử Thách Áp Lực"],
                yt: "https://www.youtube.com/watch?v=rVGxoDKwQuk"),

            M("mc_intl_06", "Pan-seared Scallops with Minted Pea Puree", "Sò Điệp Áp Chảo Sốt Đậu Hà Lan & Ba Chỉ Giòn", "Seafood", "British", 310, 28, 14, 16,
                ["King Scallops", "Sweet Green Peas", "Fresh Mint", "Crispy Pancetta", "Butter", "Lemon"],
                ["Sò điệp đại dương khổng lồ", "Đậu Hà Lan ngọt", "Lá bạc hà tươi", "Thịt ba chỉ muối Pancetta", "Bơ lạt", "Chanh tươi"],
                "1. Sear king scallops in smoking hot pan with butter for exactly 90 seconds on one side, 30 seconds on the other. 2. Puree sweet peas with butter and fresh garden mint. 3. Serve golden caramelized scallops over emerald puree with shards of crispy pancetta.",
                "1. Sò điệp đại dương tươi rói thấm khô, áp chảo trên chảo gang bơ nóng đúng 90 giây mặt đầu và 30 giây mặt sau để tạo lớp vỏ caramen vàng ruộm trong khi thịt ngọt mềm mọng. 2. Xay nhuyễn đậu Hà Lan ngọt với bơ và lá bạc hà thành sốt xanh ngọc bích mịn màng. 3. Rắc vụn ba chỉ muối Pancetta giòn rụm - món khai vị tiêu chuẩn vàng của Gordon Ramsay.",
                "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80",
                ["⭐ Gordon Ramsay", "🦪 Sò Điệp Áp Chảo", "👑 MasterChef Classic", "💚 Sốt Đậu Bạc Hà"],
                yt: "https://www.youtube.com/watch?v=jZ_5qXlqXf8"),

            M("mc_intl_07", "Gordon Ramsay's Perfect Scrambled Eggs", "Trứng Khuấy Bơ Kiểu Pháp Gordon Ramsay", "Breakfast", "French", 290, 18, 4, 23,
                ["Farm Fresh Eggs", "French Butter", "Crème Fraîche", "Fresh Chives", "Sourdough Toast", "Black Pepper"],
                ["Trứng gà tươi", "Bơ Pháp béo ngậy", "Kem chua Crème Fraîche", "Hẹ tây thái mịn", "Bánh mì men tự nhiên Sourdough", "Tiêu đen xay thô"],
                "1. Put eggs and butter directly into cold saucepan without whisking. 2. Cook on and off heat continuously stirring with spatula. 3. Fold in crème fraîche and chives off heat to create the creamiest scrambled eggs on earth.",
                "1. Cho trứng và bơ trực tiếp vào nồi lạnh không đánh trước. 2. Nấu theo kỹ thuật nhấc nồi ra vào lửa liên tục, đảo đều tay bằng phới dẻo cho trứng cô đặc mịn như kem. 3. Nhấc khỏi bếp cho một thìa kem chua Crème Fraîche và hẹ thái mịn vào đảo đều, múc lên bánh mì nướng - công thức trứng triệu view của Gordon Ramsay.",
                "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=600&q=80",
                ["⭐ Gordon Ramsay", "🍳 Trứng Khuấy Huyền Thoại", "🍞 Bữa Sáng Đẳng Cấp", "🧈 Béo Mịn Nhẹ Bụng"],
                yt: "https://www.youtube.com/watch?v=PUP7U5vTMMgk"),

            M("mc_intl_08", "Molten Chocolate Lava Cake", "Bánh Lava Socola Trào Chảy Thử Thách Áp Lực", "Dessert", "French", 460, 8, 48, 28,
                ["Dark Belgian Chocolate 70%", "Butter", "Eggs", "Caster Sugar", "Flour", "Vanilla Ice Cream"],
                ["Socola đen Bỉ 70%", "Bơ lạt", "Trứng gà tươi", "Đường mịn", "Bột mì", "Kem vani Madagascar"],
                "1. Melt dark chocolate with butter over gentle double boiler. 2. Whisk eggs and sugar until pale, fold into chocolate, and bake in ramekins at 200°C for exactly 11 minutes. 3. Invert onto plate; cutting reveals warm molten chocolate flowing out flawlessly.",
                "1. Đun chảy socola đen Bỉ 70% cùng bơ lạt cách thủy. 2. Đánh bông trứng với đường, trộn nhẹ cùng hỗn hợp socola rồi đổ khuôn ramekin nướng đúng 11 phút ở 200°C. 3. Úp ngược ra đĩa, khi dùng muỗng xắn nhẹ thì dòng nham thạch socola ấm nóng tuôn trào mềm mại - cơn ác mộng và thử thách áp lực kinh điển của mọi thí sinh MasterChef.",
                "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80",
                ["🍫 MasterChef Pressure Test", "🌋 Socola Trào Chảy", "🍨 Đỉnh Cao Tráng Miệng"],
                yt: "https://www.youtube.com/watch?v=U0Q0zN7iKz8"),

            // === CÁC THÍ SINH NỔI TIẾNG US: FRANK, BECKY, LESLIE, NICK DIGIOVANNI ===
            M("mc_intl_frank_01", "Handmade Pappardelle with Rabbit Ragù", "Mì Ý Tươi Làm Tay Sốt Ragu Thỏ Frank Mirarchi", "Pasta", "Italian", 520, 38, 54, 16,
                ["Handmade Pasta Flour", "Rabbit Meat", "Chianti Wine", "Pancetta", "Rosemary", "Parmigiano-Reggiano"],
                ["Bột mì Ý cán tay", "Thịt thỏ băm nhỏ", "Rượu vang Chianti Ý", "Thịt muối Pancetta", "Hương thảo", "Phô mai Parmigiano"],
                "1. Roll fresh egg pasta dough thinly and cut into wide pappardelle ribbons. 2. Slow simmer diced rabbit meat with Chianti wine, mirepoix, and sweet pancetta for 2 hours. 3. Toss hot pasta in glossy ragù with snowfall of Parmigiano.",
                "1. Tự nhào bột trứng cán mỏng cắt thành từng dải mì bản rộng Pappardelle tươi mềm mướt. 2. Hầm chậm thịt thỏ băm cùng rượu vang Chianti và thịt muối Pancetta trong 2 tiếng cho sánh đặc đậm đà. 3. Món mì Ý gia truyền giúp chàng lính cứu hỏa Frank Mirarchi nhận tràng pháo tay giòn giã từ giám khảo Joe Bastianich.",
                "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "👨‍🚒 Frank Mirarchi Mùa 3", "🍝 Mì Ý Tươi Ragu Thỏ", "🇮🇹 Đậm Chất Ý"],
                yt: "https://www.youtube.com/watch?v=rp8Slv4INLk"),

            M("mc_intl_becky_01", "Crispy Scotch Egg with Whole Grain Mustard", "Trứng Scotch Bọc Thịt Giòn Rụm Becky Reams", "Starter", "British", 380, 26, 16, 24,
                ["Soft-boiled Egg", "Pork Sausage Meat", "Panko Breadcrumbs", "Wholegrain Mustard", "Chives"],
                ["Trứng lòng đào luộc chuẩn", "Thịt xúc xích heo gia vị", "Bột chiên xù Panko", "Mù tạt hạt nguyên cám", "Hẹ tươi"],
                "1. Soft boil eggs for exactly 5 minutes, shock in ice bath, and peel carefully. 2. Wrap evenly with seasoned sausage meat, dredge in panko, and deep fry until crunchy. 3. Slice open to reveal a luscious, flowing golden yolk.",
                "1. Luộc trứng đúng 5 phút cho lòng đào dẻo quánh rồi ngâm đá bóc vỏ nhẹ nhàng. 2. Bọc đều lớp thịt xúc xích heo tẩm thảo mộc, lăn qua bột xù panko chiên vàng ruộm giòn tan. 3. Cắt đôi quả trứng lòng đào chảy vàng óng ả chấm mù tạt hạt - món thử thách áp lực kinh điển của nhiếp ảnh gia Becky Reams.",
                "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "📸 Becky Reams Mùa 3", "🥚 Trứng Lòng Đào Scotch", "🔥 Thử Thách Áp Lực"],
                yt: "https://www.youtube.com/watch?v=f-waAIrn2iA"),

            M("mc_intl_nick_01", "Wood-fired Wagyu with Black Garlic Jus", "Bò Wagyu Nướng Sốt Tỏi Đen Nick DiGiovanni", "Meat", "American", 580, 48, 12, 38,
                ["A5 Wagyu Beef", "Fermented Black Garlic", "Beef Bone Marrow", "Shiitake", "Micro Greens"],
                ["Thịt bò Wagyu vân mỡ cẩm thạch", "Tỏi đen lên men ngọt dịu", "Tủy xương bò nướng", "Nấm đông cô", "Rau mầm tươi"],
                "1. Flash sear beautifully marbled A5 Wagyu over charcoal embers to medium-rare. 2. Blend sweet umami-rich black garlic cloves with reduced bone marrow jus. 3. Serve succulent sliced Wagyu with glistening dark sauce.",
                "1. Áp chảo thăn bò Wagyu A5 vân mỡ cẩm thạch tuyệt mỹ trên than củi cho cháy cạnh ngoài mà bên trong mềm như bơ tan ngay trên đầu lưỡi. 2. Xay nhuyễn tỏi đen lên men ngọt thơm cùng sốt tủy xương bò hầm cô đặc. 3. Món ăn tinh hoa của chàng sinh viên Harvard Nick DiGiovanni - hiện là nhà sáng tạo ẩm thực triệu view nổi tiếng nhất thế giới.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🌟 Nick DiGiovanni Mùa 10", "🥩 Bò Wagyu Tỏi Đen", "🔥 Triệu View"],
                yt: "https://www.youtube.com/watch?v=zT9kL_3mRkQ"),

            M("mc_intl_leslie_01", "Classic Lemon Meringue Tart Flambé", "Bánh Tart Chanh Vàng Meringue Nướng Leslie Gilliams", "Dessert", "French", 360, 6, 52, 14,
                ["Shortcrust Pastry", "Lemon Curd", "Egg Whites", "Caster Sugar", "Lemon Zest"],
                ["Vỏ bánh tart bơ nướng vàng", "Kem chanh vàng cốt dừa mịn", "Lòng trắng trứng đánh bông", "Đường mịn", "Vỏ chanh bào"],
                "1. Blind-bake shortcrust tart shells until golden and crisp. 2. Fill with silky, tangy homemade lemon curd. 3. Pipe pillowy Italian meringue on top and torch tips to a caramelized golden hue.",
                "1. Nướng chín vỏ bánh tart bơ vàng ruộm giòn tan. 2. Đổ đầy lớp kem chanh vàng chua dịu mịn mượt như lụa. 3. Bắt bông kem meringue trắng muốt như mây và dùng đèn khò xém vàng các đỉnh chóp - chiếc bánh giúp quý ông Leslie Gilliams nhiều lần chiến thắng ngoạn mục ở thử thách loại trừ.",
                "https://images.unsplash.com/photo-1517673132405-a56a62b18caf?auto=format&fit=crop&w=600&q=80",
                ["🏆 MasterChef US", "🎩 Leslie Gilliams Mùa 5", "🍋 Tart Chanh Meringue", "🔥 Thử Thách Áp Lực"],
                yt: "https://www.youtube.com/watch?v=pSupybydA_U")
        ];
    }

    /// <summary>
    /// 5. MASTERCHEF AUSTRALIA & CÁC HUYỀN THOẠI QUỐC TẾ
    /// </summary>
    private static List<RecommendedMealDto> GetMasterChefAustraliaAndLegends()
    {
        return
        [
            M("mc_intl_11", "Reynold Poernomo's Coconut Mango Panna Cotta", "Panna Cotta Dừa Rừng Sốt Xoài Vua Món Ngọt Reynold", "Dessert", "Australian", 320, 6, 34, 18,
                ["Coconut Cream", "Mango Puree", "Passion Fruit", "White Chocolate Crumble", "Mint Oil", "Edible Flowers"],
                ["Nước cốt dừa béo", "Xoài chín xay nhuyễn", "Chanh dây thanh mát", "Vụn socola trắng nướng", "Dầu bạc hà", "Hoa ăn được trang trí"],
                "1. Set delicate coconut panna cotta in silicone pebble molds. 2. Prepare vibrant mango passionfruit coulis and golden baked white chocolate soil. 3. Assemble artistic nature-inspired plate worthy of MasterChef Australia's Dessert King.",
                "1. Đổ khuôn panna cotta cốt dừa mềm mướt núng nính như những viên sỏi ngọc bích. 2. Nấu sốt xoài chanh dây nhiệt đới chua ngọt rực rỡ và nướng vụn socola trắng giòn bùi như rêu rừng. 3. Bày trí đĩa tráng miệng tựa như tác phẩm nghệ thuật đỉnh cao của Vua món ngọt Reynold Poernomo khiến ban giám khảo ngả mũ thán phục.",
                "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=600&q=80",
                ["🇦🇺 MasterChef Australia", "👑 Vua Món Ngọt Reynold", "🥭 Panna Cotta Dừa Xoài", "🎨 Tác Phẩm Nghệ Thuật"],
                yt: "https://www.youtube.com/watch?v=gT8_wXkXh3I"),

            M("mc_intl_10", "Pan-seared Duck Breast with Cherry Jus", "Ức Vịt Áp Chảo Sốt Quả Anh Đào & Khoai Fondant", "Meat", "French", 480, 42, 18, 26,
                ["Duck Breast", "Fresh Cherries", "Port Wine", "Duck Fat Potatoes", "Thyme", "Butter"],
                ["Ức vịt tươi khía da", "Quả anh đào cherry đỏ", "Rượu vang đỏ ngọt", "Khoai tây hầm mỡ vịt Fondant", "Cỏ xạ hương", "Bơ"],
                "1. Score duck skin and render fat on cold pan until skin is razor crisp, finish in oven to medium-rare. 2. Cook fondant potatoes in duck fat until creamy inside. 3. Glaze with sweet tart cherry and Port wine reduction.",
                "1. Khía ô quả trám trên da vịt, áp chảo từ chảo lạnh ép kiệt mỡ cho da giòn tan như bim bim, giữ thịt hồng medium-rare. 2. Nấu khoai tây Fondant trong mỡ vịt vàng óng ngoài giòn trong bở mịn như bơ. 3. Rưới sốt quả anh đào cherry đỏ thắm chua ngọt quý phái cân bằng độ béo ngậy của thịt vịt.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["👑 MasterChef Classic", "🦆 Ức Vịt Sốt Cherry", "🥔 Khoai Tây Fondant", "🇫🇷 Ẩm Thực Pháp"],
                yt: "https://www.youtube.com/watch?v=fE85ioKQ7ew"),

            M("mc_intl_poh_01", "Poh Ling Yeow's Traditional Beef Rendang", "Bò Rendang Nước Cốt Dừa & Cơm Nasi Lemak Poh Ling Yeow", "Beef", "Malaysian", 580, 46, 38, 28,
                ["Beef Chuck", "Coconut Milk", "Toasted Coconut (Kerisik)", "Lemongrass", "Galangal", "Kaffir Lime Leaves"],
                ["Bắp bò gân giòn", "Nước cốt dừa đậm đặc", "Cùi dừa nạo rang vàng Kerisik", "Sả cây", "Củ riềng thơm", "Lá chúc chanh Thái"],
                "1. Pound spice paste with galangal, shallots, and dried chilies. 2. Brown beef cubes and slow-simmer in thick coconut milk for 3 hours until sauce evaporates into dark caramelized oil. 3. Fold in fragrant kerisik and serve with coconut rice.",
                "1. Giã nhuyễn hỗn hợp thảo mộc sả riềng ớt khô thơm nồng. 2. Đảo săn thịt bắp bò rồi hầm chậm liu riu với nước cốt dừa suốt 3 tiếng cho cạn kiệt thành lớp dầu màu cánh gián thơm ngát. 3. Rắc cùi dừa nạo rang Kerisik giòn bùi ăn kèm cơm dừa Nasi Lemak - món ăn biểu tượng đưa Poh Ling Yeow trở thành huyền thoại ẩm thực nước Úc.",
                "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80",
                ["🇦🇺 MasterChef Australia", "🌟 Huyền Thoại Poh Ling Yeow", "🥥 Bò Rendang Nước Dừa", "🍚 Nasi Lemak"],
                yt: "https://www.youtube.com/watch?v=d_xKxG0oY1Y"),

            M("mc_intl_matt_01", "Crispy Pork Belly Bao Buns with Hoisin", "Bánh Bao Kẹp Ba Chỉ Heo Quay Giòn Bì Matt Sinclair", "Pork", "Asian", 480, 24, 46, 22,
                ["Pork Belly", "Steamed Bao Buns", "Hoisin Sauce", "Pickled Cucumbers", "Spring Onion", "Crushed Peanuts"],
                ["Thịt ba chỉ quay giòn rụm bì", "Vỏ bánh bao trắng hấp mềm xốp", "Sốt tương ngọt Hoisin", "Dưa chuột bao tử ngâm chua ngọt", "Đầu hành hoa tước sợi", "Đậu phộng rang giã"],
                "1. Roast pork belly with salted skin until crackling shatters like glass. 2. Steam fluffy white bao buns. 3. Assemble bao stuffed with crispy pork belly, sweet hoisin sauce, pickled cucumbers, and scallions.",
                "1. Quay thịt ba chỉ với muối hột cho bì nổ giòn rụm tan trong miệng, thớ thịt mọng nước đậm đà. 2. Hấp vỏ bánh bao trắng muốt mềm như bông gòn. 3. Kẹp từng miếng thịt ba chỉ giòn rụm cùng sốt hoisin ngọt thơm, dưa leo chua ngọt và rắc đậu phộng bùi béo - món ăn đường phố đưa Matt Sinclair thành ngôi sao MasterChef Úc.",
                "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80",
                ["🇦🇺 MasterChef Australia", "🌟 Matt Sinclair Mùa 8", "🥟 Bánh Bao Thịt Quay", "🔥 Giòn Rụm Tan Chảy"],
                yt: "https://www.youtube.com/watch?v=wG4L1hKx0w0"),

            M("mc_intl_marion_01", "Thai Steamed Barramundi with Lime & Chili", "Cá Chẽm Hấp Chanh Sả Ớt Chua Cay Marion Grasby", "Seafood", "Thai", 310, 36, 12, 11,
                ["Fresh Barramundi Fillet", "Fresh Lime Juice", "Garlic", "Bird's Eye Chilies", "Fish Sauce", "Cilantro"],
                ["Phi lê cá chẽm tươi", "Nước cốt chanh tươi vắt", "Tỏi băm", "Ớt hiểm đỏ xắt lát", "Nước mắm nhĩ ngon", "Rau mùi tươi ngò gai"],
                "1. Score skin of fresh barramundi and steam over high heat with lemongrass and kaffir lime leaves for 8 mins. 2. Whisk fresh lime juice, fish sauce, garlic, and sliced bird's eye chilies into fiery tangy dressing. 3. Pour bubbling dressing over fish.",
                "1. Khía da cá chẽm tươi ngọt, hấp cách thủy cùng sả và lá chanh Thái trong 8 phút cho vừa chín tới ngọt mọng. 2. Pha nước sốt chanh ớt chua cay bùng nổ hương vị từ nước cốt chanh tươi, mắm cốt và ớt hiểm đỏ rực. 3. Chan nước sốt sôi sùng sục lên thân cá tỏa khói ngào ngạt - công thức làm nên tên tuổi nữ đầu bếp Marion Grasby.",
                "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80",
                ["🇦🇺 MasterChef Australia", "👩‍🍳 Marion Grasby", "🐟 Cá Chẽm Hấp Chanh Ớt", "🌶️ Chua Cay Bùng Nổ"],
                yt: "https://www.youtube.com/watch?v=N9yV0tK0j1A")
        ];
    }
}
