# 📝 Funcionalidad de Registro de Pasajeros

## ✨ Características Implementadas

Se ha implementado una pantalla de registro completa y elegante para pasajeros con las siguientes características:

### 🎨 Interfaz de Usuario
- **Diseño moderno** con gradientes y sombras suaves
- **Tema consistente** con los colores de la app (AppColors)
- **Modo oscuro** compatible
- **Animaciones** sutiles y profesionales
- **Iconos profesionales** de Iconsax

### 📋 Campos del Formulario
1. **Foto de perfil** - Selector de imagen desde galería
2. **Nombre** - Campo de texto requerido
3. **Apellido** - Campo de texto requerido
4. **Tipo de identificación** - Dropdown con opciones:
   - CC (Cédula de Ciudadanía)
   - CE (Cédula de Extranjería)
   - TI (Tarjeta de Identidad)
   - Pasaporte
5. **Número de identificación** - Campo numérico requerido
6. **Fecha de nacimiento** - Selector de fecha con calendario
7. **Sexo** - Selector visual (Masculino/Femenino)
8. **Correo electrónico** - Con validación de formato
9. **Celular** - Campo de teléfono requerido
10. **Dirección** - Campo de texto requerido
11. **Contraseña** - Con requisito de mínimo 6 caracteres
12. **Confirmar contraseña** - Valida que coincidan

### ✅ Validaciones
- ✓ Todos los campos obligatorios validados
- ✓ Validación de formato de email
- ✓ Validación de longitud mínima de contraseña
- ✓ Validación de coincidencia de contraseñas
- ✓ Validación de fecha de nacimiento obligatoria

### 🔧 Funcionalidades Técnicas
- **Envío multipart/form-data** para incluir la foto
- **Manejo de errores** con mensajes amigables
- **Loading state** durante el registro
- **Formato de fecha** compatible con el backend (YYYY-MM-DD)
- **Navegación** automática al login después del registro exitoso

## 📁 Archivos Modificados/Creados

### Nuevos Archivos
- `lib/features/auth/presentation/register_screen.dart` - Pantalla de registro

### Archivos Modificados
- `lib/features/auth/services/auth_service.dart` - Agregado método `register()`
- `lib/features/auth/logic/auth_provider.dart` - Agregado método `register()`
- `lib/features/auth/presentation/login_screen.dart` - Agregada navegación al registro
- `lib/main.dart` - Agregada ruta '/register'

## 🚀 Cómo Usar

### Para el Usuario
1. En la pantalla de login, presionar **"Regístrate aquí"**
2. Completar todos los campos del formulario
3. Opcionalmente, agregar una foto de perfil
4. Presionar el botón **"Registrarse"**
5. Si el registro es exitoso, será redirigido al login

### Para Desarrolladores

#### Endpoint del Backend
```
POST {{base_url}}/register_passenger
Content-Type: multipart/form-data
```

#### Parámetros Enviados
```dart
{
  'identificacion': String,
  'nombre1': String,
  'apellido1': String,
  'fechaNac': String (YYYY-MM-DD),
  'direccion': String,
  'email': String,
  'celular': String,
  'sexo': String ('M' o 'F'),
  'idTipoIdentificacion': int (1-4),
  'password': String,
  'password_confirmation': String,
  'foto': File (opcional)
}
```

#### Uso Programático
```dart
// Navegar a la pantalla de registro
Navigator.pushNamed(context, '/register');

// O usar el botón en la pantalla de login
TextButton(
  onPressed: () {
    Navigator.pushNamed(context, '/register');
  },
  child: const Text("Regístrate aquí"),
)
```

## 🎨 Personalización de Estilos

Los estilos utilizan los colores definidos en `AppColors`:
- **Primary**: `#FFC502`
- **Accent**: `#FF6605`
- **Secondary**: `#FFDC4A`

Para modificar los estilos, edita el archivo:
```
lib/core/theme/app_colors.dart
```

## 📱 Permisos Requeridos

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Necesitamos acceso a tu galería para seleccionar una foto de perfil</string>
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a tu cámara para tomar una foto</string>
```

## 🐛 Manejo de Errores

La aplicación maneja los siguientes errores:
- Errores de validación del servidor (mostrados individualmente)
- Errores de conexión
- Errores de formato de datos
- Timeouts de red

Todos los errores se muestran mediante `SnackBar` con fondo rojo para errores y verde para éxito.

## 🔐 Seguridad

- Las contraseñas se envían al servidor (el backend debe encriptarlas)
- No se almacenan localmente después del registro
- La foto se comprime a 1024x1024 con calidad del 85%

## 📊 Estado de Carga

Durante el proceso de registro:
- El botón muestra un `CircularProgressIndicator`
- Se deshabilita el botón para evitar dobles envíos
- Se actualiza el estado global con `AuthProvider`

## 🎯 Próximas Mejoras Sugeridas

1. ✨ Agregar opción para tomar foto con la cámara
2. ✨ Validación de teléfono con formato específico
3. ✨ Verificación de email mediante código
4. ✨ Términos y condiciones con checkbox
5. ✨ Indicador de fortaleza de contraseña
6. ✨ Auto-login después del registro exitoso

---

**Desarrollado con ❤️ para IntelliTaxi**
