# Sistema de Gestión Integral para Iglesias

Aplicación móvil Flutter para Android e iOS con Material Design 3 y backend
Supabase.

## Estado actual

La primera fase implementada contiene:

- Proyecto Flutter para Android e iOS.
- Tema Material 3 responsive.
- Configuración segura mediante `--dart-define`.
- Inicialización opcional de Supabase.
- Inicio de sesión con correo y contraseña.
- Recuperación de contraseña por correo.
- Cierre de sesión.
- Sesión reactiva con Supabase Auth.
- Dashboard móvil inicial con KPIs y navegación `NavigationBar`.
- Gestión de miembros con búsqueda, filtros, alta, edición y baja lógica.
- Gestión de eventos con tipos, fecha, hora, lugar, edición y cancelación.
- Control de asistencia con selección de evento/fecha, presentes, ausentes,
  guardado por lote e historial.
- Ministerios con coordinadores, integrantes, activación y desactivación.
- Actividades de ministerios con alta, edición, consulta y eliminación.
- Finanzas con control por rol, movimientos, anonimato, periodos y resumen.
- Comunicados con borradores, publicación, edición y eliminación.
- Dashboard con KPIs reales, resumen financiero autorizado y gráfica de
  asistencia de seis meses.
- Reportes de miembros, asistencia, ministerios y finanzas autorizadas con
  vista previa y exportación PDF.
- Configuración institucional con datos de contacto, horarios y logotipo en
  Supabase Storage.
- Pruebas de widgets para configuración y validaciones.

Los requisitos y el diseño de todos los módulos están documentados en
[`docs/`](./docs/).

La autorización de servidor y el bucket del logotipo se configuran con
[`06-rls-y-storage.sql`](./docs/06-rls-y-storage.sql). Debe ejecutarse después
del esquema base. Este script también crea automáticamente el perfil en
`public.profiles` al registrar un usuario en Supabase Auth. Después del primer
registro, asígnale manualmente un rol en `public.user_roles`; por ejemplo:

```sql
insert into public.user_roles (user_id, role)
select id, 'administrador'::public.app_role
from auth.users
where email = 'admin@tu-dominio.com';
```

Valida la configuración con usuarios de roles distintos.

## Configuración de Supabase

No se guardan credenciales en el repositorio. Ejecuta la aplicación con la URL
del proyecto y la clave pública:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=tu-clave-publica
```

La clave debe ser la clave pública/publishable de Supabase. Nunca uses una
service role key dentro de la aplicación móvil.

## Verificación local

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Estructura principal

```text
lib/
  app/                 # Aplicación y tema Material 3
  core/config/         # Configuración por entorno
  features/auth/       # Login y recuperación
  features/dashboard/  # Dashboard inicial
```

La migración SQL incluye RLS, políticas de Storage y triggers de auditoría para
las operaciones de negocio. Debe ejecutarse en Supabase antes de producción.
