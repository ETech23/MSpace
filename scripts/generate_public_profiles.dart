import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final env = _loadEnv('.env');
  final supabaseUrl = env['SUPABASE_URL'];
  final serviceKey = env['SUPABASE_SERVICE_ROLE_KEY'];
  if (supabaseUrl == null || serviceKey == null) {
    stderr.writeln('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
    exit(1);
  }

  final headers = {
    'apikey': serviceKey,
    'Authorization': 'Bearer $serviceKey',
    'Content-Type': 'application/json',
  };

  final profiles = <_ProfileRef>[];
  profiles.addAll(await _fetchProfileRefs(
    supabaseUrl,
    headers,
    'artisan_profiles',
  ));
  profiles.addAll(await _fetchProfileRefs(
    supabaseUrl,
    headers,
    'business_profiles',
  ));

  final outputDir = Directory('public/p');
  if (outputDir.existsSync()) {
    outputDir.deleteSync(recursive: true);
  }
  outputDir.createSync(recursive: true);

  final generatedProfiles = <_ProfileRef>[];
  for (final profile in profiles) {
    final data = await _fetchPublicProfile(supabaseUrl, headers, profile.userId);
    if (data == null) continue;
    generatedProfiles.add(profile);
    final profileDir = Directory('public/p/${profile.userId}');
    if (!profileDir.existsSync()) {
      profileDir.createSync(recursive: true);
    }
    final html = _buildProfileHtml(data);
    File('${profileDir.path}/index.html').writeAsStringSync(html);
  }

  _writeSitemap(generatedProfiles);
  stdout.writeln('Generated ${generatedProfiles.length} profile pages.');
}

Map<String, String> _loadEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final lines = file.readAsLinesSync();
  final env = <String, String>{};
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    final key = trimmed.substring(0, idx).trim();
    final value = trimmed.substring(idx + 1).trim();
    env[key] = value;
  }
  return env;
}

Future<List<_ProfileRef>> _fetchProfileRefs(
  String baseUrl,
  Map<String, String> headers,
  String table,
) async {
  final uri = Uri.parse(
    '$baseUrl/rest/v1/$table?select=user_id,updated_at',
  );
  final res = await http.get(uri, headers: headers);
  if (res.statusCode != 200) {
    stderr.writeln('Failed to fetch $table: ${res.body}');
    return [];
  }
  final data = json.decode(res.body) as List<dynamic>;
  return data
      .map((row) => _ProfileRef(
            userId: row['user_id'] as String,
            updatedAt: row['updated_at'] as String?,
          ))
      .toList();
}

Future<Map<String, dynamic>?> _fetchPublicProfile(
  String baseUrl,
  Map<String, String> headers,
  String userId,
) async {
  final uri = Uri.parse('$baseUrl/rest/v1/rpc/get_public_profile');
  final res = await http.post(
    uri,
    headers: headers,
    body: json.encode({'profile_user_id': userId}),
  );
  if (res.statusCode != 200) {
    stderr.writeln('Failed to fetch profile $userId: ${res.body}');
    return null;
  }
  if (res.body == 'null') return null;
  return json.decode(res.body) as Map<String, dynamic>;
}

String _buildProfileHtml(Map<String, dynamic> profile) {
  String esc(String? value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value ?? '');

  final displayName = esc(profile['display_name']?.toString());
  final profileType =
      profile['user_type']?.toString() == 'business' ? 'Business' : 'Artisan';
  final category = profile['category']?.toString();
  final categoriesList = profile['categories'];
  final categories = category ??
      (categoriesList is List ? categoriesList.join(', ') : null);
  final categoryText = esc(categories);
  final city = esc(profile['city']?.toString());
  final state = esc(profile['state']?.toString());
  final description =
      esc(profile['description']?.toString() ?? profile['bio']?.toString());

  final location = [city, state].where((e) => e.isNotEmpty).join(', ');
  final summaryParts = [
    if (categoryText.isNotEmpty) categoryText,
    if (location.isNotEmpty) 'Based in $location',
  ];
  final summary = summaryParts.join(' - ');
  final email = esc(profile['email']?.toString());
  final contactPhone = esc(
    profile['contact_phone']?.toString() ?? profile['phone']?.toString(),
  );
  final address = esc(profile['address']?.toString());
  final details = [
    if (email.isNotEmpty) '<p><strong>Email:</strong> $email</p>',
    if (contactPhone.isNotEmpty) '<p><strong>Phone:</strong> $contactPhone</p>',
    if (address.isNotEmpty) '<p><strong>Address:</strong> $address</p>',
  ].join('');

  return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$displayName | MSpace</title>
  <meta name="description" content="View $displayName on MSpace.">
  <link rel="canonical" href="https://naco-d2738.web.app/p/${esc(profile['user_id']?.toString())}">
  <style>
    body { font-family: "Trebuchet MS", "Segoe UI", Tahoma, sans-serif; margin: 0; background: #f7faff; color: #0b1a2a; }
    .wrap { max-width: 900px; margin: 0 auto; padding: 28px; }
    .card { background: #fff; border-radius: 18px; padding: 24px; border: 1px solid rgba(10,35,64,0.12); }
    .pill { display: inline-flex; padding: 6px 12px; border-radius: 999px; font-size: 12px; background: rgba(26,115,232,0.08); color: #0b57d0; font-weight: 600; }
    h1 { margin: 12px 0 8px; }
    .muted { color: #52606d; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="pill">$profileType</div>
      <h1>$displayName</h1>
      <p class="muted">$summary</p>
      $details
      <p>${description.isEmpty ? '' : description}</p>
    </div>
  </div>
</body>
</html>
''';
}

void _writeSitemap(List<_ProfileRef> profiles) {
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final profile in profiles) {
    final loc = 'https://naco-d2738.web.app/p/${profile.userId}';
    buffer.writeln('  <url>');
    buffer.writeln('    <loc>$loc</loc>');
    if (profile.updatedAt != null) {
      buffer.writeln('    <lastmod>${profile.updatedAt}</lastmod>');
    }
    buffer.writeln('  </url>');
  }
  buffer.writeln('</urlset>');

  File('public/sitemap-profiles.xml').writeAsStringSync(buffer.toString());
}

class _ProfileRef {
  final String userId;
  final String? updatedAt;

  _ProfileRef({required this.userId, this.updatedAt});
}
