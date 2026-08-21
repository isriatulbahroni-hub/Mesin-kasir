import 'package:supabase_flutter/supabase_flutter.dart';

/// KONEKSI SUPABASE — PROJECT "Project kasir" (Kasir Pro)
///
/// PENTING: project ini (gyibrbxvffqfxveckhcp) TERPISAH TOTAL dari project
/// "Ppob" (ekbescwqymtqvbjmxxhu) milik NexaPay. JANGAN PERNAH ditukar/dicampur
/// URL atau anon key di file ini dengan project NexaPay.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://gyibrbxvffqfxveckhcp.supabase.co';

  // Anon key ini AMAN untuk ditaruh di client (Flutter), karena akses data
  // sepenuhnya dibatasi oleh RLS policy per-role (owner/admin/kasir) di
  // setiap tabel — bukan oleh kerahasiaan key ini.
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5aWJyYnh2ZmZxZnh2ZWNraGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4NDMzOTYsImV4cCI6MjEwMjQxOTM5Nn0.Sn9Ai8vQofht4moq4_aT6SsDZmrXgc8sUtwC3LSdIvA';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
