
# 🧠 Flutter Frontend Explanation – Brain MRI Segmentation App

This Flutter app allows users to interact with a FastAPI backend for brain MRI segmentation. The UI lets the user upload medical images, trigger prediction or visualization endpoints, and preview results like images and 3D models.

---

## 🧩 Project Overview

- Upload `.nii` or `.nii.gz` NIfTI files for:
  - **FLAIR** MRI (fluid-attenuated)
  - **T1ce** MRI (contrast-enhanced)
  - **Segmentation masks**
- Call backend API endpoints to get:
  - Segmentation predictions
  - Anatomical 4-panel previews
  - 3D tumor meshes
  - Combined brain + tumor meshes
- View results directly in-app:
  - Image previews (`Image.file`)
  - 3D model viewer (`ModelViewer`)

---

## 📁 Key Flutter File: `main.dart`

### 1. **App Initialization**
```dart
void main() => runApp(const BrainSegApp());
```
Starts the Flutter application.

---

### 2. **`BrainSegApp`**
```dart
class BrainSegApp extends StatelessWidget
```
- Sets up the base `MaterialApp`
- Uses Material3 and a Teal color scheme
- The home page is `HomePage()`

---

### 3. **`HomePage` Widget (Stateful)**
This is the main UI screen. It handles:
- File selection
- HTTP communication
- Result rendering

---

### 4. **File Management**

```dart
PlatformFile? flairFile, t1ceFile, segFile;
```

The app supports three file inputs:
- `flairFile` → FLAIR MRI scan
- `t1ceFile` → T1ce MRI scan
- `segFile` → Segmentation mask

Users can choose them via file picker:
```dart
_pickFile(String role)
```

---

### 5. **HTTP Setup**

```dart
final _http = IOClient(HttpClient()..connectionTimeout = ...);
String get _base => Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
```

- `IOClient`: allows long-lived connections
- `_base`: backend address (Android emulator uses `10.0.2.2`)

---

### 6. **API Integrations**

Each function calls a backend endpoint using `MultipartRequest`.

#### a. **`_callPredict()`**
Sends FLAIR and T1ce files → receives 6 slice PNGs with tumor mask overlays.
```dart
POST /predict
```

Stores the output files locally using `getApplicationDocumentsDirectory()`.

---

#### b. **`_callPreview()`**
Sends FLAIR and Seg → receives a 4-view image using Nilearn.
```dart
POST /plot_preview
```

---

#### c. **`_callTumorMesh()`**
Sends Seg → receives a `.glb` file showing a 3D tumor mesh.
```dart
POST /tumor_mesh
```

---

#### d. **`_callBrainMesh()`**
Sends FLAIR and Seg → receives a `.glb` with brain + tumor.
```dart
POST /brain_mesh
```

---

### 7. **UI Widgets**

#### a. File pickers
```dart
_FileTile(label: ..., file: ..., onTap: ...)
```

Reusable list tiles to show selected files and allow browsing.

---

#### b. Control Buttons
```dart
FilledButton.icon(...)
```

- Predict
- Preview
- Tumor 3D
- Brain 3D  
Each button triggers one API call.

---

#### c. Previews & Results

- Shows PNG slice images with `ListTile`
- Uses `Image.file(...)` for preview images
- Uses `ModelViewer` to show `.glb` 3D models

---

### 8. **Error Handling**
```dart
_showErr(String msg)
```
Displays `SnackBar` errors like invalid file types, API failures, etc.

---

### 9. **Helper Classes**

#### a. `_FileTile`
A UI tile for selecting and displaying file info.

#### b. `_Slice`
Stores each slice result (title + file).

---

## 🧪 Notes on Packages Used

- `file_picker`: To select `.nii` and `.nii.gz` files
- `http`: For backend API requests
- `model_viewer_plus`: View `.glb` models (WebGL-based)
- `open_filex`: To open files in external viewers
- `path_provider`: To save/download images/3D files

---

## ✅ Summary

This Flutter app is:
- A mobile interface for medical image analysis
- Fully integrated with a FastAPI backend
- Capable of both 2D and 3D visual feedback
- Usable locally or in production with minimal changes
