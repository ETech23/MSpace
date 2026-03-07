# Shorebird OTA Setup (Flutter)

This project supports backend runtime flags already. Shorebird adds OTA patching for Dart code changes.

## 1) Install Shorebird CLI (local machine)

```bash
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
iwr -UseBasicParsing 'https://raw.githubusercontent.com/shorebirdtech/install/main/install.ps1'|iex
shorebird --version
```

## 2) Authenticate

```bash
shorebird login
```

## 3) Initialize in this app (one-time)

Run from project root:

```bash
shorebird init
```

This creates Shorebird project metadata.

## 4) First production release (required before patches)

Android:

```bash
shorebird release android --flavor prod
```

iOS:

```bash
shorebird release ios --flavor prod
```

## 5) Publish OTA patch (Dart-only changes)

Android:

```bash
shorebird patch android --flavor prod
```

iOS:

```bash
shorebird patch ios --flavor prod
```

## 6) Verify patch rollout

Use Shorebird dashboard/CLI release status to confirm active patches and affected versions.

## Notes

- OTA patching covers Dart layer updates.
- Native/plugin changes still require a normal store release.
- Keep backend feature flags as kill switches even when using Shorebird.
- Test patch on internal testers before full rollout.
