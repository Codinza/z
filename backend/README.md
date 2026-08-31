# RideFlow Backend Phase 1

This backend is the first, runnable phase of the ride-hailing app.

## What is included
- Express server
- Socket.IO real-time events
- Dummy user context for the current phase
- Ride request business logic
- Prisma schema for future persistence
- Google Maps-ready service layer structure

## Phase 1 goals
- Create a ride request
- Estimate fare
- Assign a driver status
- Track trip lifecycle
- Emit real-time updates over Socket.IO

## Run

## Supabase setup

1. Create a new Supabase project and open **Project Settings > Database > Connection string**.
2. Copy the **Session pooler** URI into `DATABASE_URL`; keep port `6543`, add `pgbouncer=true`, and use `connection_limit=1`.
3. Copy the **Direct connection** URI into `DIRECT_URL`; keep port `5432`.
4. Put both values in `backend/.env` (never commit this file).
5. Create the current tables and new shipping fields:

```bash
cd backend
npm run prisma:push
npm run prisma:generate
```

Use the database password from the new project. If it is unknown, reset it in Supabase under **Project Settings > Database**.

```bash
cd backend
npm install
npm run dev
```
