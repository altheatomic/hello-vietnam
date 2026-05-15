# HelloVietnam Frontend

Flutter application for the HelloVietnam product.

## Run locally

```powershell
cd frontend
flutter pub get
flutter run
```

## Main folders

- `lib/`: app code
- `assets/`: bundled assets
- `android/`, `ios/`, `web/`: platform targets
- `test/`: widget and unit tests

## Architecture

The frontend follows a feature-first structure:

- `lib/app/`: app shell, router, theme
- `lib/core/`: shared infrastructure
- `lib/features/`: feature modules

For the fuller setup guide, see [guide.md](./guide.md).
