param(
  [ValidateSet("android", "ios")]
  [string]$Platform = "android"
)

Write-Host "Publishing Shorebird OTA patch for $Platform..."
shorebird patch $Platform --flavor prod
