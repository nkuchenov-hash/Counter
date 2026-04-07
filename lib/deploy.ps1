Write-Host "🚀 Начинаем сборку Flutter..." -ForegroundColor Cyan
flutter build web --release --no-tree-shake-icons

Write-Host "☁️ Отправляем в Firebase..." -ForegroundColor Yellow
# Мы используем полную команду через npx, чтобы Cursor точно ее нашел
npx firebase-tools deploy --only hosting

Write-Host "✅ Готово! Сайт обновлен." -ForegroundColor Green