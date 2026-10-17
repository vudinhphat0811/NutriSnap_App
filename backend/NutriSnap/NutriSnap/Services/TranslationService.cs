using System.Text;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Caching.Memory;

namespace NutriSnap.Services;

public class TranslationService
{
    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly ILogger<TranslationService> _logger;

    public TranslationService(HttpClient httpClient, IMemoryCache cache, ILogger<TranslationService> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
        _logger = logger;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36");
    }

    /// <summary>
    /// Dịch một đoạn văn bản hoặc câu từ Tiếng Anh sang Tiếng Việt (có Cache)
    /// </summary>
    public async Task<string> TranslateAsync(string text, string targetLang = "vi", string sourceLang = "en")
    {
        if (string.IsNullOrWhiteSpace(text)) return text;
        if (targetLang.Equals(sourceLang, StringComparison.OrdinalIgnoreCase)) return text;

        string cacheKey = $"trans_{sourceLang}_{targetLang}_{text.Trim().GetHashCode()}";
        if (_cache.TryGetValue(cacheKey, out string? cached) && !string.IsNullOrEmpty(cached))
        {
            return cached;
        }

        try
        {
            string url = $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={sourceLang}&tl={targetLang}&dt=t&q={Uri.EscapeDataString(text)}";
            var response = await _httpClient.GetStringAsync(url);
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
                    // Cache kết quả dịch trong 7 ngày
                    _cache.Set(cacheKey, translated, TimeSpan.FromDays(7));
                    return translated;
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Lỗi khi gọi API dịch văn bản: {Text}", text.Length > 50 ? text[..50] + "..." : text);
        }

        return text;
    }

    /// <summary>
    /// Dịch một danh sách các chuỗi (nguyên liệu, đơn vị)
    /// </summary>
    public async Task<List<string>> TranslateBatchAsync(List<string> texts, string targetLang = "vi", string sourceLang = "en")
    {
        var result = new List<string>();
        foreach (var text in texts)
        {
            var translated = await TranslateAsync(text, targetLang, sourceLang);
            result.Add(translated);
        }
        return result;
    }
}
