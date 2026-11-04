# Plan de desarrollo y calidad

## Fases

1. **Fundación:** proyecto Flutter mobile-first, tema Material 3, Supabase,
   navegación y manejo de sesión.
2. **Identidad:** registro, login, recuperación, perfil y RBAC.
3. **Operación principal:** dashboard, miembros, eventos y asistencia.
4. **Organización:** ministerios, equipos, responsables y actividades.
5. **Comunicación:** comunicados y próximos eventos.
6. **Finanzas:** movimientos, resúmenes, permisos y auditoría.
7. **Reportes:** consultas agregadas, PDF y compartir desde móvil.
8. **Configuración:** institución, horarios y logotipo.
9. **QA y endurecimiento:** pruebas, accesibilidad, rendimiento, seguridad y
   revisión de requisitos.

## Pruebas obligatorias

- Unitarias: validadores, casos de uso, mapeadores y cálculo de KPIs.
- Widgets: formularios, estados de carga/error/vacío, permisos y responsive.
- Integración: sesión, navegación protegida y operaciones CRUD con Supabase.
- Seguridad: RLS por rol, acceso financiero y sesión expirada.
- Reportes: contenido, totales, formato de moneda y compartir PDF.
- Accesibilidad: labels, contraste, tamaño táctil, escalado de texto.
- Responsive: teléfonos pequeños, teléfonos grandes, tablet vertical y
  horizontal.

## Criterios de salida

- `dart format` sin cambios pendientes.
- `flutter analyze` sin errores ni warnings del proyecto.
- Suite de pruebas automatizadas aprobada.
- Cada RF-01 a RF-10 tiene evidencia de prueba.
- No existen secretos en el repositorio.
- RLS verificada con al menos dos roles distintos.
- La migración `06-rls-y-storage.sql` fue ejecutada y validada en Supabase.
- No hay overflow en las resoluciones objetivo.
- Las pantallas tienen estados de carga, vacío y error.
- Las operaciones financieras quedan auditadas.

## Validación externa pendiente

- Ejecutar `06-rls-y-storage.sql` en el proyecto Supabase objetivo.
- Probar login, CRUD y RLS con usuarios de los cinco roles.
- Confirmar redirect URLs de recuperación de contraseña en Supabase.
- Confirmar la política institucional de retención de `audit_log`.
- Validar en dispositivos físicos Android/iOS y tablets; la navegación adapta
  `NavigationBar` en teléfonos y `NavigationRail` desde 800 dp.
