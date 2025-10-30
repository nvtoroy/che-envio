#!/bin/bash

# Полный скрипт создания .app bundle для CorreoCheck

APP_NAME="CorreoCheck"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 Создание полного .app bundle для $APP_NAME..."

# Сборка релизной версии
echo "� Сборка релизной версии..."
swift build --configuration release

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при сборке"
    exit 1
fi

# Очистка предыдущей версии
echo "🧹 Очистка предыдущей версии..."
rm -rf "$APP_DIR"

# Создание структуры .app
echo "� Создание структуры .app..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Копирование исполняемого файла
echo "📋 Копирование исполняемого файла..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Копирование иконки
echo "🎨 Копирование иконки..."
if [ -f "icon.png" ]; then
    cp "icon.png" "$RESOURCES_DIR/icon.png"
    echo "✅ Иконка добавлена"
else
    echo "⚠️ Файл icon.png не найден"
fi

# Создание Info.plist
echo "� Создание Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Correo Argentino Check</string>
    <key>CFBundleIdentifier</key>
    <string>com.correoarg.check</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>icon.png</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 CorreoCheck. All rights reserved.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

# Создание PkgInfo
echo "📦 Создание PkgInfo..."
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Установка прав доступа
echo "🔐 Установка прав доступа..."
chmod +x "$MACOS_DIR/$APP_NAME"

# Проверка целостности
echo "✅ Проверка целостности .app bundle..."
if [ -f "$MACOS_DIR/$APP_NAME" ] && [ -f "$CONTENTS_DIR/Info.plist" ] && [ -f "$CONTENTS_DIR/PkgInfo" ]; then
    echo "✅ .app bundle создан успешно: $APP_DIR"
    echo ""
    echo "� Информация о приложении:"
    echo "   Имя: Correo Argentino Check"
    echo "   Исполняемый файл: $MACOS_DIR/$APP_NAME"
    echo "   Размер: $(du -h "$APP_DIR" | cut -f1)"
    echo ""
    echo "🚀 Команды для запуска:"
    echo "   GUI: open $APP_DIR"
    echo "   Консоль: $MACOS_DIR/$APP_NAME"
    echo ""
    echo "📁 Структура:"
    tree "$APP_DIR" 2>/dev/null || find "$APP_DIR" -type f
else
    echo "❌ Ошибка создания .app bundle"
    exit 1
fi
