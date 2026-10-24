using NutriSnap.Models;

namespace NutriSnap.Services;

/// <summary>
/// Kho dữ liệu dinh dưỡng nguyên liệu THÔ (sống, chưa qua chế biến hay nấu nướng)
/// Tiêu chuẩn đo lường trên 100g nguyên liệu thô theo Bảng thành phần thực phẩm VN & USDA.
/// Tên nguyên liệu thuần khiết, không kèm từ ngữ quảng cáo (tươi, ngon) hay nấu nướng (luộc, chiên, xào, hấp).
/// </summary>
public static class IngredientCutCatalog
{
    private static IngredientCutDto I(
        string id, string category, string icon, string name, string engName, string desc,
        string portionName, double portionG,
        double cal100g, double pro100g, double carb100g, double fat100g, double fiber100g,
        string badge = "", string tip = "")
    {
        return new IngredientCutDto
        {
            Id = id,
            Category = category,
            CategoryIcon = icon,
            Name = name,
            EnglishName = engName,
            Description = desc,
            DefaultPortionName = portionName,
            DefaultPortionWeightG = portionG,
            CaloriesPer100g = cal100g,
            ProteinPer100g = pro100g,
            CarbsPer100g = carb100g,
            FatPer100g = fat100g,
            FiberPer100g = fiber100g,
            SuitableGoals = new() { "Kiểm soát calo", "Eat Clean", "Tăng cơ giảm mỡ" },
            GymBadges = string.IsNullOrEmpty(badge) ? new() { $"🔥 {cal100g} kcal / 100g thô", $"💪 {pro100g}g Đạm" } : new() { badge },
            GymTip = tip,
            ImageUrl = ""
        };
    }

    private static readonly List<IngredientCutDto> _cuts = new()
    {
        // ==========================================
        // 1. THỊT & TRỨNG (NGUYÊN LIỆU THÔ)
        // ==========================================
        I("raw_chicken_breast", "Thịt & Trứng", "🍗", "Ức gà", "Raw Chicken Breast",
          "Thịt nạc trắng giàu đạm chất lượng cao, cực kỳ ít mỡ.", "100g thô", 100, 120, 22.5, 0.0, 2.6, 0.0,
          "💪 22.5g Đạm / 100g", "Nguyên liệu vàng cho siết mỡ và tăng cơ nạc."),

        I("raw_chicken_thigh", "Thịt & Trứng", "🍗", "Đùi gà", "Raw Chicken Thigh",
          "Thịt sẫm màu, mềm ẩm mọng nước và đậm đà tự nhiên.", "100g thô", 100, 177, 19.7, 0.0, 10.4, 0.0,
          "🍗 177 kcal / 100g", "Thích hợp cho bữa ăn xả hoặc nạp năng lượng tập luyện."),

        I("raw_chicken_drumstick", "Thịt & Trứng", "🍗", "Má đùi gà", "Raw Chicken Drumstick/Thigh Cut",
          "Phần má đùi nhiều cơ nạc xen kẽ, hàm lượng kẽm và sắt cao.", "100g thô", 100, 209, 17.5, 0.0, 15.3, 0.0,
          "🍗 209 kcal / 100g", "Giàu vi chất sắt và vitamin B12."),

        I("raw_chicken_wing", "Thịt & Trứng", "🍗", "Cánh gà", "Raw Chicken Wing",
          "Tỉ lệ da và sụn cao, giàu collagen tự nhiên.", "100g thô", 100, 203, 18.3, 0.0, 14.1, 0.0,
          "🍗 203 kcal / 100g", "Chứa nhiều collagen tốt cho khớp xương."),

        I("raw_chicken_feet", "Thịt & Trứng", "🍗", "Chân gà", "Raw Chicken Feet",
          "Chủ yếu là sụn và da, dồi dào canxi và gelatin.", "100g thô", 100, 215, 19.4, 0.2, 14.6, 0.0,
          "🍗 215 kcal / 100g", "Hàm lượng canxi và collagen cao."),

        I("raw_beef_tenderloin", "Thịt & Trứng", "🥩", "Thăn bò", "Raw Beef Tenderloin",
          "Phần thịt bò mềm nhất, tỉ lệ mỡ thấp, cực giàu đạm và creatine.", "100g thô", 100, 142, 22.3, 0.0, 5.4, 0.0,
          "🥩 22.3g Đạm / 100g", "Cung cấp sắt heme và creatine tự nhiên tăng sức mạnh cơ bắp."),

        I("raw_beef_shank", "Thịt & Trứng", "🥩", "Bắp bò", "Raw Beef Shank",
          "Thịt nạc có nhiều gân hoa giòn rụm, calo vừa phải, giàu kẽm.", "100g thô", 100, 130, 21.5, 0.0, 4.2, 0.0,
          "🥩 130 kcal / 100g", "Lựa chọn nạc tuyệt vời cho chế độ ăn kiểm soát calo."),

        I("raw_beef_brisket", "Thịt & Trứng", "🥩", "Ba chỉ bò", "Raw Beef Plate / Brisket",
          "Thịt xen kẽ các dải mỡ ngậy béo, nhiều calo.", "100g thô", 100, 260, 17.0, 0.0, 21.0, 0.0,
          "🥩 260 kcal / 100g", "Phù hợp giai đoạn xả cơ (bulking) hoặc chế độ keto."),

        I("raw_beef_flank", "Thịt & Trứng", "🥩", "Gầu bò", "Raw Beef Flank",
          "Miếng thịt có mỡ giòn viền ngoài, thơm đậm mùi bò.", "100g thô", 100, 251, 17.5, 0.0, 20.0, 0.0,
          "🥩 251 kcal / 100g", "Chứa nhiều năng lượng và khoáng chất kẽm."),

        I("raw_beef_chuck", "Thịt & Trứng", "🥩", "Nạc vai bò", "Raw Beef Chuck",
          "Thịt nạc vai cân đối, đạm cao mỡ vừa.", "100g thô", 100, 165, 20.5, 0.0, 8.5, 0.0,
          "🥩 165 kcal / 100g", "Cân bằng hoàn hảo giữa đạm và năng lượng."),

        I("raw_pork_tenderloin", "Thịt & Trứng", "🥩", "Thăn heo", "Raw Pork Tenderloin",
          "Phần nạc mềm nhất của heo, calo và chất béo thấp ngang ức gà.", "100g thô", 100, 139, 21.1, 0.0, 5.5, 0.0,
          "🥩 21.1g Đạm / 100g", "Lựa chọn thịt heo siết mỡ số 1 cho người tập gym."),

        I("raw_pork_belly", "Thịt & Trứng", "🥩", "Ba chỉ heo", "Raw Pork Belly",
          "Thịt ba chỉ 3 lớp mỡ nạc đan xen, năng lượng dồi dào.", "100g thô", 100, 297, 16.5, 0.0, 25.5, 0.0,
          "🥩 297 kcal / 100g", "Cần cân đối khẩu phần khi ăn trong chế độ giảm cân."),

        I("raw_pork_shoulder", "Thịt & Trứng", "🥩", "Nạc vai heo", "Raw Pork Shoulder",
          "Thịt vai mềm có chút vân mỡ mỏng không bị khô.", "100g thô", 100, 176, 19.0, 0.0, 11.0, 0.0,
          "🥩 176 kcal / 100g", "Nguồn đạm phổ biến và giàu vitamin B1."),

        I("raw_pork_ribs", "Thịt & Trứng", "🥩", "Sườn heo", "Raw Pork Spare Ribs",
          "Sườn heo gồm thịt nạc dính xương và sụn non.", "100g thô", 100, 242, 17.2, 0.0, 18.8, 0.0,
          "🥩 242 kcal / 100g", "Giàu canxi và phospho tự nhiên."),

        I("raw_pork_minced", "Thịt & Trứng", "🥩", "Thịt băm heo", "Raw Ground Pork",
          "Thịt nạc heo xay nhuyễn tiêu chuẩn.", "100g thô", 100, 240, 17.0, 0.0, 19.0, 0.0,
          "🥩 240 kcal / 100g", "Dễ dàng định lượng chính xác theo gram."),

        I("raw_pork_leg", "Thịt & Trứng", "🥩", "Nạc mông heo", "Raw Pork Leg/Ham",
          "Thịt nạc chắc, ít mỡ, đạm cao.", "100g thô", 100, 145, 20.8, 0.0, 6.2, 0.0,
          "🥩 145 kcal / 100g", "Lựa chọn kinh tế và nạc cho bữa ăn hàng ngày."),

        I("raw_egg_whole", "Thịt & Trứng", "🥚", "Trứng gà", "Whole Raw Egg",
          "Trứng gà nguyên quả chuẩn, tỉ lệ hấp thu protein BV 100.", "1 quả (~55g)", 55, 143, 12.6, 0.8, 9.5, 0.0,
          "🥚 ~78 kcal / quả", "Siêu thực phẩm tự nhiên với đầy đủ axit amin thiết yếu."),

        I("raw_egg_white", "Thịt & Trứng", "🥚", "Lòng trắng trứng", "Raw Egg White",
          "100% đạm albumin tinh khiết, hoàn toàn không chứa chất béo.", "1 lòng trắng (~33g)", 33, 52, 10.9, 0.7, 0.2, 0.0,
          "🥚 ~17 kcal / lòng trắng", "Nguồn đạm tinh khiết bậc nhất để siết calo tối đa."),

        I("raw_egg_yolk", "Thịt & Trứng", "🥚", "Lòng đỏ trứng", "Raw Egg Yolk",
          "Chứa choline nuôi não bộ, lutein sáng mắt và vitamin tan trong dầu.", "1 lòng đỏ (~18g)", 18, 322, 15.9, 3.6, 26.5, 0.0,
          "🥚 ~55 kcal / lòng đỏ", "Giàu choline và vi chất dinh dưỡng quý giá."),

        I("raw_egg_quail", "Thịt & Trứng", "🥚", "Trứng cút", "Raw Quail Egg",
          "Hàm lượng vitamin A, B và sắt cao hơn tỷ lệ ở trứng gà.", "1 quả (~10g)", 10, 158, 13.0, 0.4, 11.1, 0.0,
          "🥚 ~16 kcal / quả", "Nạp vi chất dinh dưỡng đậm đặc."),

        I("raw_egg_duck", "Thịt & Trứng", "🥚", "Trứng vịt", "Raw Duck Egg",
          "Trứng vịt to hơn trứng gà, vị béo ngậy và nhiều đạm.", "1 quả (~70g)", 70, 185, 13.0, 1.5, 14.2, 0.0,
          "🥚 ~130 kcal / quả", "Cung cấp lượng axit béo và năng lượng dồi dào."),

        // ==========================================
        // 2. THỦY HẢI SẢN (NGUYÊN LIỆU THÔ)
        // ==========================================
        I("raw_salmon", "Thủy hải sản", "🐟", "Cá hồi", "Raw Salmon",
          "Cá hồi thịt cam đậm, kho tàng Axit béo Omega-3 EPA & DHA.", "100g thô", 100, 208, 20.4, 0.0, 13.4, 0.0,
          "🐟 Giàu Omega-3", "Axit béo lành mạnh bảo vệ tim mạch và phục hồi khớp."),

        I("raw_basa", "Thủy hải sản", "🐟", "Cá basa", "Raw Basa Fish",
          "Thịt cá trắng mềm ngọt, đạm sạch dễ hấp thu, calo vừa phải.", "100g thô", 100, 124, 17.5, 0.0, 5.8, 0.0,
          "🐟 124 kcal / 100g", "Thực phẩm đạm kinh tế và dễ tìm."),

        I("raw_tuna", "Thủy hải sản", "🐟", "Cá ngừ", "Raw Tuna",
          "Thịt đỏ săn chắc, đạm siêu cao lên tới 28g/100g, cực ít mỡ.", "100g thô", 100, 130, 28.0, 0.0, 1.0, 0.0,
          "💪 28g Đạm / 100g", "Hàm lượng đạm nạc top đầu thế giới thủy hải sản."),

        I("raw_tilapia", "Thủy hải sản", "🐟", "Cá rô phi", "Raw Tilapia",
          "Cá thịt trắng nạc, ít tanh, không béo.", "100g thô", 100, 96, 20.1, 0.0, 1.7, 0.0,
          "🐟 Chỉ 96 kcal / 100g", "Nguồn đạm nạc tinh khiết tuyệt vời."),

        I("raw_mackerel", "Thủy hải sản", "🐟", "Cá thu", "Raw Mackerel",
          "Cá biển thịt thơm béo, dồi dào vitamin D và Omega-3.", "100g thô", 100, 205, 18.6, 0.0, 13.9, 0.0,
          "🐟 Giàu Vitamin D", "Tăng cường hấp thu canxi và hỗ trợ miễn dịch."),

        I("raw_snakehead", "Thủy hải sản", "🐟", "Cá lóc (cá quả)", "Raw Snakehead Fish",
          "Cá nước ngọt lành tính, vị ngọt tự nhiên, nhiều đạm ít mỡ.", "100g thô", 100, 97, 18.2, 0.0, 2.7, 0.0,
          "🐟 97 kcal / 100g", "Hỗ trợ hồi phục sức khỏe và làm lành vết thương."),

        I("raw_shrimp", "Thủy hải sản", "🦐", "Tôm", "Raw Shrimp",
          "Tôm thịt chắc giòn, đạm cao, cực ít calo và chất béo.", "100g thô", 100, 85, 18.4, 0.9, 0.9, 0.0,
          "🦐 Chỉ 85 kcal / 100g", "Cung cấp astaxanthin chống oxy hóa mạnh mẽ."),

        I("raw_squid", "Thủy hải sản", "🦑", "Mực", "Raw Squid",
          "Mực thịt dày giòn ngọt, giàu đồng, kẽm và protein nạc.", "100g thô", 100, 92, 15.6, 3.1, 1.4, 0.0,
          "🦑 92 kcal / 100g", "Tốt cho việc siết cân mà không gây ngán."),

        I("raw_octopus", "Thủy hải sản", "🐙", "Bạch tuộc", "Raw Octopus",
          "Bạch tuộc thịt săn chắc, chứa nhiều vitamin B12 và sắt.", "100g thô", 100, 82, 14.9, 2.2, 1.0, 0.0,
          "🐙 82 kcal / 100g", "Thực phẩm giàu vi chất và rất ít calo."),

        I("raw_crab", "Thủy hải sản", "🦀", "Cua biển", "Raw Sea Crab",
          "Thịt cua thơm ngọt, giàu đạm và canxi tự nhiên.", "100g thô", 100, 87, 18.1, 0.4, 1.1, 0.0,
          "🦀 18.1g Đạm / 100g", "Bổ sung canxi và khoáng chất biển."),

        I("raw_clam", "Thủy hải sản", "🦪", "Ngao (nghêu)", "Raw Clam",
          "Giàu sắt gấp nhiều lần thịt bò, cực kỳ bổ máu và ít calo.", "100g thô", 100, 74, 12.8, 2.6, 1.0, 0.0,
          "🦪 Siêu Giàu Sắt", "Hỗ trợ tăng sinh hồng cầu và thể lực."),

        // ==========================================
        // 3. RAU CỦ (NGUYÊN LIỆU THÔ)
        // ==========================================
        I("raw_broccoli", "Rau củ", "🥦", "Bông cải xanh", "Raw Broccoli",
          "Giàu sulforaphane chống viêm, chất xơ và vitamin C.", "100g thô", 100, 34, 2.8, 6.6, 0.4, 2.6,
          "🥦 Top 1 Rau Thể Thao", "Giúp no lâu và thải độc gan."),

        I("raw_cauliflower", "Rau củ", "🥦", "Súp lơ trắng", "Raw Cauliflower",
          "Vị ngọt thanh, calo cực thấp, thay thế tinh bột rất tốt.", "100g thô", 100, 25, 1.9, 5.0, 0.3, 2.0,
          "🥦 25 kcal / 100g", "Lựa chọn hàng đầu để làm giả cơm (cauliflower rice)."),

        I("raw_spinach", "Rau củ", "🥬", "Cải bó xôi", "Raw Spinach",
          "Rau bina giàu sắt, magie, canxi và chất chống oxy hóa lutein.", "100g thô", 100, 23, 2.9, 3.6, 0.4, 2.2,
          "🌿 23 kcal / 100g", "Tăng cường cơ bắp và bảo vệ mắt."),

        I("raw_bok_choy", "Rau củ", "🥬", "Cải thìa", "Raw Bok Choy",
          "Cải thìa mọng nước, thanh mát, hầu như không có calo.", "100g thô", 100, 13, 1.5, 2.2, 0.2, 1.0,
          "🥬 13 kcal / 100g", "Giúp no bụng mà không làm tăng năng lượng nạp."),

        I("raw_choy_sum", "Rau củ", "🥬", "Cải ngọt", "Raw Choy Sum",
          "Rau cải ngọt quen thuộc, giàu vitamin A và vitamin C.", "100g thô", 100, 16, 1.7, 2.1, 0.2, 1.2,
          "🥬 16 kcal / 100g", "Bổ sung chất xơ hòa tan hỗ trợ tiêu hóa."),

        I("raw_water_spinach", "Rau củ", "🥬", "Rau muống", "Raw Water Spinach",
          "Rau muống xanh thanh mát, giàu chất xơ và sắt.", "100g thô", 100, 19, 3.2, 2.1, 0.4, 2.1,
          "🌿 19 kcal / 100g", "Thực phẩm quen thuộc thanh nhiệt cơ thể."),

        I("raw_cabbage", "Rau củ", "🥬", "Bắp cải", "Raw Green Cabbage",
          "Bắp cải xanh giòn ngọt, giàu glutamine bảo vệ niêm mạc dạ dày.", "100g thô", 100, 25, 1.3, 5.8, 0.1, 2.5,
          "🥬 25 kcal / 100g", "Chất xơ dồi dào tạo cảm giác no dai dẳng."),

        I("raw_red_cabbage", "Rau củ", "🥬", "Bắp cải tím", "Raw Red Cabbage",
          "Màu tím đặc trưng từ anthocyanin chống lão hóa cực mạnh.", "100g thô", 100, 31, 1.4, 7.4, 0.2, 2.1,
          "💜 Giàu Anthocyanin", "Tăng đề kháng và làm đẹp da."),

        I("raw_carrot", "Rau củ", "🥕", "Cà rốt", "Raw Carrot",
          "Nguồn cung cấp beta-carotene tiền vitamin A dồi dào.", "100g thô", 100, 41, 0.9, 9.6, 0.2, 2.8,
          "🥕 41 kcal / 100g", "Hỗ trợ thị lực và miễn dịch."),

        I("raw_tomato", "Rau củ", "🍅", "Cà chua", "Raw Tomato",
          "Giàu chất chống oxy hóa lycopene, vitamin C và kali.", "100g thô", 100, 18, 0.9, 3.9, 0.2, 1.2,
          "🍅 18 kcal / 100g", "Lycopene bảo vệ tim mạch và làn da."),

        I("raw_cucumber", "Rau củ", "🥒", "Dưa chuột", "Raw Cucumber",
          "Chứa tới 95% là nước, thanh nhiệt và bù khoáng cấp tốc.", "100g thô", 100, 15, 0.7, 3.6, 0.1, 0.5,
          "🥒 15 kcal / 100g", "Thực phẩm ăn vặt không lo tăng cân."),

        I("raw_bell_pepper", "Rau củ", "🫑", "Ớt chuông", "Raw Bell Pepper",
          "Lượng vitamin C cao gấp 3 lần quả cam, hỗ trợ đốt mỡ.", "100g thô", 100, 26, 1.0, 6.0, 0.3, 2.1,
          "🫑 Gấp 3 Lần Vitamin C", "Thúc đẩy quá trình trao đổi chất."),

        I("raw_king_oyster_mushroom", "Rau củ", "🍄", "Nấm đùi gà", "Raw King Oyster Mushroom",
          "Thịt nấm dày ngọt như thịt gà, giàu beta-glucan tăng đề kháng.", "100g thô", 100, 35, 3.3, 5.0, 0.5, 2.3,
          "🍄 3.3g Đạm / 100g", "Nguồn đạm nấm thực vật thơm ngon."),

        I("raw_enoki_mushroom", "Rau củ", "🍄", "Nấm kim châm", "Raw Enoki Mushroom",
          "Sợi nấm giòn ngọt, chứa nhiều axit amin thiết yếu.", "100g thô", 100, 37, 2.7, 7.8, 0.3, 2.7,
          "🍄 37 kcal / 100g", "Bổ sung chất xơ và tăng miễn dịch."),

        I("raw_shiitake_mushroom", "Rau củ", "🍄", "Nấm hương", "Raw Shiitake Mushroom",
          "Hương thơm đặc trưng, giàu lentinan bảo vệ tế bào.", "100g thô", 100, 34, 2.2, 6.8, 0.5, 2.5,
          "🍄 34 kcal / 100g", "Giúp tăng cường hệ miễn dịch tự nhiên."),

        I("raw_onion", "Rau củ", "🧅", "Hành tây", "Raw Onion",
          "Chứa quercetin chống viêm và hỗ trợ hạ đường huyết.", "100g thô", 100, 40, 1.1, 9.3, 0.1, 1.7,
          "🧅 40 kcal / 100g", "Tạo vị ngọt tự nhiên cho mọi món ăn."),

        I("raw_zucchini", "Rau củ", "🥒", "Bí ngòi", "Raw Zucchini",
          "Calo cực thấp, nhiều nước và chất xơ hòa tan.", "100g thô", 100, 17, 1.2, 3.1, 0.3, 1.0,
          "🥒 17 kcal / 100g", "Tuyệt vời cho chế độ ăn keto và thâm hụt calo."),

        I("raw_pumpkin", "Rau củ", "🎃", "Bí đỏ", "Raw Pumpkin",
          "Bí đỏ giàu tinh bột chậm, kali và vitamin A.", "100g thô", 100, 26, 1.0, 6.5, 0.1, 0.5,
          "🎃 26 kcal / 100g", "Nguồn carb sạch ít calo thay thế cơm."),

        I("raw_asparagus", "Rau củ", "🌱", "Măng tây", "Raw Asparagus",
          "Giàu folate và asparagine hỗ trợ đào thải muối thừa, giảm tích nước.", "100g thô", 100, 20, 2.2, 3.9, 0.1, 2.1,
          "🌱 Thải Muối & Nước", "Thực phẩm quen thuộc của các vận động viên thể hình trước ngày thi đấu."),

        I("raw_lettuce", "Rau củ", "🥗", "Xà lách", "Raw Lettuce",
          "Lá xà lách tươi giòn, cung cấp nước và khoáng chất.", "100g thô", 100, 15, 1.4, 2.9, 0.2, 1.3,
          "🥗 15 kcal / 100g", "Thực phẩm nền tảng cho các món salad."),

        I("raw_celery", "Rau củ", "🥬", "Cần tây", "Raw Celery",
          "Chứa apigenin giúp thư giãn mạch máu và thanh lọc độc tố.", "100g thô", 100, 16, 0.7, 3.0, 0.2, 1.6,
          "🌿 16 kcal / 100g", "Hỗ trợ kiểm soát huyết áp và giảm viêm."),

        I("raw_bean_sprout", "Rau củ", "🌱", "Giá đỗ", "Raw Bean Sprouts",
          "Mầm đậu xanh giàu vitamin E, canxi và enzyme sống.", "100g thô", 100, 30, 3.0, 5.0, 0.2, 1.8,
          "🌱 30 kcal / 100g", "Bổ sung enzyme hỗ trợ quá trình tiêu hóa."),

        // ==========================================
        // 4. TRÁI CÂY (NGUYÊN LIỆU THÔ)
        // ==========================================
        I("raw_banana", "Trái cây", "🍌", "Chuối", "Raw Banana",
          "Giàu carbohydrate hấp thu nhanh và kali chống chuột rút cơ bắp.", "1 quả (~100g)", 100, 89, 1.1, 22.8, 0.3, 2.6,
          "🍌 89 kcal / quả", "Nạp năng lượng tối ưu trước buổi tập 30 phút."),

        I("raw_apple", "Trái cây", "🍎", "Táo", "Raw Apple",
          "Giàu chất xơ pectin hòa tan giúp no lâu và ổn định đường huyết.", "1 quả (~150g)", 150, 52, 0.3, 13.8, 0.2, 2.4,
          "🍎 78 kcal / quả", "Bữa phụ kinh điển cho chế độ giảm mỡ."),

        I("raw_avocado", "Trái cây", "🥑", "Bơ", "Raw Avocado",
          "Trái cây dồi dào chất béo không bão hòa đơn tốt cho tim và khớp.", "100g thô", 100, 160, 2.0, 8.5, 14.7, 6.7,
          "🥑 Giàu Chất Béo Tốt", "Giàu chất béo lành mạnh và chất xơ hòa tan."),

        I("raw_watermelon", "Trái cây", "🍉", "Dưa hấu", "Raw Watermelon",
          "Chứa 92% nước, giàu citrulline giúp giãn nở mạch máu và giảm đau cơ.", "1 miếng (~150g)", 150, 30, 0.6, 7.6, 0.2, 0.4,
          "🍉 45 kcal / miếng", "Giải khát tức thì và bù nước sau tập luyện."),

        I("raw_guava", "Trái cây", "🍐", "Ổi", "Raw Guava",
          "Lượng vitamin C gấp 4 lần quả cam, chất xơ cao, đường thấp.", "1 quả (~150g)", 150, 68, 2.6, 14.3, 1.0, 5.4,
          "🍐 Vua Vitamin C & Xơ", "Hỗ trợ siết mỡ bụng và kiểm soát đường huyết."),

        I("raw_orange", "Trái cây", "🍊", "Cam", "Raw Orange",
          "Giàu vitamin C tự nhiên, flavonoid và kali.", "1 quả (~150g)", 150, 47, 0.9, 11.8, 0.1, 2.4,
          "🍊 70 kcal / quả", "Tăng cường sức đề kháng và phục hồi."),

        I("raw_strawberry", "Trái cây", "🍓", "Dâu tây", "Raw Strawberry",
          "Cực kỳ ít đường, giàu chất chống oxy hóa anthocyanin.", "100g thô", 100, 32, 0.7, 7.7, 0.3, 2.0,
          "🍓 32 kcal / 100g", "Món tráng miệng ít calo hoàn hảo."),

        I("raw_dragonfruit", "Trái cây", "🐉", "Thanh long", "Raw Dragon Fruit",
          "Mát lành, hạt thanh long chứa nhiều chất béo omega-3 tự nhiên.", "100g thô", 100, 60, 1.2, 13.0, 0.6, 2.9,
          "🐉 60 kcal / 100g", "Chất xơ tự nhiên hỗ trợ nhuận tràng."),

        I("raw_mango", "Trái cây", "🥭", "Xoài", "Raw Mango",
          "Vị ngọt thơm đậm đà, giàu vitamin A và polyphenol.", "100g thô", 100, 60, 0.8, 15.0, 0.4, 1.6,
          "🥭 60 kcal / 100g", "Cung cấp năng lượng tự nhiên nhanh chóng."),

        I("raw_grape", "Trái cây", "🍇", "Nho", "Raw Grape",
          "Chứa resveratrol chống oxy hóa và bảo vệ tim mạch.", "100g thô", 100, 67, 0.6, 17.2, 0.4, 0.9,
          "🍇 67 kcal / 100g", "Bổ sung đường đơn lành mạnh từ tự nhiên."),

        I("raw_kiwi", "Trái cây", "🥝", "Kiwi", "Raw Kiwi",
          "Chứa enzyme actinidin phân giải protein giúp tiêu hóa nhanh.", "1 quả (~75g)", 75, 61, 1.1, 14.7, 0.5, 3.0,
          "🥝 45 kcal / quả", "Hỗ trợ tiêu hóa tối đa bữa ăn nhiều đạm."),

        I("raw_pineapple", "Trái cây", "🍍", "Dứa (thơm)", "Raw Pineapple",
          "Giàu enzyme bromelain chống viêm và phân cắt protein.", "100g thô", 100, 50, 0.5, 13.1, 0.1, 1.4,
          "🍍 50 kcal / 100g", "Hỗ trợ hấp thụ thịt và giảm đau nhức cơ bắp."),

        I("raw_pomelo", "Trái cây", "🍈", "Bưởi", "Raw Pomelo",
          "Chứa naringenin hỗ trợ kích hoạt thụ thể đốt mỡ trong gan.", "100g thô", 100, 42, 0.8, 10.7, 0.1, 1.0,
          "🍈 42 kcal / 100g", "Trái cây vàng cho người muốn giảm béo bụng."),

        I("raw_pear", "Trái cây", "🍐", "Lê", "Raw Pear",
          "Vị thanh mát mọng nước, giàu chất xơ hòa tan.", "1 quả (~150g)", 150, 57, 0.4, 15.2, 0.1, 3.1,
          "🍐 85 kcal / quả", "Làm dịu cổ họng và hỗ trợ đường ruột."),

        // ==========================================
        // 5. GẠO & TINH BỘT THÔ (HẠT & CỦ THÔ)
        // ==========================================
        I("raw_white_rice", "Gạo & Tinh bột", "🍚", "Gạo trắng", "Raw White Rice (Dry Grain)",
          "Hạt gạo thô nguyên chất, nguồn carb chính cung cấp năng lượng sạch.", "100g thô", 100, 365, 7.1, 80.0, 0.7, 1.3,
          "🍚 365 kcal / 100g thô", "Nguồn năng lượng cơ bản cho cơ bắp hoạt động."),

        I("raw_brown_rice", "Gạo & Tinh bột", "🌾", "Gạo lứt", "Raw Brown Rice (Dry Grain)",
          "Gạo còn nguyên lớp cám, giàu vitamin B, magie và chất xơ.", "100g thô", 100, 370, 7.9, 77.2, 2.9, 3.5,
          "🌾 Carb Chậm & Giàu Xơ", "Chỉ số GI thấp, giải phóng năng lượng từ từ không tăng vọt đường huyết."),

        I("raw_rolled_oats", "Gạo & Tinh bột", "🥣", "Yến mạch", "Raw Rolled Oats",
          "Chứa beta-glucan làm giảm cholesterol máu, đạm thực vật cao.", "100g thô", 100, 389, 16.9, 66.3, 6.9, 10.6,
          "🥣 16.9g Đạm / 100g", "Carb chậm số 1 cho bữa sáng gymer."),

        I("raw_sweet_potato", "Gạo & Tinh bột", "🍠", "Khoai lang", "Raw Sweet Potato",
          "Củ thô giàu tinh bột kháng, chất xơ và tiền vitamin A.", "1 củ (~150g)", 150, 86, 1.6, 20.1, 0.1, 3.0,
          "🍠 86 kcal / 100g thô", "Carb phức chất lượng cao hỗ trợ siết cơ giảm mỡ."),

        I("raw_potato", "Gạo & Tinh bột", "🥔", "Khoai tây", "Raw Potato",
          "Củ thô giàu kali hơn cả chuối, tinh bột dễ tiêu hóa.", "1 củ (~150g)", 150, 77, 2.0, 17.5, 0.1, 2.2,
          "🥔 Chỉ số no rất cao", "Giúp no lâu và bổ sung kali cho cơ bắp."),

        I("raw_sweet_corn", "Gạo & Tinh bột", "🌽", "Bắp ngọt (ngô)", "Raw Sweet Corn",
          "Hạt ngô thô mọng sữa, giàu lutein, zeaxanthin và chất xơ.", "100g thô", 100, 86, 3.2, 19.0, 1.2, 2.0,
          "🌽 86 kcal / 100g thô", "Nguồn carb ngọt thanh tự nhiên."),

        I("raw_taro", "Gạo & Tinh bột", "🥔", "Khoai môn", "Raw Taro",
          "Củ thô giàu chất xơ và kháng tinh bột, calo thấp.", "100g thô", 100, 112, 1.5, 26.5, 0.2, 4.1,
          "🥔 112 kcal / 100g thô", "Carb no lâu và thơm bùi."),

        I("raw_black_bean", "Gạo & Tinh bột", "🫘", "Đậu đen", "Raw Black Beans (Dry)",
          "Hạt đậu đen khô, giàu anthocyanin, đạm thực vật và molypden.", "100g thô", 100, 341, 21.6, 62.4, 1.4, 15.2,
          "🫘 21.6g Đạm / 100g thô", "Nguồn đạm và chất xơ thực vật khổng lồ."),

        I("raw_green_bean", "Gạo & Tinh bột", "🫘", "Đậu xanh", "Raw Mung Beans (Dry)",
          "Hạt đậu xanh khô thanh nhiệt, giải độc và giàu khoáng chất.", "100g thô", 100, 347, 23.9, 62.6, 1.2, 16.3,
          "🫘 23.9g Đạm / 100g thô", "Cực giàu đạm và vitamin nhóm B."),

        I("raw_red_bean", "Gạo & Tinh bột", "🫘", "Đậu đỏ", "Raw Red Kidney Beans (Dry)",
          "Hạt đậu đỏ khô giàu chất sắt, magie và protein thực vật nạc.", "100g thô", 100, 329, 19.9, 61.3, 0.8, 15.2,
          "🫘 19.9g Đạm / 100g thô", "Hỗ trợ bổ máu và phát triển cơ bắp."),

        // ==========================================
        // 6. ĐẬU & HẠT (NGUYÊN LIỆU THÔ)
        // ==========================================
        I("raw_tofu", "Đậu & Hạt", "🧈", "Đậu phụ", "Raw Fresh Tofu",
          "Đậu hũ thô trắng mềm, nguồn đạm đậu nành lành tính không cholesterol.", "1 miếng (~150g)", 150, 76, 8.1, 1.9, 4.8, 0.3,
          "🧈 8.1g Đạm / 100g", "Thực phẩm đạm nền tảng cho người ăn chay."),

        I("raw_almond", "Đậu & Hạt", "🥜", "Hạnh nhân", "Raw Almonds",
          "Hạt hạnh nhân thô giàu vitamin E, magie và chất béo không bão hòa đơn.", "1 nắm (~30g)", 30, 579, 21.2, 21.6, 49.9, 12.5,
          "🥜 Giàu Vitamin E & Magie", "Bảo vệ màng tế bào và phục hồi cơ thể."),

        I("raw_walnut", "Đậu & Hạt", "🥜", "Hạt óc chó", "Raw Walnuts",
          "Vua của các loại hạt về hàm lượng Omega-3 thực vật (ALA).", "1 nắm (~30g)", 30, 654, 15.2, 13.7, 65.2, 6.7,
          "🧠 Siêu Thực Phẩm Não Bộ", "Cải thiện trí nhớ và điều hòa huyết áp."),

        I("raw_cashew", "Đậu & Hạt", "🥜", "Hạt điều", "Raw Cashews",
          "Vị ngọt bùi tự nhiên, dồi dào kẽm, magie và sắt.", "1 nắm (~30g)", 30, 553, 18.2, 30.2, 43.8, 3.3,
          "🥜 18.2g Đạm / 100g", "Giúp xương khớp chắc khỏe."),

        I("raw_peanut", "Đậu & Hạt", "🥜", "Hạt lạc (đậu phộng)", "Raw Peanuts",
          "Hạt lạc thô giàu đạm bậc nhất trong các loại đậu hạt, kèm niacin B3.", "1 nắm (~30g)", 30, 567, 25.8, 16.1, 49.2, 8.5,
          "🥜 25.8g Đạm / 100g", "Nguồn năng lượng bền bỉ giá trị cao."),

        I("raw_chia_seed", "Đậu & Hạt", "🌱", "Hạt chia", "Raw Chia Seeds",
          "Hạt chia thô nở gấp 10 lần trong nước, kho tàng Omega-3 và chất xơ hòa tan.", "1 muỗng (~15g)", 15, 486, 16.5, 42.1, 30.7, 34.4,
          "🌱 34.4g Xơ / 100g", "Tạo cảm giác no lâu và thanh lọc đường ruột."),

        // ==========================================
        // 7. SỮA & SỮA CHUA
        // ==========================================
        I("raw_yogurt_plain", "Sữa & Sữa chua", "🥛", "Sữa chua không đường", "Plain Unsweetened Yogurt",
          "Sữa chua lên men tự nhiên, giàu lợi khuẩn Probiotics, không đường.", "1 hộp (100g)", 100, 61, 3.5, 4.8, 3.1, 0.0,
          "🥛 61 kcal / hộp", "Lựa chọn tốt nhất cho siết calo và đường ruột."),

        I("raw_yogurt_sweet", "Sữa & Sữa chua", "🥛", "Sữa chua có đường", "Sweetened Yogurt",
          "Sữa chua vị ngọt dịu thơm mát, bổ sung năng lượng nhanh.", "1 hộp (100g)", 100, 105, 3.0, 15.5, 3.0, 0.0,
          "🥛 105 kcal / hộp", "Nạp carb nhanh trước giờ tập luyện."),

        I("raw_yogurt_greek", "Sữa & Sữa chua", "🥣", "Sữa chua Hy Lạp", "Greek Yogurt Plain",
          "Lọc bỏ váng sữa, lượng đạm gấp 3 lần sữa chua thường, đặc quánh tự nhiên.", "100g", 100, 97, 10.0, 3.6, 5.0, 0.0,
          "💪 10g Đạm / 100g", "Thực phẩm vàng xây dựng cơ bắp nạc."),

        I("raw_milk_unsweetened", "Sữa & Sữa chua", "🥛", "Sữa tươi không đường", "Fresh Milk Unsweetened",
          "Sữa bò tươi nguyên chất 100%, giàu canxi và đạm tự nhiên cân bằng.", "1 ly (200ml)", 200, 62, 3.2, 4.7, 3.5, 0.0,
          "🥛 62 kcal / 100ml", "Dễ dàng kết hợp yến mạch hoặc trái cây."),

        I("raw_soy_milk", "Sữa & Sữa chua", "🥛", "Sữa đậu nành", "Pure Soy Milk",
          "Sữa từ hạt đậu nành nguyên chất, không đường, giàu isoflavone.", "1 ly (200ml)", 200, 54, 3.1, 5.5, 1.8, 0.5,
          "🌱 Đạm Thực Vật", "Phù hợp cho người ăn chay hoặc không dung nạp lactose.")
    };

    public static List<IngredientCutDto> GetAll() => _cuts;

    public static List<IngredientCutDto> GetByCategory(string? category)
    {
        if (string.IsNullOrWhiteSpace(category) || category.Equals("Tất cả", StringComparison.OrdinalIgnoreCase))
            return _cuts;

        return _cuts.Where(c => c.Category.Contains(category, StringComparison.OrdinalIgnoreCase) ||
                                category.Contains(c.Category, StringComparison.OrdinalIgnoreCase)).ToList();
    }

    public static IngredientCutDto? GetById(string id)
    {
        return _cuts.FirstOrDefault(c => c.Id.Equals(id, StringComparison.OrdinalIgnoreCase));
    }

    public static List<IngredientCutDto> Search(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return _cuts;

        string q = query.Trim().ToLower();
        return _cuts.Where(c => c.Name.ToLower().Contains(q) ||
                                c.EnglishName.ToLower().Contains(q) ||
                                c.Category.ToLower().Contains(q) ||
                                c.Description.ToLower().Contains(q)).ToList();
    }

    public static CalculatedCutMacroDto CalculateMacros(string cutId, double weightG)
    {
        var cut = GetById(cutId) ?? _cuts[0];
        double safeWeight = Math.Max(1.0, weightG);
        double factor = safeWeight / 100.0;

        double cal = Math.Round(cut.CaloriesPer100g * factor, 1);
        double pro = Math.Round(cut.ProteinPer100g * factor, 1);
        double carb = Math.Round(cut.CarbsPer100g * factor, 1);
        double fat = Math.Round(cut.FatPer100g * factor, 1);
        double fiber = Math.Round(cut.FiberPer100g * factor, 1);

        double proCal = pro * 4.0;
        double carbCal = carb * 4.0;
        double fatCal = fat * 9.0;
        double totalMacroCal = Math.Max(1.0, proCal + carbCal + fatCal);

        double proPct = Math.Round((proCal / totalMacroCal) * 100.0, 1);
        double carbPct = Math.Round((carbCal / totalMacroCal) * 100.0, 1);
        double fatPct = Math.Round((fatCal / totalMacroCal) * 100.0, 1);

        return new CalculatedCutMacroDto
        {
            CutId = cut.Id,
            Name = cut.Name,
            WeightG = safeWeight,
            TotalCalories = cal,
            TotalProtein = pro,
            TotalCarbs = carb,
            TotalFat = fat,
            TotalFiber = fiber,
            ProteinPercent = proPct,
            CarbsPercent = carbPct,
            FatPercent = fatPct,
            GymBadges = cut.GymBadges,
            GymTip = cut.GymTip
        };
    }
}
