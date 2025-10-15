# 🎵 StepSync

> _"Sentí el ritmo. Sincronizá tus pasos con la música."_

---

## 🚀 Descripción
**StepSync** es una app móvil desarrollada en **Flutter**, que combina movimiento y música. Utiliza los sensores del teléfono (acelerómetro y GPS) para detectar tu ritmo al caminar, trotar o correr, y sincroniza bucles musicales (loops) que se adaptan automáticamente a tu BPM.

🎯 **Objetivo:** transformar la actividad física en una experiencia interactiva, inmersiva y divertida.

---

## 🧩 Características principales
- 🔐 **Inicio de sesión con Google** (Firebase Authentication)
- 🎮 **Modos de juego:** Caminar, Trotar y Correr
- 📈 **Detección de pasos y BPM** en tiempo real con `sensors_plus`
- 🎵 **Loops musicales adaptativos** según tu ritmo (100–160 BPM)
- 🗺️ **Medición de distancia y calorías** (GPS + estimación energética)
- 🏆 **Sistema de logros y niveles** (en desarrollo)
- ☁️ **Progreso guardado en la nube** (Firebase Firestore)

---

## 🧱 Arquitectura
La app sigue una estructura modular tipo **MVC + Services**, separando UI, lógica de negocio y servicios:

```
/lib
├── screens/           # Pantallas (UI)
│   ├── splash_screen.dart
│   ├── welcome_screen.dart
│   ├── home_screen.dart
│   └── session_screen.dart
├── services/          # Lógica de sensores, auth, etc.
│   ├── auth_service.dart
│   └── step_service.dart
├── utils/             # Temas, constantes y helpers
│   └── theme.dart
├── widgets/           # Componentes reutilizables (botones, cards...)
└── app_router.dart    # Sistema de rutas (GoRouter)
```

📦 **Backend:** Firebase (Auth, Firestore)  
🧠 **Frontend:** Flutter + Material Design + Google Fonts  
🎵 **Sensores:** `sensors_plus` y `geolocator`

---

## 🧭 Flujo de usuario

1. 👋 **Pantalla de bienvenida** → login con Google.  
2. 🏠 **Home:** elegir modo de actividad (caminar/trotar/correr).  
3. 🎶 **Sesión:** la app detecta tus pasos, calcula el BPM y ajusta la música.  
4. 📊 **Estadísticas:** resumen de distancia, duración y BPM promedio.  
5. 🏅 **Logros:** desbloqueo de canciones y niveles (en próximos sprints).

---

## 🧠 Tecnologías utilizadas
| Categoría | Herramientas |
|------------|--------------|
| **Framework** | Flutter 3.24+ |
| **Lenguaje** | Dart |
| **Backend** | Firebase (Auth, Firestore) |
| **Sensores** | sensors_plus, geolocator |
| **Estado / Routing** | Provider, GoRouter |
| **Audio** | just_audio (loops musicales) |
| **UI / Estilo** | Google Fonts, Gradients, Material Design |

---

## 🪄 Paleta de colores
🎨 Inspirada en la energía del movimiento y la música electrónica.

| Color | Hex |
|--------|------|
| Fondo principal | `#0D0C14` |
| Gradiente azul-violeta | `#1B174B → #1C0B2D` |
| Verde (caminar) | `#42C86D → #2D978C` |
| Azul (trotar) | `#117DE7 → #2A41CE` |
| Rosa (correr) | `#BF3091` |
| Púrpura (otros menús) | `#8837F6 → #481A9D` |

---

## ⚙️ Instalación y ejecución

### 1️⃣ Clonar el repositorio
```bash
git clone https://github.com/<tu_usuario>/stepsync.git
cd stepsync
```

### 2️⃣ Instalar dependencias
```bash
flutter pub get
```

### 3️⃣ Configurar Firebase
- Crear un proyecto en [Firebase Console](https://console.firebase.google.com)
- Descargar `google-services.json` y colocarlo en `android/app/`
- Ejecutar:
```bash
flutterfire configure
```

### 4️⃣ Ejecutar en dispositivo físico (recomendado)
```bash
flutter run
```

---

## 🧑‍💻 Equipo de desarrollo
👨‍💻 **Alan Titos**  
📍 Universidad Nacional de la Patagonia Austral (UACO)  
📆 Proyecto para LAB. De Desarrollo De Software – 2025

---

## 🚧 Roadmap
- [x] Login con Google  
- [x] Detección de pasos simulada  
- [ ] Lectura real del acelerómetro  
- [ ] Sincronización de música con BPM  
- [ ] Logros y progreso en la nube  
- [ ] Modo desafío multijugador

---

> _StepSync: el ritmo está en vos._
