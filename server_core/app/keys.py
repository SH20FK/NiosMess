import base64
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

# 1. Генерируем асимметричный ключ RSA-2048
private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

# 2. Сохраняем приватный ключ в файл PEM (хранить строго на сервере ni-os.ru!)
private_pem = private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)
with open("private_key.pem", "wb") as f:
    f.write(private_pem)
print("[OK] private_key.pem успешно создан в папке скрипта.")

# 3. Получаем публичный ключ в кодировке DER (Base64) для Java-плагина
public_key = private_key.public_key()
public_der = public_key.public_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PublicFormat.SubjectPublicKeyInfo
)
public_base64 = base64.b64encode(public_der).decode("utf-8")

print("\n--- СКОПИРУЙ СТРОКУ НИЖЕ И ВСТАВЬ В JAVA-КОД ПЛАГИНА (StringCrypt) ---")
print(public_base64)
print("--------------------------------------------------------------------\n")