# Smart Nutrition Assistant

A cross-platform clinical decision support app for nutritionists. It helps manage patient records, predict obesity-related health risk with machine learning, and generate personalized nutrition recommendations.

Graduation project, B.Sc. Information Technology and Computing, Arab Open University – Egypt.


## Features

- Secure nutritionist login and registration (JWT authentication, bcrypt password hashing)
- Patient management: add, update, delete, and search patients
- BMI calculation and categorization
- ML-based health risk prediction
- Prediction explanations using LIME
- Training plots screen showing model training history
- CSV and PDF report export
- Light and dark themes
- Runs on Android and Windows (Flutter)

## Tech Stack

| Layer | Technology |
| --- | --- |
| Frontend | Flutter (Dart), Provider |
| Backend | Python, Flask, Flask-JWT-Extended, Flask-Bcrypt, SQLAlchemy |
| Database | PostgreSQL |
| Machine learning | scikit-learn, TensorFlow / Keras, LIME |
| Reports | ReportLab (PDF), CSV |

## Architecture

```
Flutter app  ──HTTPS/JSON──►  Flask REST API  ──►  PostgreSQL
                                   │
                                   └──►  ML models (Random Forest, neural network) + LIME explainer
```

## Machine Learning

- **Dataset:** UCI *Estimation of Obesity Levels* dataset (`Backend/ObesityDataSet.csv`), 2,111 records. The dataset is largely synthetic (generated with SMOTE), so results reflect performance on that data and not clinical validation.
- **Models:**
  - Random Forest classifier (`ml_model.py`, saved as `model.pkl`)
  - Neural network built with TensorFlow / Keras (`neural_network.py`, saved as `neural_network.h5`), using Dropout, Batch Normalization, and early stopping
- **Neural network results:** about 98% validation accuracy (final epoch: 94.7% training / 98.2% validation accuracy). Training history is saved in `Backend/training_history.json` and shown in the app.
- **Explainability:** LIME explains individual predictions (`lime_explainer.py`).

## Project Structure

```
Backend/     Flask API, ML training and inference code, trained models
frontend/    Flutter app (Android, Windows, web)
```

## Screenshots

| Patients | Detail | Risk prediction |
| --- | --- | --- |
| ![Patients](docs/Menu.png) | ![Detail](docs/overview.png) | ![Risk prediction](docs/Health risk.png) |

## Getting Started

### Prerequisites

- Python 3.12
- Flutter SDK
- PostgreSQL (or set a different database URL)

### Backend

```bash
cd Backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

Set environment variables:

```bash
set JWT_SECRET_KEY=your-long-random-secret
set DATABASE_URL=postgresql://user:password@localhost:5432/dbname
```

Run the API:

```bash
python app.py
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

Set the backend URL in `frontend/lib/services/api_service.dart` to point to your running API (for local development, the machine running `app.py`).

## Author

**Ahmed Medhat Bador**
GitHub: [AhmedMedhatBador](https://github.com/AhmedMedhatBador)
