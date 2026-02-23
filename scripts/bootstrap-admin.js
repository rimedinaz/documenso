#!/usr/bin/env node

const { PrismaClient } = require('@prisma/client');
const { hash } = require('@node-rs/bcrypt');

async function main() {
  const email = process.env.BOOTSTRAP_ADMIN_EMAIL;
  const plainPassword = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  const name = process.env.BOOTSTRAP_ADMIN_NAME || 'Admin';

  if (!email || !plainPassword) {
    console.error('Missing BOOTSTRAP_ADMIN_EMAIL or BOOTSTRAP_ADMIN_PASSWORD');
    process.exit(1);
  }

  const prisma = new PrismaClient();
  const password = await hash(plainPassword, 12);

  const user = await prisma.user.upsert({
    where: { email },
    update: {
      name,
      password,
      emailVerified: new Date(),
      roles: ['ADMIN'],
      identityProvider: 'DOCUMENSO',
      disabled: false,
    },
    create: {
      name,
      email,
      password,
      emailVerified: new Date(),
      roles: ['ADMIN'],
      identityProvider: 'DOCUMENSO',
      disabled: false,
    },
  });

  console.log(`bootstrap_admin_ok id=${user.id} email=${user.email}`);
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

