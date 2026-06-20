# NEDOKO / スマホねぐら

Non-medical sleep-entry ritual app built with Flutter Web first.

NEDOKO helps the user stop nighttime phone use by putting a small phone buddy into a nest, covering it with a blanket, and collecting a gentle morning souvenir.

Public build:

- https://new31005.github.io/nedoko-smartphone-nest/

## Scope

- Mobile-first Flutter app
- Local persistence with `shared_preferences`
- Core flow: tuck phone -> cover blanket -> sleeping state -> morning souvenir -> shelf
- Screens: ねぐら, 棚, 装い, 設定
- Non-medical boundary: no medicine, dosage, diagnosis, treatment, or sleep-effect claims

## Commands

```powershell
C:\Users\Rig5070\flutter\bin\flutter.bat analyze
C:\Users\Rig5070\flutter\bin\flutter.bat test
C:\Users\Rig5070\flutter\bin\flutter.bat build web --release --base-href /nedoko-smartphone-nest/
```
