# Matriz de permisos y seguridad

| Capacidad | Administrador | Pastor | Secretario | Tesorero | Coordinador |
|---|---:|---:|---:|---:|---:|
| Gestionar usuarios y roles | CRUD | Ver | No | No | No |
| Configuración institucional | CRUD | Editar | Ver | Ver | No |
| Miembros | CRUD | CRUD | CRUD | Ver | Ver asignados |
| Asistencia | CRUD | CRUD | CRUD | Ver | Registrar asignados |
| Eventos | CRUD | CRUD | CRUD | Ver | Crear asignados |
| Ministerios | CRUD | CRUD | Ver | Ver | CRUD asignado |
| Finanzas | CRUD | Ver resumen | No | CRUD | No |
| Comunicados | CRUD | CRUD/publicar | CRUD/publicar | Ver | Proponer |
| Dashboard general | Sí | Sí | Sí | Sí financiero | Sí asignado |
| Reporte de miembros | Sí | Sí | Sí | Sí | Asignado |
| Reporte de asistencia | Sí | Sí | Sí | Sí | Asignado |
| Reporte financiero | Sí | Resumen | No | Sí | No |

## Seguridad de autenticación

- Supabase Auth gestiona registro, login, refresh token y recuperación.
- La aplicación nunca implementa hashing propio ni guarda contraseñas.
- El deep link de restablecimiento abre una ruta protegida de nueva contraseña.
- La sesión se invalida con cierre de sesión y expiración del refresh token.
- Los errores de login se muestran sin revelar si un correo existe.

## Autorización

- La UI oculta acciones no permitidas, pero no se confía en esa ocultación.
- Cada tabla tiene RLS habilitado.
- Las funciones SQL de autorización consultan `user_roles`.
- Las operaciones privilegiadas se validan también en Edge Functions.
- Finanzas no se incluyen en consultas de dashboard para usuarios sin permiso.

## Protección de datos

- Validación y normalización de correo, teléfonos, fechas y montos.
- Límites de longitud y cantidades positivas en el cliente y PostgreSQL.
- No registrar datos sensibles en logs de producción.
- Storage de logotipo con bucket público o URL firmada según decisión final.
- Auditoría de cambios financieros, roles y configuración.
