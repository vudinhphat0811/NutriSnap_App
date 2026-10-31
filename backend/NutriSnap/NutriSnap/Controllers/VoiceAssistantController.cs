using Microsoft.AspNetCore.Mvc;
using NutriSnap.Models;
using NutriSnap.Services;

namespace NutriSnap.Controllers;

[ApiController]
[Route("api/voice-assistant")]
public class VoiceAssistantController : ControllerBase
{
    private readonly VoiceAssistantService _voiceService;
    private readonly ILogger<VoiceAssistantController> _logger;

    public VoiceAssistantController(VoiceAssistantService voiceService, ILogger<VoiceAssistantController> logger)
    {
        _voiceService = voiceService;
        _logger = logger;
    }

    [HttpPost("process")]
    public async Task<IActionResult> ProcessVoice([FromBody] VoiceAssistantRequestDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { message = "Dữ liệu yêu cầu không hợp lệ." });
        }

        try
        {
            var result = await _voiceService.ProcessVoiceCommandAsync(dto);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi xử lý lệnh giọng nói: {Msg}", ex.Message);
            return StatusCode(500, new { message = "Lỗi máy chủ khi xử lý lệnh giọng nói." });
        }
    }

    [HttpPost("process-audio")]
    public async Task<IActionResult> ProcessVoiceAudio([FromBody] VoiceAudioAssistantRequestDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { message = "Dữ liệu âm thanh yêu cầu không hợp lệ." });
        }

        try
        {
            var result = await _voiceService.ProcessVoiceAudioCommandAsync(dto);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi xử lý âm thanh giọng nói: {Msg}", ex.Message);
            return StatusCode(500, new { message = "Lỗi máy chủ khi xử lý âm thanh giọng nói." });
        }
    }
}
