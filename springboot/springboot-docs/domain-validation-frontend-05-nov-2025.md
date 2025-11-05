# Domain Validation - Frontend Developer Guide

## Quick Overview
When users sign up, their email domain determines if they can register:
- **Public domains** (gmail.com, yahoo.com): Anyone can use ✓
- **Corporate domains** (systech.com): First person locks it ✗

## API Endpoints

### 1. Check Domain Availability
**Before** user submits signup form, validate their domain.

```typescript
GET /api/v1/auth/check-domain?domain=systech.com
```

**Response:**
```json
{
  "available": false,
  "isPublic": false,
  "domain": "systech.com"
}
```

**Fields:**
- `available`: `true` = can register, `false` = blocked
- `isPublic`: `true` = public email (gmail.com), `false` = corporate
- `domain`: normalized lowercase domain

### 2. Signup Flow
```typescript
POST /api/v1/auth/signup
```

**Request:**
```json
{
  "email": "ramesh@systech.com",
  "password": "SecurePass123",
  "firstName": "Ramesh",
  "lastName": "Babu",
  "companyName": "Systech Industries",
  "phone": "+1234567890"
}
```

**Error Cases:**
```json
// Domain already registered
{
  "success": false,
  "message": "Domain systech.com is already registered to another company"
}

// Email already exists
{
  "success": false,
  "message": "Email address already exists"
}
```

## Frontend Implementation

### Step 1: Extract Domain from Email
```typescript
function extractDomain(email: string): string {
  return email.substring(email.indexOf('@') + 1).toLowerCase();
}
```

### Step 2: Validate Domain (Real-time)
```typescript
async function checkDomain(email: string) {
  const domain = extractDomain(email);

  const response = await fetch(
    `/api/v1/auth/check-domain?domain=${domain}`
  );

  const data = await response.json();

  if (!data.available && !data.isPublic) {
    return {
      valid: false,
      message: `Domain ${domain} is already registered`
    };
  }

  return { valid: true };
}
```

### Step 3: Show User Feedback
```typescript
// When user types email
onEmailChange(async (email) => {
  if (email.includes('@')) {
    const result = await checkDomain(email);

    if (!result.valid) {
      showError(result.message);
    } else {
      showSuccess('Domain available');
    }
  }
});
```

## UX Recommendations

### Public Domain (gmail.com)
✅ Show: "Personal email detected. You can proceed."

### Corporate Domain - Available (newcompany.com)
✅ Show: "This will register newcompany.com to your company."

### Corporate Domain - Taken (systech.com)
❌ Show: "Domain systech.com is already registered. Contact admin@systech.com or use a different email."

## Public Domains List
Pre-approved public domains:
- gmail.com
- yahoo.com
- outlook.com
- hotmail.com
- icloud.com
- protonmail.com
- aol.com
- zoho.com
- mail.com
- yandex.com

## Common Scenarios

### Scenario 1: First User from Company
```
Email: john@acme.com
Domain: acme.com
Status: Available ✓
Result: Locks acme.com to tenant_id
```

### Scenario 2: Second User from Same Company
```
Email: jane@acme.com
Domain: acme.com
Status: Already registered ✗
Result: Signup blocked
```

### Scenario 3: Personal Email
```
Email: john@gmail.com
Domain: gmail.com
Status: Public domain ✓
Result: Multiple tenants allowed
```

## Error Handling

```typescript
try {
  const response = await signup(formData);

  if (response.success) {
    showSuccess('Account created! Check your email.');
  }
} catch (error) {
  if (error.status === 409) {
    showError('Email or domain already exists');
  } else if (error.status === 400) {
    showError('Invalid domain. Use your company email.');
  } else {
    showError('Signup failed. Please try again.');
  }
}
```

## Testing Checklist

- [ ] Public email (gmail.com) allows signup
- [ ] Corporate email (first user) locks domain
- [ ] Corporate email (second user) gets blocked
- [ ] Domain check shows real-time feedback
- [ ] Error messages are user-friendly
- [ ] Domain is case-insensitive (GMAIL.com = gmail.com)

## Questions?
Contact: Backend Team
