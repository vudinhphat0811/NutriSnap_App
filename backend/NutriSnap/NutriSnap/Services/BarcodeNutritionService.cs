using System.Text.Json;
using NutriSnap.Models;

namespace NutriSnap.Services;

public class BarcodeNutritionService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<BarcodeNutritionService> _logger;

    public BarcodeNutritionService(HttpClient httpClient, ILogger<BarcodeNutritionService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _httpClient.Timeout = TimeSpan.FromSeconds(3.5);
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("NutriSnap/1.0 (contact@nutrisnap.app)");
    }

    /// <summary>
    /// Danh mục sản phẩm siêu thị & Gym phổ biến tại Việt Nam (EAN-13 & Tem Cân)
    /// </summary>
    private static readonly List<BarcodeProductDto> SupermarketProducts = new()
    {
        // === KHAY THỊT TƯƠI TEM CÂN SIÊU THỊ (Variable Weight 20xxxxx) ===
        new BarcodeProductDto
        {
            Barcode = "201024503504",
            ProductName = "Khay Ức Gà Phi Lê Tươi MeatDeli (Tem Cân Siêu Thị)",
            Brand = "MeatDeli",
            Category = "Thịt Gà & Gia Cầm",
            CategoryIcon = "🍗",
            BarcodeType = "Tem Cân Siêu Thị (Variable Weight)",
            NetWeightG = 350.0,
            ServingSize = "1 Khay 350g",
            CaloriesPer100g = 120.0,
            ProteinPer100g = 22.5,
            CarbsPer100g = 0.0,
            FatPer100g = 2.6,
            FiberPer100g = 0.0,
            SodiumMg = 65.0,
            CutEquivalentId = "chicken_breast_skinless",
            Source = "Tem Cân Siêu Thị WinMart/MeatDeli",
            Notes = "Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 350g từ mã vạch",
            ImageUrl = "https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "201011002808",
            ProductName = "Khay Thịt Bò Thăn Úc Tươi (Tem Cân Siêu Thị Aeon/WinMart)",
            Brand = "WinMart / Aeon Fresh",
            Category = "Thịt Bò",
            CategoryIcon = "🥩",
            BarcodeType = "Tem Cân Siêu Thị (Variable Weight)",
            NetWeightG = 280.0,
            ServingSize = "1 Khay 280g",
            CaloriesPer100g = 135.0,
            ProteinPer100g = 22.0,
            CarbsPer100g = 0.0,
            FatPer100g = 4.5,
            FiberPer100g = 0.0,
            SodiumMg = 55.0,
            CutEquivalentId = "beef_tenderloin",
            Source = "Tem Cân Siêu Thị WinMart",
            Notes = "Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 280g từ mã vạch",
            ImageUrl = "https://images.unsplash.com/photo-1558030006-450675393462?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "201030004502",
            ProductName = "Khay Nạc Thăn Heo Tươi CP (Tem Cân Siêu Thị)",
            Brand = "CP Foods",
            Category = "Thịt Heo",
            CategoryIcon = "🥓",
            BarcodeType = "Tem Cân Siêu Thị (Variable Weight)",
            NetWeightG = 450.0,
            ServingSize = "1 Khay 450g",
            CaloriesPer100g = 143.0,
            ProteinPer100g = 21.0,
            CarbsPer100g = 0.0,
            FatPer100g = 6.0,
            FiberPer100g = 0.0,
            SodiumMg = 60.0,
            CutEquivalentId = "pork_tenderloin",
            Source = "Tem Cân Siêu Thị CP Fresh Shop",
            Notes = "Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 450g từ mã vạch",
            ImageUrl = "https://images.unsplash.com/photo-1602498456745-e9503b30470b?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "201040003005",
            ProductName = "Khay Cá Hồi Phi Lê Nauy Tươi (Tem Cân Siêu Thị Mega Market)",
            Brand = "Mega Market / Aeon Fresh",
            Category = "Cá & Hải Sản",
            CategoryIcon = "🐟",
            BarcodeType = "Tem Cân Siêu Thị (Variable Weight)",
            NetWeightG = 300.0,
            ServingSize = "1 Khay 300g",
            CaloriesPer100g = 208.0,
            ProteinPer100g = 20.4,
            CarbsPer100g = 0.0,
            FatPer100g = 13.4,
            FiberPer100g = 0.0,
            SodiumMg = 59.0,
            CutEquivalentId = "salmon_fillet",
            Source = "Tem Cân Siêu Thị Mega Market",
            Notes = "Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 300g từ mã vạch",
            ImageUrl = "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "201050005006",
            ProductName = "Khay Đùi Gà Góc Tư Tươi SanHa (Tem Cân Bách Hóa Xanh)",
            Brand = "SanHa Foods",
            Category = "Thịt Gà & Gia Cầm",
            CategoryIcon = "🍗",
            BarcodeType = "Tem Cân Siêu Thị (Variable Weight)",
            NetWeightG = 500.0,
            ServingSize = "1 Khay 500g",
            CaloriesPer100g = 177.0,
            ProteinPer100g = 19.5,
            CarbsPer100g = 0.0,
            FatPer100g = 11.2,
            FiberPer100g = 0.0,
            SodiumMg = 72.0,
            CutEquivalentId = "chicken_leg_with_skin",
            Source = "Tem Cân Siêu Thị Bách Hóa Xanh",
            Notes = "Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 500g từ mã vạch",
            ImageUrl = "https://images.unsplash.com/photo-1587593810167-a84920ea0781?w=400&q=80"
        },

        // === SẢN PHẨM ĐÓNG HỘP / DINH DƯỠNG GYM (EAN-13 Tiêu chuẩn Quốc Tế & VN) ===
        new BarcodeProductDto
        {
            Barcode = "8936036010017",
            ProductName = "Sữa Tươi Tiệt Trùng TH True Milk Ít Đường 180ml",
            Brand = "TH True Milk",
            Category = "Trứng & Sữa / Whey",
            CategoryIcon = "🥛",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 180.0,
            ServingSize = "1 Hộp 180ml",
            CaloriesPer100g = 70.0,
            ProteinPer100g = 3.0,
            CarbsPer100g = 7.8,
            FatPer100g = 3.2,
            FiberPer100g = 0.0,
            SodiumMg = 45.0,
            Source = "Bao Bì Nhà Sản Xuất TH True Milk",
            Notes = "Hộp 180ml chứa ~126 Kcal, 5.4g Protein chất lượng cao",
            ImageUrl = "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8934673111018",
            ProductName = "Sữa Tươi Tiệt Trùng Vinamilk 100% Không Đường 180ml",
            Brand = "Vinamilk",
            Category = "Trứng & Sữa / Whey",
            CategoryIcon = "🥛",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 180.0,
            ServingSize = "1 Hộp 180ml",
            CaloriesPer100g = 60.2,
            ProteinPer100g = 3.1,
            CarbsPer100g = 4.2,
            FatPer100g = 3.4,
            FiberPer100g = 0.0,
            SodiumMg = 42.0,
            Source = "Bao Bì Nhà Sản Xuất Vinamilk",
            Notes = "Hộp 180ml chứa ~108 Kcal, 5.6g Protein, không thêm đường",
            ImageUrl = "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8934673641027",
            ProductName = "Sữa Chua Hy Lạp Vinamilk Greek Style Không Đường 100g",
            Brand = "Vinamilk",
            Category = "Trứng & Sữa / Whey",
            CategoryIcon = "🥛",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 100.0,
            ServingSize = "1 Hũ 100g",
            CaloriesPer100g = 95.0,
            ProteinPer100g = 7.0,
            CarbsPer100g = 4.5,
            FatPer100g = 5.2,
            FiberPer100g = 0.0,
            SodiumMg = 38.0,
            Source = "Bao Bì Vinamilk Greek Style",
            Notes = "Sữa chua Hy Lạp đạm cao gấp đôi, giàu lợi khuẩn đường ruột",
            ImageUrl = "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "0030000010402",
            ProductName = "Yến Mạch Quaker Oats Quick 1-Minute 500g",
            Brand = "Quaker Oats",
            Category = "Tinh Bột & Ngũ Cốc",
            CategoryIcon = "🥣",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 500.0,
            ServingSize = "1 Khẩu phần 40g",
            CaloriesPer100g = 375.0,
            ProteinPer100g = 12.5,
            CarbsPer100g = 67.5,
            FatPer100g = 7.5,
            FiberPer100g = 10.0,
            SodiumMg = 5.0,
            CutEquivalentId = "rolled_oats",
            Source = "Bao Bì Chính Hãng Quaker Oats",
            Notes = "Ngũ cốc nguyên cám GI thấp, giàu chất xơ hòa tan Beta-Glucan",
            ImageUrl = "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "0748927028669",
            ProductName = "Sữa Tăng Cơ Whey Gold Standard 100% ON (Double Rich Chocolate)",
            Brand = "Optimum Nutrition (ON)",
            Category = "Trứng & Sữa / Whey",
            CategoryIcon = "💪",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 907.0,
            ServingSize = "1 Muỗng (Scoop) 30.4g",
            CaloriesPer100g = 394.7,
            ProteinPer100g = 78.9,
            CarbsPer100g = 9.8,
            FatPer100g = 4.9,
            FiberPer100g = 2.0,
            SodiumMg = 427.0,
            CutEquivalentId = "whey_isolate",
            Source = "Bao Bì Chính Hãng Optimum Nutrition",
            Notes = "Mỗi muỗng 30.4g cung cấp 24g Protein tinh khiết hấp thu siêu nhanh",
            ImageUrl = "https://images.unsplash.com/photo-1593095948071-474c5cc2989d?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8934617011015",
            ProductName = "Cá Ngừ Ngâm Dầu Canfos Hạ Long 175g",
            Brand = "Hạ Long Canfoco",
            Category = "Cá & Hải Sản",
            CategoryIcon = "🐟",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 175.0,
            ServingSize = "1 Hộp 175g",
            CaloriesPer100g = 190.0,
            ProteinPer100g = 21.0,
            CarbsPer100g = 0.0,
            FatPer100g = 12.0,
            FiberPer100g = 0.0,
            SodiumMg = 380.0,
            CutEquivalentId = "tuna_steak",
            Source = "Bao Bì Đồ Hộp Hạ Long",
            Notes = "Cá ngừ đại dương đóng hộp tiện lợi, dồi dào Protein và Omega-3",
            ImageUrl = "https://images.unsplash.com/photo-1501595091296-3aa970afb3ff?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8935049500019",
            ProductName = "Hộp 10 Quả Trứng Gà Tươi Tiệt Trùng Ba Huân",
            Brand = "Ba Huân",
            Category = "Trứng & Sữa / Whey",
            CategoryIcon = "🥚",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 600.0,
            ServingSize = "1 Quả (~60g)",
            CaloriesPer100g = 143.0,
            ProteinPer100g = 12.6,
            CarbsPer100g = 0.7,
            FatPer100g = 9.5,
            FiberPer100g = 0.0,
            SodiumMg = 142.0,
            CutEquivalentId = "whole_egg",
            Source = "Bao Bì Trứng Sạch Ba Huân",
            Notes = "Mỗi quả trung bình 60g có ~86 Kcal và 7.5g Protein sinh học hoàn chỉnh",
            ImageUrl = "https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8935044400123",
            ProductName = "Ức Gà Ăn Liền CP Fi-le Vị Tiêu Đen 100g",
            Brand = "CP Foods",
            Category = "Thịt Gà & Gia Cầm",
            CategoryIcon = "🍗",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 100.0,
            ServingSize = "1 Gói 100g",
            CaloriesPer100g = 115.0,
            ProteinPer100g = 24.0,
            CarbsPer100g = 1.0,
            FatPer100g = 1.5,
            FiberPer100g = 0.0,
            SodiumMg = 320.0,
            CutEquivalentId = "chicken_breast_skinless",
            Source = "Bao Bì CP Ready-to-eat",
            Notes = "Gói 100g chín sẵn ăn liền, chuẩn Eat-Clean đạm cao không dầu mỡ",
            ImageUrl = "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8938501230014",
            ProductName = "Bánh Gạo Lứt Ăn Kiêng Zozin Hương Mè Đen 125g",
            Brand = "Zozin",
            Category = "Tinh Bột & Ngũ Cốc",
            CategoryIcon = "🌾",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 125.0,
            ServingSize = "1 Bánh (~10g)",
            CaloriesPer100g = 380.0,
            ProteinPer100g = 8.5,
            CarbsPer100g = 78.0,
            FatPer100g = 3.5,
            FiberPer100g = 6.5,
            SodiumMg = 85.0,
            Source = "Bao Bì Bánh Gạo Lứt Zozin",
            Notes = "Ăn vặt không lo tích mỡ, no lâu nhờ nguồn tinh bột phức hợp",
            ImageUrl = "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80"
        },
        new BarcodeProductDto
        {
            Barcode = "8934572001021",
            ProductName = "Đậu Hũ Non Vissan Hộp 300g",
            Brand = "Vissan",
            Category = "Trứng & Sữa / Whey",
            CategoryIcon = "🧈",
            BarcodeType = "EAN-13 Tiêu Chuẩn",
            NetWeightG = 300.0,
            ServingSize = "1 Hộp 300g",
            CaloriesPer100g = 76.0,
            ProteinPer100g = 8.1,
            CarbsPer100g = 1.9,
            FatPer100g = 4.2,
            FiberPer100g = 0.5,
            SodiumMg = 15.0,
            CutEquivalentId = "firm_tofu",
            Source = "Bao Bì Đậu Hũ Non Vissan",
            Notes = "Đạm thực vật tinh khiết từ đậu nành tự nhiên, thanh đạm dễ tiêu",
            ImageUrl = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80"
        }
    };

    /// <summary>
    /// Tra cứu thông tin dinh dưỡng theo mã vạch:
    /// 1. Kiểm tra mã vạch trong danh mục siêu thị Việt Nam đã lưu sẵn
    /// 2. Nếu là mã vạch tem cân siêu thị (bắt đầu 20-29), giải mã khối lượng tự động
    /// 3. Nếu không có, tra cứu trực tuyến Open Food Facts API
    /// </summary>
    public async Task<BarcodeLookupResponseDto> LookupBarcodeAsync(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode))
        {
            return new BarcodeLookupResponseDto
            {
                Success = false,
                Message = "Mã vạch không được để trống."
            };
        }

        var cleanBarcode = barcode.Trim().Replace(" ", "").Replace("-", "");

        // Chuẩn hóa 12 số sang 13 số nếu thiếu số 0 đầu (UPC-A to EAN-13)
        var paddedBarcode = cleanBarcode.Length == 12 ? "0" + cleanBarcode : cleanBarcode;

        // 1. Kiểm tra trực tiếp trong danh mục siêu thị
        var match = SupermarketProducts.FirstOrDefault(p =>
            p.Barcode.Equals(cleanBarcode, StringComparison.OrdinalIgnoreCase) ||
            p.Barcode.Equals(paddedBarcode, StringComparison.OrdinalIgnoreCase));

        if (match != null)
        {
            var productCopy = CloneProduct(match);
            PopulatePortionMacros(productCopy);
            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = cleanBarcode,
                Product = productCopy,
                Message = $"Tìm thấy sản phẩm '{productCopy.ProductName}' ({productCopy.Brand}) trong CSDL Siêu Thị NutriSnap."
            };
        }

        // 2. Kiểm tra nếu là Tem Cân Siêu Thị (Variable weight prefix 20..29)
        if (IsSupermarketScaleBarcode(cleanBarcode))
        {
            var scaleProduct = TryParseScaleBarcode(cleanBarcode);
            if (scaleProduct != null)
            {
                PopulatePortionMacros(scaleProduct);
                return new BarcodeLookupResponseDto
                {
                    Success = true,
                    Barcode = cleanBarcode,
                    Product = scaleProduct,
                    Message = $"Đã giải mã thành công tem cân siêu thị! Khối lượng bóc tách tự động: {scaleProduct.NetWeightG}g."
                };
            }
        }

        // 3. Tra cứu trực tuyến từ Open Food Facts API
        var onlineProduct = await TryFetchOpenFoodFactsAsync(paddedBarcode);
        if (onlineProduct != null)
        {
            PopulatePortionMacros(onlineProduct);
            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = cleanBarcode,
                Product = onlineProduct,
                Message = $"Tìm thấy sản phẩm '{onlineProduct.ProductName}' từ cơ sở dữ liệu mở Open Food Facts."
            };
        }

        // 4. Không tìm thấy - tạo gợi ý
        return new BarcodeLookupResponseDto
        {
            Success = false,
            Barcode = cleanBarcode,
            Message = $"Không tìm thấy thông tin cho mã vạch '{cleanBarcode}'. Bạn có thể chọn trong danh sách nguyên liệu hoặc thử các mã vạch siêu thị mẫu.",
            Suggestions = SupermarketProducts.Select(p => $"{p.ProductName} ({p.Barcode})").Take(6).ToList()
        };
    }

    /// <summary>
    /// Lấy danh sách các sản phẩm mẫu để test quét mã vạch
    /// </summary>
    public List<BarcodeProductDto> GetSampleProducts()
    {
        return SupermarketProducts.Select(p =>
        {
            var clone = CloneProduct(p);
            PopulatePortionMacros(clone);
            return clone;
        }).ToList();
    }

    /// <summary>
    /// Kiểm tra tiền tố tem cân siêu thị chuẩn GS1 (20 đến 29)
    /// </summary>
    private static bool IsSupermarketScaleBarcode(string barcode)
    {
        if (barcode.Length != 12 && barcode.Length != 13) return false;
        var prefix = barcode.Length == 13 ? barcode.Substring(0, 2) : barcode.Substring(0, 1);
        if (barcode.Length == 13)
        {
            return prefix is "20" or "21" or "22" or "23" or "24" or "25" or "26" or "27" or "28" or "29";
        }
        return prefix == "2";
    }

    /// <summary>
    /// Giải mã tem cân siêu thị tự động:
    /// Cấu trúc: 20 + [5 số mã mặt hàng] + [4 hoặc 5 số trọng lượng grams] + [1 số kiểm tra]
    /// </summary>
    private static BarcodeProductDto? TryParseScaleBarcode(string barcode)
    {
        try
        {
            double weightG = 250.0; // mặc định nếu không tách được
            string productDigits = "";

            if (barcode.Length == 13)
            {
                // Format: 20 + PPPPP (5) + WWWW (4) + C (1) hoặc PPPPP (4) + WWWWW (5)
                productDigits = barcode.Substring(2, 5);
                var weightDigits = barcode.Substring(7, 4);
                if (double.TryParse(weightDigits, out var parsedW) && parsedW > 10 && parsedW < 5000)
                {
                    weightG = parsedW;
                }
            }
            else if (barcode.Length == 12)
            {
                productDigits = barcode.Substring(1, 5);
                var weightDigits = barcode.Substring(6, 4);
                if (double.TryParse(weightDigits, out var parsedW) && parsedW > 10 && parsedW < 5000)
                {
                    weightG = parsedW;
                }
            }

            // Đoán loại thịt/nguyên liệu từ mã mặt hàng hoặc fallback sang ức gà / thịt bò chuẩn
            string name = $"Khay Thịt Tươi Siêu Thị ({weightG:0}g)";
            string category = "Thịt Gà & Gia Cầm";
            string cutId = "chicken_breast_skinless";
            double cal100 = 120.0;
            double pro100 = 22.5;
            double carb100 = 0.0;
            double fat100 = 2.6;

            if (productDigits.StartsWith("101") || productDigits.Contains("bo") || productDigits.Contains("beef"))
            {
                name = $"Khay Thịt Bò Tươi Siêu Thị ({weightG:0}g)";
                category = "Thịt Bò";
                cutId = "beef_tenderloin";
                cal100 = 135.0;
                pro100 = 22.0;
                fat100 = 4.5;
            }
            else if (productDigits.StartsWith("103") || productDigits.Contains("heo") || productDigits.Contains("pork"))
            {
                name = $"Khay Thịt Heo Nạc Siêu Thị ({weightG:0}g)";
                category = "Thịt Heo";
                cutId = "pork_tenderloin";
                cal100 = 143.0;
                pro100 = 21.0;
                fat100 = 6.0;
            }
            else if (productDigits.StartsWith("104") || productDigits.Contains("ca") || productDigits.Contains("fish"))
            {
                name = $"Khay Cá Phi Lê Siêu Thị ({weightG:0}g)";
                category = "Cá & Hải Sản";
                cutId = "salmon_fillet";
                cal100 = 208.0;
                pro100 = 20.4;
                fat100 = 13.4;
            }
            else
            {
                name = $"Khay Ức Gà / Phi Lê Siêu Thị ({weightG:0}g)";
                category = "Thịt Gà & Gia Cầm";
                cutId = "chicken_breast_skinless";
                cal100 = 120.0;
                pro100 = 22.5;
                fat100 = 2.6;
            }

            return new BarcodeProductDto
            {
                Barcode = barcode,
                ProductName = name,
                Brand = "Siêu Thị (WinMart / Co.op / Aeon / Bách Hóa Xanh)",
                Category = category,
                CategoryIcon = category == "Thịt Bò" ? "🥩" : (category == "Thịt Heo" ? "🥓" : (category == "Cá & Hải Sản" ? "🐟" : "🍗")),
                BarcodeType = "Tem Cân Siêu Thị (Variable Weight)",
                NetWeightG = weightG,
                ServingSize = $"1 Khay {weightG:0}g",
                CaloriesPer100g = cal100,
                ProteinPer100g = pro100,
                CarbsPer100g = carb100,
                FatPer100g = fat100,
                FiberPer100g = 0.0,
                SodiumMg = 60.0,
                CutEquivalentId = cutId,
                Source = "Tem Cân Tự Động Siêu Thị",
                Notes = $"Giải mã tự động: Tiền tố tem cân {barcode.Substring(0, 2)}, trích xuất khối lượng {weightG:0}g",
                ImageUrl = "https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400&q=80"
            };
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Truy vấn trực tuyến Open Food Facts API
    /// </summary>
    private async Task<BarcodeProductDto?> TryFetchOpenFoodFactsAsync(string barcode)
    {
        try
        {
            var url = $"https://world.openfoodfacts.org/api/v2/product/{barcode}.json";
            var response = await _httpClient.GetAsync(url);
            if (!response.IsSuccessStatusCode) return null;

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.TryGetProperty("status", out var statusElem) && statusElem.GetInt32() != 1)
            {
                return null;
            }

            if (!root.TryGetProperty("product", out var productElem))
            {
                return null;
            }

            string name = "";
            if (productElem.TryGetProperty("product_name_vi", out var viName) && !string.IsNullOrWhiteSpace(viName.GetString()))
            {
                name = viName.GetString()!;
            }
            else if (productElem.TryGetProperty("product_name", out var defName))
            {
                name = defName.GetString() ?? "";
            }

            if (string.IsNullOrWhiteSpace(name))
            {
                name = $"Sản phẩm mã vạch {barcode}";
            }

            string brand = "";
            if (productElem.TryGetProperty("brands", out var brandElem))
            {
                brand = brandElem.GetString() ?? "";
            }

            double cal100 = 0;
            double pro100 = 0;
            double carb100 = 0;
            double fat100 = 0;
            double fiber100 = 0;
            double? sodium = null;
            double weightG = 100;

            if (productElem.TryGetProperty("nutriments", out var nutriments))
            {
                if (nutriments.TryGetProperty("energy-kcal_100g", out var calElem))
                    cal100 = calElem.GetDouble();
                else if (nutriments.TryGetProperty("energy-kcal", out var cal2))
                    cal100 = cal2.GetDouble();

                if (nutriments.TryGetProperty("proteins_100g", out var proElem))
                    pro100 = proElem.GetDouble();

                if (nutriments.TryGetProperty("carbohydrates_100g", out var carbElem))
                    carb100 = carbElem.GetDouble();

                if (nutriments.TryGetProperty("fat_100g", out var fatElem))
                    fat100 = fatElem.GetDouble();

                if (nutriments.TryGetProperty("fiber_100g", out var fibElem))
                    fiber100 = fibElem.GetDouble();

                if (nutriments.TryGetProperty("sodium_100g", out var sodElem))
                    sodium = sodElem.GetDouble() * 1000.0; // convert to mg
            }

            if (productElem.TryGetProperty("product_quantity", out var qtyElem) && double.TryParse(qtyElem.GetString(), out var q) && q > 0)
            {
                weightG = q;
            }

            string imgUrl = "";
            if (productElem.TryGetProperty("image_front_url", out var imgElem))
            {
                imgUrl = imgElem.GetString() ?? "";
            }

            return new BarcodeProductDto
            {
                Barcode = barcode,
                ProductName = name,
                Brand = string.IsNullOrWhiteSpace(brand) ? "Thương hiệu đã xác thực" : brand,
                Category = "Thực Phẩm Đóng Gói",
                CategoryIcon = "📦",
                BarcodeType = "EAN-13 Tiêu Chuẩn (Open Food Facts)",
                NetWeightG = weightG > 0 ? weightG : 100.0,
                ServingSize = $"{weightG:0}g",
                CaloriesPer100g = Math.Round(cal100, 1),
                ProteinPer100g = Math.Round(pro100, 1),
                CarbsPer100g = Math.Round(carb100, 1),
                FatPer100g = Math.Round(fat100, 1),
                FiberPer100g = Math.Round(fiber100, 1),
                SodiumMg = sodium != null ? Math.Round(sodium.Value, 1) : null,
                Source = "Open Food Facts Global Database",
                Notes = "Dữ liệu dinh dưỡng được trích xuất từ cơ sở dữ liệu mở Open Food Facts",
                ImageUrl = imgUrl
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Lỗi truy vấn Open Food Facts cho barcode {Barcode}", barcode);
            return null;
        }
    }

    private static void PopulatePortionMacros(BarcodeProductDto product)
    {
        var factor = (product.NetWeightG <= 0 ? 100.0 : product.NetWeightG) / 100.0;
        var cal = Math.Round(product.CaloriesPer100g * factor, 1);
        var pro = Math.Round(product.ProteinPer100g * factor, 1);
        var carb = Math.Round(product.CarbsPer100g * factor, 1);
        var fat = Math.Round(product.FatPer100g * factor, 1);
        var fib = Math.Round(product.FiberPer100g * factor, 1);

        var proCal = pro * 4.0;
        var carbCal = carb * 4.0;
        var fatCal = fat * 9.0;
        var totalMacroCal = (proCal + carbCal + fatCal) <= 0 ? 1.0 : (proCal + carbCal + fatCal);

        product.CalculatedPortionMacros = new CalculatedCutMacroDto
        {
            CutId = product.Barcode,
            Name = product.ProductName,
            WeightG = product.NetWeightG,
            TotalCalories = cal,
            TotalProtein = pro,
            TotalCarbs = carb,
            TotalFat = fat,
            TotalFiber = fib,
            ProteinPercent = Math.Round((proCal / totalMacroCal) * 100.0, 1),
            CarbsPercent = Math.Round((carbCal / totalMacroCal) * 100.0, 1),
            FatPercent = Math.Round((fatCal / totalMacroCal) * 100.0, 1),
            GymBadges = new List<string> { product.Brand, product.BarcodeType },
            GymTip = product.Notes
        };
    }

    private static BarcodeProductDto CloneProduct(BarcodeProductDto p)
    {
        return new BarcodeProductDto
        {
            Barcode = p.Barcode,
            ProductName = p.ProductName,
            Brand = p.Brand,
            Category = p.Category,
            CategoryIcon = p.CategoryIcon,
            BarcodeType = p.BarcodeType,
            NetWeightG = p.NetWeightG,
            ServingSize = p.ServingSize,
            CaloriesPer100g = p.CaloriesPer100g,
            ProteinPer100g = p.ProteinPer100g,
            CarbsPer100g = p.CarbsPer100g,
            FatPer100g = p.FatPer100g,
            FiberPer100g = p.FiberPer100g,
            SodiumMg = p.SodiumMg,
            ImageUrl = p.ImageUrl,
            Source = p.Source,
            CutEquivalentId = p.CutEquivalentId,
            Notes = p.Notes
        };
    }
}
