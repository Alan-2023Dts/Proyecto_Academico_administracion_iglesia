# Sistema de Gestión Integral para Iglesias

## Alcance aprobado

- Aplicación móvil Flutter para Android e iOS.
- Material Design 3 con enfoque mobile-first.
- Backend Supabase: Auth, PostgreSQL, Storage y API.
- Módulos RF-01 a RF-10.
- Exportación de reportes en PDF.
- Autorización por roles y políticas RLS en la base de datos.

## Requisitos funcionales

| ID | Módulo | Criterios de aceptación |
|---|---|---|
| RF-01 | Autenticación | Registro, inicio/cierre de sesión, recuperación y restablecimiento por correo; rutas protegidas por sesión y rol. |
| RF-02 | Miembros | Alta, edición, consulta, búsqueda por nombre, filtros activo/inactivo y baja lógica. |
| RF-03 | Asistencia | Selección de evento y fecha, marcado presente/ausente, historial y resúmenes semanales/mensuales. |
| RF-04 | Eventos | CRUD, cancelación, responsables, eventos religiosos/administrativos y agenda. |
| RF-05 | Ministerios | CRUD de ministerios/equipos, coordinadores, integrantes y actividades. |
| RF-06 | Finanzas | Aportaciones, donaciones y ofrendas; periodo, monto, concepto, método, anonimato y restricciones. |
| RF-07 | Comunicados | Crear, editar, eliminar y publicar avisos con fecha y próximos eventos. |
| RF-08 | Dashboard | KPIs de miembros, eventos, asistencia, ministerios e ingresos según permisos. |
| RF-09 | Reportes | Reportes de miembros, asistencia, ministerios y finanzas; exportación PDF. |
| RF-10 | Configuración | Nombre, logotipo, dirección, contacto, horarios e información institucional. |

## Requisitos no funcionales

- Contraseñas gestionadas por Supabase Auth; nunca se almacenan en tablas propias.
- RLS obligatoria en tablas con información institucional o personal.
- Validación de entradas en cliente y restricciones en base de datos.
- No incluir claves secretas en el repositorio; solo la URL y clave pública de Supabase.
- Estados de carga, vacío, error, éxito y reintento en cada módulo.
- Controles táctiles de al menos 48 dp y etiquetas accesibles.
- Diseño adaptable a teléfonos pequeños, grandes y tablets.
- Soft delete para miembros y cancelación lógica de eventos.
- Auditoría de acciones sensibles, especialmente finanzas y permisos.

## Casos de uso principales

### Autenticación

- CU-01 Registrar usuario.
- CU-02 Iniciar sesión.
- CU-03 Solicitar recuperación.
- CU-04 Restablecer contraseña.
- CU-05 Cerrar sesión.

### Operación

- CU-06 Gestionar miembro.
- CU-07 Registrar asistencia.
- CU-08 Gestionar evento.
- CU-09 Gestionar ministerio e integrantes.
- CU-10 Registrar movimiento financiero autorizado.
- CU-11 Publicar comunicado.
- CU-12 Consultar dashboard.
- CU-13 Generar y compartir reporte PDF.
- CU-14 Actualizar configuración institucional.

## Reglas de negocio

1. Solo usuarios autenticados acceden a la aplicación.
2. El administrador administra usuarios, roles y configuración.
3. Las finanzas solo son visibles para Administrador y Tesorero.
4. El Pastor puede consultar la información global y aprobar/publicar contenido.
5. Secretario gestiona miembros, asistencia, eventos y comunicados.
6. Coordinador gestiona su ministerio, integrantes y actividades asignadas.
7. Un miembro inactivo no se elimina físicamente y no aparece en selecciones activas.
8. Una asistencia debe pertenecer a un evento, fecha y miembro únicos.
9. Un evento cancelado no se registra como próximo.
10. Un movimiento financiero no se elimina físicamente; se audita su corrección.
