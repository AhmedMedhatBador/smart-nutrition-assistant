import numpy as np
import pandas as pd
from lime.lime_tabular import LimeTabularExplainer
from ml_model import load_model
import pickle
import os

# ── Feature names ──────────────────────────────────────────
FEATURE_NAMES = [
    "Age", "Gender", "Weight", "Height",
    "BMI", "BMR", "TDEE", "Activity Level",
    "Water Intake", "Physical Activity Frequency", "Tech Usage Time"
]

FEATURE_LABELS = {
    "Age": "Age",
    "Gender": "Gender",
    "Weight": "Weight (kg)",
    "Height": "Height (cm)",
    "BMI": "BMI",
    "BMR": "BMR (kcal)",
    "TDEE": "TDEE (kcal)",
    "Activity Level": "Activity Level",
    "Water Intake": "Water Intake (L)",
    "Physical Activity Frequency": "Physical Activity",
    "Tech Usage Time": "Tech Usage (hrs)"
}

CLASS_NAMES = ["Low", "Moderate", "High", "Critical"]

# ── Load training data for LIME background ─────────────────
def load_training_data():
    df = pd.read_csv("ObesityDataSet.csv")

    if df["Height"].mean() < 10:
        df["Height"] = df["Height"] * 100

    df["BMI"] = df["Weight"] / ((df["Height"] / 100) ** 2)
    df["Gender_num"] = (df["Gender"] == "Male").astype(int)
    df["activity_num"] = df["FAF"].apply(lambda x:
        0 if x == 0 else 1 if x <= 1 else 2 if x <= 2 else 3)

    def calc_bmr(row):
        w, h, a = row["Weight"], row["Height"], row["Age"]
        return (10*w + 6.25*h - 5*a + 5) if row["Gender"] == "Male" \
               else (10*w + 6.25*h - 5*a - 161)

    df["BMR"] = df.apply(calc_bmr, axis=1)
    factors = [1.2, 1.375, 1.55, 1.725]
    df["TDEE"] = df.apply(
        lambda r: r["BMR"] * factors[int(r["activity_num"])], axis=1)

    features = ["Age", "Gender_num", "Weight", "Height",
                "BMI", "BMR", "TDEE", "activity_num",
                "CH2O", "FAF", "TUE"]

    return df[features].values


# ── Generate LIME explanation ──────────────────────────────
def explain_prediction(age, gender, weight, height, activity_level):
    model = load_model()
    training_data = load_training_data()

    # ── Build explainer ────────────────────────────────────
    explainer = LimeTabularExplainer(
        training_data,
        feature_names=FEATURE_NAMES,
        class_names=CLASS_NAMES,
        mode="classification",
        discretize_continuous=True
    )

    # ── Prepare patient features ───────────────────────────
    gender_num = 1 if gender.lower() == "male" else 0
    activity_map = {
        "sedentary": 0, "light": 1,
        "moderate": 2, "active": 3, "very_active": 3
    }
    activity_num = activity_map.get(activity_level.lower(), 0)

    bmi = weight / ((height / 100) ** 2)
    if gender.lower() == "male":
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
    else:
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161

    factors = [1.2, 1.375, 1.55, 1.725]
    tdee = bmr * factors[min(activity_num, 3)]

    patient_features = np.array([
        age, gender_num, weight, height,
        bmi, bmr, tdee, activity_num,
        2.0, float(activity_num), 1.0
    ])

    # ── Get prediction ─────────────────────────────────────
    prediction = model.predict([patient_features])[0]
    predicted_class = CLASS_NAMES[prediction]

    # ── Generate explanation ───────────────────────────────
    explanation = explainer.explain_instance(
        patient_features,
        model.predict_proba,
        num_features=6,
        top_labels=1
    )

    # ── Extract feature contributions ─────────────────────
    exp_list = explanation.as_list(label=prediction)

    contributions = []
    for feature_condition, weight_val in exp_list:
        # Determine if pushing risk up or down
        direction = "increases_risk" if weight_val > 0 else "decreases_risk"
        impact = round(abs(weight_val) * 100, 2)

        contributions.append({
            "feature": feature_condition,
            "impact": impact,
            "direction": direction,
            "weight": round(float(weight_val), 4)
        })

    # Sort by impact
    contributions.sort(key=lambda x: x["impact"], reverse=True)

    return {
        "predicted_risk": predicted_class,
        "explanation": contributions,
        "summary": _generate_summary(contributions, predicted_class)
    }


# ── Generate human readable summary ───────────────────────
def _generate_summary(contributions, risk_level):
    increasing = [c for c in contributions if c["direction"] == "increases_risk"]
    decreasing = [c for c in contributions if c["direction"] == "decreases_risk"]

    summary = f"This patient is classified as {risk_level} risk. "

    if increasing:
        top_increase = increasing[0]["feature"]
        summary += f"The main factor increasing risk is: {top_increase}. "

    if decreasing:
        top_decrease = decreasing[0]["feature"]
        summary += f"The main factor reducing risk is: {top_decrease}."

    return summary


if __name__ == "__main__":
    # Test
    result = explain_prediction(30, "female", 70, 165, "moderate")
    print("Predicted Risk:", result["predicted_risk"])
    print("\nExplanation:")
    for c in result["explanation"]:
        arrow = "↑" if c["direction"] == "increases_risk" else "↓"
        print(f"  {arrow} {c['feature']}: {c['impact']}%")
    print("\nSummary:", result["summary"])