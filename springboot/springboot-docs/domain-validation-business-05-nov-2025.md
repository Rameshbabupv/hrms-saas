# Domain Validation - Business Guide

## What Is This?

When someone signs up for the HRMS platform using their email address, the system checks the **email domain** (the part after @) to decide if they can create an account.

## Why Do We Need This?

**Problem:** Without domain validation, anyone could:
- Use your company email (john@systech.com) to create their own account
- Steal your company name
- Confuse employees about which account is real

**Solution:** Lock company email domains to prevent unauthorized usage.

## How It Works

### Two Types of Email Domains

#### 1. Public Email Domains
**Examples:** gmail.com, yahoo.com, outlook.com

**What happens:**
- ✅ Multiple companies can use the same public domain
- ✅ John@gmail.com and Jane@gmail.com can both create separate companies
- ✅ No restrictions

**Why:** These are personal email services used by millions of people.

#### 2. Corporate Email Domains
**Examples:** systech.com, acme.com, yourcompany.com

**What happens:**
- 🔒 First person to sign up **locks** the domain
- ❌ Second person with same domain is **blocked**
- ✅ Forces everyone to join the same company account

**Why:** Ensures one company = one account. Prevents duplicate or fake accounts.

## Real-World Examples

### Example 1: Small Business Owner
**Scenario:** Sarah owns "Acme Industries" with email sarah@acme.com

**What happens:**
1. Sarah signs up with sarah@acme.com
2. System locks "acme.com" to Sarah's company
3. Later, employee John tries john@acme.com
4. System blocks John: "Domain acme.com is already registered"
5. John must contact Sarah to get added as an employee

**Result:** Prevents duplicate companies, ensures proper company structure.

### Example 2: Freelancer
**Scenario:** Mike is a freelancer using mike@gmail.com

**What happens:**
1. Mike signs up with mike@gmail.com
2. System allows it (gmail.com is public)
3. Later, Lisa (another freelancer) signs up with lisa@gmail.com
4. System allows Lisa too
5. Both have separate company accounts

**Result:** Public email users can coexist.

### Example 3: Second Location Attempt
**Scenario:** Acme Industries has 2 locations. Manager at Location 2 tries to create separate account.

**What happens:**
1. Location 1 manager already registered with admin@acme.com
2. Location 2 manager tries location2@acme.com
3. System blocks: "Domain acme.com is already registered"
4. Location 2 must contact Location 1 admin

**Result:** Prevents data fragmentation across multiple accounts.

## User Experience

### During Signup

**Step 1:** User enters email
**Step 2:** System extracts domain
**Step 3:** System checks domain availability
**Step 4:** User sees result:

#### If Public Domain (gmail.com)
```
✅ Personal email detected. You can proceed.
```

#### If Corporate Domain - Available (newcompany.com)
```
✅ This will register newcompany.com to your company.
   You will be the company admin.
```

#### If Corporate Domain - Already Taken (systech.com)
```
❌ Domain systech.com is already registered.
   Contact: admin@systech.com for access.
```

## Business Rules

### Rule 1: First Come, First Served
- First person with corporate email locks the domain
- No exceptions (prevents disputes)

### Rule 2: Public Domains Are Free
- Public email services never get locked
- Unlimited users can use gmail.com, yahoo.com, etc.

### Rule 3: One Company = One Domain
- Corporate domain can only belong to one company account
- Prevents data duplication and confusion

### Rule 4: Domain Cannot Be Transferred
- Once locked, domain stays with that company
- Admin intervention required to unlock (rare cases)

## Benefits

### For Company Admins
- ✅ Control over who represents your company
- ✅ Prevent unauthorized account creation
- ✅ Ensure all employees use one central account
- ✅ Better data integrity

### For Employees
- ✅ Clear which account to join
- ✅ No confusion about company affiliation
- ✅ Prevented from accidentally creating duplicate accounts

### For Platform
- ✅ Reduces fake/duplicate companies
- ✅ Cleaner data
- ✅ Better multi-tenant isolation
- ✅ Easier support (one company = one account)

## Supported Public Domains

Pre-approved public email services:
- Gmail (gmail.com)
- Yahoo (yahoo.com)
- Outlook (outlook.com, hotmail.com)
- iCloud (icloud.com)
- ProtonMail (protonmail.com)
- AOL (aol.com)
- Zoho (zoho.com)
- Mail.com (mail.com)
- Yandex (yandex.com)

**Note:** More can be added if needed.

## Common Questions

### Q1: What if I use a personal email by mistake?
**A:** You can still sign up with gmail.com/yahoo.com, but you should use your company email if you have one.

### Q2: What if someone else registered my company domain?
**A:** Contact support with proof of ownership. We can unlock and transfer the domain.

### Q3: Can I change my email domain later?
**A:** No. Domain is locked permanently during signup.

### Q4: What if we merge with another company?
**A:** Contact support. Manual intervention required for domain transfers.

### Q5: What if employee leaves the company?
**A:** Their individual account is removed, but the domain lock remains for the company.

### Q6: Can I use subdomain? (john@sales.acme.com)
**A:** No. Only the main domain (acme.com) is validated.

## Edge Cases

### Case 1: Company Using Gmail for Business
**Situation:** Company uses Gmail Workspace (john@acme.com via Google)

**Solution:** Works fine. System sees "acme.com" as corporate domain and locks it.

### Case 2: Multiple Business Units
**Situation:** Acme Corp has HR@acme.com and Sales@acme.com trying to create separate accounts

**Result:** Second one blocked. Must use single account with role-based access.

### Case 3: Typo in Email
**Situation:** User types john@gmial.com (typo in gmail)

**Result:** System treats "gmial.com" as corporate domain and locks it to that user.
**Prevention:** Frontend validation should catch common typos.

## Support Scenarios

### Scenario 1: User Locked Out
**Problem:** "My email is blocked during signup"
**Cause:** Domain already registered
**Resolution:** Provide contact info of existing admin

### Scenario 2: Wrong Person Registered
**Problem:** "Employee registered before admin"
**Cause:** No way to prevent this automatically
**Resolution:** Manual domain transfer by support team

### Scenario 3: Public Domain Not Recognized
**Problem:** "My public email is being treated as corporate"
**Cause:** Domain not in public domain list
**Resolution:** Add to public domain list and redeploy

## Metrics to Monitor

### Business Metrics
- Number of corporate domains registered per day
- Number of signup blocks (attempted duplicates)
- Ratio of public vs corporate email signups
- Support tickets related to domain issues

### Health Metrics
- Domain validation API response time
- Signup conversion rate
- Bounce rate on domain validation errors

## Future Considerations

### Potential Enhancements
1. **Whitelist Management:** Allow admins to pre-approve employee emails
2. **Domain Verification:** Require DNS verification for corporate domains
3. **Bulk Import:** Allow admin to invite employees via CSV
4. **Domain Transfer:** Self-service domain ownership transfer
5. **Subdomain Support:** Treat sales.acme.com separately from acme.com

### Not Planned
- Domain sharing between companies
- Temporary domain locks
- User-requested domain unlocks

## Summary

**Simple Rule:**
- Personal emails (gmail.com) = Open for everyone
- Company emails (yourcompany.com) = First person locks it

**Goal:** One company = One account = Clean data + Better security

## Questions?
Contact: Product Team or Support
