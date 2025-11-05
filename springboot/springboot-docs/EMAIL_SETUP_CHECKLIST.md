# Email Setup - Quick Checklist
## 5-Minute Setup Guide

**Goal:** Enable email verification for HRMS SaaS user signups

---

## ✅ Quick Setup Checklist

### □ Step 1: Generate Gmail App Password (2 minutes)

1. **Open:** https://myaccount.google.com/apppasswords
2. **If you don't see "App Passwords":**
   - Enable 2-Step Verification first at: https://myaccount.google.com/security
3. **Create App Password:**
   - App: **Mail**
   - Device: **HRMS Keycloak**
4. **Copy the password:** `abcd efgh ijkl mnop`
5. **Remove spaces:** `abcdefghijklmnop` ← Use this!

---

### □ Step 2: Configure Keycloak (3 minutes)

1. **Open Keycloak:** http://localhost:8090
2. **Login:** admin / admin
3. **Navigate:**
   - Realm: **hrms-saas** (top-left dropdown)
   - **Realm settings** → **Email** tab
4. **Fill in:**

```
From:                   your-email@gmail.com
From Display Name:      HRMS SaaS Platform
Host:                   smtp.gmail.com
Port:                   587
☑ Enable StartTLS
☐ Enable SSL
☑ Enable Authentication
Username:               your-email@gmail.com
Password:               [paste 16-char app password]
```

5. **Save** → Click **Test connection**
6. **Enter your email** → Check inbox for test email

---

### □ Step 3: Test Signup Flow (2 minutes)

1. **Open:** http://localhost:3000/signup
2. **Sign up** with a real email address
3. **Check inbox** for verification email
4. **Click verification link**
5. **Try logging in** at http://localhost:3000

---

## ⚠️ Common Issues

| Issue | Solution |
|-------|----------|
| "Authentication failed" | Use App Password, NOT regular Gmail password |
| "Connection refused" | Check port is 587, not 465 |
| "StartTLS required" | Enable StartTLS checkbox |
| Email not received | Check spam folder, wait 5 minutes |

---

## 📧 What Emails Get Sent?

| Trigger | Email Subject | Recipient |
|---------|---------------|-----------|
| User signs up | "Verify email" | New user |
| User clicks "Resend Email" | "Verify email" | User |
| Password reset requested | "Reset password" | User |

---

## 🎯 Success Criteria

✅ Test email sent successfully from Keycloak
✅ Signup sends verification email to user's inbox
✅ Verification link works and activates account
✅ User can login after verification

---

## 📖 Full Documentation

For detailed troubleshooting and production setup:
- See: `docs/EMAIL_SETUP_GUIDE.md`

---

**Setup Time:** 5-7 minutes
**Required By:** Backend Team, DevOps
**Updated:** 2025-10-31
