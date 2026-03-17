/**
 * Prisma Client Singleton
 * Per docs/operations-planning/08-VERCEL-NEON-PRISMA-INTEGRATION.md:
 * - Create Prisma Client once per server instance
 * - Reuse across requests
 * - In development, reuse via global reference to avoid hot-reload explosion
 */
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === "development"
        ? ["query", "error", "warn"]
        : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
