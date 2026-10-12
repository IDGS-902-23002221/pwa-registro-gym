# registro-gym

App web para registrar socios y membresías de un gym.

## Arquitectura

App estática (React + Vite) + Supabase como backend. No hay servidor propio ni
API intermedia: el frontend habla directo con Supabase y la seguridad la
definen las Row Level Security policies de la base de datos.

## Estructura

```text
registro-gym/
├─ apps/
│  └─ web/                     # React + Vite (JavaScript)
│     └─ src/
│        ├─ app/               # App.jsx, tema, rutas
│        ├─ features/          # una carpeta por funcionalidad
│        │  ├─ auth/
│        │  ├─ socios/         # components, hooks, services, models
│        │  ├─ membresias/
│        │  ├─ planes/
│        │  ├─ pagos/
│        │  └─ reportes/
│        ├─ pages/             # una pantalla por ruta
│        └─ shared/            # layouts, cliente de Supabase, utilidades
├─ db/
│  ├─ migrations/              # 0001_*.sql, 0002_*.sql ...
│  ├─ seed.sql                 # datos iniciales (planes)
│  └─ tests/                   # consultas de verificación
└─ scripts/                    # aplicar migraciones, respaldo y restauración
```

### Convenciones de `src/`

- `app/` es el único lugar que conoce todas las features. ahí vive el árbol de
  rutas, el tema y los hooks de nivel superior.
- `features/` guarda lógica de negocio reutilizable: `components/`, `hooks/`,
  `services/` (las queries a Supabase) y `models/` (validación). Una feature no
  importa de otra feature; si necesita datos de otra, se los pasan `app/` por
  props.
- `pages/` guarda las pantallas de ruta: un componente por ruta, que compone
  features y decide qué se renderiza. Son wrappers delgados, sin lógica de
  negocio. Ejemplos: `Login`, `ListaSocios`, `DetalleSocio`, `RegistrarPago`.
- `shared/` es lo transversal: layouts, cliente de Supabase y utilidades.

`features/auth`, `features/planes`, `features/pagos`, `features/reportes` y
`pages/` están vacíos: son marcadores de posición con un `.gitkeep`, porque git
no trackea carpetas vacías. `shared/` todavía no tiene el cliente de Supabase; se
agrega cuando se conecte la persistencia.

Hoy las pantallas viven en `features/socios/components/ModuloSocios.jsx` y
`features/membresias/components/ModuloMembresias.jsx`, que cumplen el papel de
`pages/` pero sin router todavía. Se mudan a `pages/` cuando se agreguen las
rutas, para no moverlas dos veces.

## Requisitos

- Node.js 20 o superior
- Un proyecto de Supabase con URL y clave anon
- PostgreSQL 15 o superior, para trabajar la base en local (ver [Base de datos](#base-de-datos))

## Puesta en marcha

```bash
npm install
cp .env.example .env    # completar con los valores del proyecto
cd apps/web
npm run dev
```

La app queda en http://localhost:5173.

## Scripts

Se ejecutan desde `apps/web`:

| Comando         | Qué hace                        |
| --------------- | ------------------------------- |
| `npm run dev`   | Servidor de desarrollo con HMR  |
| `npm run build` | Build de producción en `dist/`  |
| `npm run lint`  | Lint con `oxlint`               |
| `npm run preview` | Sirve el build de producción  |

## Variables de entorno

| Variable                | Para qué sirve                          |
| ----------------------- | --------------------------------------- |
| `VITE_SUPABASE_URL`     | URL del proyecto Supabase               |
| `VITE_SUPABASE_ANON_KEY`| Clave pública, limitada por las policies |

Ambas van en `.env`, que está en `.gitignore`. `.env.example` es la plantilla
sin valores. El prefijo `VITE_` es obligatorio para que Vite las exponga al
bundle; la clave anon nunca es una credencial administrativa.

## Base de datos

El backend es Supabase (PostgreSQL) y el frontend le habla directo. La seguridad no
está en el código del cliente: está en las policies de RLS y en las columnas a las
que cada rol tiene permiso.

### Estructura

```text
db/
├─ migrations/       # 0001_*.sql, 0002_*.sql ... en orden, nunca se editan
├─ seed.sql          # datos iniciales (planes), idempotente
└─ tests/            # verificaciones, cada una en su transacción
scripts/
├─ migrate.sh        # aplica las migraciones pendientes
├─ test-db.sh        # corre db/tests/
└─ test-folios-concurrencia.sh  # dos sesiones cobrando a la vez
```

### Requisitos

PostgreSQL 15 o superior. La vista `socios_con_estado` se crea con
`security_invoker = true`, y eso no existe antes de la 15. En Supabase siempre se
cumple; en local hay que comprobarlo:

```bash
psql -c 'SHOW server_version'
```

### Migraciones

Se aplican en orden y se registran en `public.schema_migrations` con un checksum, de
modo que un archivo ya aplicado que después cambia es un error y no un cambio
silencioso.

```bash
export DATABASE_URL='postgresql://usuario@localhost:5432/registro_gym'
./scripts/migrate.sh                    # solo las de 0001 a 0008
./scripts/migrate.sh --listar           # muestra cuáles faltan
```

Contra Supabase hay que decir `--objetivo supabase`, que además aplica `0009`:

```bash
./scripts/migrate.sh --objetivo supabase
```

`0009_trigger_perfil_auth.sql` es la única que toca el esquema `auth` (la llave
foránea a `auth.users` y el trigger que crea el perfil al dar de alta a un
usuario), porque en el PostgreSQL local ese esquema no existe. Corre solo con
`--objetivo supabase`; si se pide en local, el script se niega.

**Reglas de los archivos**

- Un archivo, una transacción. No se escribe `BEGIN` ni `COMMIT`: el runner los
  mete, y por eso `db/tests/` puede usar `BEGIN` / `ROLLBACK` sin conflicto.
- Nada de `CREATE INDEX CONCURRENTLY`: no se puede dentro de una transacción.
- Se agregan archivos nuevos, no se editan los que ya se aplicaron.
- No se edita `schema_migrations` a mano.

### Seed

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/seed.sql
```

Solo inserta el catálogo de planes, de forma idempotente. No crea socios ni pagos:
esos los crean `registrar_pago()` y `cambiar_estado_socio()`, y meterlos aquí se
saltaría las reglas de negocio.

### Verificaciones

```bash
./scripts/test-db.sh
```

Cada prueba de `db/tests/` corre en su propia transacción y la revierte al final, así
que no dejan filas. Sale con código 1 si algo falla. Requiere `psql` y que las
migraciones ya estén aplicadas.

| Verificación                    | Qué fija                                              |
| ------------------------------- | ---------------------------------------------------- |
| `01_identidad_unica.sql`        | El socio duplicado se rechaza; el homónimo con otro teléfono no |
| `02_doble_cobro.sql`            | El doble cobro del periodo falla, los errores de negocio y la cobertura |
| `03_folio_unico.sql`            | Los folios son consecutivos y un cobro revertido no reutiliza su folio |
| `04_estado_socio.sql`           | `activo` / `pausado` / `vencido` se calculan al leer |
| `05_cadena_de_cobertura.sql`    | La cobertura se encadena, ARCO anonimiza y conserva pagos (ADR-004) |
| `06_rls.sql`                    | `anon` no lee nada, un perfil desactivado tampoco, y lo que no se puede escribir desde el cliente |
| `07_rendimiento.sql`             | Con 500 socios, búsqueda y listado usan índices (RNF-07) |
| `test-folios-concurrencia.sh`   | Dos sesiones cobrando a la vez no repiten periodo ni folio |

La de concurrencia es la única que necesita dos conexiones de verdad: abre dos
`psql` en paralelo, por eso está en `scripts/` y no en `db/tests/`.

### Errores de negocio

Las funciones de negocio lanzan errores con SQLSTATE propio, para que el cliente
separe "no se pudo hacer" de "se cayó la conexión":

| Código    | Significado                       |
| --------- | --------------------------------- |
| `GYM01`   | `PAGO_PERIODO_YA_CUBIERTO`        |
| `GYM02`   | `SOCIO_NO_ENCONTRADO`             |
| `GYM03`   | `SOCIO_YA_ELIMINADO`              |
| `GYM04`   | `MONTO_INVALIDO`                  |
| `GYM05`   | `FORMA_PAGO_INVALIDA`             |
| `GYM06`   | `PERIODO_INVALIDO`                |
| `GYM07`   | `PLAN_INVALIDO`                   |
| `GYM08`   | `ESTADO_SOCIO_INVALIDO`           |
| `GYM09`   | `JUSTIFICACION_REQUERIDA`         |
| `GYM10`   | `PERFIL_INACTIVO`                 |

El `MESSAGE` es siempre el nombre en mayúsculas y el `DETAIL` lleva el detalle en
texto plano, legible en el panel de Supabase sin consultar la documentación.

### Funciones de negocio

El cliente no escribe en `pago`, `recibo`, `membresia` ni `auditoria`: llama a estas
funciones, que son `SECURITY DEFINER` y por eso pueden escribir ignorando las
policies. A cambio, son las que garantizan las reglas.

| Función                                       | Para qué                                              |
| --------------------------------------------- | ----------------------------------------------------- |
| `registrar_pago(socio, monto, forma, periodo, referencia, plan)` | Cobra un periodo, emite el recibo, renueva la membresía y devuelve el folio |
| `cambiar_estado_socio(socio, estado, motivo)` | Pausa o reactiva un socio, con motivo obligatorio     |
| `reporte_ingresos(desde, hasta)`               | Ingresos por forma de pago en un rango                |
| `reporte_cartera()`                           | Quién está al corriente y quién se atrasó             |
| `exportar_socio(socio)`                       | Ficha completa de un socio, para exportar             |
| `eliminar_socio(socio)`                       | Anonimiza los datos personales (ARCO) y conserva pagos |

### Datos de prueba en local

En local no se cargan datos reales (03 §1). El `seed` solo trae planes; los socios y
pagos de las pruebas se crean y se borran solos.

El `README` y las carpetas cambian con cada ticket: la estructura y el árbol de
`src/` los define `TICKET 000.0`, y esta sección de base de datos, `TICKET 000.1`.
