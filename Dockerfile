# ==========================================
# NUTRISNAP .NET 8 BACKEND DOCKERFILE
# Multi-stage build for Render / Cloud deploy
# ==========================================

# Stage 1: Build & Publish
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["backend/NutriSnap/NutriSnap/NutriSnap.csproj", "backend/NutriSnap/NutriSnap/"]
RUN dotnet restore "backend/NutriSnap/NutriSnap/NutriSnap.csproj"

# Copy source and publish
COPY backend/NutriSnap/NutriSnap/ backend/NutriSnap/NutriSnap/
WORKDIR "/src/backend/NutriSnap/NutriSnap"
RUN dotnet publish "NutriSnap.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 2: Production Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

# Render defaults to port 8080 or uses the PORT environment variable
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "NutriSnap.dll"]
