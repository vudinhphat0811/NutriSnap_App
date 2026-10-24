# ======================================================================
# NutriSnap - Script cao du lieu da nguon (1,000+ mon an) lam Database
# ======================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " [NutriSnap] TIEN TRINH CAO DU LIEU CONG THUC DA NGUON (1,000+ MON)" -ForegroundColor Yellow
Write-Host " Nguon 1: TheMealDB API (790 mon quoc te A-Z)" -ForegroundColor White
Write-Host " Nguon 2: DummyJSON Modern Recipes API (50 mon Au - My - Y)" -ForegroundColor White
Write-Host " Nguon 3: NutriSnap VN Culinary Heritage (190 mon Viet Nam & Eat Clean)" -ForegroundColor White
Write-Host " Nguon 4: Combination Recipe Catalog (30 mon ket hop da nguyen lieu)" -ForegroundColor White
Write-Host " Nguon 5: MasterChef Vietnam & International (32+ mon Vua Dau Bep doi dau thi sinh)" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan

$backendDir = Join-Path $PSScriptRoot "backend\NutriSnap\NutriSnap"
$projectFile = Join-Path $backendDir "NutriSnap.csproj"

if (-not (Test-Path $projectFile)) {
    Write-Host "[LOI] Khong tim thay file du an NutriSnap.csproj tai: $backendDir" -ForegroundColor Red
    exit 1
}

Write-Host ">> Dang khoi chay .NET 8 Web API va cao du lieu da nguon..." -ForegroundColor Green
Write-Host ">> Du lieu se tu dong duoc luu vao:" -ForegroundColor Gray
Write-Host "   1. File Database: backend\NutriSnap\NutriSnap\Data\mealdb_recipes.json" -ForegroundColor Gray
Write-Host "   2. Bang SavedRecipes trong Database (SQL Server / PostgreSQL)" -ForegroundColor Gray
Write-Host "----------------------------------------------------------------------" -ForegroundColor DarkGray

dotnet run --project $projectFile -- --crawl-mealdb
