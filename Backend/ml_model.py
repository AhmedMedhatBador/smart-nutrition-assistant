import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
from sklearn.preprocessing import LabelEncoder
import pickle
import os

# ── Load and prepare real dataset ─────────────────────────
def load_real_data():
    df = pd.read_csv("ObesityDataSet.csv")

    # ── Map obesity labels to risk levels ─────────────────
    risk_map = {
        "Insufficient_Weight": 2,    # High
        "Normal_Weight": 0,           # Low
        "Overweight_Level_I": 1,      # Moderate
        "Overweight_Level_II": 1,     # Moderate
        "Obesity_Type_I": 2,          # High
        "Obesity_Type_II": 2,         # High
        "Obesity_Type_III": 3         # Critical
    }
    df["risk"] = df["NObeyesdad"].map(risk_map)

    # ── Convert height to cm if needed ────────────────────
    if df["Height"].mean() < 10:
        df["Height"] = df["Height"] * 100

    # ── Calculate BMI ─────────────────────────────────────
    df["BMI"] = df["Weight"] / ((df["Height"] / 100) ** 2)

    # ── Encode gender ──────────────────────────────────────
    df["Gender_num"] = (df["Gender"] == "Male").astype(int)

    # ── Encode activity level (FAF = physical activity frequency)
    # FAF: 0=none, 1=1-2 days, 2=2-4 days, 3=4-5 days
    df["activity_num"] = df["FAF"].apply(lambda x:
        0 if x == 0 else
        1 if x <= 1 else
        2 if x <= 2 else
        3
    )

    # ── Calculate BMR ──────────────────────────────────────
    def calc_bmr(row):
        w = row["Weight"]
        h = row["Height"]
        a = row["Age"]
        if row["Gender"] == "Male":
            return (10 * w) + (6.25 * h) - (5 * a) + 5
        else:
            return (10 * w) + (6.25 * h) - (5 * a) - 161

    df["BMR"] = df.apply(calc_bmr, axis=1)

    activity_factors = [1.2, 1.375, 1.55, 1.725]
    df["TDEE"] = df.apply(
        lambda row: row["BMR"] * activity_factors[int(row["activity_num"])],
        axis=1
    )

    # ── Select features ────────────────────────────────────
    features = ["Age", "Gender_num", "Weight", "Height",
                "BMI", "BMR", "TDEE", "activity_num",
                "CH2O",   # water intake
                "FAF",    # physical activity frequency
                "TUE",    # time using technology
                ]

    X = df[features].values
    y = df["risk"].values

    return X, y, features


# ── Train the model ────────────────────────────────────────
def train_model():
    print("Loading real dataset...")
    X, y, features = load_real_data()
    print(f"Dataset: {X.shape[0]} patients, {X.shape[1]} features")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print("Training Random Forest on real data...")
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=15,
        random_state=42,
        class_weight="balanced"
    )
    model.fit(X_train, y_train)

    # ── Evaluate ───────────────────────────────────────────
    y_pred = model.predict(X_test)
    print("\nModel Evaluation on Real Data:")
    print(classification_report(
        y_test, y_pred,
        target_names=["Low", "Moderate", "High", "Critical"]
    ))

    # ── Feature importance ─────────────────────────────────
    print("\nFeature Importance:")
    for name, imp in sorted(
        zip(features, model.feature_importances_),
        key=lambda x: x[1], reverse=True
    ):
        print(f"  {name}: {round(imp * 100, 2)}%")

    # ── Save model ─────────────────────────────────────────
    with open("model.pkl", "wb") as f:
        pickle.dump(model, f)
    print("\nModel saved to model.pkl")

    return model


# ── Load or train ──────────────────────────────────────────
def load_model():
    if os.path.exists("model.pkl"):
        with open("model.pkl", "rb") as f:
            return pickle.load(f)
    else:
        return train_model()


# ── Predict risk for a patient ─────────────────────────────
def predict_risk(age, gender, weight, height, activity_level):
    model = load_model()

    gender_num = 1 if gender.lower() == "male" else 0
    activity_map = {
        "sedentary": 0,
        "light": 1,
        "moderate": 2,
        "active": 3,
        "very_active": 3
    }
    activity_num = activity_map.get(activity_level.lower(), 0)

    bmi = weight / ((height / 100) ** 2)

    if gender.lower() == "male":
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
    else:
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161

    activity_factors = [1.2, 1.375, 1.55, 1.725]
    tdee = bmr * activity_factors[min(activity_num, 3)]

    # Default values for extra features
    ch2o = 2.0      # average water intake
    faf = activity_num
    tue = 1.0       # average tech usage

    features = np.array([[age, gender_num, weight, height,
                           bmi, bmr, tdee, activity_num,
                           ch2o, faf, tue]])

    prediction = model.predict(features)[0]
    probability = model.predict_proba(features)[0]

    risk_labels = ["Low", "Moderate", "High", "Critical"]
    risk_label = risk_labels[prediction]

    # ── Patient specific risk factors ─────────────────────
    patient_factors = []
    if bmi >= 30 or bmi < 18.5:
        patient_factors.append(f"BMI ({round(bmi, 1)}) — abnormal range")
    if age > 60:
        patient_factors.append(f"Age ({age}) — senior risk")
    if activity_level.lower() == "sedentary":
        patient_factors.append("Sedentary lifestyle")
    if bmi >= 25 and bmi < 30:
        patient_factors.append(f"BMI ({round(bmi, 1)}) — overweight range")
    if weight > 90:
        patient_factors.append(f"Weight ({weight}kg) — above healthy range")
    if age > 45:
        patient_factors.append(f"Age ({age}) — middle-age metabolic risk")
    if not patient_factors:
        patient_factors.append("BMI within acceptable range")
        patient_factors.append("No major individual risk factors detected")

    return {
        "risk_level": risk_label,
        "confidence": round(float(max(probability)) * 100, 2),
        "probabilities": {
            "Low": round(float(probability[0]) * 100, 2),
            "Moderate": round(float(probability[1]) * 100, 2),
            "High": round(float(probability[2]) * 100, 2),
            "Critical": round(float(probability[3]) * 100, 2)
        },
        "top_risk_factors": patient_factors,
        "bmi": round(bmi, 2)
    }


# ── Run directly to train ──────────────────────────────────
if __name__ == "__main__":
    train_model()