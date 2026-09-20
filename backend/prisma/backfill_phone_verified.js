/**
 * One-off backfill: grandfather every account that existed before phone
 * verification was introduced, so the new login gate cannot lock them out.
 *
 * Safe to re-run: it only touches rows still flagged as unverified, and the
 * cutoff keeps accounts registered after the rollout subject to verification.
 *
 * Usage: node prisma/backfill_phone_verified.js [isoCutoffDate]
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const cutoffArg = process.argv[2];
  const cutoff = cutoffArg ? new Date(cutoffArg) : new Date();

  if (Number.isNaN(cutoff.getTime())) {
    throw new Error(`Invalid cutoff date: ${cutoffArg}`);
  }

  const pending = await prisma.user.count({
    where: { phoneVerified: false, createdAt: { lt: cutoff } },
  });

  if (pending === 0) {
    console.log('Nothing to backfill: no legacy unverified accounts found.');
    return;
  }

  const { count } = await prisma.user.updateMany({
    where: { phoneVerified: false, createdAt: { lt: cutoff } },
    data: { phoneVerified: true },
  });

  console.log(
    `Grandfathered ${count} account(s) created before ${cutoff.toISOString()}.`
  );
}

main()
  .catch((e) => {
    console.error(`Backfill failed: ${e.message}`);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
