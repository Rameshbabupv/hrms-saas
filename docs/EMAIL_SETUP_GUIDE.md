# Email Setup Guide for HRMS SaaS
## Keycloak Gmail SMTP Configuration

**Version:** 1.0.0
**Last Updated:** 2025-10-31
**Author:** Systech Team
**Environment:** Development & Production

---

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Gmail App Password Setup](#gmail-app-password-setup)
4. [Keycloak SMTP Configuration](#keycloak-smtp-configuration)
5. [Testing Email Verification](#testing-email-verification)
6. [Troubleshooting](#troubleshooting)
7. [Production Considerations](#production-considerations)
8. [Alternative Email Providers](#alternative-email-providers)

---

## Overview

The HRMS SaaS application uses **Keycloak** for authentication and email verification. When users sign up, Keycloak sends a verification email to confirm their email address before they can access the system.

### Email Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User signs up via React app                             │
│    (Email: user@example.com)                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Spring Boot creates user in Keycloak                    │
│    - enabled: false                                         │
│    - emailVerified: false                                   │
│    - Calls: sendVerifyEmail(userId)                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Keycloak sends verification email via Gmail SMTP        │
│    From: noreply@yourdomain.com                             │
│    Subject: Verify email                                    │
│    Body: Click the link to verify your email               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. User receives email and clicks verification link        │
│    Link: http://localhost:8090/realms/hrms-saas/...        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Keycloak verifies email                                 │
│    - enabled: true                                          │
│    - emailVerified: true                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. User can now login to HRMS application                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before configuring email, ensure you have:

- ✅ Keycloak running on `http://localhost:8090`
- ✅ Admin access to Keycloak (username: `admin`, password: `admin`)
- ✅ Gmail account with 2-Step Verification enabled
- ✅ Spring Boot backend running on `http://localhost:8081`

---

## Gmail App Password Setup

### Why App Password?

Google requires **App Passwords** for applications accessing Gmail via SMTP. You cannot use your regular Gmail password due to security restrictions.

### Step-by-Step Instructions

#### Step 1: Enable 2-Step Verification (if not already enabled)

1. Go to your Google Account: https://myaccount.google.com/
2. Click **Security** in the left sidebar
3. Under "Signing in to Google", click **2-Step Verification**
4. Follow the setup wizard to enable 2-Step Verification
5. Complete the setup with your phone number

#### Step 2: Generate App Password

1. Go to App Passwords: https://myaccount.google.com/apppasswords

   **Note:** If you don't see "App Passwords" option:
   - Ensure 2-Step Verification is enabled
   - Wait a few minutes after enabling 2-Step Verification
   - Try logging out and back in

2. You'll see the "App Passwords" screen

3. Select the app and device:
   - **Select app:** Choose **Mail**
   - **Select device:** Choose **Other (Custom name)**
   - Type: `HRMS Keycloak SMTP`

4. Click **Generate**

5. Google will show you a 16-character password like:
   ```
   abcd efgh ijkl mnop
   ```

6. **IMPORTANT:** Copy this password and remove the spaces:
   ```
   Original:  abcd efgh ijkl mnop
   Use this:  abcdefghijklmnop
   ```

7. **Save this password securely** - you'll need it in the next step

8. Click **Done**

---

## Keycloak SMTP Configuration

### Step 1: Access Keycloak Admin Console

1. Open your browser and navigate to:
   ```
   http://localhost:8090
   ```

2. Click **Administration Console**

3. Login with admin credentials:
   - **Username:** `admin`
   - **Password:** `admin`

### Step 2: Navigate to Email Settings

1. In the top-left dropdown, select the realm: **hrms-saas**

   ![Select Realm](images/select-realm.png)

2. Click **Realm settings** in the left sidebar

3. Click the **Email** tab at the top

### Step 3: Configure SMTP Settings

Fill in the following fields:

#### Basic Settings

| Field | Value | Description |
|-------|-------|-------------|
| **From** | `your-email@gmail.com` | The email address users will see as sender |
| **From Display Name** | `HRMS SaaS Platform` | Friendly name shown to users |
| **Reply To** | *(leave empty)* | Optional: where replies go |
| **Reply To Display Name** | *(leave empty)* | Optional |
| **Envelope From** | *(leave empty)* | Optional: return-path address |

**Example:**
```
From: noreply@systech.com
From Display Name: HRMS SaaS Platform
```

#### SMTP Server Settings

| Field | Value | Description |
|-------|-------|-------------|
| **Host** | `smtp.gmail.com` | Gmail SMTP server |
| **Port** | `587` | TLS port (recommended) |
| **Encryption** | ☑ **Enable StartTLS** | Use TLS encryption |
| | ☐ Enable SSL | Do NOT check this |
| **Authentication** | ☑ **Enable Authentication** | Required for Gmail |
| **Username** | `your-email@gmail.com` | Your Gmail address |
| **Password** | `abcdefghijklmnop` | The 16-char App Password from Step 2 |

**Complete Configuration:**
```
Host: smtp.gmail.com
Port: 587
Enable StartTLS: ✓ YES
Enable SSL: ✗ NO
Enable Authentication: ✓ YES
Username: noreply@systech.com
Password: abcdefghijklmnop (16-char App Password)
```

### Step 4: Save and Test

1. Click **Save** button at the bottom

2. After saving, a **Test connection** button appears

3. Click **Test connection**

4. Enter your email address to receive a test email

5. Check your inbox for an email with subject: **"Test email from Keycloak"**

6. **Success Indicators:**
   - ✅ Green success message in Keycloak: "Email sent successfully"
   - ✅ Test email received in your inbox within 1-2 minutes
   - ✅ Email sender shows: "HRMS SaaS Platform <your-email@gmail.com>"

7. **Failure Indicators:**
   - ❌ Red error message in Keycloak
   - ❌ Common errors:
     - "Authentication failed" → Check App Password (not regular password)
     - "Connection refused" → Check port (use 587, not 465)
     - "StartTLS required" → Ensure "Enable StartTLS" is checked

---

## Testing Email Verification

Once SMTP is configured, test the complete signup and email verification flow:

### Test Scenario 1: New User Signup

1. **Sign up via React app:**
   ```
   URL: http://localhost:3000/signup

   Company Name: Test Company
   First Name: John
   Last Name: Doe
   Email: your-test-email@gmail.com
   Phone: +919876543210
   Password: TestPass@2024!
   ```

2. **Click "Create Account"**

3. **Expected Result:**
   - ✅ Redirected to "Check Your Email" page
   - ✅ Message: "We've sent a verification link to your-test-email@gmail.com"

4. **Check your email inbox:**
   - **From:** HRMS SaaS Platform <your-email@gmail.com>
   - **Subject:** Verify email
   - **Body:** Contains a verification link

5. **Click the verification link** in the email

6. **Expected Result:**
   - ✅ Browser opens Keycloak page
   - ✅ Message: "Your email has been verified"
   - ✅ Button: "Back to Application" or "Continue"

7. **Try logging in:**
   ```
   URL: http://localhost:3000/
   Email: your-test-email@gmail.com
   Password: TestPass@2024!
   ```

8. **Expected Result:**
   - ✅ Successfully logged in
   - ✅ Redirected to dashboard/home page

### Test Scenario 2: Resend Verification Email

1. Sign up with a new email (don't verify)

2. On the "Check Your Email" page, click **"Resend Email"**

3. Check inbox for a new verification email

4. Click the link to verify

---

## Troubleshooting

### Issue 1: "Authentication failed" Error

**Symptoms:**
- Keycloak shows error: "535-5.7.8 Username and Password not accepted"
- Test connection fails

**Solutions:**

✅ **Solution 1:** Verify you're using App Password, NOT regular Gmail password
```
Regular password: ❌ MyGmailPassword123
App Password:     ✅ abcdefghijklmnop (16 characters)
```

✅ **Solution 2:** Ensure App Password has no spaces
```
Wrong: abcd efgh ijkl mnop
Right: abcdefghijklmnop
```

✅ **Solution 3:** Regenerate App Password
- Delete old App Password in Google Account
- Create new App Password
- Update Keycloak configuration

---

### Issue 2: Connection Timeout or Refused

**Symptoms:**
- Error: "Connection timed out"
- Error: "Connection refused"

**Solutions:**

✅ **Solution 1:** Check port number
```
Correct for TLS:  Port 587 (with Enable StartTLS ✓)
Correct for SSL:  Port 465 (with Enable SSL ✓)
Wrong:            Port 25 (blocked by most ISPs)
```

✅ **Solution 2:** Verify firewall settings
- Ensure port 587 is not blocked by firewall
- Test with: `telnet smtp.gmail.com 587`

✅ **Solution 3:** Check network connectivity
```bash
# Test if Gmail SMTP is reachable
curl -v telnet://smtp.gmail.com:587
```

---

### Issue 3: Email Not Received

**Symptoms:**
- Keycloak says "Email sent successfully"
- But email not in inbox

**Solutions:**

✅ **Solution 1:** Check spam/junk folder
- Gmail might mark Keycloak emails as spam initially
- Mark as "Not Spam" to train filter

✅ **Solution 2:** Wait 5-10 minutes
- Gmail may delay delivery for new senders
- First email often takes longer

✅ **Solution 3:** Check Gmail sent folder
- Login to the Gmail account used for SMTP
- Check "Sent" folder to verify email was sent

✅ **Solution 4:** Verify user email in Keycloak
```
Keycloak → Users → Search for user → View Details
Check: Email field is correct
```

---

### Issue 4: "StartTLS required" Error

**Symptoms:**
- Error: "530 5.7.0 Must issue a STARTTLS command first"

**Solution:**

✅ Ensure "Enable StartTLS" is checked in Keycloak
```
Configuration:
Port: 587
Enable StartTLS: ✓ YES
Enable SSL:      ✗ NO
```

---

### Issue 5: Email Link Redirects to Wrong URL

**Symptoms:**
- Verification link points to wrong domain
- Link shows: http://localhost:8090 instead of production URL

**Solution:**

✅ Update Keycloak Frontend URL (for production):
```
Keycloak Admin → Realm settings → General tab
Frontend URL: https://auth.yourdomain.com
```

---

## Production Considerations

### 1. Use a Dedicated Email Account

❌ **Don't use:**
- Personal Gmail accounts
- Shared team email accounts

✅ **Do use:**
- Dedicated account: `noreply@yourdomain.com`
- Professional email service (see alternatives below)

### 2. Email Delivery Limits

**Gmail Free Account Limits:**
- **500 emails per day** (24-hour rolling period)
- If exceeded, account may be temporarily suspended

**For Production:**
- Use Google Workspace (2,000 emails/day)
- Or use dedicated email service (see alternatives)

### 3. SPF, DKIM, and DMARC

For production, configure email authentication:

**SPF Record:**
```dns
yourdomain.com. IN TXT "v=spf1 include:_spf.google.com ~all"
```

**DKIM Record:**
- Enable in Google Workspace
- Add DNS TXT record provided by Google

**DMARC Record:**
```dns
_dmarc.yourdomain.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

### 4. Monitor Email Delivery

**Setup monitoring for:**
- Failed email deliveries
- Bounce rates
- Spam complaints

**Keycloak Logs:**
```bash
# Check Keycloak logs for email errors
docker logs keycloak | grep -i email
```

**Spring Boot Logs:**
```bash
# Check backend logs
tail -f /var/log/hrms-saas/application.log | grep -i "email\|keycloak"
```

### 5. Email Templates Customization

**Default email is plain text. To customize:**

1. Navigate to: **Realm settings → Themes**
2. Set **Email Theme** to custom theme
3. Create custom email templates in:
   ```
   /themes/your-theme/email/html/
   /themes/your-theme/email/text/
   ```

**Example templates:**
- `email-verification.ftl` - Email verification
- `password-reset.ftl` - Password reset
- `email-test.ftl` - Test email

---

## Alternative Email Providers

For production, consider these alternatives to Gmail:

### Option 1: SendGrid (Recommended for Production)

**Pros:**
- 100 free emails/day
- Professional email delivery
- Advanced analytics
- High deliverability

**Configuration:**
```
Host: smtp.sendgrid.net
Port: 587
Enable StartTLS: YES
Enable Authentication: YES
Username: apikey
Password: [Your SendGrid API Key]
```

**Setup:**
1. Sign up: https://sendgrid.com
2. Create API key with "Mail Send" permissions
3. Verify sender identity
4. Use API key as password in Keycloak

---

### Option 2: Mailgun

**Pros:**
- 5,000 free emails/month (first 3 months)
- Easy setup
- Good documentation

**Configuration:**
```
Host: smtp.mailgun.org
Port: 587
Enable StartTLS: YES
Enable Authentication: YES
Username: postmaster@your-domain.mailgun.org
Password: [Your Mailgun SMTP Password]
```

**Setup:**
1. Sign up: https://mailgun.com
2. Add and verify your domain
3. Get SMTP credentials
4. Configure in Keycloak

---

### Option 3: Amazon SES

**Pros:**
- $0.10 per 1,000 emails
- Highly scalable
- AWS integration

**Configuration:**
```
Host: email-smtp.[region].amazonaws.com
Port: 587
Enable StartTLS: YES
Enable Authentication: YES
Username: [SMTP Username from AWS]
Password: [SMTP Password from AWS]
```

**Setup:**
1. AWS Console → SES
2. Verify email addresses or domain
3. Create SMTP credentials
4. Request production access (remove sandbox)

---

### Option 4: Google Workspace (Paid Gmail)

**Pros:**
- Professional email (@yourdomain.com)
- 2,000 emails/day per user
- Better reputation than free Gmail

**Configuration:**
```
Host: smtp-relay.gmail.com
Port: 587
Enable StartTLS: YES
Enable Authentication: YES
Username: your-email@yourdomain.com
Password: [App Password]
```

**Pricing:**
- $6/user/month (Business Starter)

---

## Security Best Practices

### 1. Protect SMTP Credentials

❌ **Never:**
- Commit passwords to Git
- Share passwords in Slack/Email
- Use plain text configuration files

✅ **Always:**
- Use environment variables
- Store in secret management (AWS Secrets Manager, Vault)
- Rotate passwords regularly (every 90 days)

### 2. Use Environment-Specific Configurations

```yaml
# Development
From: noreply-dev@yourdomain.com

# Staging
From: noreply-staging@yourdomain.com

# Production
From: noreply@yourdomain.com
```

### 3. Email Rate Limiting

Implement rate limiting to prevent abuse:

**In Spring Boot:**
```java
// Limit: 5 verification emails per hour per user
@RateLimiter(name = "emailVerification", fallbackMethod = "emailLimitExceeded")
public void sendVerificationEmail(String userId) {
    // Send email
}
```

---

## Verification Email Template

### Default Keycloak Email (Plain Text)

```
Subject: Verify email

Please verify your email address by clicking on the link below:

http://localhost:8090/realms/hrms-saas/login-actions/action-token?key=...

This link will expire in 5 minutes.
```

### Customized Email (HTML)

For better user experience, create custom HTML email template:

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 8px;
        }
    </style>
</head>
<body>
    <h2>Welcome to HRMS SaaS!</h2>
    <p>Thank you for signing up. Please verify your email address.</p>
    <p>
        <a href="${link}" class="button">Verify Email Address</a>
    </p>
    <p>Or copy this link: ${link}</p>
    <p>This link expires in 5 minutes.</p>
    <hr>
    <p><small>HRMS SaaS Platform - Systech Solutions</small></p>
</body>
</html>
```

---

## FAQ

### Q1: Can I use a free Gmail account for production?

**A:** Not recommended. Free Gmail accounts have:
- Daily sending limits (500 emails)
- Higher chance of being marked as spam
- No SLA guarantees

For production, use Google Workspace or dedicated email service.

---

### Q2: How long is the verification link valid?

**A:** By default, Keycloak verification links expire after **5 minutes**.

To change:
1. Keycloak → Realm settings → Tokens tab
2. Change "Action Token Expiration"

---

### Q3: Can users request a new verification email?

**A:** Yes, the React app has a "Resend Email" button that calls:
```
POST /api/v1/auth/resend-verification
Body: { "email": "user@example.com" }
```

---

### Q4: What happens if user never verifies email?

**A:** User account exists but:
- `enabled: false` → Cannot login
- `emailVerified: false` → Blocked by Keycloak

Admin can manually verify in Keycloak:
1. Users → Search user
2. Edit user
3. Check "Email Verified"
4. Set "Enabled" to ON
5. Save

---

### Q5: Can I disable email verification for testing?

**A:** Yes, for development only:

1. Keycloak → Realm settings → Login tab
2. Uncheck "Verify email"
3. Save

**Note:** Users will be enabled immediately without email verification.

---

## Support & Contacts

**For Email Configuration Issues:**
- Backend Team Lead: backend@systech.com
- DevOps Team: devops@systech.com

**For Keycloak Issues:**
- Keycloak Admin: keycloak-admin@systech.com

**Documentation:**
- Keycloak Docs: https://www.keycloak.org/docs/latest/server_admin/
- Gmail SMTP: https://support.google.com/a/answer/176600

---

## Appendix: Quick Reference

### Gmail SMTP Settings (Copy-Paste)

```
Host: smtp.gmail.com
Port: 587
Enable StartTLS: YES
Enable SSL: NO
Enable Authentication: YES
Username: your-email@gmail.com
Password: [16-char App Password]
```

### Test Email Command (cURL)

```bash
# Test SMTP connectivity
curl -v --url 'smtp://smtp.gmail.com:587' \
  --mail-from 'your-email@gmail.com' \
  --mail-rcpt 'test@example.com' \
  --upload-file - \
  --user 'your-email@gmail.com:app-password' \
  --ssl-reqd
```

### Keycloak Admin API - Send Verification Email

```bash
# Get admin token
TOKEN=$(curl -s -X POST http://localhost:8090/realms/master/protocol/openid-connect/token \
  -d 'client_id=admin-cli' \
  -d 'username=admin' \
  -d 'password=admin' \
  -d 'grant_type=password' | jq -r '.access_token')

# Send verification email
curl -X PUT "http://localhost:8090/admin/realms/hrms-saas/users/{userId}/send-verify-email" \
  -H "Authorization: Bearer $TOKEN"
```

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-31
**Maintained By:** Systech DevOps Team
