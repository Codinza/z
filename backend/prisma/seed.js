import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const MIN_PASSWORD_LENGTH = 6;

async function main() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  const phone = process.env.ADMIN_PHONE || 'admin002';
  const name = process.env.ADMIN_NAME || 'Admin';

  if (!email || !password) {
    throw new Error(
      'ADMIN_EMAIL and ADMIN_PASSWORD are required. Set them in backend/.env (or your host env) before seeding.'
    );
  }

  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new Error(
      `ADMIN_PASSWORD must be at least ${MIN_PASSWORD_LENGTH} characters long.`
    );
  }

  const hashedPassword = await bcrypt.hash(password, 12);
  const adminData = {
    name,
    phone,
    email,
    password: hashedPassword,
    role: 'super_admin',
    phoneVerified: true,
  };

  const byEmail = await prisma.user.findUnique({ where: { email } });
  const byPhone = await prisma.user.findUnique({ where: { phone } });

  let admin;
  if (byEmail && byPhone && byEmail.id !== byPhone.id) {
    // Phone belongs to another account — promote that one and free the email slot.
    await prisma.user.update({
      where: { id: byEmail.id },
      data: { email: `legacy-${byEmail.id}@local.invalid` },
    });
    admin = await prisma.user.update({
      where: { id: byPhone.id },
      data: adminData,
    });
  } else if (byPhone) {
    admin = await prisma.user.update({
      where: { id: byPhone.id },
      data: adminData,
    });
  } else if (byEmail) {
    admin = await prisma.user.update({
      where: { id: byEmail.id },
      data: adminData,
    });
  } else {
    admin = await prisma.user.create({ data: adminData });
  }

  console.log(`Super admin ready: ${admin.email} / ${admin.phone} (id: ${admin.id})`);
}

main()
  .catch((e) => {
    console.error(`Seed failed: ${e.message}`);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
