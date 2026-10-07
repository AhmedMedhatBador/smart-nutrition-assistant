import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, BatchNormalization
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.utils import to_categorical
import pickle
import os
import json

# ── Load and prepare data ──────────────────────────────────
def load_data():
    df = pd.read_csv("ObesityDataSet.csv")

    risk_map = {
        "Insufficient_Weight": 2,
        "Normal_Weight": 0,
        "Overweight_Level_I": 1,
        "Overweight_Level_II": 1,
        "Obesity_Type_I": 2,
        "Obesity_Type_II": 2,
        "Obesity_Type_III": 3
    }
    df["risk"] = df["NObeyesdad"].map(risk_map)

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

    X = df[features].values
    y = df["risk"].values
    return X, y, features


# ── Build Neural Network ───────────────────────────────────
def build_model(input_dim):
    model = Sequential([
        Dense(128, activation="relu", input_shape=(input_dim,)),
        BatchNormalization(),
        Dropout(0.3),

        Dense(64, activation="relu"),
        BatchNormalization(),
        Dropout(0.3),

        Dense(32, activation="relu"),
        Dropout(0.2),

        Dense(4, activation="softmax")  # 4 risk levels
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )
    return model


# ── Train Neural Network ───────────────────────────────────
def train_neural_network():
    print("Loading real dataset...")
    X, y, features = load_data()
    print(f"Dataset: {X.shape[0]} patients, {X.shape[1]} features")

    # ── Scale features ─────────────────────────────────────
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # ── Split data ─────────────────────────────────────────
    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y, test_size=0.2, random_state=42, stratify=y
    )

    # ── One-hot encode labels ──────────────────────────────
    y_train_cat = to_categorical(y_train, num_classes=4)
    y_test_cat = to_categorical(y_test, num_classes=4)

    # ── Build and train ────────────────────────────────────
    print("Building Neural Network...")
    model = build_model(X_train.shape[1])
    model.summary()

    early_stop = EarlyStopping(
        monitor="val_loss",
        patience=10,
        restore_best_weights=True
    )

    print("\nTraining Neural Network...")
    history = model.fit(
        X_train, y_train_cat,
        validation_split=0.2,
        epochs=100,
        batch_size=32,
        callbacks=[early_stop],
        verbose=1
    )

    # ── Evaluate ───────────────────────────────────────────
    print("\nEvaluating on test set...")
    y_pred = np.argmax(model.predict(X_test), axis=1)
    print(classification_report(
        y_test, y_pred,
        target_names=["Low", "Moderate", "High", "Critical"]
    ))

    # ── Save model and scaler ──────────────────────────────
    model.save("neural_network.h5")
    with open("scaler.pkl", "wb") as f:
        pickle.dump(scaler, f)

    # ── Save training history for plots ───────────────────
    history_data = {
        "accuracy": [float(x) for x in history.history["accuracy"]],
        "val_accuracy": [float(x) for x in history.history["val_accuracy"]],
        "loss": [float(x) for x in history.history["loss"]],
        "val_loss": [float(x) for x in history.history["val_loss"]]
    }
    with open("training_history.json", "w") as f:
        json.dump(history_data, f)

    print("\nSaved: neural_network.h5, scaler.pkl, training_history.json")
    return model, scaler, history_data


# ── Load model ─────────────────────────────────────────────
def load_neural_network():
    if os.path.exists("neural_network.h5") and os.path.exists("scaler.pkl"):
        model = tf.keras.models.load_model("neural_network.h5")
        with open("scaler.pkl", "rb") as f:
            scaler = pickle.load(f)
        return model, scaler
    else:
        model, scaler, _ = train_neural_network()
        return model, scaler


# ── Predict risk using Neural Network ─────────────────────
def nn_predict_risk(age, gender, weight, height, activity_level):
    model, scaler = load_neural_network()

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

    features = np.array([[age, gender_num, weight, height,
                           bmi, bmr, tdee, activity_num,
                           2.0, float(activity_num), 1.0]])

    features_scaled = scaler.transform(features)
    probability = model.predict(features_scaled, verbose=0)[0]
    prediction = np.argmax(probability)

    risk_labels = ["Low", "Moderate", "High", "Critical"]

    return {
        "risk_level": risk_labels[prediction],
        "confidence": round(float(max(probability)) * 100, 2),
        "probabilities": {
            "Low": round(float(probability[0]) * 100, 2),
            "Moderate": round(float(probability[1]) * 100, 2),
            "High": round(float(probability[2]) * 100, 2),
            "Critical": round(float(probability[3]) * 100, 2)
        }
    }


# ── Run directly to train ──────────────────────────────────
if __name__ == "__main__":
    train_neural_network()