### Running with environment variables

# Development
flutter run \
  --dart-define=SUPABASE_URL=https://pbkoxrobqltdyoaemgez.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBia294cm9icWx0ZHlvYWVtZ2V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNTMwODcsImV4cCI6MjA3NzgyOTA4N30.yf2uLwtsgTt0uY5W5M2oBPUYqaZLjXvnXLCFORDf1lE \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key

# Production
flutter run --release \
  --dart-define=SUPABASE_URL=https://pbkoxrobqltdyoaemgez.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBia294cm9icWx0ZHlvYWVtZ2V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNTMwODcsImV4cCI6MjA3NzgyOTA4N30.yf2uLwtsgTt0uY5W5M2oBPUYqaZLjXvnXLCFORDf1lE \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_your_key
