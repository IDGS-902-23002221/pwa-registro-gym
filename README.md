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
│        └─ shared/            # layouts, cliente de Supabase, utilidades
├─ db/
│  ├─ migrations/              # 0001_*.sql, 0002_*.sql ...
│  ├─ seed.sql                 # datos iniciales (planes)
│  └─ tests/                   # consultas de verificación
└─ scripts/                    # aplicar migraciones, respaldo y restauración
```

`features/auth`, `features/planes`, `features/pagos` y `features/reportes` están
vacíos: son marcadores de posición con un `.gitkeep`, porque git no trackea
carpetas vacías. `shared/` todavía no tiene el cliente de Supabase; se agrega
cuando se conecte la persistencia.

## Requisitos

- Node.js 20 o superior
- Un proyecto de Supabase con URL y clave anon

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

- `db/migrations/` guarda los archivos `.sql` numerados y en orden. Se aplican
  en secuencia y no se editan una vez aplicados.
- `db/seed.sql` inserta los datos iniciales (planes) de forma idempotente.
- `db/tests/` contiene consultas SQL de verificación para correr a mano contra
  la base ya migrada.

Hoy esas carpetas están vacías: el schema se define en un ticket aparte.
