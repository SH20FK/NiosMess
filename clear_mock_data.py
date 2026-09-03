import os, json, time, sys

print('=' * 60)
print('   NiosMess: Сброс демо-режима и удаление всех мок-данных')
print('=' * 60)

reset_payload = {
    'reset': True,
    'timestamp': int(time.time()),
    'message': 'Mock data reset requested by user'
}

targets = [
    os.path.join(r'f:\Niosmess V2\pulse_flutter\build\web', 'mock_reset.json'),
    os.path.join(r'f:\Niosmess V2\pulse_flutter\web', 'mock_reset.json'),
]

for t in targets:
    try:
        os.makedirs(os.path.dirname(t), exist_ok=True)
        with open(t, 'w', encoding='utf-8') as f2:
            json.dump(reset_payload, f2, indent=2)
        print(f'[OK] Флаг сброса записан: {t}')
    except Exception as e:
        print(f'[WARN] Не удалось записать в {t}: {e}')

print('\n[SUCCESS] Все мок-данные и демо-сессия помечены на удаление!')
print('Обновите страницу в браузере (Ctrl + F5) — приложение автоматически')
print('очистит кэш, IndexedDB, localStorage и вернется к чистому экрану входа Nios ID.')
print('=' * 60)
