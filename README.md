
# 🧠 Brain MRI Segmentation App (Flutter + FastAPI)

A full-stack application for interactive brain tumor segmentation using MRI data. This project includes:

- A **FastAPI backend** for processing NIfTI (.nii/.nii.gz) brain scans.
- A **Flutter frontend** that allows users to upload files, visualize predictions, and interact with 3D tumor/brain models.

---

## 🚀 Features

### 🔙 FastAPI Backend (`main.py`)
- `/predict`: Generates 6 PNG slices with tumor mask overlays.
- `/plot_preview`: Produces a preview image with 4 anatomical views using Nilearn.
- `/tumor_mesh`: Converts the segmentation into a 3D colored GLB model.
- `/brain_mesh`: Returns a full brain surface + tumor mesh in one GLB file.

### 📱 Flutter Frontend (`main.dart`)
- Upload `.nii` or `.nii.gz` files for FLAIR, T1ce, and segmentation.
- Trigger API endpoints and receive:
    - PNG slice predictions
    - A 4-view anatomical preview
    - Interactive 3D tumor and brain meshes
- View results with:
    - Local file display
    - Embedded 3D model viewer (GLB)

---

## 📦 Project Structure

```
btc_model/
├── app/                # Flutter app source
│   └── main.dart
├── models/             # Trained models (H5)
├── static/             # Output PNGs and GLBs
├── main.py             # FastAPI backend
├── requirements.txt
└── .gitignore
```

---

## 🔧 How to Run

### 🧠 Backend (FastAPI)
1. Create and activate a virtual environment:
    ```bash
    python -m venv .venv
    source .venv/bin/activate  # Windows: .venv\Scripts\activate
    ```
2. Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3. Run the server:
    ```bash
    uvicorn main:app --reload
    ```

> Make sure the model file `3D_MRI_Brain_tumor_segmentation.h5` is placed under `models/`.

---

### 📱 Frontend (Flutter)

1. Ensure Flutter is installed: [flutter.dev](https://flutter.dev)
2. Navigate to the `app/` directory and run:
    ```bash
    flutter pub get
    flutter run
    ```

---

## 📁 Example Files

- Use NIfTI files (`.nii` / `.nii.gz`) as input.
- Predictions, previews, and GLB models will be saved locally on the device and shown in the UI.

---

## 🧪 Notes

- GLB models are displayed using [`model_viewer_plus`](https://pub.dev/packages/model_viewer_plus).
- Designed to work on Android emulator or iOS simulator (use `10.0.2.2` or `127.0.0.1` for local IP).
- Ensure the backend is running before launching the app.

---

## 🙋 Support

For issues, please open an issue on the GitHub repository or email the maintainer.
