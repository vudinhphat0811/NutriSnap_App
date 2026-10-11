using Microsoft.AspNetCore.Mvc;
using NutriSnap.Services;

namespace NutriSnap.Controllers;

[ApiController]
[Route("api/[controller]")]
public class RecipesController : ControllerBase
{
    private readonly RecipeService _recipeService;

    public RecipesController(RecipeService recipeService)
    {
        _recipeService = recipeService;
    }

    [HttpGet("shake")]
    public async Task<IActionResult> Shake()
    {
        var meal = await _recipeService.GetRandomMealAsync();
        return meal != null ? Ok(meal) : NotFound();
    }
}