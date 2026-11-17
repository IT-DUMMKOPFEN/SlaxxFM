# Prepares SlaxxFM for a local build on Windows.
# Usage: .\setup.ps1            
param([string]$Platforms = "windows,linux,macos,android")
flutter create --org de.itdummkopfen --project-name slaxxfm --platforms=$Platforms .
flutter pub get
dart run tool/patch_platforms.dart
dart run flutter_launcher_icons
Write-Host ""
Write-Host "Done. Start with:  flutter run -d windows"
