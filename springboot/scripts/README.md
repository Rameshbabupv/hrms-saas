# HRMS SaaS Scripts

Command-line tools and test scripts for the HRMS SaaS system.

---

## 📋 Prerequisites

- Python 3.7 or higher (for Python scripts)
- Spring Boot application running on `http://localhost:8081`
- Keycloak running on `http://localhost:8090`
- `jq` installed (for JSON parsing in bash scripts)
- `curl` installed (for API testing)

---

## 📂 Available Scripts

### 1. test-domain-validation.sh
**Type**: Bash test script
**Purpose**: Automated testing for domain validation feature

**Usage**:
```bash
cd springboot
./scripts/test-domain-validation.sh
```

**What it tests**:
- ✅ Public domain validation (gmail.com, yahoo.com, etc.)
- ✅ Corporate domain locking (first signup locks domain)
- ✅ Domain isolation (second signup blocked)
- ✅ Case insensitive checks (GMAIL.com = gmail.com)
- ✅ Signup flows with public and corporate emails
- ✅ Email already exists checks

**Requirements**:
- Spring Boot running on port 8081
- PostgreSQL with V2 migration applied

**Output**: Color-coded test results with pass/fail indicators

---

### 2. signup_user.py
**Type**: Python CLI tool
**Purpose**: Interactive user signup with Keycloak integration

---

## 🚀 Installation

```bash
# Navigate to scripts directory
cd /Users/rameshbabu/data/projects/systech/hrms-saas/springboot/scripts

# Install dependencies
pip install -r requirements.txt

# Make script executable (optional)
chmod +x signup_user.py
```

---

## 📖 User Signup Tool

### Description

`signup_user.py` - Create a new user account in the HRMS SaaS system.

This tool:
- ✅ Validates email format
- ✅ Checks password complexity (min 8 chars, uppercase, lowercase, digit, special char)
- ✅ Makes REST API call to `/api/v1/auth/signup`
- ✅ Displays response with **tenant_id**
- ✅ Optionally retrieves JWT token after signup
- ✅ Saves response to JSON file
- ✅ Color-coded output for better readability

---

### Usage Examples

#### 1. Interactive Mode (Recommended for first-time use)

```bash
python signup_user.py
```

**You will be prompted for:**
- Email address
- Password (hidden input)
- Company Name
- First Name
- Last Name
- Phone (optional)

---

#### 2. Command-Line Arguments (Scriptable)

```bash
python signup_user.py \
  --email admin@mycompany.com \
  --password "SecurePass123!" \
  --company "My Company Ltd" \
  --first-name "John" \
  --last-name "Doe" \
  --phone "+1234567890"
```

---

#### 3. Get JWT Token After Signup

```bash
python signup_user.py \
  --email admin@mycompany.com \
  --password "SecurePass123!" \
  --company "My Company Ltd" \
  --first-name "John" \
  --last-name "Doe" \
  --get-token
```

**Output will include:**
- User signup response with tenant_id
- JWT access token
- Decoded JWT claims (tenant_id, company_id, user_type, etc.)

---

#### 4. Save Response to File

```bash
python signup_user.py \
  --email admin@mycompany.com \
  --password "SecurePass123!" \
  --company "My Company Ltd" \
  --first-name "John" \
  --last-name "Doe" \
  --save signup_response.json
```

**Creates file:** `signup_response.json` with full response including tenant_id

---

#### 5. Custom API URL (Different Environment)

```bash
python signup_user.py \
  --api-url "http://qa-server:8081/api/v1/auth/signup" \
  --email admin@mycompany.com \
  --password "SecurePass123!" \
  --company "My Company Ltd"
```

---

### Command-Line Options

```
Required (if not using interactive mode):
  --email, -e          User email address
  --password, -p       User password
  --company, -c        Company name
  --first-name, -f     First name
  --last-name, -l      Last name

Optional:
  --phone              Phone number (international format: +1234567890)
  --api-url            Signup API URL (default: http://localhost:8081/api/v1/auth/signup)
  --get-token          Get JWT token after successful signup
  --keycloak-url       Keycloak token URL (default: http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token)
  --client-id          Keycloak client ID (default: hrms-web-app)
  --client-secret      Keycloak client secret (default: xE39L2zsTFkOjmAt47ToFQRwgIekjW3l)
  --save, -s           Save response to JSON file
  --no-color           Disable colored output
  --help, -h           Show help message
```

---

### Expected Output

#### ✅ Success Response

```
======================================================================
✓ USER SIGNUP SUCCESSFUL!
======================================================================

Response Details:
  Status Code: 201
  Success: True
  Message: Account created successfully. Please verify your email to continue.

  Tenant ID: a3b9c8d2e1f4
  User ID: 226f442e-c931-4119-90d8-09435b2de2cf
  Requires Email Verification: true

Full Response:
{
  "success": true,
  "message": "Account created successfully. Please verify your email to continue.",
  "tenantId": "a3b9c8d2e1f4",
  "userId": "226f442e-c931-4119-90d8-09435b2de2cf",
  "requiresEmailVerification": true
}

======================================================================
```

#### ❌ Error Response

```
======================================================================
✗ USER SIGNUP FAILED!
======================================================================

  Status Code: 400
  Error: User with this email already exists

Response Data:
{
  "timestamp": "2025-11-04T12:00:00.000+00:00",
  "status": 400,
  "error": "Bad Request",
  "message": "User with this email already exists",
  "path": "/api/v1/auth/signup"
}

======================================================================
```

---

### Password Requirements

The script validates that passwords meet these requirements:
- ✅ Minimum 8 characters
- ✅ At least one uppercase letter (A-Z)
- ✅ At least one lowercase letter (a-z)
- ✅ At least one digit (0-9)
- ✅ At least one special character (!@#$%^&*(),.?":{}|<>)

**Example valid passwords:**
- `SecurePass123!`
- `MyCompany@2025`
- `Admin#User99`

---

### Email Validation

The script validates email format:
- ✅ Must contain `@` symbol
- ✅ Must have domain extension (.com, .org, etc.)
- ✅ Follows standard email format

**Example valid emails:**
- `admin@mycompany.com`
- `user.name@example.org`
- `john.doe+test@company.co.uk`

---

### Phone Format

Phone numbers are optional and support:
- ✅ International format: `+1234567890`
- ✅ US format: `(123) 456-7890`
- ✅ Simple format: `123-456-7890`

---

## 🧪 Testing Workflow

### Complete Signup → Login → Test Endpoints

```bash
# 1. Create new user and get JWT token
python signup_user.py \
  --email testuser@example.com \
  --password "TestPass123!" \
  --company "Test Company" \
  --first-name "Test" \
  --last-name "User" \
  --get-token \
  --save signup.json

# 2. Extract token from response
TOKEN=$(cat signup.json | jq -r '.jwt_token')

# 3. Test user profile endpoint
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/profile | jq .

# 4. Test tenant info endpoint
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/api/v1/user/tenant-info | jq .
```

---

## 🐛 Troubleshooting

### Issue: "Connection refused"

**Cause**: Spring Boot application not running

**Solution**:
```bash
cd /Users/rameshbabu/data/projects/systech/hrms-saas/springboot
mvn spring-boot:run
```

---

### Issue: "Failed to get token: 401"

**Cause**: User not enabled in Keycloak or wrong credentials

**Solution**:
1. Check Keycloak Admin Console (http://localhost:8090/admin)
2. Verify user is enabled
3. Check email verification status
4. Retry with correct password

---

### Issue: "User with this email already exists"

**Cause**: Email already registered

**Solution**:
- Use a different email address
- Or delete the existing user from Keycloak Admin Console

---

### Issue: "Invalid password" errors

**Cause**: Password doesn't meet complexity requirements

**Solution**: Use a password with:
- At least 8 characters
- Uppercase, lowercase, digit, and special character

---

## 📝 Tips

1. **Save tenant_id for later use**: Use `--save` option to save the response
2. **Get JWT token immediately**: Use `--get-token` to avoid separate login step
3. **Script automation**: Use command-line arguments for CI/CD pipelines
4. **Test multiple tenants**: Create multiple users with different companies
5. **Verify in Keycloak**: Check Keycloak Admin Console to verify user attributes

---

## 🔐 Security Notes

⚠️ **IMPORTANT**:
- Never commit files containing JWT tokens or passwords to Git
- The default client secret is for development only
- Change client secret in production environments
- Use environment variables for sensitive configuration

---

## 📚 Related Documentation

- `MULTI_TENANT_TESTING_GUIDE.md` - Complete multi-tenant testing guide
- `MULTI_TENANT_IMPLEMENTATION.md` - Implementation details
- `keycloak_to_springboot_2025-11-04.md` - Keycloak integration guide

---

## 🎯 Next Steps

After creating a user:
1. ✅ Verify user exists in Keycloak Admin Console
2. ✅ Check tenant_id attribute is set
3. ✅ Test login with JWT token
4. ✅ Test multi-tenant endpoints
5. ✅ Create additional users for different tenants

---

**Happy Testing! 🚀**
