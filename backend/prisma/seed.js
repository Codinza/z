import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Starting seed...');

  // Create admin user with specific email
  const adminPassword = await bcrypt.hash('admin123', 12);
  
  const admin = await prisma.user.upsert({
    where: { email: 'ayman01aay@gmail.com' },
    update: { 
      name: 'Admin',
      password: adminPassword,
      role: 'super_admin',
    },
    create: {
      name: 'Admin',
      phone: 'admin002',
      email: 'ayman01aay@gmail.com',
      password: adminPassword,
      role: 'super_admin',
    },
  });

  console.log('Admin user created/updated:', admin);

  console.log('Seed completed.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
