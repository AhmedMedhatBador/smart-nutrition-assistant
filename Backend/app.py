from lime_explainer import explain_prediction
import json
from neural_network import nn_predict_risk
from flask import Flask, request, jsonify, send_file
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
import io
import csv
from ml_model import predict_risk
import os

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///nutrition.db"
app.config["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY", "dev-only-key")

db = SQLAlchemy(app)
jwt = JWTManager(app)
bcrypt = Bcrypt(app)
CORS(app)

# ── User Model ──────────────────────────────────────────
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)

# ── Patient Model ─────────────────────────────────────────
class Patient(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    nutritionist_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    gender = db.Column(db.String(10), nullable=False)
    weight = db.Column(db.Float, nullable=False)   # in kg
    height = db.Column(db.Float, nullable=False)   # in cm
    activity_level = db.Column(db.String(20), nullable=False)  # sedentary, light, moderate, active, very_active
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    
# ── Register ─────────────────────────────────────────────
@app.route("/auth/register", methods=["POST"])
def register():
    data = request.get_json()
    
    if User.query.filter_by(email=data["email"]).first():
        return jsonify({"error": "Email already exists"}), 400
    
    hashed_password = bcrypt.generate_password_hash(data["password"]).decode("utf-8")
    new_user = User(name=data["name"], email=data["email"], password=hashed_password)
    
    db.session.add(new_user)
    db.session.commit()
    
    return jsonify({"message": "User registered successfully!"}), 201

# ── Login ─────────────────────────────────────────────────
@app.route("/auth/login", methods=["POST"])
def login():
    data = request.get_json()
    user = User.query.filter_by(email=data["email"]).first()
    
    if not user or not bcrypt.check_password_hash(user.password, data["password"]):
        return jsonify({"error": "Invalid email or password"}), 401
    
    token = create_access_token(identity=str(user.id))
    return jsonify({"token": token, "name": user.name}), 200

# ── Protected test route ──────────────────────────────────
@app.route("/auth/me", methods=["GET"])
@jwt_required()
def me():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    return jsonify({"id": user.id, "name": user.name, "email": user.email})

# ── Add Patient ───────────────────────────────────────────
@app.route("/patients", methods=["POST"])
@jwt_required()
def add_patient():
    user_id = get_jwt_identity()
    data = request.get_json()

    patient = Patient(
        nutritionist_id=user_id,
        name=data["name"],
        age=data["age"],
        gender=data["gender"],
        weight=data["weight"],
        height=data["height"],
        activity_level=data["activity_level"]
    )
    db.session.add(patient)
    db.session.commit()
    return jsonify({"message": "Patient added!", "id": patient.id}), 201

# ── Get All Patients ──────────────────────────────────────
@app.route("/patients", methods=["GET"])
@jwt_required()
def get_patients():
    user_id = get_jwt_identity()
    patients = Patient.query.filter_by(nutritionist_id=user_id).all()
    return jsonify([{
        "id": p.id,
        "name": p.name,
        "age": p.age,
        "gender": p.gender,
        "weight": p.weight,
        "height": p.height,
        "activity_level": p.activity_level
    } for p in patients]), 200

# ── Get One Patient ───────────────────────────────────────
@app.route("/patients/<int:patient_id>", methods=["GET"])
@jwt_required()
def get_patient(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404
    return jsonify({
        "id": patient.id,
        "name": patient.name,
        "age": patient.age,
        "gender": patient.gender,
        "weight": patient.weight,
        "height": patient.height,
        "activity_level": patient.activity_level
    }), 200

# ── Update Patient ────────────────────────────────────────
@app.route("/patients/<int:patient_id>", methods=["PUT"])
@jwt_required()
def update_patient(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404
    data = request.get_json()
    patient.name = data.get("name", patient.name)
    patient.age = data.get("age", patient.age)
    patient.gender = data.get("gender", patient.gender)
    patient.weight = data.get("weight", patient.weight)
    patient.height = data.get("height", patient.height)
    patient.activity_level = data.get("activity_level", patient.activity_level)
    db.session.commit()
    return jsonify({"message": "Patient updated!"}), 200

# ── Delete Patient ────────────────────────────────────────
@app.route("/patients/<int:patient_id>", methods=["DELETE"])
@jwt_required()
def delete_patient(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404
    db.session.delete(patient)
    db.session.commit()
    return jsonify({"message": "Patient deleted!"}), 200

# ── Calculations (FR3) ────────────────────────────────────
@app.route("/patients/<int:patient_id>/calculate", methods=["GET"])
@jwt_required()
def calculate(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    w = patient.weight   # kg
    h = patient.height   # cm
    a = patient.age
    g = patient.gender
    activity = patient.activity_level

    # ── BMI ──────────────────────────────────────────────
    bmi = round(w / ((h / 100) ** 2), 2)
    if bmi < 18.5:
        bmi_category = "Underweight"
    elif bmi < 25:
        bmi_category = "Normal"
    elif bmi < 30:
        bmi_category = "Overweight"
    else:
        bmi_category = "Obese"

    # ── BMR (Mifflin-St Jeor) ────────────────────────────
    if g.lower() == "male":
        bmr = round((10 * w) + (6.25 * h) - (5 * a) + 5, 2)
    else:
        bmr = round((10 * w) + (6.25 * h) - (5 * a) - 161, 2)

    # ── TDEE ─────────────────────────────────────────────
    activity_factors = {
        "sedentary": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "active": 1.725,
        "very_active": 1.9
    }
    factor = activity_factors.get(activity.lower(), 1.2)
    tdee = round(bmr * factor, 2)

    # ── Macronutrients ───────────────────────────────────
    protein = round((tdee * 0.30) / 4, 2)   # 30% of calories / 4 cal per gram
    carbs = round((tdee * 0.45) / 4, 2)     # 45% of calories / 4 cal per gram
    fats = round((tdee * 0.25) / 9, 2)      # 25% of calories / 9 cal per gram

    return jsonify({
        "patient": patient.name,
        "bmi": bmi,
        "bmi_category": bmi_category,
        "bmr": bmr,
        "tdee": tdee,
        "macronutrients": {
            "protein_g": protein,
            "carbs_g": carbs,
            "fats_g": fats
        }
    }), 200

# ── Risk Assessment with ML (FR4) ─────────────────────────
@app.route("/patients/<int:patient_id>/risk", methods=["GET"])
@jwt_required()
def risk_assessment(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    result = predict_risk(
        age=patient.age,
        gender=patient.gender,
        weight=patient.weight,
        height=patient.height,
        activity_level=patient.activity_level
    )

    # Generate recommendations based on ML risk level
    recommendations = []
    risks = []

    if result["risk_level"] == "Low":
        risks.append("No significant health risks detected")
        recommendations.append("Maintain current healthy lifestyle")
        recommendations.append("Regular health checkups recommended")

    elif result["risk_level"] == "Moderate":
        risks.append("Moderate risk — early intervention recommended")
        recommendations.append("Reduce daily caloric intake by 300-500 calories")
        recommendations.append("Increase physical activity to at least 150 min/week")
        recommendations.append("Monitor weight weekly")

    elif result["risk_level"] == "High":
        risks.append("High risk — prompt action required")
        recommendations.append("Consult with a physician for structured plan")
        recommendations.append("Target 500-750 calorie daily deficit")
        recommendations.append("Consider referral to registered dietitian")

    elif result["risk_level"] == "Critical":
        risks.append("Critical risk — immediate medical attention recommended")
        recommendations.append("Immediate medical consultation required")
        recommendations.append("Supervised weight management program recommended")
        recommendations.append("Regular monitoring of blood pressure and glucose")

    return jsonify({
        "patient": patient.name,
        "bmi": result["bmi"],
        "risk_level": result["risk_level"],
        "confidence": f"{result['confidence']}%",
        "risk_probabilities": result["probabilities"],
        "top_risk_factors": result["top_risk_factors"],
        "risks": risks,
        "recommendations": recommendations
    }), 200
    
    
# ── Neural Network Risk Assessment ────────────────────────
@app.route("/patients/<int:patient_id>/risk/nn", methods=["GET"])
@jwt_required()
def risk_assessment_nn(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    result = nn_predict_risk(
        age=patient.age,
        gender=patient.gender,
        weight=patient.weight,
        height=patient.height,
        activity_level=patient.activity_level
    )

    return jsonify({
        "patient": patient.name,
        "model": "Deep Neural Network",
        "risk_level": result["risk_level"],
        "confidence": f"{result['confidence']}%",
        "risk_probabilities": result["probabilities"]
    }), 200

# ── Compare both models ───────────────────────────────────
@app.route("/patients/<int:patient_id>/risk/compare", methods=["GET"])
@jwt_required()
def compare_models(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    rf_result = predict_risk(
        age=patient.age,
        gender=patient.gender,
        weight=patient.weight,
        height=patient.height,
        activity_level=patient.activity_level
    )

    nn_result = nn_predict_risk(
        age=patient.age,
        gender=patient.gender,
        weight=patient.weight,
        height=patient.height,
        activity_level=patient.activity_level
    )

    # If both models agree → higher confidence
    agreement = rf_result["risk_level"] == nn_result["risk_level"]

    return jsonify({
        "patient": patient.name,
        "random_forest": {
            "risk_level": rf_result["risk_level"],
            "confidence": f"{rf_result['confidence']}%"
        },
        "neural_network": {
            "risk_level": nn_result["risk_level"],
            "confidence": f"{nn_result['confidence']}%"
        },
        "models_agree": agreement,
        "final_verdict": rf_result["risk_level"] if agreement else "Requires Review",
        "top_risk_factors": rf_result["top_risk_factors"]
    }), 200

# ── LIME Explanation (Explainable AI) ─────────────────────
@app.route("/patients/<int:patient_id>/explain", methods=["GET"])
@jwt_required()
def explain_risk(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    result = explain_prediction(
        age=patient.age,
        gender=patient.gender,
        weight=patient.weight,
        height=patient.height,
        activity_level=patient.activity_level
    )

    return jsonify({
        "patient": patient.name,
        "predicted_risk": result["predicted_risk"],
        "summary": result["summary"],
        "explanation": result["explanation"]
    }), 200

# ── Training history for plots ────────────────────────────
@app.route("/ml/training-history", methods=["GET"])
def training_history():
    try:
        with open("training_history.json", "r") as f:
            history = json.load(f)
        return jsonify(history), 200
    except:
        return jsonify({"error": "Training history not found"}), 404
# ── Patient Categorization (FR5) ──────────────────────────
@app.route("/patients/categories", methods=["GET"])
@jwt_required()
def categorize_patients():
    user_id = get_jwt_identity()
    patients = Patient.query.filter_by(nutritionist_id=user_id).all()

    if not patients:
        return jsonify({"error": "No patients found"}), 404

    categories = {
        "by_bmi": {
            "Underweight": [],
            "Normal": [],
            "Overweight": [],
            "Obese": []
        },
        "by_age_group": {
            "Child (0-17)": [],
            "Adult (18-44)": [],
            "Middle-aged (45-59)": [],
            "Senior (60+)": []
        },
        "by_risk_level": {
            "Low": [],
            "Moderate": [],
            "High": [],
            "Critical": []
        }
    }

    for p in patients:
        bmi = round(p.weight / ((p.height / 100) ** 2), 2)

        # ── BMI category ──────────────────────────────────
        if bmi < 18.5:
            bmi_cat = "Underweight"
        elif bmi < 25:
            bmi_cat = "Normal"
        elif bmi < 30:
            bmi_cat = "Overweight"
        else:
            bmi_cat = "Obese"

        # ── Age group ─────────────────────────────────────
        if p.age < 18:
            age_group = "Child (0-17)"
        elif p.age < 45:
            age_group = "Adult (18-44)"
        elif p.age < 60:
            age_group = "Middle-aged (45-59)"
        else:
            age_group = "Senior (60+)"

        # ── Risk level ────────────────────────────────────
        risk = "Low"
        if bmi < 18.5 or bmi >= 30:
            risk = "High"
        elif bmi >= 25:
            risk = "Moderate"
        if bmi >= 35:
            risk = "Critical"
        if p.activity_level.lower() == "sedentary" and risk == "Low":
            risk = "Moderate"

        # ── Patient summary ───────────────────────────────
        summary = {
            "id": p.id,
            "name": p.name,
            "age": p.age,
            "bmi": bmi,
            "bmi_category": bmi_cat,
            "risk_level": risk
        }

        categories["by_bmi"][bmi_cat].append(summary)
        categories["by_age_group"][age_group].append(summary)
        categories["by_risk_level"][risk].append(summary)

    return jsonify(categories), 200

import io
import csv
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from flask import send_file

# ── Export CSV (FR8) ──────────────────────────────────────
@app.route("/patients/export/csv", methods=["GET"])
@jwt_required()
def export_csv():
    user_id = get_jwt_identity()
    patients = Patient.query.filter_by(nutritionist_id=user_id).all()

    if not patients:
        return jsonify({"error": "No patients found"}), 404

    output = io.StringIO()
    writer = csv.writer(output)

    # Header row
    writer.writerow(["ID", "Name", "Age", "Gender", "Weight (kg)",
                     "Height (cm)", "Activity Level", "BMI", "BMI Category",
                     "BMR", "TDEE", "Protein (g)", "Carbs (g)", "Fats (g)"])

    for p in patients:
        bmi = round(p.weight / ((p.height / 100) ** 2), 2)
        if bmi < 18.5:
            bmi_cat = "Underweight"
        elif bmi < 25:
            bmi_cat = "Normal"
        elif bmi < 30:
            bmi_cat = "Overweight"
        else:
            bmi_cat = "Obese"

        if p.gender.lower() == "male":
            bmr = round((10 * p.weight) + (6.25 * p.height) - (5 * p.age) + 5, 2)
        else:
            bmr = round((10 * p.weight) + (6.25 * p.height) - (5 * p.age) - 161, 2)

        factors = {"sedentary": 1.2, "light": 1.375, "moderate": 1.55,
                   "active": 1.725, "very_active": 1.9}
        tdee = round(bmr * factors.get(p.activity_level.lower(), 1.2), 2)

        protein = round((tdee * 0.30) / 4, 2)
        carbs = round((tdee * 0.45) / 4, 2)
        fats = round((tdee * 0.25) / 9, 2)

        writer.writerow([p.id, p.name, p.age, p.gender, p.weight,
                         p.height, p.activity_level, bmi, bmi_cat,
                         bmr, tdee, protein, carbs, fats])

    output.seek(0)
    return send_file(
        io.BytesIO(output.getvalue().encode()),
        mimetype="text/csv",
        as_attachment=True,
        download_name="patients_report.csv"
    )

# ── Export PDF (FR8) ──────────────────────────────────────
@app.route("/patients/export/pdf", methods=["GET"])
@jwt_required()
def export_pdf():
    user_id = get_jwt_identity()
    patients = Patient.query.filter_by(nutritionist_id=user_id).all()

    if not patients:
        return jsonify({"error": "No patients found"}), 404

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4)
    styles = getSampleStyleSheet()
    elements = []

    # Title
    elements.append(Paragraph("Smart Nutrition Assistant", styles["Title"]))
    elements.append(Paragraph("Patient Report", styles["Heading2"]))
    elements.append(Spacer(1, 20))

    for p in patients:
        bmi = round(p.weight / ((p.height / 100) ** 2), 2)
        if bmi < 18.5:
            bmi_cat = "Underweight"
        elif bmi < 25:
            bmi_cat = "Normal"
        elif bmi < 30:
            bmi_cat = "Overweight"
        else:
            bmi_cat = "Obese"

        if p.gender.lower() == "male":
            bmr = round((10 * p.weight) + (6.25 * p.height) - (5 * p.age) + 5, 2)
        else:
            bmr = round((10 * p.weight) + (6.25 * p.height) - (5 * p.age) - 161, 2)

        factors = {"sedentary": 1.2, "light": 1.375, "moderate": 1.55,
                   "active": 1.725, "very_active": 1.9}
        tdee = round(bmr * factors.get(p.activity_level.lower(), 1.2), 2)
        protein = round((tdee * 0.30) / 4, 2)
        carbs = round((tdee * 0.45) / 4, 2)
        fats = round((tdee * 0.25) / 9, 2)

        # Risk
        risk = "Low"
        if bmi < 18.5 or bmi >= 30:
            risk = "High"
        elif bmi >= 25:
            risk = "Moderate"
        if bmi >= 35:
            risk = "Critical"

        # Patient name header
        elements.append(Paragraph(f"Patient: {p.name}", styles["Heading3"]))
        elements.append(Spacer(1, 6))

        # Patient data table
        data = [
            ["Field", "Value"],
            ["Age", str(p.age)],
            ["Gender", p.gender.capitalize()],
            ["Weight", f"{p.weight} kg"],
            ["Height", f"{p.height} cm"],
            ["Activity Level", p.activity_level.capitalize()],
            ["BMI", f"{bmi} ({bmi_cat})"],
            ["BMR", f"{bmr} kcal/day"],
            ["TDEE", f"{tdee} kcal/day"],
            ["Protein", f"{protein} g/day"],
            ["Carbs", f"{carbs} g/day"],
            ["Fats", f"{fats} g/day"],
            ["Risk Level", risk],
        ]

        table = Table(data, colWidths=[200, 250])
        table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2E86AB")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F0F4F8")]),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("PADDING", (0, 0), (-1, -1), 6),
        ]))

        elements.append(table)
        elements.append(Spacer(1, 20))

    doc.build(elements)
    buffer.seek(0)
    return send_file(
        buffer,
        mimetype="application/pdf",
        as_attachment=True,
        download_name="patients_report.pdf"
    )

# ── Recommendations (FR7) ─────────────────────────────────
@app.route("/patients/<int:patient_id>/recommendations", methods=["GET"])
@jwt_required()
def recommendations(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    bmi = round(patient.weight / ((patient.height / 100) ** 2), 2)

    if patient.gender.lower() == "male":
        bmr = round((10 * patient.weight) + (6.25 * patient.height) - (5 * patient.age) + 5, 2)
    else:
        bmr = round((10 * patient.weight) + (6.25 * patient.height) - (5 * patient.age) - 161, 2)

    factors = {"sedentary": 1.2, "light": 1.375, "moderate": 1.55,
               "active": 1.725, "very_active": 1.9}
    tdee = round(bmr * factors.get(patient.activity_level.lower(), 1.2), 2)

    meal_plan = []
    lifestyle = []
    dietary_focus = []

    # ── Based on BMI ──────────────────────────────────────
    if bmi < 18.5:
        target_calories = tdee + 500
        meal_plan = [
            "Breakfast: Oats with whole milk, banana, and peanut butter",
            "Snack: Greek yogurt with honey and mixed nuts",
            "Lunch: Grilled chicken with brown rice and avocado",
            "Snack: Whole grain bread with cheese",
            "Dinner: Salmon with sweet potato and steamed vegetables"
        ]
        dietary_focus = [
            "Focus on calorie-dense nutrient-rich foods",
            "Eat every 3 hours to increase caloric intake",
            "Add healthy fats like nuts, avocado, and olive oil"
        ]
        lifestyle = [
            "Light resistance training 3x per week to build muscle",
            "Avoid excessive cardio which burns needed calories",
            "Track daily food intake to ensure caloric surplus"
        ]

    elif bmi < 25:
        target_calories = tdee
        meal_plan = [
            "Breakfast: Eggs with whole grain toast and fruit",
            "Snack: Apple with almond butter",
            "Lunch: Grilled fish with quinoa and salad",
            "Snack: Handful of mixed nuts",
            "Dinner: Lean meat with roasted vegetables and brown rice"
        ]
        dietary_focus = [
            "Maintain balanced macronutrient distribution",
            "Stay hydrated with 8 glasses of water daily",
            "Include a variety of colorful vegetables"
        ]
        lifestyle = [
            "Maintain current activity level",
            "Include 150 minutes of moderate exercise per week",
            "Prioritize 7-8 hours of sleep for metabolic health"
        ]

    elif bmi < 30:
        target_calories = tdee - 400
        meal_plan = [
            "Breakfast: Egg white omelette with spinach and tomatoes",
            "Snack: Celery with hummus",
            "Lunch: Grilled chicken salad with olive oil dressing",
            "Snack: Low-fat Greek yogurt",
            "Dinner: Baked fish with steamed broccoli and cauliflower rice"
        ]
        dietary_focus = [
            "Reduce refined carbohydrates and added sugars",
            "Increase fiber intake through vegetables and legumes",
            "Choose lean proteins to stay full longer"
        ]
        lifestyle = [
            "30 minutes of cardio 5 days per week",
            "Replace sugary drinks with water or herbal tea",
            "Use smaller plates to manage portion sizes"
        ]

    else:
        target_calories = tdee - 600
        meal_plan = [
            "Breakfast: Vegetable omelette with no added fat",
            "Snack: Cucumber and carrot sticks",
            "Lunch: Large salad with grilled chicken and lemon dressing",
            "Snack: Small handful of unsalted nuts",
            "Dinner: Steamed fish with large portion of non-starchy vegetables"
        ]
        dietary_focus = [
            "Strictly limit processed foods and fast food",
            "Eliminate sugary drinks and alcohol",
            "Focus on high-volume low-calorie foods like vegetables"
        ]
        lifestyle = [
            "Start with low-impact exercise like walking or swimming",
            "Consult a physician before starting intense exercise",
            "Consider working with a registered dietitian"
        ]

    # ── Age specific additions ────────────────────────────
    if patient.age > 60:
        dietary_focus.append("Increase calcium-rich foods: dairy, leafy greens, sardines")
        dietary_focus.append("Ensure adequate vitamin D through sunlight or supplements")

    # ── Activity specific additions ───────────────────────
    if patient.activity_level.lower() in ["active", "very_active"]:
        dietary_focus.append("Increase protein intake to support muscle recovery")
        dietary_focus.append("Consume carbohydrates before and after workouts")

    return jsonify({
        "patient": patient.name,
        "bmi": bmi,
        "target_calories_per_day": target_calories,
        "meal_plan": meal_plan,
        "dietary_focus": dietary_focus,
        "lifestyle_tips": lifestyle
    }), 200
    
    # ── Export Single Patient PDF ─────────────────────────────
@app.route("/patients/<int:patient_id>/export/pdf", methods=["GET"])
@jwt_required()
def export_patient_pdf(patient_id):
    user_id = get_jwt_identity()
    patient = Patient.query.filter_by(
        id=patient_id, nutritionist_id=user_id).first()
    if not patient:
        return jsonify({"error": "Patient not found"}), 404

    # ── Calculate metrics ──────────────────────────────────
    bmi = round(patient.weight / ((patient.height / 100) ** 2), 2)
    if bmi < 18.5: bmi_cat = "Underweight"
    elif bmi < 25: bmi_cat = "Normal"
    elif bmi < 30: bmi_cat = "Overweight"
    else: bmi_cat = "Obese"

    if patient.gender.lower() == "male":
        bmr = round((10 * patient.weight) + (6.25 * patient.height) -
                    (5 * patient.age) + 5, 2)
    else:
        bmr = round((10 * patient.weight) + (6.25 * patient.height) -
                    (5 * patient.age) - 161, 2)

    factors = {"sedentary": 1.2, "light": 1.375, "moderate": 1.55,
               "active": 1.725, "very_active": 1.9}
    tdee = round(bmr * factors.get(patient.activity_level.lower(), 1.2), 2)
    protein = round((tdee * 0.30) / 4, 2)
    carbs = round((tdee * 0.45) / 4, 2)
    fats = round((tdee * 0.25) / 9, 2)

    # ── ML Risk ────────────────────────────────────────────
    from ml_model import predict_risk
    risk_result = predict_risk(
        age=patient.age, gender=patient.gender,
        weight=patient.weight, height=patient.height,
        activity_level=patient.activity_level
    )

    # ── Build PDF ──────────────────────────────────────────
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4,
                            rightMargin=40, leftMargin=40,
                            topMargin=40, bottomMargin=40)
    styles = getSampleStyleSheet()
    elements = []

    # Title
    title_style = styles["Title"]
    elements.append(Paragraph("NutriAssist", title_style))
    elements.append(Paragraph("Patient Health Report",
                               styles["Heading2"]))
    elements.append(Spacer(1, 12))

    # Patient info
    elements.append(Paragraph("Patient Information",
                               styles["Heading3"]))
    info_data = [
        ["Field", "Value"],
        ["Name", patient.name],
        ["Age", f"{patient.age} years"],
        ["Gender", patient.gender.capitalize()],
        ["Weight", f"{patient.weight} kg"],
        ["Height", f"{patient.height} cm"],
        ["Activity Level", patient.activity_level.replace(
            '_', ' ').capitalize()],
    ]
    info_table = Table(info_data, colWidths=[180, 280])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0),
         colors.HexColor("#0D9488")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1),
         [colors.white, colors.HexColor("#F0F9FF")]),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("PADDING", (0, 0), (-1, -1), 8),
    ]))
    elements.append(info_table)
    elements.append(Spacer(1, 16))

    # Health metrics
    elements.append(Paragraph("Health Metrics",
                               styles["Heading3"]))
    metrics_data = [
        ["Metric", "Value", "Status"],
        ["BMI", str(bmi), bmi_cat],
        ["BMR", f"{bmr} kcal/day", "Base metabolic rate"],
        ["TDEE", f"{tdee} kcal/day", "Daily energy expenditure"],
        ["Risk Level", risk_result["risk_level"],
         f"{risk_result['confidence']}% confidence"],
    ]
    metrics_table = Table(metrics_data, colWidths=[150, 180, 130])
    metrics_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0),
         colors.HexColor("#0D9488")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1),
         [colors.white, colors.HexColor("#F0F9FF")]),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("PADDING", (0, 0), (-1, -1), 8),
    ]))
    elements.append(metrics_table)
    elements.append(Spacer(1, 16))

    # Macronutrients
    elements.append(Paragraph("Daily Macronutrient Targets",
                               styles["Heading3"]))
    macro_data = [
        ["Macronutrient", "Daily Target", "Calories"],
        ["Protein", f"{protein} g", f"{round(protein * 4)} kcal"],
        ["Carbohydrates", f"{carbs} g", f"{round(carbs * 4)} kcal"],
        ["Fats", f"{fats} g", f"{round(fats * 9)} kcal"],
        ["Total", "", f"{tdee} kcal"],
    ]
    macro_table = Table(macro_data, colWidths=[180, 150, 130])
    macro_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0),
         colors.HexColor("#0D9488")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -2),
         [colors.white, colors.HexColor("#F0F9FF")]),
        ("BACKGROUND", (0, -1), (-1, -1),
         colors.HexColor("#CCFBF1")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("PADDING", (0, 0), (-1, -1), 8),
    ]))
    elements.append(macro_table)
    elements.append(Spacer(1, 16))

    # Risk probabilities
    elements.append(Paragraph("Risk Assessment",
                               styles["Heading3"]))
    risk_probs = risk_result["probabilities"]
    risk_data = [
        ["Risk Level", "Probability"],
        ["Low", f"{risk_probs['Low']}%"],
        ["Moderate", f"{risk_probs['Moderate']}%"],
        ["High", f"{risk_probs['High']}%"],
        ["Critical", f"{risk_probs['Critical']}%"],
    ]
    risk_table = Table(risk_data, colWidths=[240, 220])
    risk_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0),
         colors.HexColor("#0D9488")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1),
         [colors.white, colors.HexColor("#F0F9FF")]),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("PADDING", (0, 0), (-1, -1), 8),
    ]))
    elements.append(risk_table)
    elements.append(Spacer(1, 16))

    # Footer
    elements.append(Paragraph(
        "Generated by NutriAssist — Smart Nutrition Management System",
        styles["Italic"]))

    doc.build(elements)
    buffer.seek(0)
    return send_file(
        buffer,
        mimetype="application/pdf",
        as_attachment=True,
        download_name=f"{patient.name.replace(' ', '_')}_report.pdf"
    )

# ── Run ───────────────────────────────────────────────────
if __name__ == "__main__":
    with app.app_context():
        db.create_all()  # Creates the database tables automatically
    app.run(host="0.0.0.0", port=5000, debug=True)