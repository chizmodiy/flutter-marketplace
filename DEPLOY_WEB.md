# Оновлення веб-версії Zeno

## Деплой через Vercel CLI (без Git)

Якщо Git-інтеграція не працює — деплой з терміналу:

```bash
npm i -g vercel
vercel login
cd /шлях/до/olxclone
vercel link
vercel deploy --prod
```

**Перший раз:** `vercel link` → вибери **zeno** (або створій новий). Далі `vercel deploy --prod` — збірка піде на сервери Vercel, Git не потрібен.

## Локальна збірка (без деплою)

```bash
flutter config --enable-web
flutter pub get
flutter build web --release --base-href /
```

Результат у `build/web/`.
