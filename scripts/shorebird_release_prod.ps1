param(
  [ValidateSet("android", "ios")]
  [string]$Platform = "android"
)

Write-Host "Running Shorebird production release for $Platform..."
shorebird release $Platform --flavor prod
