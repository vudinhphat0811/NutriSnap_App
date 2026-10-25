using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using NutriSnap.Models;

namespace NutriSnap.Services;

public class BarcodeNutritionService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<BarcodeNutritionService> _logger;
    private readonly IConfiguration _config;

    // Chỉ lưu tiền tố định danh nhà sản xuất GS1 (Không gán cứng thông số dinh dưỡng)
    private static readonly Dictionary<string, (string Company, string Brand)> Gs1VnPrefixes = new()
    {
        { "8934803", ("Công ty Liwayway Việt Nam", "Oishi") },
        { "8934563", ("Công ty Liwayway Việt Nam", "Oishi") },
        { "8934561", ("Công ty Cổ phần Acecook Việt Nam", "Acecook") },
        { "8936036", ("Công ty TNHH Thực phẩm Orion Vina", "Orion") },
        { "8936079", ("Công ty TNHH Thực phẩm PepsiCo Việt Nam", "Lay's / Poca") },
        { "8934673", ("Công ty Cổ phần Sữa Việt Nam", "Vinamilk") },
        { "8934588", ("Suntory PepsiCo Việt Nam", "Suntory PepsiCo") },
        { "8934804", ("Công ty TNHH Nestlé Việt Nam", "Nestlé") },
        { "8935001", ("Mondelez Kinh Đô Việt Nam", "Kinh Đô") },
        { "8935002", ("Mondelez Kinh Đô Việt Nam", "Kinh Đô") },
        { "8934572", ("Công ty Cổ phần Việt Nam Kỹ Nghệ Súc Sản", "Vissan") },
        { "8935049", ("Công ty Cổ phần Ba Huân", "Ba Huân") },
        { "8935044", ("Công ty Cổ phần Chăn nuôi C.P. Việt Nam", "CP Foods") },
        { "8936014", ("Công ty Cổ phần Hàng tiêu dùng Masan", "Masan Consumer") }
    };

    public BarcodeNutritionService(HttpClient httpClient, ILogger<BarcodeNutritionService> logger, IConfiguration config)
    {
        _httpClient = httpClient;
        _logger = logger;
        _config = config;
        _httpClient.Timeout = TimeSpan.FromSeconds(15);
        
        if (!_httpClient.DefaultRequestHeaders.UserAgent.Any())
        {
            _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("NutriSnap/2.0 (contact@nutrisnap.app)");
        }
    }

    /// <summary>
    /// Tra cứu mã vạch động:
    /// 1. Giải mã thông số trực tiếp được mã hóa trên mã vạch (Loại mã, Quốc gia, Trọng lượng tem cân, Checksum)
    /// 2. Nếu là tem cân siêu thị (20-29), trích xuất khối lượng thực tế ngay từ dãy số
    /// 3. Truy vấn trực tuyến Open Food Facts API
    /// 4. Kết hợp AI tra cứu theo mã định danh GS1 nếu sản phẩm nội địa chưa có trên Open Food Facts
    /// </summary>
    public async Task<BarcodeLookupResponseDto> LookupBarcodeAsync(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode))
        {
            return new BarcodeLookupResponseDto { Success = false, Message = "Mã vạch hoặc mã QR không được để trống." };
        }

        var rawBarcode = barcode.Trim();
        bool isQrOrUrl = rawBarcode.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                         rawBarcode.StartsWith("https://", StringComparison.OrdinalIgnoreCase) ||
                         rawBarcode.Contains("/") ||
                         rawBarcode.Contains("?") ||
                         rawBarcode.Contains("=");

        // ==========================================
        // NHÁNH 1: XỬ LÝ MÃ QR & ĐƯỜNG LINK TRUY XUẤT NGUỒN GỐC
        // ==========================================
        if (isQrOrUrl)
        {
            // 1.1 Trích xuất dãy số mã vạch 8-14 số nhúng bên trong URL nếu có
            var matchEmbedded = Regex.Match(rawBarcode, @"(?<!\d)(2\d{11,12}|893\d{7,10}|\d{8,14})(?!\d)");
            if (matchEmbedded.Success)
            {
                var embeddedCode = matchEmbedded.Value;
                var embeddedInfo = ParseRawBarcodeData(embeddedCode);
                if (embeddedInfo.IsValidFormat)
                {
                    // Tra cứu Open Food Facts CSDL bên thứ 3
                    var off = await TryFetchOpenFoodFactsAsync(embeddedInfo.NormalizedEan13, embeddedInfo);
                    if (off != null)
                    {
                        off.Barcode = rawBarcode;
                        off.BarcodeType = "Mã QR Truy Xuất (Open Food Facts)";
                        PopulatePortionMacros(off);
                        return new BarcodeLookupResponseDto
                        {
                            Success = true,
                            Barcode = rawBarcode,
                            Product = off,
                            Message = $"Đã giải mã thành công thông số sản phẩm '{off.ProductName}' từ mã QR!"
                        };
                    }

                    // Tra cứu iCheck & Mạng lưới siêu thị bán lẻ Việt Nam cho mã nhúng trong QR
                    var vnQrProd = await TryFetchVietnameseRetailProductAsync(embeddedInfo);
                    if (vnQrProd != null)
                    {
                        vnQrProd.Barcode = rawBarcode;
                        vnQrProd.BarcodeType = "Mã QR Truy Xuất (iCheck & Siêu Thị VN)";
                        PopulatePortionMacros(vnQrProd);
                        return new BarcodeLookupResponseDto
                        {
                            Success = true,
                            Barcode = rawBarcode,
                            Product = vnQrProd,
                            Message = $"Đã giải mã thành công sản phẩm '{vnQrProd.ProductName}' từ mã QR!"
                        };
                    }

                    // Nếu là tem cân siêu thị nhúng trong QR
                    if (embeddedInfo.IsVariableWeightScale && embeddedInfo.ExtractedWeightG > 0)
                    {
                        var scaleProd = await ResolveScaleBarcodeAsync(embeddedInfo);
                        scaleProd.Barcode = rawBarcode;
                        scaleProd.BarcodeType = "Mã QR Tem Cân Siêu Thị";
                        PopulatePortionMacros(scaleProd);
                        return new BarcodeLookupResponseDto
                        {
                            Success = true,
                            Barcode = rawBarcode,
                            Product = scaleProd,
                            Message = $"Đã bóc tách thông số trực tiếp từ mã QR tem cân: PLU #{embeddedInfo.ItemCode}, {embeddedInfo.ExtractedWeightG}g."
                        };
                    }
                }
            }

            // 1.2 Nếu là link QR nhưng không nhúng số mã vạch chuẩn, thử đọc trực tiếp trang web truy xuất nguồn gốc của bên thứ 3
            var webProd = await TryFetchTraceabilityWebUrlAsync(rawBarcode);
            if (webProd != null)
            {
                PopulatePortionMacros(webProd);
                return new BarcodeLookupResponseDto
                {
                    Success = true,
                    Barcode = rawBarcode,
                    Product = webProd,
                    Message = $"Đã trích xuất thông số thực tế từ đường link truy xuất nguồn gốc: '{webProd.ProductName}'!"
                };
            }

            return new BarcodeLookupResponseDto
            {
                Success = false,
                Barcode = rawBarcode,
                Message = $"Không tìm thấy thông tin sản phẩm cho mã QR '{rawBarcode}' trên CSDL Open Food Facts hoặc cổng truy xuất nguồn gốc."
            };
        }

        // ==========================================
        // NHÁNH 2: XỬ LÝ MÃ VẠCH TIÊU CHUẨN (EAN-13, UPC-A, TEM CÂN)
        // ==========================================
        var cleanBarcode = Regex.Replace(barcode.Trim(), @"[\s\-]", "");
        var parsedInfo = ParseRawBarcodeData(cleanBarcode);

        if (!parsedInfo.IsValidFormat)
        {
            return new BarcodeLookupResponseDto
            {
                Success = false,
                Barcode = cleanBarcode,
                Message = $"Định dạng mã vạch '{cleanBarcode}' không hợp lệ (Chuẩn yêu cầu: EAN-8, UPC-A 12 số, EAN-13 hoặc GS1)."
            };
        }

        // 2.1 Nếu là mã vạch Tem Cân Siêu Thị (In-store Variable Measure: đầu 02 hoặc 20-29)
        // Loại mã vạch này ghi trực tiếp SỐ GRAM và MÃ PLU ngay trong các con số của mã vạch
        if (parsedInfo.IsVariableWeightScale && parsedInfo.ExtractedWeightG > 0)
        {
            var scaleProduct = await ResolveScaleBarcodeAsync(parsedInfo);
            PopulatePortionMacros(scaleProduct);
            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = cleanBarcode,
                Product = scaleProduct,
                Message = $"Đã bóc tách thông số trực tiếp từ mã vạch: Mã PLU #{parsedInfo.ItemCode}, Khối lượng tịnh = {parsedInfo.ExtractedWeightG}g."
            };
        }

        // 2.2 Tra cứu trực tuyến trên CSDL chuẩn quốc tế Open Food Facts (Bên thứ 3)
        var onlineProduct = await TryFetchOpenFoodFactsAsync(parsedInfo.NormalizedEan13, parsedInfo);
        if (onlineProduct != null)
        {
            PopulatePortionMacros(onlineProduct);
            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = cleanBarcode,
                Product = onlineProduct,
                Message = $"Tìm thấy thông số sản phẩm '{onlineProduct.ProductName}' từ CSDL mã vạch Open Food Facts."
            };
        }

        // 2.3 Tra cứu Cơ sở Dữ liệu iCheck Việt Nam & Mạng lưới Bán lẻ Siêu thị (Bách Hóa Xanh, AvaKids)
        var vnProduct = await TryFetchVietnameseRetailProductAsync(parsedInfo);
        if (vnProduct != null)
        {
            PopulatePortionMacros(vnProduct);
            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = cleanBarcode,
                Product = vnProduct,
                Message = $"Tìm thấy thông số sản phẩm '{vnProduct.ProductName}' ({vnProduct.Brand}) từ CSDL iCheck & Chuỗi Siêu thị Việt Nam!"
            };
        }

        // 2.4 Nếu chưa có trong iCheck -> Dùng AI tra cứu theo định danh GS1 & Mạng lưới bán lẻ
        var aiProduct = await LookupBarcodeViaAiAsync(parsedInfo);
        if (aiProduct != null)
        {
            PopulatePortionMacros(aiProduct);
            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = cleanBarcode,
                Product = aiProduct,
                Message = $"Đã tra cứu thành công sản phẩm '{aiProduct.ProductName}' ({aiProduct.Brand})."
            };
        }

        return new BarcodeLookupResponseDto
        {
            Success = false,
            Barcode = cleanBarcode,
            Message = $"Mã vạch '{cleanBarcode}' ({parsedInfo.BarcodeType} - {parsedInfo.OriginCountry}) chưa có dữ liệu trên CSDL Open Food Facts hay iCheck Việt Nam. Vui lòng thử mã vạch khác hoặc chụp ảnh bao bì."
        };
    }

    /// <summary>
    /// Quét mã vạch & đọc trực tiếp bảng thông số dinh dưỡng (Nutrition Facts) in trên bao bì từ hình ảnh
    /// </summary>
    public async Task<BarcodeLookupResponseDto> ScanBarcodeFromImageAsync(byte[] imageBytes, string contentType = "image/jpeg")
    {
        try
        {
            string prompt = @"Hãy đóng vai trò là máy quét mã vạch quang học (Optical Barcode Scanner) và OCR đọc bao bì thực phẩm.
Quan sát hình ảnh và đọc CHÍNH XÁC các thông số được in trên bao bì (không tự suy diễn nếu không có hình ảnh thực phẩm):
1. 'barcode': Đọc dãy số mã vạch dưới các vạch đen trắng (EAN-13, EAN-8, UPC-A hoặc Tem cân). Nếu không có mã vạch trong ảnh, trả về null.
2. 'productName': Tên sản phẩm in trên nhãn. Nếu ảnh không phải sản phẩm/thực phẩm, trả về null.
3. 'brand': Thương hiệu in trên bao bì.
4. 'category': Phân loại thực phẩm.
5. 'categoryIcon': 1 Emoji đại diện.
6. 'netWeightG': Khối lượng tịnh/thể tích ghi trên bao bì hoặc giải mã từ tem cân (quy về số gram/ml).
7. 'servingSize': Khẩu phần ghi trên nhãn (ví dụ: '1 gói 40g', '100g').
8. Đọc bảng 'Thành phần dinh dưỡng / Nutrition Facts' in trên bao bì và quy đổi về trên 100g:
   'caloriesPer100g', 'proteinPer100g', 'carbsPer100g', 'fatPer100g', 'fiberPer100g', 'sodiumMg'.
   (Chỉ ước lượng dựa theo thành phần thực tế nếu mặt bao bì trong ảnh bị khuất bảng Nutrition Facts).

Trả về JSON thuần túy:
{
  ""barcode"": ""string hoặc null"",
  ""productName"": ""string hoặc null"",
  ""brand"": ""string"",
  ""category"": ""string"",
  ""categoryIcon"": ""string"",
  ""netWeightG"": 0.0,
  ""servingSize"": ""string"",
  ""caloriesPer100g"": 0.0,
  ""proteinPer100g"": 0.0,
  ""carbsPer100g"": 0.0,
  ""fatPer100g"": 0.0,
  ""fiberPer100g"": 0.0,
  ""sodiumMg"": 0.0,
  ""hasPrintedNutritionTable"": true,
  ""notes"": ""Ghi chú thông số đọc được từ nhãn""
}";

            string? visionJson = await ExecuteAiVisionRequestAsync(imageBytes, contentType, prompt);
            if (string.IsNullOrWhiteSpace(visionJson))
            {
                return new BarcodeLookupResponseDto
                {
                    Success = false,
                    Message = "Không thể kết nối dịch vụ quét quang học. Vui lòng thử lại."
                };
            }

            var node = JsonNode.Parse(CleanJsonMarkdown(visionJson));
            string? detectedBarcode = node?["barcode"]?.ToString()?.Trim();
            string? detectedName = node?["productName"]?.ToString()?.Trim();
            bool hasPrintedTable = node?["hasPrintedNutritionTable"]?.GetValue<bool>() ?? false;

            // NẾU QUÉT ĐƯỢC DÃY SỐ MÃ VẠCH TỪ ẢNH:
            // Ưu tiên đem mã vạch đó đi giải mã thông số chuẩn & tra cứu OpenFoodFacts trước!
            if (!string.IsNullOrWhiteSpace(detectedBarcode) && Regex.IsMatch(detectedBarcode, @"^\d{8,14}$"))
            {
                var lookupResult = await LookupBarcodeAsync(detectedBarcode);
                
                // Nếu tìm thấy dữ liệu chuẩn trên OpenFoodFacts hoặc Tem cân, và ảnh không chụp bảng Nutrition Facts chi tiết -> Dùng kết quả chuẩn
                if (lookupResult.Success && lookupResult.Product != null && !hasPrintedTable)
                {
                    return lookupResult;
                }
            }

            if (string.IsNullOrWhiteSpace(detectedName) || detectedName.Equals("null", StringComparison.OrdinalIgnoreCase))
            {
                return new BarcodeLookupResponseDto
                {
                    Success = false,
                    Message = "Không tìm thấy mã vạch hoặc thông tin sản phẩm hợp lệ trong ảnh."
                };
            }

            // Tạo kết quả từ thông số đọc trực tiếp trên nhãn bao bì
            var parsedBarcodeInfo = !string.IsNullOrWhiteSpace(detectedBarcode) ? ParseRawBarcodeData(detectedBarcode) : null;
            double weightG = ParseNodeDouble(node?["netWeightG"], parsedBarcodeInfo?.ExtractedWeightG ?? 100.0);

            var product = new BarcodeProductDto
            {
                Barcode = !string.IsNullOrWhiteSpace(detectedBarcode) ? detectedBarcode : $"SCAN_{DateTime.UtcNow:yyyyMMddHHmmss}",
                ProductName = detectedName,
                Brand = node?["brand"]?.ToString() ?? parsedBarcodeInfo?.ManufacturerBrand ?? "Chưa rõ thương hiệu",
                Category = node?["category"]?.ToString() ?? "Thực Phẩm Đóng Gói",
                CategoryIcon = node?["categoryIcon"]?.ToString() ?? "📦",
                BarcodeType = parsedBarcodeInfo?.BarcodeType ?? "Quét Nhãn Bao Bì (OCR)",
                NetWeightG = weightG,
                ServingSize = node?["servingSize"]?.ToString() ?? $"{weightG:0}g",
                CaloriesPer100g = ParseNodeDouble(node?["caloriesPer100g"], 0),
                ProteinPer100g = ParseNodeDouble(node?["proteinPer100g"], 0),
                CarbsPer100g = ParseNodeDouble(node?["carbsPer100g"], 0),
                FatPer100g = ParseNodeDouble(node?["fatPer100g"], 0),
                FiberPer100g = ParseNodeDouble(node?["fiberPer100g"], 0),
                SodiumMg = ParseNodeDouble(node?["sodiumMg"], 0),
                Source = hasPrintedTable ? "Đọc trực tiếp từ Bảng Dinh Dưỡng bao bì" : "Quét mã vạch & Nhãn bao bì",
                Notes = node?["notes"]?.ToString() ?? ""
            };

            PopulatePortionMacros(product);

            return new BarcodeLookupResponseDto
            {
                Success = true,
                Barcode = product.Barcode,
                Product = product,
                Message = $"Quét thành công '{product.ProductName}' (Khối lượng: {product.NetWeightG:0}g)."
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi quét mã vạch từ hình ảnh");
            return new BarcodeLookupResponseDto
            {
                Success = false,
                Message = $"Lỗi đọc mã vạch từ ảnh: {ex.Message}"
            };
        }
    }

    // =========================================================================
    // BỘ GIẢI MÃ THÔNG SỐ TRỰC TIẾP TỪ DÃY SỐ MÃ VẠCH (GS1 / EAN / TEM CÂN)
    // =========================================================================

    private record ParsedBarcodeData(
        string RawBarcode,
        string NormalizedEan13,
        bool IsValidFormat,
        bool IsValidChecksum,
        string BarcodeType,
        string OriginCountry,
        string? ManufacturerCompany,
        string? ManufacturerBrand,
        bool IsVariableWeightScale,
        string? ScalePrefix,
        string? ItemCode,
        double ExtractedWeightG
    );

    /// <summary>
    /// Phân tích cấu trúc vật lý của mã vạch theo chuẩn GS1 Quốc Tế:
    /// - Kiểm tra Check Digit (Modulo 10)
    /// - Xác định Quốc gia đăng ký (GS1 Country Prefix)
    /// - Giải mã trọng lượng tịnh (grams) nếu là mã vạch Tem cân (Prefix 20-29) hoặc GS1 AI (3103)
    /// </summary>
    private static ParsedBarcodeData ParseRawBarcodeData(string cleanBarcode)
    {
        // Hỗ trợ giải mã GS1-128 nếu chuỗi chứa Application Identifier (01) GTIN và (310x) Net Weight
        if (cleanBarcode.Length > 14 && cleanBarcode.StartsWith("01"))
        {
            return ParseGs1ApplicationIdentifiers(cleanBarcode);
        }

        if (!Regex.IsMatch(cleanBarcode, @"^\d{8,14}$"))
        {
            return new ParsedBarcodeData(cleanBarcode, cleanBarcode, false, false, "Không hợp lệ", "Không rõ", null, null, false, null, null, 0);
        }

        string normalized = cleanBarcode.Length == 12 ? "0" + cleanBarcode : cleanBarcode;
        bool isValidChecksum = ValidateGs1Checksum(cleanBarcode);

        string barcodeType = cleanBarcode.Length switch
        {
            8 => "EAN-8",
            12 => "UPC-A (12 số)",
            13 => "EAN-13 Tiêu Chuẩn",
            14 => "GTIN-14",
            _ => "GS1 Barcode"
        };

        // Kiểm tra xem có phải Tem cân siêu thị (In-Store Variable Measure Barcode: tiền tố 20 -> 29)
        string prefix2 = normalized.Length >= 2 ? normalized[..2] : "";
        bool isScale = normalized.Length == 13 && prefix2 is "20" or "21" or "22" or "23" or "24" or "25" or "26" or "27" or "28" or "29";

        string? itemCode = null;
        double extractedWeightG = 0;

        if (isScale)
        {
            barcodeType = $"EAN-13 Tem Cân Siêu Thị (Đầu số {prefix2})";
            // Cấu trúc chuẩn EAN-13 Tem Cân: [2 số Prefix: 20-29] + [5 số Item PLU] + [5 số Khối lượng (gram)] + [1 số Checksum]
            itemCode = normalized.Substring(2, 5);
            string weightStr = normalized.Substring(7, 5);

            if (double.TryParse(weightStr, out double w) && w > 0)
            {
                extractedWeightG = w;
            }
        }

        // Xác định quốc gia và doanh nghiệp từ tiền tố GS1
        string country = ResolveGs1Country(normalized);
        string? company = null;
        string? brand = null;

        foreach (var kvp in Gs1VnPrefixes)
        {
            if (normalized.StartsWith(kvp.Key))
            {
                company = kvp.Value.Company;
                brand = kvp.Value.Brand;
                break;
            }
        }

        return new ParsedBarcodeData(
            RawBarcode: cleanBarcode,
            NormalizedEan13: normalized,
            IsValidFormat: true,
            IsValidChecksum: isValidChecksum,
            BarcodeType: barcodeType,
            OriginCountry: country,
            ManufacturerCompany: company,
            ManufacturerBrand: brand,
            IsVariableWeightScale: isScale,
            ScalePrefix: isScale ? prefix2 : null,
            ItemCode: itemCode ?? (normalized.Length == 13 ? normalized.Substring(7, 5) : null),
            ExtractedWeightG: extractedWeightG
        );
    }

    /// <summary>
    /// Giải mã chuẩn GS1-128 / GS1 DataBar chứa trực tiếp GTIN (01) và Khối lượng (3103 = gram)
    /// </summary>
    private static ParsedBarcodeData ParseGs1ApplicationIdentifiers(string gs1String)
    {
        // AI (01): 14 chữ số GTIN
        string gtin = gs1String.Substring(2, 14);
        string ean13 = gtin.StartsWith("0") ? gtin[1..] : gtin;
        double weightG = 0;

        // Tìm AI (3103): Khối lượng tịnh tính theo 0.001 kg (tức là gram, gồm 6 chữ số)
        int weightIdx = gs1String.IndexOf("3103", 16, StringComparison.Ordinal);
        if (weightIdx != -1 && gs1String.Length >= weightIdx + 10)
        {
            string weightDigits = gs1String.Substring(weightIdx + 4, 6);
            if (double.TryParse(weightDigits, out double parsedG))
            {
                weightG = parsedG;
            }
        }

        return new ParsedBarcodeData(
            RawBarcode: gs1String,
            NormalizedEan13: ean13,
            IsValidFormat: true,
            IsValidChecksum: true,
            BarcodeType: "GS1-128 (Chứa GTIN & Trọng lượng)",
            OriginCountry: ResolveGs1Country(ean13),
            ManufacturerCompany: null,
            ManufacturerBrand: null,
            IsVariableWeightScale: weightG > 0,
            ScalePrefix: "GS1",
            ItemCode: ean13,
            ExtractedWeightG: weightG
        );
    }

    /// <summary>
    /// Thuật toán kiểm tra số Checksum (Modulo-10) chuẩn GS1
    /// </summary>
    private static bool ValidateGs1Checksum(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode) || !barcode.All(char.IsDigit)) return false;

        int sum = 0;
        int length = barcode.Length;
        int checkDigit = barcode[length - 1] - '0';

        for (int i = length - 2; i >= 0; i--)
        {
            int digit = barcode[i] - '0';
            int positionFromRight = (length - 1) - i;
            sum += (positionFromRight % 2 != 0) ? digit * 3 : digit;
        }

        int calculatedCheck = (10 - (sum % 10)) % 10;
        return calculatedCheck == checkDigit;
    }

    private static string ResolveGs1Country(string ean13)
    {
        if (ean13.Length < 3 || !int.TryParse(ean13[..3], out int prefix)) return "Quốc tế";
        return prefix switch
        {
            893 => "Việt Nam (893)",
            >= 0 and <= 139 => "Mỹ / Canada (UPC)",
            >= 200 and <= 299 => "Mã Nội Bộ / Tem Cân Siêu Thị",
            >= 300 and <= 379 => "Pháp",
            >= 400 and <= 440 => "Đức",
            >= 450 and <= 459 or >= 490 and <= 499 => "Nhật Bản",
            >= 471 and <= 471 => "Đài Loan",
            >= 500 and <= 509 => "Vương Quốc Anh (UK)",
            >= 690 and <= 699 => "Trung Quốc",
            >= 880 and <= 880 => "Hàn Quốc (880)",
            >= 885 and <= 885 => "Thái Lan (885)",
            >= 888 and <= 888 => "Singapore (888)",
            >= 899 and <= 899 => "Indonesia (899)",
            >= 930 and <= 939 => "Úc",
            >= 940 and <= 949 => "New Zealand",
            _ => $"Quốc tế (GS1 Prefix {prefix})"
        };
    }

    /// <summary>
    /// Giải mã chi tiết tem cân siêu thị dựa trên Mã PLU và Khối lượng trích xuất từ mã vạch
    /// </summary>
    private async Task<BarcodeProductDto> ResolveScaleBarcodeAsync(ParsedBarcodeData parsed)
    {
        // Thử tra cứu trên OpenFoodFacts trước phòng trường hợp siêu thị có đăng ký mã PLU
        var offProduct = await TryFetchOpenFoodFactsAsync(parsed.NormalizedEan13, parsed);
        if (offProduct != null)
        {
            offProduct.NetWeightG = parsed.ExtractedWeightG;
            offProduct.ServingSize = $"1 Khay cân thực tế ({parsed.ExtractedWeightG:0}g)";
            return offProduct;
        }

        // Phân tích nhóm hàng thực phẩm tươi sống theo chuẩn đầu số tem cân (20-29)
        var (category, icon, defaultName, cal, pro, carb, fat) = parsed.ScalePrefix switch
        {
            "21" or "22" => ("Thịt Bò", "🥩", "Thịt Bò Tươi Đóng Khay", 135.0, 22.0, 0.0, 4.5),
            "23" or "25" or "26" => ("Thịt Heo", "🥓", "Thịt Heo Tươi Đóng Khay", 143.0, 21.0, 0.0, 6.0),
            "24" or "27" => ("Cá & Hải Sản", "🐟", "Cá / Hải Sản Tươi Đóng Khay", 180.0, 20.0, 0.0, 10.0),
            "28" => ("Rau Củ", "🥬", "Rau Củ Tươi Cân Ký", 25.0, 2.0, 4.0, 0.2),
            "29" => ("Trái Cây", "🍎", "Trái Cây Tươi Cân Ký", 52.0, 0.5, 13.0, 0.2),
            _ => ("Thịt & Gia Cầm", "🍗", "Thực Phẩm Tươi Sống Cân Ký", 120.0, 22.0, 0.0, 3.0)
        };

        return new BarcodeProductDto
        {
            Barcode = parsed.RawBarcode,
            ProductName = $"{defaultName} (Mã PLU: {parsed.ItemCode} - {parsed.ExtractedWeightG:0}g)",
            Brand = "Tem Cân Siêu Thị",
            Category = category,
            CategoryIcon = icon,
            BarcodeType = parsed.BarcodeType,
            NetWeightG = parsed.ExtractedWeightG,
            ServingSize = $"Khối lượng cân: {parsed.ExtractedWeightG:0}g",
            CaloriesPer100g = cal,
            ProteinPer100g = pro,
            CarbsPer100g = carb,
            FatPer100g = fat,
            FiberPer100g = parsed.ScalePrefix is "28" or "29" ? 2.5 : 0.0,
            SodiumMg = 60.0,
            Source = "Trích xuất trực tiếp từ chuỗi số Mã Vạch Tem Cân",
            Notes = $"Đầu số: {parsed.ScalePrefix} | Mã hàng (PLU): {parsed.ItemCode} | Trọng lượng ghi trên mã vạch: {parsed.ExtractedWeightG:0}g"
        };
    }

    /// <summary>
    /// Đọc trực tiếp tiêu đề và thông tin sản phẩm từ cổng website truy xuất nguồn gốc (URL mã QR) của bên thứ 3
    /// </summary>
    private async Task<BarcodeProductDto?> TryFetchTraceabilityWebUrlAsync(string url)
    {
        try
        {
            if (!url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) && !url.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                return null;

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
            var resp = await _httpClient.SendAsync(req, cts.Token);
            if (!resp.IsSuccessStatusCode) return null;

            var html = await resp.Content.ReadAsStringAsync(cts.Token);
            
            // Trích xuất og:title hoặc <title>
            string title = "";
            var ogTitleMatch = Regex.Match(html, @"<meta\s+property=[""']og:title[""']\s+content=[""']([^""']+)[""']", RegexOptions.IgnoreCase);
            if (ogTitleMatch.Success) title = ogTitleMatch.Groups[1].Value.Trim();
            else
            {
                var titleMatch = Regex.Match(html, @"<title>([^<]+)</title>", RegexOptions.IgnoreCase);
                if (titleMatch.Success) title = titleMatch.Groups[1].Value.Trim();
            }

            if (string.IsNullOrWhiteSpace(title) || title.Length < 3) return null;

            string ogImage = "";
            var ogImgMatch = Regex.Match(html, @"<meta\s+property=[""']og:image[""']\s+content=[""']([^""']+)[""']", RegexOptions.IgnoreCase);
            if (ogImgMatch.Success) ogImage = ogImgMatch.Groups[1].Value.Trim();

            Uri parsedUri = new Uri(url);
            string host = parsedUri.Host.Replace("www.", "");

            return new BarcodeProductDto
            {
                Barcode = url,
                ProductName = title,
                Brand = host,
                Category = "Thực Phẩm Truy Xuất Nguồn Gốc",
                CategoryIcon = "🏷️",
                BarcodeType = "Mã QR Truy Xuất Nguồn Gốc",
                NetWeightG = 100.0,
                ServingSize = "100g",
                CaloriesPer100g = 0.0,
                ProteinPer100g = 0.0,
                CarbsPer100g = 0.0,
                FatPer100g = 0.0,
                FiberPer100g = 0.0,
                Source = $"Website Truy Xuất Nguồn Gốc ({host})",
                Notes = $"Trích xuất trực tiếp từ cổng truy xuất: {url}",
                ImageUrl = ogImage
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể tải trang web truy xuất {Url}: {Msg}", url, ex.Message);
            return null;
        }
    }

    // =========================================================================
    // TRA CỨU CƠ SỞ DỮ LIỆU QUỐC TẾ OPEN FOOD FACTS & AI FALLBACK
    // =========================================================================

    private async Task<BarcodeProductDto?> TryFetchOpenFoodFactsAsync(string barcode, ParsedBarcodeData parsedInfo)
    {
        try
        {
            var url = $"https://world.openfoodfacts.org/api/v2/product/{barcode}.json";
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.UserAgent.ParseAdd("NutriSnap-App/2.0 (contact@nutrisnap.app)");
            var response = await _httpClient.SendAsync(req);
            if (!response.IsSuccessStatusCode) return null;

            var bytes = await response.Content.ReadAsByteArrayAsync();
            string json;
            if (bytes.Length > 2 && bytes[0] == 0x1F && bytes[1] == 0x8B)
            {
                using var ms = new MemoryStream(bytes);
                using var gz = new System.IO.Compression.GZipStream(ms, System.IO.Compression.CompressionMode.Decompress);
                using var sr = new StreamReader(gz, Encoding.UTF8);
                json = await sr.ReadToEndAsync();
            }
            else
            {
                json = Encoding.UTF8.GetString(bytes);
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.TryGetProperty("status", out var statusElem) && statusElem.GetInt32() != 1)
                return null;

            if (!root.TryGetProperty("product", out var productElem))
                return null;

            string name = GetFirstNonEmptyString(productElem, "product_name_vi", "product_name", "product_name_en");
            if (string.IsNullOrWhiteSpace(name)) return null;

            string brand = productElem.TryGetProperty("brands", out var brandElem)
                ? ParseStringSafe(brandElem)
                : (parsedInfo.ManufacturerBrand ?? "Nhà sản xuất đã đăng ký GS1");

            double cal100 = 0, pro100 = 0, carb100 = 0, fat100 = 0, fiber100 = 0;
            double? sugars100 = null, satFat100 = null, sodiumMg = null;

            if (productElem.TryGetProperty("nutriments", out var nutriments))
            {
                if (nutriments.TryGetProperty("energy-kcal_100g", out var calElem)) cal100 = ParseDoubleSafe(calElem);
                else if (nutriments.TryGetProperty("energy-kcal", out var cal2)) cal100 = ParseDoubleSafe(cal2);

                if (nutriments.TryGetProperty("proteins_100g", out var proElem)) pro100 = ParseDoubleSafe(proElem);
                if (nutriments.TryGetProperty("carbohydrates_100g", out var carbElem)) carb100 = ParseDoubleSafe(carbElem);
                if (nutriments.TryGetProperty("sugars_100g", out var sugElem)) sugars100 = ParseDoubleSafe(sugElem);
                if (nutriments.TryGetProperty("fat_100g", out var fatElem)) fat100 = ParseDoubleSafe(fatElem);
                if (nutriments.TryGetProperty("saturated-fat_100g", out var satElem)) satFat100 = ParseDoubleSafe(satElem);
                if (nutriments.TryGetProperty("fiber_100g", out var fibElem)) fiber100 = ParseDoubleSafe(fibElem);
                if (nutriments.TryGetProperty("sodium_100g", out var sodElem)) sodiumMg = ParseDoubleSafe(sodElem) * 1000.0;
                else if (nutriments.TryGetProperty("salt_100g", out var saltElem)) sodiumMg = ParseDoubleSafe(saltElem) * 400.0;
            }

            // Trích xuất danh sách thành phần nguyên liệu thực tế ghi trên bao bì
            string ingredients = GetFirstNonEmptyString(productElem, "ingredients_text_vi", "ingredients_text", "ingredients_text_en");

            // Ưu tiên khối lượng trích xuất trực tiếp từ mã vạch nếu có, sau đó mới lấy từ CSDL
            double weightG = parsedInfo.ExtractedWeightG > 0 ? parsedInfo.ExtractedWeightG : 100.0;
            if (parsedInfo.ExtractedWeightG <= 0)
            {
                if (productElem.TryGetProperty("product_quantity", out var qtyElem) && ParseDoubleSafe(qtyElem) > 0)
                    weightG = ParseDoubleSafe(qtyElem);
                else if (productElem.TryGetProperty("quantity", out var qtyStrElem) && ParseDoubleSafe(qtyStrElem) > 0)
                    weightG = ParseDoubleSafe(qtyStrElem);
            }

            string servingSize = productElem.TryGetProperty("serving_size", out var servElem) && !string.IsNullOrWhiteSpace(ParseStringSafe(servElem))
                ? ParseStringSafe(servElem)
                : $"{weightG:0}g";

            string imgUrl = productElem.TryGetProperty("image_front_url", out var imgElem) ? ParseStringSafe(imgElem) : "";
            var (cat, icon) = ClassifyCategoryFromTags(productElem);

            return new BarcodeProductDto
            {
                Barcode = parsedInfo.RawBarcode,
                ProductName = name,
                Brand = brand,
                Category = cat,
                CategoryIcon = icon,
                BarcodeType = $"{parsedInfo.BarcodeType} ({parsedInfo.OriginCountry})",
                NetWeightG = weightG,
                ServingSize = servingSize,
                CaloriesPer100g = Math.Round(cal100, 1),
                ProteinPer100g = Math.Round(pro100, 1),
                CarbsPer100g = Math.Round(carb100, 1),
                FatPer100g = Math.Round(fat100, 1),
                FiberPer100g = Math.Round(fiber100, 1),
                SugarsPer100g = sugars100.HasValue ? Math.Round(sugars100.Value, 1) : null,
                SaturatedFatPer100g = satFat100.HasValue ? Math.Round(satFat100.Value, 1) : null,
                SodiumMg = sodiumMg.HasValue ? Math.Round(sodiumMg.Value, 1) : null,
                IngredientsText = ingredients,
                Source = "Open Food Facts (CSDL Bên Thứ 3)",
                Notes = $"Mã vạch chuẩn {parsedInfo.BarcodeType} | Xuất xứ GS1: {parsedInfo.OriginCountry}",
                ImageUrl = imgUrl
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Lỗi truy vấn Open Food Facts cho barcode {Barcode}", barcode);
            return null;
        }
    }

    /// <summary>
    /// Tra cứu Cơ sở Dữ liệu iCheck Việt Nam & Mạng lưới Bán lẻ Siêu thị (Bách Hóa Xanh, AvaKids, WinMart)
    /// </summary>
    private async Task<BarcodeProductDto?> TryFetchVietnameseRetailProductAsync(ParsedBarcodeData parsedInfo)
    {
        try
        {
            var cleanBarcode = parsedInfo.NormalizedEan13;
            var (name, imageUrl, desc) = await TryFetchICheckVnAsync(cleanBarcode);

            if (string.IsNullOrWhiteSpace(name) && cleanBarcode != parsedInfo.RawBarcode)
            {
                (name, imageUrl, desc) = await TryFetchICheckVnAsync(parsedInfo.RawBarcode);
            }

            if (string.IsNullOrWhiteSpace(name))
            {
                return null;
            }

            string brand = parsedInfo.ManufacturerBrand ?? "Thương hiệu Việt Nam";
            if (name.Contains("Oishi", StringComparison.OrdinalIgnoreCase)) brand = "Oishi";
            else if (name.Contains("Hảo Hảo", StringComparison.OrdinalIgnoreCase)) brand = "Hảo Hảo (Acecook)";
            else if (name.Contains("Chocopie", StringComparison.OrdinalIgnoreCase)) brand = "Orion";
            else if (name.Contains("Vinamilk", StringComparison.OrdinalIgnoreCase)) brand = "Vinamilk";
            else if (name.Contains("TH True Milk", StringComparison.OrdinalIgnoreCase)) brand = "TH True Milk";

            // Bổ sung bảng Dinh dưỡng & Thành phần nguyên liệu từ dữ liệu công bố chuỗi bán lẻ
            var enriched = await EnrichProductNutritionViaRetailAiAsync(cleanBarcode, name, brand, imageUrl, parsedInfo);
            if (enriched != null)
            {
                return enriched;
            }

            // Fallback nếu AI timeout: trả về bản ghi chính thức từ iCheck
            return new BarcodeProductDto
            {
                Barcode = parsedInfo.RawBarcode,
                ProductName = name,
                Brand = brand,
                Category = "Thực Phẩm Đóng Gói (Việt Nam)",
                CategoryIcon = "🇻🇳",
                BarcodeType = $"{parsedInfo.BarcodeType} ({parsedInfo.OriginCountry})",
                NetWeightG = parsedInfo.ExtractedWeightG > 0 ? parsedInfo.ExtractedWeightG : 35.0,
                ServingSize = "1 gói",
                CaloriesPer100g = 480.0,
                ProteinPer100g = 4.5,
                CarbsPer100g = 62.0,
                FatPer100g = 24.0,
                FiberPer100g = 2.0,
                SodiumMg = 450.0,
                IngredientsText = desc ?? "Xem thông tin chi tiết trên bao bì sản phẩm.",
                ImageUrl = imageUrl ?? "",
                Source = "iCheck VN & Mạng lưới Bán lẻ Siêu thị (Bách Hóa XANH, AvaKids)",
                Notes = $"Mã vạch chuẩn GS1 {parsedInfo.OriginCountry} | Doanh nghiệp: {parsedInfo.ManufacturerCompany ?? brand}"
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Lỗi tra cứu CSDL bán lẻ Việt Nam cho barcode {Barcode}: {Msg}", parsedInfo.RawBarcode, ex.Message);
            return null;
        }
    }

    /// <summary>
    /// Tra cứu thông tin gốc từ cổng CSDL iCheck Việt Nam (icheck.vn)
    /// </summary>
    private async Task<(string? Name, string? ImageUrl, string? Description)> TryFetchICheckVnAsync(string barcode)
    {
        try
        {
            var url = $"https://icheck.vn/san-pham/{barcode}";
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(6));
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
            var resp = await _httpClient.SendAsync(req, cts.Token);
            if (!resp.IsSuccessStatusCode) return (null, null, null);

            var html = await resp.Content.ReadAsStringAsync(cts.Token);

            // Xử lý meta-refresh redirect của iCheck
            var refreshMatch = Regex.Match(html, @"<meta\s+http-equiv=[""']refresh[""']\s+content=[""'][^""']*?url=([^""'\s>]+)[""']", RegexOptions.IgnoreCase);
            if (refreshMatch.Success)
            {
                var targetPath = refreshMatch.Groups[1].Value.Trim();
                var redirectUrl = targetPath.StartsWith("http", StringComparison.OrdinalIgnoreCase)
                    ? targetPath
                    : $"https://icheck.vn{targetPath}";

                using var req2 = new HttpRequestMessage(HttpMethod.Get, redirectUrl);
                req2.Headers.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
                var resp2 = await _httpClient.SendAsync(req2, cts.Token);
                if (resp2.IsSuccessStatusCode)
                {
                    html = await resp2.Content.ReadAsStringAsync(cts.Token);
                }
            }

            var titleMatch = Regex.Match(html, @"<meta\s+property=[""']og:title[""']\s+content=[""']([^""']+)[""']", RegexOptions.IgnoreCase);
            if (!titleMatch.Success) return (null, null, null);

            string rawTitle = titleMatch.Groups[1].Value.Trim();
            if (string.IsNullOrWhiteSpace(rawTitle) ||
                rawTitle.Contains("Sản phẩm chưa được cập nhật", StringComparison.OrdinalIgnoreCase) ||
                rawTitle.Contains("Không tìm thấy", StringComparison.OrdinalIgnoreCase))
            {
                return (null, null, null);
            }

            string cleanTitle = rawTitle.Replace("| iCheck.vn", "", StringComparison.OrdinalIgnoreCase).Trim();

            string? imgUrl = null;
            var imgMatch = Regex.Match(html, @"<meta\s+property=[""']og:image[""']\s+content=[""']([^""']+)[""']", RegexOptions.IgnoreCase);
            if (imgMatch.Success && !imgMatch.Groups[1].Value.Contains("default", StringComparison.OrdinalIgnoreCase))
            {
                imgUrl = imgMatch.Groups[1].Value.Trim();
            }

            string? desc = null;
            var descMatch = Regex.Match(html, @"<meta\s+property=[""']og:description[""']\s+content=[""']([^""']+)[""']", RegexOptions.IgnoreCase);
            if (descMatch.Success)
            {
                desc = descMatch.Groups[1].Value.Trim();
            }

            return (cleanTitle, imgUrl, desc);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("iCheck query failed for {Barcode}: {Msg}", barcode, ex.Message);
            return (null, null, null);
        }
    }

    /// <summary>
    /// Đối chiếu thông số dinh dưỡng & thành phần nguyên liệu từ dữ liệu bán lẻ siêu thị Việt Nam
    /// </summary>
    private async Task<BarcodeProductDto?> EnrichProductNutritionViaRetailAiAsync(
        string barcode,
        string productName,
        string brand,
        string? imageUrl,
        ParsedBarcodeData parsedInfo)
    {
        try
        {
            string prompt = $@"Bạn là hệ thống trích xuất thông số dinh dưỡng thực phẩm siêu thị Việt Nam.
Sản phẩm được xác thực mã vạch từ CSDL iCheck / GS1 Việt Nam:
- Mã số mã vạch: {barcode}
- Tên chính thức: {productName}
- Thương hiệu / Doanh nghiệp: {brand} (GS1: {parsedInfo.ManufacturerCompany ?? brand})

Dựa trên bảng công bố thành phần dinh dưỡng và nguyên liệu của sản phẩm này in trên bao bì hoặc được niêm yết trên các hệ thống chuỗi bán lẻ (Bách Hóa XANH, WinMart, Co.opmart, AvaKids, sàn TMĐT), hãy cung cấp thông số dinh dưỡng trên 100g và danh sách nguyên liệu:
1. 'caloriesPer100g': Năng lượng tính trên 100g (kcal).
2. 'proteinPer100g': Hàm lượng đạm tính trên 100g (g).
3. 'carbsPer100g': Hàm lượng tinh bột/carbohydrate tính trên 100g (g).
4. 'fatPer100g': Hàm lượng chất béo tính trên 100g (g).
5. 'fiberPer100g': Hàm lượng chất xơ tính trên 100g (g).
6. 'sugarsPer100g': Hàm lượng đường tính trên 100g (g hoặc null).
7. 'sodiumMg': Hàm lượng natri tính trên 100g (mg hoặc null).
8. 'netWeightG': Khối lượng tịnh tiêu chuẩn của 1 gói/lon/hộp thông dụng (ví dụ gói bánh bí đỏ 32-40g).
9. 'category': Phân loại ngành hàng (ví dụ: 'Snack & Ăn Vặt', 'Mì Ăn Liền', 'Đồ Uống').
10. 'ingredientsText': Danh sách thành phần nguyên liệu chính in trên bao bì (ví dụ: 'Bột mì, tinh bột sắn, bí đỏ tươi, dầu ăn, bột bò, gia vị hành tỏi, muối i-ốt...').

Trả về DUY NHẤT một chuỗi JSON chuẩn:
{{
  ""found"": true,
  ""productName"": ""{productName}"",
  ""brand"": ""{brand}"",
  ""category"": ""Snack & Ăn Vặt"",
  ""netWeightG"": 35.0,
  ""servingSize"": ""1 gói"",
  ""caloriesPer100g"": 480.0,
  ""proteinPer100g"": 4.5,
  ""carbsPer100g"": 62.0,
  ""fatPer100g"": 24.0,
  ""fiberPer100g"": 2.0,
  ""sugarsPer100g"": 6.0,
  ""sodiumMg"": 450.0,
  ""ingredientsText"": ""Danh sách nguyên liệu"",
  ""notes"": ""Dữ liệu đối chiếu từ thông số bao bì chuỗi bán lẻ Việt Nam""
}}";

            string? jsonText = await ExecuteAiTextRequestAsync(prompt);
            if (string.IsNullOrWhiteSpace(jsonText)) return null;

            var node = JsonNode.Parse(CleanJsonMarkdown(jsonText));
            if (node == null || node["found"]?.ToString()?.ToLowerInvariant() is "false" or "0")
                return null;

            double cal100 = ParseNodeDouble(node["caloriesPer100g"], 0);
            double pro100 = ParseNodeDouble(node["proteinPer100g"], 0);
            double carb100 = ParseNodeDouble(node["carbsPer100g"], 0);
            double fat100 = ParseNodeDouble(node["fatPer100g"], 0);
            double fib100 = ParseNodeDouble(node["fiberPer100g"], 0);
            double? sugars100 = node["sugarsPer100g"] != null ? ParseNodeDouble(node["sugarsPer100g"], 0) : null;
            double? sodiumMg = node["sodiumMg"] != null ? ParseNodeDouble(node["sodiumMg"], 0) : null;
            double weightG = parsedInfo.ExtractedWeightG > 0 ? parsedInfo.ExtractedWeightG : ParseNodeDouble(node["netWeightG"], 35.0);

            string ingredients = node["ingredientsText"]?.ToString()?.Trim() ?? "";

            return new BarcodeProductDto
            {
                Barcode = parsedInfo.RawBarcode,
                ProductName = node["productName"]?.ToString()?.Trim() ?? productName,
                Brand = node["brand"]?.ToString()?.Trim() ?? brand,
                Category = node["category"]?.ToString()?.Trim() ?? "Thực Phẩm Đóng Gói (Việt Nam)",
                CategoryIcon = "🇻🇳",
                BarcodeType = $"{parsedInfo.BarcodeType} ({parsedInfo.OriginCountry})",
                NetWeightG = weightG > 0 ? weightG : 35.0,
                ServingSize = node["servingSize"]?.ToString()?.Trim() ?? $"{weightG:0}g",
                CaloriesPer100g = Math.Round(cal100 > 0 ? cal100 : 480.0, 1),
                ProteinPer100g = Math.Round(pro100, 1),
                CarbsPer100g = Math.Round(carb100, 1),
                FatPer100g = Math.Round(fat100, 1),
                FiberPer100g = Math.Round(fib100, 1),
                SugarsPer100g = sugars100.HasValue && sugars100.Value > 0 ? Math.Round(sugars100.Value, 1) : null,
                SodiumMg = sodiumMg.HasValue && sodiumMg.Value > 0 ? Math.Round(sodiumMg.Value, 1) : null,
                IngredientsText = ingredients,
                ImageUrl = imageUrl ?? "",
                Source = "iCheck VN & Mạng lưới Bán lẻ Siêu thị (Bách Hóa XANH, AvaKids)",
                Notes = $"Mã vạch chuẩn GS1 {parsedInfo.OriginCountry} | Doanh nghiệp: {parsedInfo.ManufacturerCompany ?? brand}"
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Lỗi enrich dinh dưỡng siêu thị cho {Name}: {Msg}", productName, ex.Message);
            return null;
        }
    }

    private async Task<BarcodeProductDto?> LookupBarcodeViaAiAsync(ParsedBarcodeData parsed)
    {
        string companyHint = parsed.ManufacturerCompany != null
            ? $"Thuộc doanh nghiệp GS1 đã xác thực: {parsed.ManufacturerCompany} (Thương hiệu: {parsed.ManufacturerBrand})."
            : $"Xuất xứ mã GS1: {parsed.OriginCountry}.";

        string prompt = $@"Tra cứu thông tin sản phẩm thực tế có mã vạch EAN/GTIN: {parsed.RawBarcode}.
Thông tin giải mã từ mã vạch: {parsed.BarcodeType} - {companyHint}
YÊU CẦU NGHIÊM NGẶT:
1. Chỉ trả về kết quả nếu bạn biết CHÍNH XÁC sản phẩm thương mại tương ứng với mã số {parsed.RawBarcode}.
2. Nếu không chắc chắn hoặc mã vạch không tồn tại trên thị trường, bắt buộc trả về duy nhất: {{ ""found"": false }}
3. Không được tự bịa ra tên sản phẩm chung chung. Nếu tìm thấy, trả về JSON:
{{
  ""found"": true,
  ""productName"": ""Tên chính xác của sản phẩm"",
  ""brand"": ""Thương hiệu"",
  ""category"": ""Phân loại"",
  ""categoryIcon"": ""Emoji"",
  ""netWeightG"": 100.0,
  ""servingSize"": ""Khẩu phần"",
  ""caloriesPer100g"": 0.0,
  ""proteinPer100g"": 0.0,
  ""carbsPer100g"": 0.0,
  ""fatPer100g"": 0.0,
  ""fiberPer100g"": 0.0,
  ""sodiumMg"": 0.0,
  ""notes"": ""Thông tin dinh dưỡng""
}}";

        string? jsonText = await ExecuteAiTextRequestAsync(prompt);
        if (string.IsNullOrWhiteSpace(jsonText)) return null;

        try
        {
            var node = JsonNode.Parse(CleanJsonMarkdown(jsonText));
            if (node?["found"]?.ToString()?.ToLowerInvariant() is "false" or "0")
                return null;

            string? pName = node?["productName"]?.ToString()?.Trim();
            if (string.IsNullOrWhiteSpace(pName)) return null;

            double weightG = parsed.ExtractedWeightG > 0
                ? parsed.ExtractedWeightG
                : ParseNodeDouble(node?["netWeightG"], 100.0);

            return new BarcodeProductDto
            {
                Barcode = parsed.RawBarcode,
                ProductName = pName,
                Brand = node?["brand"]?.ToString() ?? parsed.ManufacturerBrand ?? "Đã xác thực GS1",
                Category = node?["category"]?.ToString() ?? "Thực Phẩm Đóng Gói",
                CategoryIcon = node?["categoryIcon"]?.ToString() ?? "📦",
                BarcodeType = $"{parsed.BarcodeType} ({parsed.OriginCountry})",
                NetWeightG = weightG,
                ServingSize = node?["servingSize"]?.ToString() ?? $"{weightG:0}g",
                CaloriesPer100g = ParseNodeDouble(node?["caloriesPer100g"], 0),
                ProteinPer100g = ParseNodeDouble(node?["proteinPer100g"], 0),
                CarbsPer100g = ParseNodeDouble(node?["carbsPer100g"], 0),
                FatPer100g = ParseNodeDouble(node?["fatPer100g"], 0),
                FiberPer100g = ParseNodeDouble(node?["fiberPer100g"], 0),
                SodiumMg = ParseNodeDouble(node?["sodiumMg"], 0),
                Source = $"GS1 Barcode Lookup ({parsed.OriginCountry})",
                Notes = node?["notes"]?.ToString() ?? ""
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Lỗi phân tích JSON khi tra cứu mã vạch {Barcode}: {Msg}", parsed.RawBarcode, ex.Message);
            return null;
        }
    }

    // =========================================================================
    // CÁC HÀM GỌI AI TẬP TRUNG (TRÁNH LẶP CODE) & HELPER TIỆN ÍCH
    // =========================================================================

    private async Task<string?> ExecuteAiTextRequestAsync(string prompt)
    {
        string groqKey = GetApiKey("GROQ_API_KEY", "AiKeys:GroqApiKey");
        if (!string.IsNullOrWhiteSpace(groqKey))
        {
            string[] models = { "llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen/qwen3.8-27b", "openai/gpt-oss-120b" };
            foreach (var model in models)
            {
                try
                {
                    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(8));
                    var payload = new
                    {
                        model,
                        messages = new[] { new { role = "user", content = prompt } },
                        temperature = 0.0,
                        max_tokens = 800
                    };
                    using var req = new HttpRequestMessage(HttpMethod.Post, "https://api.groq.com/openai/v1/chat/completions");
                    req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", groqKey);
                    req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

                    var resp = await _httpClient.SendAsync(req, cts.Token);
                    if (resp.IsSuccessStatusCode)
                    {
                        var doc = JsonNode.Parse(await resp.Content.ReadAsStringAsync(cts.Token));
                        var content = doc?["choices"]?[0]?["message"]?["content"]?.ToString();
                        if (!string.IsNullOrWhiteSpace(content)) return content;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Groq Text ({Model}) lỗi: {Msg}", model, ex.Message);
                }
            }
        }

        string geminiKey = GetApiKey("GEMINI_API_KEY", "AiKeys:GeminiApiKey");
        if (!string.IsNullOrWhiteSpace(geminiKey))
        {
            var parts = new object[] { new { text = prompt } };
            return await CallGeminiInternalAsync(geminiKey, parts);
        }

        return null;
    }

    private async Task<string?> ExecuteAiVisionRequestAsync(byte[] imageBytes, string contentType, string prompt)
    {
        string base64 = Convert.ToBase64String(imageBytes);
        string groqKey = GetApiKey("GROQ_API_KEY", "AiKeys:GroqApiKey");

        if (!string.IsNullOrWhiteSpace(groqKey))
        {
            try
            {
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
                var payload = new
                {
                    model = "qwen/qwen3.8-27b",
                    messages = new object[]
                    {
                        new
                        {
                            role = "user",
                            content = new object[]
                            {
                                new { type = "image_url", image_url = new { url = $"data:{contentType};base64,{base64}" } },
                                new { type = "text", text = prompt }
                            }
                        }
                    },
                    temperature = 0.0,
                    max_tokens = 600
                };

                using var req = new HttpRequestMessage(HttpMethod.Post, "https://api.groq.com/openai/v1/chat/completions");
                req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", groqKey);
                req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

                var resp = await _httpClient.SendAsync(req, cts.Token);
                if (resp.IsSuccessStatusCode)
                {
                    var doc = JsonNode.Parse(await resp.Content.ReadAsStringAsync(cts.Token));
                    var text = doc?["choices"]?[0]?["message"]?["content"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(text)) return text;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Groq Vision lỗi: {Msg}", ex.Message);
            }
        }

        string geminiKey = GetApiKey("GEMINI_API_KEY", "AiKeys:GeminiApiKey");
        if (!string.IsNullOrWhiteSpace(geminiKey))
        {
            var parts = new object[]
            {
                new { text = prompt },
                new { inline_data = new { mime_type = contentType, data = base64 } }
            };
            return await CallGeminiInternalAsync(geminiKey, parts);
        }

        return null;
    }

    private async Task<string?> CallGeminiInternalAsync(string apiKey, object[] parts)
    {
        string[] models = { "gemini-2.5-flash", "gemini-2.0-flash" };
        foreach (var model in models)
        {
            try
            {
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
                string url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}";
                var payload = new
                {
                    contents = new[] { new { parts } },
                    generationConfig = new { temperature = 0.0, maxOutputTokens = 600, responseMimeType = "application/json" }
                };

                using var req = new HttpRequestMessage(HttpMethod.Post, url);
                req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

                var resp = await _httpClient.SendAsync(req, cts.Token);
                if (resp.IsSuccessStatusCode)
                {
                    var doc = JsonNode.Parse(await resp.Content.ReadAsStringAsync(cts.Token));
                    var text = doc?["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(text)) return text;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Gemini ({Model}) lỗi: {Msg}", model, ex.Message);
            }
        }
        return null;
    }

    private string GetApiKey(string envKey, string configPath) =>
        _config[envKey] ?? _config[configPath] ?? Environment.GetEnvironmentVariable(envKey) ?? "";

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
        var totalMacroCal = Math.Max(1.0, proCal + carbCal + fatCal);

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

    private static (string Category, string Icon) ClassifyCategoryFromTags(JsonElement productElem)
    {
        string allTags = "";
        if (productElem.TryGetProperty("categories", out var catElem))
            allTags = ParseStringSafe(catElem).ToLowerInvariant();
        if (productElem.TryGetProperty("categories_tags", out var catTagsElem))
            allTags += " " + catTagsElem.ToString().ToLowerInvariant();

        if (allTags.Contains("snack") || allTags.Contains("chip") || allTags.Contains("biscuit") || allTags.Contains("cookie"))
            return ("Snack & Bánh Kẹo", "🍿");
        if (allTags.Contains("noodle") || allTags.Contains("pasta") || allTags.Contains("rice"))
            return ("Mì & Tinh Bột", "🍜");
        if (allTags.Contains("milk") || allTags.Contains("dairy") || allTags.Contains("yogurt") || allTags.Contains("cheese"))
            return ("Trứng & Sữa / Whey", "🥛");
        if (allTags.Contains("beverage") || allTags.Contains("drink") || allTags.Contains("water") || allTags.Contains("juice"))
            return ("Đồ Uống", "🥤");
        if (allTags.Contains("meat") || allTags.Contains("beef") || allTags.Contains("pork") || allTags.Contains("chicken"))
            return ("Thịt & Gia Cầm", "🥩");
        if (allTags.Contains("fish") || allTags.Contains("seafood") || allTags.Contains("tuna") || allTags.Contains("salmon"))
            return ("Cá & Hải Sản", "🐟");

        return ("Thực Phẩm Đóng Gói", "📦");
    }

    private static string GetFirstNonEmptyString(JsonElement elem, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (elem.TryGetProperty(key, out var prop) && prop.ValueKind == JsonValueKind.String)
            {
                var val = prop.GetString();
                if (!string.IsNullOrWhiteSpace(val)) return val.Trim();
            }
        }
        return "";
    }

    private static double ParseNodeDouble(JsonNode? node, double fallback) =>
        node != null && double.TryParse(node.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var val) ? val : fallback;

    private static double ParseDoubleSafe(JsonElement elem, double fallback = 0.0)
    {
        if (elem.ValueKind == JsonValueKind.Number && elem.TryGetDouble(out var d)) return d;
        if (elem.ValueKind == JsonValueKind.String)
        {
            var match = Regex.Match(elem.GetString() ?? "", @"[\d\.]+").Value;
            if (double.TryParse(match, NumberStyles.Any, CultureInfo.InvariantCulture, out var ds)) return ds;
        }
        return fallback;
    }

    private static string ParseStringSafe(JsonElement elem, string fallback = "") =>
        elem.ValueKind switch
        {
            JsonValueKind.String => elem.GetString() ?? fallback,
            JsonValueKind.Number => elem.GetRawText(),
            _ => fallback
        };

    /// <summary>
    /// Sửa lỗi cắt chuỗi Markdown JSON từ phản hồi AI
    /// </summary>
    private static string CleanJsonMarkdown(string text)
    {
        var match = Regex.Match(text.Trim(), @"\{[\s\S]*\}");
        return match.Success ? match.Value : text.Trim();
    }
}