# Supabase Configuration

## Для приватного репозиторію

Файл `lib/config/supabase_config.dart` містить API ключі Supabase і знаходиться в Git репозиторії.

**Важливо:** Репозиторій повинен залишатися приватним!

## API ключі

- **Project URL:** https://wcczieoznbopcafdatpk.supabase.co
- **Anon Key:** Для клієнтських запитів
- **Service Role Key:** Для адміністративних операцій (AdminService)

## Безпека

⚠️ **Ніколи не робіть репозиторій публічним** з цими ключами!

Якщо потрібно зробити код відкритим:
1. Додайте `lib/config/supabase_config.dart` до `.gitignore`
2. Створіть template файл з placeholder значеннями
3. Налаштуйте environment variables для CI/CD 