# Documenso - Open Source Document Signing Platform

## Introduction

Documenso is an open-source document signing platform that serves as a self-hostable alternative to DocuSign. Built with modern TypeScript technologies, it provides a complete solution for digital document signing, template management, and workflow automation. The platform is structured as a monorepo using npm workspaces, with the main application built on React Router v7 (formerly Remix), tRPC for type-safe APIs, and Prisma as the database ORM. Documenso supports OAuth authentication, two-factor authentication, passkeys, and offers both a web interface and comprehensive REST/tRPC APIs for integrations.

The platform enables organizations to create, send, and manage legally binding digital signatures on PDF documents. It includes advanced features such as multi-recipient workflows, customizable field types (signatures, text, checkboxes, dropdowns), template systems with shareable links, webhook integrations, audit logging, and team/organization management. With support for Google Cloud HSM for digital signatures, S3-compatible storage, and extensive customization options, Documenso is designed for both individual users and enterprise deployments requiring full control over their document signing infrastructure.

## APIs and Key Functions

### REST API v1 - Create and Send Document

HTTP-based API for document lifecycle management using Bearer token authentication.

```bash
# 1. Create document
curl -X POST https://documenso.com/api/v1/documents \
  -H "Authorization: Bearer api_xxx" \
  -F "title=Service Agreement.pdf" \
  -F "file=@contract.pdf"

# Response
{
  "id": 123,
  "title": "Service Agreement.pdf",
  "status": "DRAFT",
  "uploadUrl": "https://..."
}

# 2. Add recipient
curl -X POST https://documenso.com/api/v1/documents/123/recipients \
  -H "Authorization: Bearer api_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@company.com",
    "name": "John Doe",
    "role": "SIGNER",
    "signingOrder": 1
  }'

# Response
{
  "id": 1,
  "email": "john.doe@company.com",
  "role": "SIGNER",
  "token": "rec_abc123xyz"
}

# 3. Add signature field
curl -X POST https://documenso.com/api/v1/documents/123/fields \
  -H "Authorization: Bearer api_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SIGNATURE",
    "recipientId": 1,
    "page": 1,
    "positionX": 100,
    "positionY": 200,
    "width": 200,
    "height": 60
  }'

# 4. Send document for signing
curl -X POST https://documenso.com/api/v1/documents/123/send \
  -H "Authorization: Bearer api_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "sendEmail": true
  }'

# Response
{
  "id": 123,
  "status": "PENDING",
  "sentAt": "2024-01-15T10:30:00Z"
}

# 5. Download completed document
curl -X GET https://documenso.com/api/v1/documents/123/download \
  -H "Authorization: Bearer api_xxx" \
  --output signed-contract.pdf
```

### REST API v1 - Template Management and Generation

Create reusable templates and generate documents with predefined fields and recipients.

```bash
# 1. Create template
curl -X POST https://documenso.com/api/v1/templates \
  -H "Authorization: Bearer api_xxx" \
  -F "title=NDA Template" \
  -F "type=PRIVATE" \
  -F "file=@nda-template.pdf"

# Response
{
  "id": 456,
  "title": "NDA Template",
  "type": "PRIVATE",
  "status": "DRAFT"
}

# 2. Add template recipient placeholder
curl -X POST https://documenso.com/api/v1/templates/456/recipients \
  -H "Authorization: Bearer api_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "",
    "name": "Signer",
    "role": "SIGNER"
  }'

# 3. Add template fields
curl -X POST https://documenso.com/api/v1/templates/456/fields \
  -H "Authorization: Bearer api_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SIGNATURE",
    "recipientId": 2,
    "page": 1,
    "positionX": 150,
    "positionY": 450,
    "width": 200,
    "height": 60
  }'

# 4. Generate document from template
curl -X POST https://documenso.com/api/v1/templates/456/generate-document \
  -H "Authorization: Bearer api_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "NDA - John Doe",
    "recipients": [
      {
        "id": 2,
        "email": "john.doe@company.com",
        "name": "John Doe"
      }
    ],
    "distributeDocument": true
  }'

# Response
{
  "id": 789,
  "title": "NDA - John Doe",
  "status": "PENDING",
  "recipients": [
    {
      "id": 3,
      "email": "john.doe@company.com",
      "role": "SIGNER",
      "sendStatus": "SENT"
    }
  ]
}
```

### tRPC API - Document Operations

Type-safe API for document management using tRPC client.

```typescript
import { createTRPCClient, httpBatchLink } from '@trpc/client';
import type { AppRouter } from '@documenso/trpc';

// Initialize tRPC client
const trpc = createTRPCClient<AppRouter>({
  links: [
    httpBatchLink({
      url: 'https://documenso.com/api/trpc',
      headers: {
        authorization: 'Bearer api_xxx',
      },
    }),
  ],
});

// Create new document
const document = await trpc.envelope.create.mutate({
  type: 'DOCUMENT',
  title: 'Employment Contract',
  envelopeItems: [
    {
      documentDataId: 'doc_data_123',
    },
  ],
});

// Add recipient
const recipient = await trpc.envelope.recipient.create.mutate({
  envelopeId: document.id,
  email: 'employee@company.com',
  name: 'Jane Smith',
  role: 'SIGNER',
  signingOrder: 1,
});

// Add signature field
const field = await trpc.envelope.field.create.mutate({
  envelopeId: document.id,
  recipientId: recipient.id,
  type: 'SIGNATURE',
  page: 1,
  positionX: 100,
  positionY: 300,
  width: 200,
  height: 60,
});

// Send document
const sentDocument = await trpc.envelope.send.mutate({
  envelopeId: document.id,
  sendEmail: true,
});

console.log(`Document sent: ${sentDocument.status}`);
// Output: Document sent: PENDING
```

### tRPC API - Advanced Field Types

Create advanced form fields with metadata for rich document interactions.

```typescript
// Text field with validation
const textField = await trpc.envelope.field.create.mutate({
  envelopeId: documentId,
  recipientId: recipientId,
  type: 'TEXT',
  page: 1,
  positionX: 100,
  positionY: 400,
  width: 300,
  height: 40,
  fieldMeta: {
    type: 'text',
    label: 'Company Name',
    placeholder: 'Enter company name',
    required: true,
    characterLimit: 100,
    fontSize: 12,
    textAlign: 'left',
  },
});

// Dropdown field
const dropdownField = await trpc.envelope.field.create.mutate({
  envelopeId: documentId,
  recipientId: recipientId,
  type: 'DROPDOWN',
  page: 1,
  positionX: 100,
  positionY: 500,
  width: 200,
  height: 30,
  fieldMeta: {
    type: 'dropdown',
    label: 'Department',
    required: true,
    values: [
      { id: 1, value: 'Engineering' },
      { id: 2, value: 'Sales' },
      { id: 3, value: 'Marketing' },
      { id: 4, value: 'Operations' },
    ],
    defaultValue: 'Engineering',
  },
});

// Checkbox group
const checkboxField = await trpc.envelope.field.create.mutate({
  envelopeId: documentId,
  recipientId: recipientId,
  type: 'CHECKBOX',
  page: 1,
  positionX: 100,
  positionY: 600,
  width: 300,
  height: 80,
  fieldMeta: {
    type: 'checkbox',
    label: 'Benefits',
    required: false,
    direction: 'vertical',
    values: [
      { id: 1, checked: false, value: 'Health Insurance' },
      { id: 2, checked: false, value: '401k Matching' },
      { id: 3, checked: false, value: 'Stock Options' },
    ],
    validationRule: 'min',
    validationLength: 1,
  },
});

// Number field with range
const numberField = await trpc.envelope.field.create.mutate({
  envelopeId: documentId,
  recipientId: recipientId,
  type: 'NUMBER',
  page: 2,
  positionX: 100,
  positionY: 200,
  width: 150,
  height: 40,
  fieldMeta: {
    type: 'number',
    label: 'Annual Salary',
    required: true,
    numberFormat: 'USD',
    minValue: 30000,
    maxValue: 500000,
    fontSize: 14,
  },
});
```

### Prisma Schema - Database Models

Core database schema showing relationships between users, documents, recipients, and fields.

```typescript
// User authentication and profile
model User {
  id                Int       @id @default(autoincrement())
  name              String?
  email             String    @unique
  emailVerified     DateTime?
  password          String?
  roles             Role[]    @default([USER])
  twoFactorEnabled  Boolean   @default(false)
  twoFactorBackupCodes String?
  disabled          Boolean   @default(false)

  accounts          Account[]
  sessions          Session[]
  passkeys          Passkey[]
  envelopes         Envelope[]
  organisations     OrganisationMember[]
  teams             TeamMember[]
  apiTokens         ApiToken[]
}

// Organization structure
model Organisation {
  id              String   @id @default(cuid())
  type            OrganisationType @default(PERSONAL)
  name            String
  url             String   @unique
  bannerUrl       String?
  avatarUrl       String?

  members         OrganisationMember[]
  teams           Team[]
  subscription    Subscription?
}

// Team within organization
model Team {
  id              Int      @id @default(autoincrement())
  name            String
  url             String   @unique
  organisationId  String

  organisation    Organisation @relation(fields: [organisationId])
  members         TeamMember[]
  envelopes       Envelope[]
  folders         Folder[]
  apiTokens       ApiToken[]
  webhooks        Webhook[]
}

// Document or Template envelope
model Envelope {
  id              String   @id @default(cuid())
  type            EnvelopeType @default(DOCUMENT)
  externalId      String?
  title           String
  status          DocumentStatus @default(DRAFT)
  source          DocumentSource @default(DOCUMENT)

  envelopeItems   EnvelopeItem[]
  recipients      Recipient[]
  fields          Field[]
  documentMeta    DocumentMeta?

  userId          Int
  teamId          Int
  folderId        String?

  user            User     @relation(fields: [userId])
  team            Team     @relation(fields: [teamId])
  folder          Folder?  @relation(fields: [folderId])

  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  completedAt     DateTime?
  deletedAt       DateTime?
}

// Document recipient
model Recipient {
  id              Int      @id @default(autoincrement())
  envelopeId      String
  email           String
  name            String
  token           String   @unique
  role            RecipientRole @default(SIGNER)
  signingOrder    Int?

  signingStatus   SigningStatus @default(NOT_SIGNED)
  sendStatus      SendStatus @default(NOT_SENT)
  readStatus      ReadStatus @default(NOT_OPENED)

  signedAt        DateTime?
  sentAt          DateTime?
  openedAt        DateTime?

  envelope        Envelope @relation(fields: [envelopeId])
  fields          Field[]
  signatures      Signature[]
}

// Form field on document
model Field {
  id              Int      @id @default(autoincrement())
  envelopeId      String
  recipientId     Int
  type            FieldType
  page            Int
  positionX       Decimal
  positionY       Decimal
  width           Decimal
  height          Decimal
  customText      String?
  inserted        Boolean  @default(false)
  fieldMeta       Json?

  envelope        Envelope @relation(fields: [envelopeId])
  recipient       Recipient @relation(fields: [recipientId])
  signature       Signature?
}

// API authentication token
model ApiToken {
  id              Int      @id @default(autoincrement())
  name            String
  token           String   @unique
  algorithm       ApiTokenAlgorithm @default(SHA512)
  expires         DateTime?

  userId          Int?
  teamId          Int

  user            User?    @relation(fields: [userId])
  team            Team     @relation(fields: [teamId])

  createdAt       DateTime @default(now())
}

// Webhook configuration
model Webhook {
  id              String   @id @default(cuid())
  webhookUrl      String
  eventTriggers   WebhookTriggerEvents[]
  secret          String?
  enabled         Boolean  @default(true)

  userId          Int
  teamId          Int

  user            User     @relation(fields: [userId])
  team            Team     @relation(fields: [teamId])

  calls           WebhookCall[]
}

enum DocumentStatus {
  DRAFT
  PENDING
  COMPLETED
  REJECTED
}

enum RecipientRole {
  SIGNER
  VIEWER
  APPROVER
  CC
  ASSISTANT
}

enum FieldType {
  SIGNATURE
  FREE_SIGNATURE
  INITIALS
  NAME
  EMAIL
  DATE
  TEXT
  NUMBER
  RADIO
  CHECKBOX
  DROPDOWN
}

enum WebhookTriggerEvents {
  DOCUMENT_CREATED
  DOCUMENT_SENT
  DOCUMENT_OPENED
  DOCUMENT_SIGNED
  DOCUMENT_COMPLETED
  DOCUMENT_REJECTED
  DOCUMENT_CANCELLED
}
```

### Session Authentication - Server-Side Implementation

Custom session management with cookie-based authentication.

```typescript
import { createSession, validateSessionToken } from '@documenso/auth/server';
import type { Session, User } from '@documenso/prisma';

// Create new session after login
async function handleLogin(userId: number, request: Request) {
  const token = generateSessionToken();
  const metadata = {
    ipAddress: request.headers.get('x-forwarded-for') || 'unknown',
    userAgent: request.headers.get('user-agent') || 'unknown',
  };

  const session = await createSession(token, userId, metadata);

  // Set session cookie
  const cookie = serialize('documenso.session-token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 30, // 30 days
    path: '/',
  });

  return {
    session,
    setCookie: cookie,
  };
}

// Validate session from request
async function getSessionFromRequest(
  request: Request
): Promise<{ session: Session; user: User } | null> {
  const cookies = parse(request.headers.get('cookie') || '');
  const token = cookies['documenso.session-token'];

  if (!token) {
    return null;
  }

  const result = await validateSessionToken(token);

  if (!result.session || !result.user) {
    return null;
  }

  return {
    session: result.session,
    user: result.user,
  };
}

// Middleware example
export async function requireAuth(request: Request) {
  const sessionData = await getSessionFromRequest(request);

  if (!sessionData) {
    throw new Response('Unauthorized', { status: 401 });
  }

  return sessionData;
}
```

### Webhook Integration - Event Handling

Configure and handle webhook events for document lifecycle notifications.

```typescript
import { createTRPCClient } from '@trpc/client';

// Configure webhook
const webhook = await trpc.webhook.createWebhook.mutate({
  webhookUrl: 'https://api.myapp.com/documenso-webhook',
  eventTriggers: [
    'DOCUMENT_SENT',
    'DOCUMENT_SIGNED',
    'DOCUMENT_COMPLETED',
    'DOCUMENT_REJECTED',
  ],
  secret: 'webhook_secret_key_xyz123',
  enabled: true,
});

// Express.js webhook endpoint example
import express from 'express';
import crypto from 'crypto';

const app = express();
app.use(express.json());

app.post('/documenso-webhook', (req, res) => {
  // Verify webhook signature
  const signature = req.headers['x-documenso-signature'];
  const payload = JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', 'webhook_secret_key_xyz123')
    .update(payload)
    .digest('hex');

  if (signature !== expectedSignature) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const { event, payload: data } = req.body;

  switch (event) {
    case 'DOCUMENT_COMPLETED':
      console.log(`Document ${data.id} completed`);
      // Update internal database
      // Send notifications
      // Trigger workflows
      break;

    case 'DOCUMENT_SIGNED':
      console.log(`Recipient signed document ${data.id}`);
      const signer = data.recipients.find(r => r.signingStatus === 'SIGNED');
      console.log(`Signed by: ${signer.email} at ${signer.signedAt}`);
      break;

    case 'DOCUMENT_REJECTED':
      console.log(`Document ${data.id} rejected`);
      // Handle rejection
      break;
  }

  res.json({ received: true });
});

// Expected webhook payload structure
interface WebhookPayload {
  event: 'DOCUMENT_COMPLETED' | 'DOCUMENT_SIGNED' | 'DOCUMENT_REJECTED';
  payload: {
    id: number;
    externalId: string | null;
    title: string;
    status: 'COMPLETED' | 'PENDING' | 'REJECTED';
    createdAt: string;
    completedAt: string | null;
    recipients: Array<{
      id: number;
      email: string;
      name: string;
      role: string;
      signingStatus: string;
      signedAt: string | null;
    }>;
  };
  createdAt: string;
  webhookEndpoint: string;
}
```

### Environment Configuration - Production Setup

Essential environment variables for self-hosting and deployment.

```bash
# Core Application
NEXTAUTH_SECRET="random-64-char-secret-string"
NEXT_PUBLIC_WEBAPP_URL="https://documenso.company.com"
NEXT_PRIVATE_INTERNAL_WEBAPP_URL="http://localhost:3000"
PORT=3000

# Database
NEXT_PRIVATE_DATABASE_URL="postgresql://user:pass@localhost:5432/documenso"
NEXT_PRIVATE_DIRECT_DATABASE_URL="postgresql://user:pass@localhost:5432/documenso"

# Encryption (32 characters)
NEXT_PRIVATE_ENCRYPTION_KEY="abcdef1234567890abcdef1234567890"
NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="1234567890abcdef1234567890abcdef"

# Email/SMTP Configuration
NEXT_PRIVATE_SMTP_TRANSPORT="smtp-auth"
NEXT_PRIVATE_SMTP_HOST="smtp.gmail.com"
NEXT_PRIVATE_SMTP_PORT=587
NEXT_PRIVATE_SMTP_USERNAME="noreply@company.com"
NEXT_PRIVATE_SMTP_PASSWORD="app-specific-password"
NEXT_PRIVATE_SMTP_SECURE="true"
NEXT_PRIVATE_SMTP_FROM_NAME="Documenso"
NEXT_PRIVATE_SMTP_FROM_ADDRESS="noreply@company.com"

# OAuth Providers (Optional)
NEXT_PRIVATE_GOOGLE_CLIENT_ID="xxx.apps.googleusercontent.com"
NEXT_PRIVATE_GOOGLE_CLIENT_SECRET="GOCSPX-xxx"
NEXT_PRIVATE_MICROSOFT_CLIENT_ID="azure-app-id"
NEXT_PRIVATE_MICROSOFT_CLIENT_SECRET="azure-secret"

# Digital Signing Certificate
NEXT_PRIVATE_SIGNING_TRANSPORT="local"
NEXT_PRIVATE_SIGNING_LOCAL_FILE_PATH="./cert.p12"
NEXT_PRIVATE_SIGNING_PASSPHRASE="certificate-password"

# Storage (S3 or Database)
NEXT_PUBLIC_UPLOAD_TRANSPORT="s3"
NEXT_PRIVATE_UPLOAD_ENDPOINT="https://s3.amazonaws.com"
NEXT_PRIVATE_UPLOAD_REGION="us-east-1"
NEXT_PRIVATE_UPLOAD_BUCKET="documenso-prod"
NEXT_PRIVATE_UPLOAD_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
NEXT_PRIVATE_UPLOAD_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Feature Flags
NEXT_PUBLIC_FEATURE_BILLING_ENABLED="true"

# Background Jobs (Inngest)
INNGEST_EVENT_KEY="inngest-event-key"
INNGEST_SIGNING_KEY="inngest-signing-key"

# Google Cloud HSM (Optional, for production signing)
NEXT_PRIVATE_SIGNING_TRANSPORT="gcloud-hsm"
NEXT_PRIVATE_SIGNING_GCLOUD_HSM_KEY_PATH="projects/xxx/locations/xxx/keyRings/xxx/cryptoKeys/xxx/cryptoKeyVersions/1"
NEXT_PRIVATE_SIGNING_GCLOUD_HSM_PUBLIC_CRT_FILE_PATH="./cert.crt"
```

### Docker Deployment - Container Configuration

Deploy Documenso using Docker with proper environment configuration.

```bash
# Pull latest image
docker pull documenso/documenso:latest

# Run with environment variables
docker run -d \
  --name documenso \
  -p 3000:3000 \
  -e NEXTAUTH_SECRET="your-secret-here" \
  -e NEXT_PUBLIC_WEBAPP_URL="https://documenso.company.com" \
  -e NEXT_PRIVATE_DATABASE_URL="postgresql://user:pass@postgres:5432/documenso" \
  -e NEXT_PRIVATE_DIRECT_DATABASE_URL="postgresql://user:pass@postgres:5432/documenso" \
  -e NEXT_PRIVATE_ENCRYPTION_KEY="32-char-encryption-key-here" \
  -e NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="32-char-secondary-key-here" \
  -e NEXT_PRIVATE_SMTP_HOST="smtp.gmail.com" \
  -e NEXT_PRIVATE_SMTP_PORT=587 \
  -e NEXT_PRIVATE_SMTP_USERNAME="noreply@company.com" \
  -e NEXT_PRIVATE_SMTP_PASSWORD="app-password" \
  -e NEXT_PRIVATE_SMTP_FROM_NAME="Documenso" \
  -e NEXT_PRIVATE_SMTP_FROM_ADDRESS="noreply@company.com" \
  -e NEXT_PRIVATE_SIGNING_TRANSPORT="local" \
  -e NEXT_PRIVATE_SIGNING_LOCAL_FILE_PATH="/app/cert.p12" \
  -e NEXT_PRIVATE_SIGNING_PASSPHRASE="cert-password" \
  -v ./cert.p12:/app/cert.p12:ro \
  documenso/documenso:latest

# Docker Compose example
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: documenso
      POSTGRES_PASSWORD: changeme
      POSTGRES_DB: documenso
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  documenso:
    image: documenso/documenso:latest
    ports:
      - "3000:3000"
    environment:
      NEXTAUTH_SECRET: "your-secret-here"
      NEXT_PUBLIC_WEBAPP_URL: "http://localhost:3000"
      NEXT_PRIVATE_DATABASE_URL: "postgresql://documenso:changeme@postgres:5432/documenso"
      NEXT_PRIVATE_DIRECT_DATABASE_URL: "postgresql://documenso:changeme@postgres:5432/documenso"
      NEXT_PRIVATE_ENCRYPTION_KEY: "abcdef1234567890abcdef1234567890"
      NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY: "1234567890abcdef1234567890abcdef"
      NEXT_PRIVATE_SMTP_TRANSPORT: "smtp-auth"
      NEXT_PRIVATE_SMTP_HOST: "mailserver"
      NEXT_PRIVATE_SMTP_PORT: "587"
    depends_on:
      - postgres
    volumes:
      - ./cert.p12:/app/cert.p12:ro

volumes:
  postgres_data:
EOF

# Start services
docker-compose up -d

# Run database migrations
docker-compose exec documenso npm run prisma:migrate-deploy

# View logs
docker-compose logs -f documenso
```

### Recipient Signing Flow - Client-Side Implementation

React component for recipient document signing interface.

```typescript
import { useState } from 'react';
import { useTRPC } from '@documenso/trpc/client';
import { SignatureCanvas } from '@documenso/ui/signature-canvas';
import { PDFViewer } from '@documenso/ui/pdf-viewer';

interface RecipientSigningProps {
  token: string;
}

export function RecipientSigning({ token }: RecipientSigningProps) {
  const [signatureData, setSignatureData] = useState<string>('');
  const trpc = useTRPC();

  // Get document and fields
  const { data: document } = trpc.envelope.getByToken.useQuery({
    token,
  });

  // Sign field mutation
  const signField = trpc.envelope.field.sign.useMutation({
    onSuccess: () => {
      console.log('Field signed successfully');
    },
  });

  const handleSignField = async (fieldId: number) => {
    await signField.mutateAsync({
      token,
      fieldId,
      signatureImageAsBase64: signatureData,
    });
  };

  const handleCompleteDocument = async () => {
    await trpc.envelope.complete.mutateAsync({
      token,
    });

    // Redirect to completion page
    window.location.href = `/sign/${token}/complete`;
  };

  if (!document) {
    return <div>Loading...</div>;
  }

  const myFields = document.fields.filter(
    (field) => field.recipient.token === token
  );

  return (
    <div className="signing-container">
      <PDFViewer
        documentUrl={document.documentUrl}
        fields={myFields}
        onFieldClick={(field) => {
          if (field.type === 'SIGNATURE') {
            // Open signature modal
            setCurrentField(field);
          }
        }}
      />

      <div className="sidebar">
        <h2>Sign Document: {document.title}</h2>

        <div className="fields-list">
          {myFields.map((field) => (
            <div key={field.id} className="field-item">
              <span>{field.type}</span>
              {field.inserted ? (
                <span className="completed">✓ Completed</span>
              ) : (
                <button onClick={() => handleSignField(field.id)}>
                  Sign
                </button>
              )}
            </div>
          ))}
        </div>

        <button
          onClick={handleCompleteDocument}
          disabled={myFields.some((f) => !f.inserted)}
        >
          Complete Document
        </button>
      </div>

      <SignatureCanvas
        onSave={(signature) => {
          setSignatureData(signature);
        }}
      />
    </div>
  );
}
```

### Template Direct Links - Self-Service Signing

Create shareable template links for recipients to sign without authentication.

```typescript
// Create template direct link
const directLink = await trpc.template.createDirectLink.mutate({
  templateId: 456,
  directRecipientId: 2, // Recipient placeholder in template
  externalId: 'vendor-onboarding-2024',
});

console.log(`Share link: ${process.env.NEXT_PUBLIC_WEBAPP_URL}/t/${directLink.token}`);
// Output: https://documenso.com/t/tpl_abc123xyz

// Recipient visits link and fills information
// Example URL: https://documenso.com/t/tpl_abc123xyz

// Handle direct link signing (server-side)
async function handleDirectLinkAccess(token: string, recipientData: {
  name: string;
  email: string;
  company?: string;
}) {
  // Generate document from template
  const document = await trpc.template.createDocumentFromDirectLink.mutate({
    token,
    recipientData: {
      name: recipientData.name,
      email: recipientData.email,
    },
    fieldData: {
      // Pre-fill fields if needed
      companyName: recipientData.company,
    },
  });

  // Recipient signs immediately
  return {
    signingUrl: `/sign/${document.recipients[0].token}`,
    documentId: document.id,
  };
}

// API endpoint for direct link
app.get('/t/:token', async (req, res) => {
  const { token } = req.params;

  const directLink = await prisma.templateDirectLink.findUnique({
    where: { token },
    include: {
      template: {
        include: {
          recipients: true,
          fields: true,
        },
      },
    },
  });

  if (!directLink || !directLink.enabled) {
    return res.status(404).json({ error: 'Link not found or disabled' });
  }

  // Render signing form
  res.render('template-direct-link', {
    template: directLink.template,
    token,
  });
});
```

### Bulk Document Sending - CSV Import

Send template to multiple recipients using CSV upload for batch operations.

```typescript
import { parse } from 'csv-parse/sync';
import fs from 'fs';

// CSV format: name,email,company,startDate
const csvContent = `
John Doe,john@company1.com,Company One,2024-02-01
Jane Smith,jane@company2.com,Company Two,2024-02-15
Bob Johnson,bob@company3.com,Company Three,2024-03-01
`;

// Parse CSV
const records = parse(csvContent, {
  columns: true,
  skip_empty_lines: true,
});

// Trigger bulk send job
const bulkJob = await trpc.template.bulkSend.mutate({
  templateId: 456,
  recipients: records.map((record) => ({
    name: record.name,
    email: record.email,
    fieldValues: {
      companyName: record.company,
      startDate: record.startDate,
    },
  })),
  sendEmail: true,
});

console.log(`Bulk job created: ${bulkJob.id}`);
console.log(`Processing ${bulkJob.recipientCount} recipients`);

// Monitor bulk job status
const checkJobStatus = async (jobId: string) => {
  const job = await trpc.template.getBulkJob.query({ jobId });

  console.log(`Status: ${job.status}`);
  console.log(`Completed: ${job.completed} / ${job.total}`);
  console.log(`Failed: ${job.failed}`);

  if (job.status === 'COMPLETED') {
    console.log('All documents sent successfully');
    console.log(`Documents created: ${job.documentIds.length}`);
  }

  return job;
};

// Poll for completion
const pollInterval = setInterval(async () => {
  const job = await checkJobStatus(bulkJob.id);

  if (job.status === 'COMPLETED' || job.status === 'FAILED') {
    clearInterval(pollInterval);
  }
}, 5000);
```

### Document Authentication - Access Control

Configure document-level and recipient-level authentication requirements.

```typescript
// Set document authentication
const document = await trpc.envelope.update.mutate({
  envelopeId: documentId,
  globalAccessAuth: {
    type: 'ACCOUNT', // Require login to view
  },
  globalActionAuth: {
    type: 'TWO_FACTOR', // Require 2FA to sign
  },
});

// Set recipient-specific authentication
const recipient = await trpc.envelope.recipient.update.mutate({
  recipientId: recipientId,
  accessAuth: {
    type: 'PASSKEY', // Require passkey to view
  },
  actionAuth: {
    type: 'TWO_FACTOR', // Require 2FA to sign
  },
});

// Authentication types available:
// - 'ACCOUNT': Requires user to have Documenso account
// - 'PASSKEY': Requires WebAuthn/FIDO2 passkey
// - 'TWO_FACTOR': Requires TOTP 2FA code

// Recipient authentication flow
async function validateRecipientAccess(
  token: string,
  userId: number | null
): Promise<boolean> {
  const recipient = await prisma.recipient.findUnique({
    where: { token },
    include: {
      envelope: {
        include: { documentMeta: true },
      },
    },
  });

  if (!recipient) {
    return false;
  }

  // Check recipient-level auth
  const recipientAuth = recipient.authOptions?.accessAuth;

  if (recipientAuth?.type === 'ACCOUNT') {
    if (!userId) {
      throw new Error('Account required');
    }

    // Verify user email matches recipient
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (user?.email !== recipient.email) {
      throw new Error('Email mismatch');
    }
  }

  if (recipientAuth?.type === 'PASSKEY') {
    // Require passkey verification
    // (handled by separate passkey challenge flow)
  }

  return true;
}
```

## Summary and Integration Patterns

Documenso provides a comprehensive document signing platform with three primary integration approaches. The REST API v1 offers straightforward HTTP endpoints for document lifecycle management, making it ideal for server-to-server integrations, webhook-based workflows, and third-party applications. The tRPC API delivers type-safe communication with automatic TypeScript types, perfect for full-stack JavaScript/TypeScript applications, internal tools, and React-based frontends. For embedded experiences, the platform supports iframe embedding, direct template links for self-service signing, and white-label deployments with custom branding. The architecture separates concerns cleanly with Prisma handling database operations, tRPC managing API routing and authentication, server-only functions implementing business logic, and background jobs processing asynchronous tasks through Inngest.

Common use cases include contract management workflows where documents flow through creation, recipient assignment, field placement, sending, signing, and completion with webhook notifications at each step. Template-based document generation enables organizations to create reusable templates with predefined fields and recipients, then generate multiple documents with dynamic recipient data and pre-filled values. Team collaboration features support organizations with multiple teams, role-based access control (admin, manager, member), folder organization, and shared templates with visibility controls. Enterprise deployments leverage S3 storage for scalability, Google Cloud HSM for secure digital signatures, OAuth/SSO for authentication, webhook integrations for workflow automation, and audit logging for compliance. The platform's flexibility, combined with comprehensive APIs and self-hosting capabilities, makes it suitable for organizations ranging from small teams to large enterprises requiring complete control over their document signing infrastructure.
