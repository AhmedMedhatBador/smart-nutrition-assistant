
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio;

 ApiService() : _dio = Dio(BaseOptions(
    baseUrl: 'https://nutriassist-backend-production.up.railway.app',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── Save token ──────────────────────────────────────────
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // ── Get token ───────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ── Clear token (logout) ────────────────────────────────
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ── Auth header ─────────────────────────────────────────
  Future<Map<String, String>> _authHeader() async {
    final token = await getToken();
    return {'Authorization': 'Bearer $token'};
  }

  // ── Register ────────────────────────────────────────────
  Future<Response> register(String name, String email, String password) async {
    return await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  // ── Login ───────────────────────────────────────────────
  Future<Response> login(String email, String password) async {
    return await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  // ── Get all patients ────────────────────────────────────
  Future<Response> getPatients() async {
    return await _dio.get('/patients',
        options: Options(headers: await _authHeader()));
  }

  // ── Add patient ─────────────────────────────────────────
  Future<Response> addPatient(Map<String, dynamic> data) async {
    return await _dio.post('/patients',
        data: data, options: Options(headers: await _authHeader()));
  }

  // ── Get calculations ────────────────────────────────────
  Future<Response> getCalculations(int patientId) async {
    return await _dio.get('/patients/$patientId/calculate',
        options: Options(headers: await _authHeader()));
  }

  // ── Get risk assessment ─────────────────────────────────
  Future<Response> getRisk(int patientId) async {
    return await _dio.get('/patients/$patientId/risk',
        options: Options(headers: await _authHeader()));
  }

  // ── Get recommendations ─────────────────────────────────
  Future<Response> getRecommendations(int patientId) async {
    return await _dio.get('/patients/$patientId/recommendations',
        options: Options(headers: await _authHeader()));
  }

  // ── Get categories ──────────────────────────────────────
  Future<Response> getCategories() async {
    return await _dio.get('/patients/categories',
        options: Options(headers: await _authHeader()));
  }

  // ── Delete patient ──────────────────────────────────────
  Future<Response> deletePatient(int patientId) async {
    return await _dio.delete('/patients/$patientId',
        options: Options(headers: await _authHeader()));
  }

  // ── Update patient ──────────────────────────────────────
  Future<Response> updatePatient(int patientId, Map<String, dynamic> data) async {
    return await _dio.put('/patients/$patientId',
        data: data, options: Options(headers: await _authHeader()));
  }

// ── Compare ML models ───────────────────────────────────
Future<Response> compareModels(int patientId) async {
  return await _dio.get('/patients/$patientId/risk/compare',
      options: Options(headers: await _authHeader()));
}

// ── LIME Explanation ────────────────────────────────────
Future<Response> explainRisk(int patientId) async {
  return await _dio.get('/patients/$patientId/explain',
      options: Options(headers: await _authHeader()));
}

// ── Training history ────────────────────────────────────
Future<Response> getTrainingHistory() async {
  return await _dio.get('/ml/training-history');
}

// ── Export CSV ──────────────────────────────────────────
Future<Response> exportCsv() async {
  return await _dio.get('/patients/export/csv',
      options: Options(
        headers: await _authHeader(),
        responseType: ResponseType.bytes,
      ));
}

// ── Export single patient PDF ───────────────────────────
Future<Response> exportPatientPdf(int patientId) async {
  return await _dio.get('/patients/$patientId/export/pdf',
      options: Options(
        headers: await _authHeader(),
        responseType: ResponseType.bytes,
      ));
}

// ── Export all patients CSV ─────────────────────────────
Future<Response> exportCsvBytes() async {
  return await _dio.get('/patients/export/csv',
      options: Options(
        headers: await _authHeader(),
        responseType: ResponseType.bytes,
      ));
}

}