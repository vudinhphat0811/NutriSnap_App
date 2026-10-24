using System.Text;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Caching.Memory;

namespace NutriSnap.Services;

public class TranslationService
{
    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly ILogger<TranslationService> _logger;

    public static readonly Dictionary<string, string> QuickDictionary = new(StringComparer.OrdinalIgnoreCase)
    {
        // Thịt & Thủy hải sản
        ["chicken"] = "Thịt gà",
        ["chicken breast"] = "Ức gà",
        ["chicken breasts"] = "Ức gà",
        ["chicken thighs"] = "Đùi gà",
        ["chicken thigh"] = "Đùi gà",
        ["chicken wings"] = "Cánh gà",
        ["chicken legs"] = "Đùi gà",
        ["chicken drumsticks"] = "Đùi gà tỏi",
        ["beef"] = "Thịt bò",
        ["minced beef"] = "Thịt bò băm",
        ["ground beef"] = "Thịt bò xay",
        ["beef steak"] = "Thịt bò bít tết",
        ["beef tenderloin"] = "Thăn nội bò",
        ["beef sirloin"] = "Thăn ngoại bò",
        ["pork"] = "Thịt heo",
        ["minced pork"] = "Thịt heo băm",
        ["ground pork"] = "Thịt heo xay",
        ["pork chops"] = "Sườn heo",
        ["pork belly"] = "Thịt ba chỉ",
        ["pork shoulder"] = "Nạc vai heo",
        ["bacon"] = "Thịt xông khói",
        ["salmon"] = "Cá hồi",
        ["salmon fillet"] = "Phi lê cá hồi",
        ["tuna"] = "Cá ngừ",
        ["cod"] = "Cá tuyết",
        ["fish"] = "Cá tươi",
        ["shrimp"] = "Tôm",
        ["shrimps"] = "Tôm",
        ["prawns"] = "Tôm sú",
        ["raw king prawns"] = "Tôm tươi",
        ["king prawns"] = "Tôm sú",
        ["tiger prawns"] = "Tôm sú",
        ["squid"] = "Mực",
        ["calamari"] = "Mực tươi",
        ["crab"] = "Cua biển",
        ["lobster"] = "Tôm hùm",
        ["egg"] = "Trứng",
        ["eggs"] = "Trứng",
        ["egg yolk"] = "Lòng đỏ trứng",
        ["egg white"] = "Lòng trắng trứng",
        ["tofu"] = "Đậu phụ",

        // Rau củ & Hành tỏi thảo mộc
        ["garlic"] = "Tỏi",
        ["garlic clove"] = "Tép tỏi",
        ["garlic cloves"] = "Tép tỏi",
        ["onion"] = "Hành tây",
        ["onions"] = "Hành tây",
        ["red onion"] = "Hành tím",
        ["red onions"] = "Hành tím",
        ["shallot"] = "Hành tím",
        ["shallots"] = "Hành tím",
        ["spring onion"] = "Hành lá",
        ["spring onions"] = "Hành lá",
        ["green onion"] = "Hành lá",
        ["green onions"] = "Hành lá",
        ["scallion"] = "Hành lá",
        ["scallions"] = "Hành lá",
        ["chives"] = "Hẹ",
        ["ginger"] = "Gừng",
        ["tomato"] = "Cà chua",
        ["tomatoes"] = "Cà chua",
        ["plum tomatoes"] = "Cà chua",
        ["cherry tomatoes"] = "Cà chua bi",
        ["potato"] = "Khoai tây",
        ["potatoes"] = "Khoai tây",
        ["sweet potato"] = "Khoai lang",
        ["sweet potatoes"] = "Khoai lang",
        ["carrot"] = "Cà rốt",
        ["carrots"] = "Cà rốt",
        ["broccoli"] = "Bông cải xanh",
        ["cauliflower"] = "Súp lơ trắng",
        ["cabbage"] = "Bắp cải",
        ["cucumber"] = "Dưa leo",
        ["mushroom"] = "Nấm tươi",
        ["mushrooms"] = "Nấm tươi",
        ["bell pepper"] = "Ớt chuông",
        ["bell peppers"] = "Ớt chuông",
        ["red pepper"] = "Ớt chuông đỏ",
        ["green pepper"] = "Ớt chuông xanh",
        ["yellow pepper"] = "Ớt chuông vàng",
        ["sweet pepper"] = "Ớt chuông",
        ["chilli"] = "Ớt cay",
        ["chili"] = "Ớt cay",
        ["chillies"] = "Ớt cay",
        ["chilies"] = "Ớt cay",
        ["chilli flakes"] = "Ớt vảy",
        ["chili flakes"] = "Ớt vảy",
        ["red pepper flakes"] = "Ớt vảy",
        ["paprika"] = "Ớt bột Paprika",
        ["smoked paprika"] = "Ớt bột hun khói Paprika",
        ["cayenne pepper"] = "Ớt bột Cayenne",
        ["coriander"] = "Rau ngò rí",
        ["coriander leaves"] = "Rau ngò rí",
        ["cilantro"] = "Rau ngò rí",
        ["parsley"] = "Ngò tây",
        ["basil"] = "Húng quế",
        ["mint"] = "Bạc hà",
        ["mint leaves"] = "Lá bạc hà",
        ["rosemary"] = "Hương thảo",
        ["thyme"] = "Xạ hương",
        ["oregano"] = "Lá kinh giới tây (Oregano)",
        ["lemongrass"] = "Sả",

        // Gia vị, Dầu ăn & Sữa
        ["salt"] = "Muối",
        ["sea salt"] = "Muối biển",
        ["pepper"] = "Tiêu",
        ["black pepper"] = "Tiêu đen",
        ["white pepper"] = "Tiêu trắng",
        ["ground black pepper"] = "Tiêu đen xay",
        ["sugar"] = "Đường",
        ["brown sugar"] = "Đường nâu",
        ["honey"] = "Mật ong",
        ["olive oil"] = "Dầu ô liu",
        ["vegetable oil"] = "Dầu thực vật",
        ["coconut oil"] = "Dầu dừa",
        ["sesame oil"] = "Dầu mè",
        ["oil"] = "Dầu ăn",
        ["water"] = "Nước",
        ["butter"] = "Bơ",
        ["flour"] = "Bột mì",
        ["cornstarch"] = "Bột bắp",
        ["corn flour"] = "Bột bắp",
        ["rice"] = "Gạo / Cơm",
        ["jasmine rice"] = "Gạo thơm",
        ["basmati rice"] = "Gạo Basmati",
        ["brown rice"] = "Gạo lứt",
        ["pasta"] = "Mì Ý / Pasta",
        ["spaghetti"] = "Mì Ý",
        ["noodles"] = "Mì / Sợi phở",
        ["soy sauce"] = "Nước tương",
        ["dark soy sauce"] = "Hắc xì dầu",
        ["fish sauce"] = "Nước mắm",
        ["oyster sauce"] = "Dầu hào",
        ["lemon"] = "Chanh vàng",
        ["lemon juice"] = "Nước cốt chanh vàng",
        ["lime"] = "Chanh xanh",
        ["lime juice"] = "Nước cốt chanh",
        ["milk"] = "Sữa tươi",
        ["coconut milk"] = "Nước cốt dừa",
        ["coconut cream"] = "Kem dừa",
        ["cheese"] = "Phô mai",
        ["parmesan"] = "Phô mai Parmesan",
        ["mozzarella"] = "Phô mai Mozzarella",
        ["cheddar cheese"] = "Phô mai Cheddar",
        ["heavy cream"] = "Kem tươi béo (Heavy Cream)",
        ["sour cream"] = "Kem chua (Sour Cream)",
        ["yogurt"] = "Sữa chua",
        ["chicken stock"] = "Nước dùng gà",
        ["chicken broth"] = "Nước hầm gà",
        ["beef stock"] = "Nước dùng bò",
        ["beef broth"] = "Nước hầm bò",
        ["vegetable stock"] = "Nước dùng rau củ",
        ["vegetable broth"] = "Nước hầm rau củ",
        ["tomato puree"] = "Sốt cà chua nhuyễn",
        ["tomato paste"] = "Cà chua cô đặc",
        ["tomato sauce"] = "Sốt cà chua",

        // Đơn vị đo cơ bản
        ["tbsp"] = "muỗng canh",
        ["tbs"] = "muỗng canh",
        ["tablespoon"] = "muỗng canh",
        ["tablespoons"] = "muỗng canh",
        ["tsp"] = "muỗng cà phê",
        ["teaspoon"] = "muỗng cà phê",
        ["teaspoons"] = "muỗng cà phê",
        ["cup"] = "chén",
        ["cups"] = "chén",
        ["g"] = "g",
        ["kg"] = "kg",
        ["ml"] = "ml",
        ["l"] = "lít",
        ["clove"] = "tép",
        ["cloves"] = "tép",
        ["pinch"] = "nhúm",
        ["pinches"] = "nhúm",
        ["to taste"] = "vừa ăn",
        ["to serve"] = "Dùng kèm",
        ["garnish"] = "Trang trí"
    };

    public TranslationService(HttpClient httpClient, IMemoryCache cache, ILogger<TranslationService> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
        _logger = logger;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36");
        _httpClient.Timeout = TimeSpan.FromSeconds(3); // Giới hạn tối đa 3s để không bao giờ làm treo ứng dụng
    }

    /// <summary>
    /// Dịch một đoạn văn bản hoặc câu từ Tiếng Anh sang Tiếng Việt (có Cache và từ điển nhanh 0ms)
    /// </summary>
    public async Task<string> TranslateAsync(string text, string targetLang = "vi", string sourceLang = "en")
    {
        if (string.IsNullOrWhiteSpace(text)) return text;
        if (targetLang.Equals(sourceLang, StringComparison.OrdinalIgnoreCase)) return text;

        string trimmed = text.Trim();

        // 1. Tra cứu nhanh từ điển (0ms)
        if (QuickDictionary.TryGetValue(trimmed, out var quickVal))
        {
            return quickVal;
        }

        // 2. Tra cứu bộ nhớ đệm Cache
        string cacheKey = $"trans_{sourceLang}_{targetLang}_{trimmed.GetHashCode()}";
        if (_cache.TryGetValue(cacheKey, out string? cached) && !string.IsNullOrEmpty(cached))
        {
            return cached;
        }

        try
        {
            string url = $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={sourceLang}&tl={targetLang}&dt=t&q={Uri.EscapeDataString(trimmed)}";
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2.5));
            var response = await _httpClient.GetStringAsync(url, cts.Token);
            var json = JsonNode.Parse(response);

            if (json is JsonArray rootArray && rootArray.Count > 0 && rootArray[0] is JsonArray sentences)
            {
                var sb = new StringBuilder();
                foreach (var s in sentences)
                {
                    if (s is JsonArray item && item.Count > 0)
                    {
                        var segment = item[0]?.ToString();
                        if (!string.IsNullOrEmpty(segment))
                        {
                            sb.Append(segment);
                        }
                    }
                }

                string translated = sb.ToString().Trim();
                if (!string.IsNullOrEmpty(translated))
                {
                    _cache.Set(cacheKey, translated, TimeSpan.FromDays(7));
                    return translated;
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Không thể dịch nhanh: {Message}", ex.Message);
        }

        return text;
    }

    /// <summary>
    /// Dịch hàng loạt danh sách chuỗi (nguyên liệu, đơn vị) gom thành 1 request duy nhất hoặc tra từ điển (siêu tốc)
    /// </summary>
    public async Task<List<string>> TranslateBatchAsync(List<string> texts, string targetLang = "vi", string sourceLang = "en")
    {
        if (texts == null || texts.Count == 0) return new List<string>();
        if (targetLang.Equals(sourceLang, StringComparison.OrdinalIgnoreCase)) return new List<string>(texts);

        var results = new string[texts.Count];
        var missingIndices = new List<int>();

        for (int i = 0; i < texts.Count; i++)
        {
            var t = texts[i];
            if (string.IsNullOrWhiteSpace(t))
            {
                results[i] = t;
                continue;
            }

            string trimmed = t.Trim();
            if (QuickDictionary.TryGetValue(trimmed, out var quick))
            {
                results[i] = quick;
                continue;
            }

            string cacheKey = $"trans_{sourceLang}_{targetLang}_{trimmed.GetHashCode()}";
            if (_cache.TryGetValue(cacheKey, out string? cached) && !string.IsNullOrEmpty(cached))
            {
                results[i] = cached;
                continue;
            }

            missingIndices.Add(i);
        }

        if (missingIndices.Count == 0)
        {
            return results.ToList();
        }

        // Dịch gộp toàn bộ các mục còn lại trong 1 request HTTP duy nhất
        try
        {
            var combinedText = string.Join("\n", missingIndices.Select(idx => texts[idx].Trim()));
            var translatedBlock = await TranslateAsync(combinedText, targetLang, sourceLang);
            var translatedLines = translatedBlock.Split('\n');

            for (int k = 0; k < missingIndices.Count; k++)
            {
                int targetIdx = missingIndices[k];
                string translatedLine = (k < translatedLines.Length && !string.IsNullOrWhiteSpace(translatedLines[k]))
                    ? translatedLines[k].Trim()
                    : texts[targetIdx];

                results[targetIdx] = translatedLine;
                string cacheKey = $"trans_{sourceLang}_{targetLang}_{texts[targetIdx].Trim().GetHashCode()}";
                _cache.Set(cacheKey, translatedLine, TimeSpan.FromDays(7));
            }
        }
        catch
        {
            foreach (var idx in missingIndices)
            {
                results[idx] = texts[idx];
            }
        }

        return results.ToList();
    }

    /// <summary>
    /// Chuẩn hóa và làm sạch nguyên liệu: khắc phục các lỗi dịch sai ngữ cảnh phổ biến (như Pepper -> Tiêu thay vì Ớt chuông, Spring Onion -> Hành tây thay vì Hành lá, Coconut milk -> Sữa tươi thay vì Nước cốt dừa)
    /// </summary>
    public static string SanitizeIngredient(string rawEnglish, string? currentVi)
    {
        string raw = rawEnglish.Trim();
        string lower = raw.ToLowerInvariant();

        // 1. Kiểm tra các lỗi dịch sai ngữ cảnh nghiêm trọng thường gặp:
        if (lower.Contains("spring onion") || lower.Contains("scallion") || lower.Contains("green onion"))
        {
            return "Hành lá";
        }
        if (lower.Contains("shallot") || lower.Equals("red onion") || lower.Equals("red onions"))
        {
            return "Hành tím";
        }
        if (lower.Contains("red pepper"))
        {
            return "Ớt chuông đỏ";
        }
        if (lower.Contains("green pepper"))
        {
            return "Ớt chuông xanh";
        }
        if (lower.Contains("yellow pepper"))
        {
            return "Ớt chuông vàng";
        }
        if (lower.Contains("bell pepper") || lower.Contains("sweet pepper"))
        {
            return "Ớt chuông";
        }
        if (lower.Contains("chilli flakes") || lower.Contains("chili flakes") || lower.Contains("red pepper flakes"))
        {
            return "Ớt vảy";
        }
        if (lower.Contains("paprika"))
        {
            return "Ớt bột Paprika";
        }
        if (lower.Contains("cayenne"))
        {
            return "Ớt bột Cayenne";
        }
        if (lower.Contains("coconut milk"))
        {
            return "Nước cốt dừa";
        }
        if (lower.Contains("coconut oil"))
        {
            return "Dầu dừa";
        }
        if (lower.Contains("coconut cream"))
        {
            return "Kem dừa";
        }
        if (lower.Contains("lime juice"))
        {
            return "Nước cốt chanh";
        }
        if (lower.Contains("lemon juice"))
        {
            return "Nước cốt chanh vàng";
        }
        if (lower.Contains("coriander") || lower.Contains("cilantro"))
        {
            return "Rau ngò rí";
        }
        if (lower.Contains("parsley"))
        {
            return "Ngò tây";
        }
        if (lower.Equals("raw king prawns") || lower.Equals("king prawns") || lower.Equals("tiger prawns"))
        {
            return "Tôm tươi";
        }

        // 2. Tra cứu trực tiếp từ điển QuickDictionary
        if (QuickDictionary.TryGetValue(raw, out var dictVi))
        {
            return dictVi;
        }

        // 3. Nếu currentVi có sẵn và hợp lệ (không phải là chuỗi tiếng Anh hoặc chuỗi lỗi)
        if (!string.IsNullOrWhiteSpace(currentVi) && !string.Equals(currentVi, raw, StringComparison.OrdinalIgnoreCase))
        {
            if (lower.Contains("pepper") && !lower.Contains("black pepper") && !lower.Contains("white pepper") && currentVi.Equals("Tiêu", StringComparison.OrdinalIgnoreCase))
            {
                return "Ớt chuông";
            }
            if (lower.Contains("onion") && (lower.Contains("spring") || lower.Contains("green") || lower.Contains("scallion")) && currentVi.Equals("Hành tây", StringComparison.OrdinalIgnoreCase))
            {
                return "Hành lá";
            }
            if (lower.Contains("coconut") && lower.Contains("milk") && currentVi.Equals("Sữa tươi", StringComparison.OrdinalIgnoreCase))
            {
                return "Nước cốt dừa";
            }
            return currentVi;
        }

        return raw;
    }

    /// <summary>
    /// Dịch và bản địa hóa đơn vị đo, số lượng và cách sơ chế từ Tiếng Anh sang Tiếng Việt chuẩn mực
    /// </summary>
    public static string TranslateMeasure(string? measure)
    {
        if (string.IsNullOrWhiteSpace(measure)) return string.Empty;
        string s = measure.Trim();
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\s+", " ");

        // 1. Nếu đã hoàn toàn là Tiếng Việt hoặc số đơn thuần (ví dụ: "450g", "75 ml", "1", "400ml")
        if (QuickDictionary.TryGetValue(s, out var quick)) return quick;

        // Xử lý các cụm từ đặc biệt phổ biến
        if (s.Equals("to serve", StringComparison.OrdinalIgnoreCase)) return "Dùng kèm";
        if (s.Equals("to taste", StringComparison.OrdinalIgnoreCase)) return "Vừa ăn";
        if (s.Equals("garnish", StringComparison.OrdinalIgnoreCase) || s.Equals("for garnish", StringComparison.OrdinalIgnoreCase)) return "Trang trí";
        if (s.Equals("for frying", StringComparison.OrdinalIgnoreCase)) return "Dùng để chiên";

        // Thay thế các đơn vị khối lượng / thể tích Anh - Mỹ sang hệ mét
        // 1 lb / 1 pound ~ 450g
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b1\s*(?:lb|lbs|pound|pounds)\b", "450g", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b2\s*(?:lb|lbs|pound|pounds)\b", "900g", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b1/2\s*(?:lb|lbs|pound|pounds)\b", "225g", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b(\d+)\s*(?:lb|lbs|pound|pounds)\b", m => $"{int.Parse(m.Groups[1].Value) * 450}g", System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        // Chuẩn hóa số lượng + cách sơ chế dạng "4 Chopped" -> "4 phần cắt nhỏ", "1 chopped" -> "1 phần băm nhỏ"
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b(\d+)\s+chopped\b", "$1 phần cắt nhỏ", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b(\d+)\s+diced\b", "$1 phần thái hạt lựu", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\b(\d+)\s+sliced\b", "$1 phần thái lát", System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        // Chuẩn hóa cụm cách chế biến (Prep words)
        var prepReplacements = new (string En, string Vi)[]
        {
            ("finely chopped", "băm nhuyễn"),
            ("coarsely chopped", "thái khúc"),
            ("chopped", "băm nhỏ"),
            ("finely minced", "băm nhuyễn"),
            ("minced", "băm nhỏ"),
            ("thinly sliced", "thái lát mỏng"),
            ("sliced", "thái lát"),
            ("diced", "thái hạt lựu"),
            ("crushed", "đập dập"),
            ("grated", "bào sợi"),
            ("peeled", "gọt vỏ"),
            ("shredded", "xé sợi"),
            ("melted", "đun chảy"),
            ("beaten", "đánh tan"),
            ("drained", "để ráo nước"),
            ("cooked", "đã nấu"),
            ("roasted", "nướng"),
            ("to serve", "dùng kèm"),
            ("to taste", "vừa ăn")
        };

        foreach (var (en, vi) in prepReplacements)
        {
            s = System.Text.RegularExpressions.Regex.Replace(s, $@"\b{en}\b", vi, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        }

        // Chuẩn hóa các đơn vị đo phổ biến (Unit replacements)
        var unitReplacements = new (string En, string Vi)[]
        {
            ("tablespoons", "muỗng canh"),
            ("tablespoon", "muỗng canh"),
            ("tbsp", "muỗng canh"),
            ("tbs", "muỗng canh"),
            ("teaspoons", "muỗng cà phê"),
            ("teaspoon", "muỗng cà phê"),
            ("tsp", "muỗng cà phê"),
            ("cloves", "tép"),
            ("clove", "tép"),
            ("cups", "chén"),
            ("cup", "chén"),
            ("cans", "lon"),
            ("can", "lon"),
            ("pinches", "nhúm"),
            ("pinch", "nhúm"),
            ("slices", "lát"),
            ("slice", "lát"),
            ("pieces", "miếng"),
            ("piece", "miếng"),
            ("bunches", "bó"),
            ("bunch", "bó"),
            ("sprigs", "nhánh"),
            ("sprig", "nhánh"),
            ("stalks", "nhánh"),
            ("stalk", "nhánh"),
            ("heads", "bắp"),
            ("head", "bắp"),
            ("handfuls", "nắm"),
            ("handful", "nắm"),
            ("leaves", "lá"),
            ("leaf", "lá")
        };

        foreach (var (en, vi) in unitReplacements)
        {
            s = System.Text.RegularExpressions.Regex.Replace(s, $@"\b{en}\b", vi, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        }

        return s.Trim();
    }

    /// <summary>
    /// Tự động sinh định lượng khẩu phần ẩm thực thực tế (thay cho nhãn giữ chỗ 'Khẩu phần tiêu chuẩn' hoặc placeholder)
    /// </summary>
    public static string GenerateDefaultMeasure(string ingredient, int index)
    {
        string lower = ingredient.ToLowerInvariant().Trim();

        // 1. Nhóm đạm chính (Thịt, cá, tôm, mực, trứng, đậu phụ...)
        if (index == 0 || lower.Contains("bò") || lower.Contains("gà") || lower.Contains("heo") ||
            lower.Contains("cá") || lower.Contains("tôm") || lower.Contains("mực") || lower.Contains("beef") ||
            lower.Contains("chicken") || lower.Contains("salmon") || lower.Contains("pork") || lower.Contains("shrimp") ||
            lower.Contains("seafood") || lower.Contains("steak") || lower.Contains("tofu") || lower.Contains("đậu phụ") ||
            lower.Contains("đậu hũ") || lower.Contains("tàu hũ"))
        {
            if (lower.Contains("trứng") || lower.Contains("egg")) return "2 quả";
            if (lower.Contains("tofu") || lower.Contains("đậu phụ") || lower.Contains("đậu hũ") || lower.Contains("tàu hũ")) return "1 - 2 bìa (150g)";
            if (lower.Contains("phi lê") || lower.Contains("fillet") || lower.Contains("cá hồi") || lower.Contains("salmon")) return "150g";
            if (lower.Contains("ức gà") || lower.Contains("bắp bò") || lower.Contains("thịt") || lower.Contains("sườn")) return "150g - 200g";
            return "150g";
        }

        // 2. Nhóm tinh bột (Cơm, bún, phở, mì, bánh mì, yến mạch)
        if (lower.Contains("phở") || lower.Contains("bún") || lower.Contains("mì") || lower.Contains("cơm") ||
            lower.Contains("bánh mì") || lower.Contains("noodle") || lower.Contains("rice") || lower.Contains("pasta") ||
            lower.Contains("spaghetti") || lower.Contains("oats") || lower.Contains("yến mạch"))
        {
            if (lower.Contains("bánh mì") || lower.Contains("bread")) return "1 ổ";
            if (lower.Contains("pasta") || lower.Contains("spaghetti")) return "100g";
            return "150g";
        }

        // 3. Nhóm bột & ngũ cốc
        if (lower.Contains("bột mì") || lower.Contains("bột bắp") || lower.Contains("bột năng") || lower.Contains("bột gạo") ||
            lower.Contains("flour") || lower.Contains("cornstarch") || lower.Contains("baking powder"))
        {
            return "2 muỗng canh";
        }

        // 4. Nhóm rau củ & nấm
        if (lower.Contains("cải") || lower.Contains("muống") || lower.Contains("bông cải") || lower.Contains("mướp") ||
            lower.Contains("rau") || lower.Contains("choy") || lower.Contains("sum") || lower.Contains("xà lách") ||
            lower.Contains("greens") || lower.Contains("vegetable") || lower.Contains("spinach") || lower.Contains("broccoli") ||
            lower.Contains("cabbage") || lower.Contains("bắp cải") || lower.Contains("mồng tơi") || lower.Contains("ngót"))
        {
            return "200g";
        }
        if (lower.Contains("cà rốt") || lower.Contains("khoai") || lower.Contains("hành tây") || lower.Contains("ớt chuông") ||
            lower.Contains("cà chua") || lower.Contains("dưa leo") || lower.Contains("bí") || lower.Contains("carrot") ||
            lower.Contains("potato") || lower.Contains("tomato") || lower.Contains("cucumber") || lower.Contains("bell pepper"))
        {
            return "1 củ / quả";
        }
        if (lower.Contains("nấm") || lower.Contains("mushroom"))
        {
            return "100g";
        }
        if (lower.Contains("giá đỗ") || lower.Contains("sprout") || lower.Contains("bắp") || lower.Contains("ngô") || lower.Contains("corn"))
        {
            return "100g";
        }

        // 5. Hành tỏi sả gừng & thảo mộc gia vị
        if (lower.Contains("tỏi") || lower.Contains("garlic")) return "2 - 3 tép băm";
        if (lower.Contains("hành tím") || lower.Contains("shallot")) return "2 - 3 củ băm";
        if (lower.Contains("hành lá") || lower.Contains("scallion") || lower.Contains("spring onion")) return "2 - 3 nhánh cắt khúc";
        if (lower.Contains("sả") || lower.Contains("lemongrass")) return "2 cây đập dập";
        if (lower.Contains("gừng") || lower.Contains("ginger")) return "1 nhánh nhỏ";
        if (lower.Contains("ớt") || lower.Contains("chili") || lower.Contains("chilli")) return "1 - 2 quả cắt lát";
        if (lower.Contains("hồi") || lower.Contains("quế") || lower.Contains("ngò") || lower.Contains("mùi") ||
            lower.Contains("húng") || lower.Contains("basil") || lower.Contains("cilantro") || lower.Contains("parsley")) return "1 nhúm nhỏ";

        // 6. Nước sốt, dầu mỡ & chất béo
        if (lower.Contains("nước mắm") || lower.Contains("nước tương") || lower.Contains("xì dầu") ||
            lower.Contains("dầu hào") || lower.Contains("dầu") || lower.Contains("sauce") || lower.Contains("oil") ||
            lower.Contains("tương ớt") || lower.Contains("tương cà") || lower.Contains("mayonnaise") || lower.Contains("ketchup"))
        {
            return "1 muỗng canh";
        }
        if (lower.Contains("bơ") || lower.Contains("butter")) return "1 muỗng canh (15g)";
        if (lower.Contains("phô mai") || lower.Contains("cheese")) return "30g - 50g";

        // 7. Gia vị nêm nếm
        if (lower.Contains("tiêu") || lower.Contains("pepper")) return "1/2 muỗng cà phê";
        if (lower.Contains("đường") || lower.Contains("muối") || lower.Contains("hạt nêm") || lower.Contains("bột canh") ||
            lower.Contains("sugar") || lower.Contains("salt") || lower.Contains("paprika"))
        {
            return "1 muỗng cà phê";
        }

        // 8. Chất lỏng (nước dùng, sữa, nước dừa)
        if (lower.Contains("nước cốt dừa") || lower.Contains("coconut milk") || lower.Contains("sữa") || lower.Contains("milk") || lower.Contains("yogurt")) return "100ml";
        if (lower.Contains("nước dừa") || lower.Contains("nước dùng") || lower.Contains("nước hầm") || lower.Contains("nước lọc") || lower.Contains("broth") || lower.Contains("stock") || lower.Contains("water")) return "200ml - 300ml";
        if (lower.Contains("chanh") || lower.Contains("giấm") || lower.Contains("lime") || lower.Contains("lemon") || lower.Contains("vinegar")) return "1 muỗng canh";
        if (lower.Contains("mè") || lower.Contains("đậu phộng") || lower.Contains("lạc") || lower.Contains("sesame") || lower.Contains("peanut") || lower.Contains("nut")) return "1 muỗng canh";

        return "Vừa đủ dùng";
    }
}
