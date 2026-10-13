class AppConstants {
  static const appName = 'กิ๋นหยังดีจ้าว';
  static const tagline = 'จากวัตถุดิบที่มี สู่เมนูที่ทำได้';

  // ส่งค่าตอน build/run: --dart-define-from-file=dart_defines.json
  static const apiKey = String.fromEnvironment('AI_API_KEY');
  static const apiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'https://gen.ai.kku.ac.th/upacth/api/v1',
  );
  static const aiModel = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'gemini-3.1-pro-preview',
  );
}
