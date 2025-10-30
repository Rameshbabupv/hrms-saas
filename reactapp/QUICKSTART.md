# 🚀 HRMS SaaS React Frontend - Quick Start

Get the multi-tenant HRMS application running in 5 minutes!

## Prerequisites Check

```bash
# Verify you have Node.js 18+
node --version

# Verify Keycloak is running
curl http://localhost:8090/realms/hrms-saas

# Verify Backend API is running
curl http://localhost:8081/actuator/health

# Verify Database is accessible
psql -h localhost -U hrms_app -d hrms_saas -c "SELECT 1;"
```

If any check fails, refer to `SETUP.md` for detailed setup instructions.

## Step 1: Install Dependencies (1 min)

```bash
cd /Users/rameshbabu/data/projects/systech/hrms-saas/reactapp
npm install
```

## Step 2: Configure Environment (1 min)

```bash
# Copy environment template
cp .env.example .env

# Edit .env file (use your actual Keycloak configuration)
cat > .env << 'EOF'
REACT_APP_KEYCLOAK_URL=http://localhost:8090
REACT_APP_KEYCLOAK_REALM=hrms-saas
REACT_APP_KEYCLOAK_CLIENT=hrms-web-app
REACT_APP_API_URL=http://localhost:8081
REACT_APP_GRAPHQL_URL=http://localhost:8081/graphql
EOF
```

## Step 3: Start Development Server (1 min)

```bash
npm start
```

Browser opens at: `http://localhost:3000`

## Step 4: Login with Test User (1 min)

**Default Test Credentials:**
- Username: `admin@testcompany.com`
- Password: `TestAdmin@123`

*Note: These credentials must be configured in Keycloak first. See SETUP.md if needed.*

## Step 5: Verify Tenant Context (1 min)

After login:

1. **Check Dashboard** - You should see:
   - Your user information
   - Tenant Context with Company ID
   - "Tenant ID (for RLS)" displayed

2. **Check Browser Console** - You should see:
   ```
   🔐 Authenticated with tenant context: {
     companyId: "550e8400-e29b-41d4-a716-446655440000",
     tenantId: "550e8400-e29b-41d4-a716-446655440000",
     userType: "company_admin"
   }
   ```

3. **Verify JWT Token**:
   - Open DevTools > Application > Local Storage
   - Find `access_token`
   - Copy value
   - Go to https://jwt.io
   - Paste token
   - Verify it contains:
     ```json
     {
       "company_id": "550e8400-...",
       "tenant_id": "550e8400-...",
       "user_type": "company_admin"
     }
     ```

## ✅ Success!

You now have:
- ✅ Multi-tenant React application running
- ✅ Keycloak authentication working
- ✅ JWT tokens with `tenant_id` for RLS
- ✅ Tenant context displayed in UI

## 🎯 Next Steps

### Test User Registration

1. Click **"Register User"** in navigation
2. Fill in employee details:
   - Email: `john.doe@testcompany.com`
   - First Name: `John`
   - Last Name: `Doe`
   - Role: `Employee`
   - Password: `TempPass123!`
3. Click **"Create User"**
4. Verify success message
5. Check Keycloak Admin Console to see new user with `company_id` attribute

### Make API Call

```javascript
// Open browser console and run:
const token = localStorage.getItem('access_token');
fetch('http://localhost:8081/api/companies', {
  headers: { 'Authorization': `Bearer ${token}` }
})
  .then(r => r.json())
  .then(data => console.log('Companies:', data));
```

### Test Multi-Tenant Isolation

1. Create second company in database:
   ```sql
   INSERT INTO company (id, company_code, company_name, company_type, is_active)
   VALUES ('770e8400-e29b-41d4-a716-446655440002', 'TEST002', 'Company 2', 'INDEPENDENT', true);
   ```

2. Create user for second company in Keycloak with `company_id=770e8400-...`

3. Login as User 1 → See only Company 1 data
4. Logout → Login as User 2 → See only Company 2 data

## 🐛 Troubleshooting

### App doesn't start
```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
npm start
```

### Login fails
- Verify Keycloak is running: `curl http://localhost:8090`
- Check `.env` has correct `REACT_APP_KEYCLOAK_URL`
- Verify test user exists in Keycloak

### JWT missing tenant_id
- Check Keycloak client mappers (see SETUP.md)
- Verify user has `company_id` attribute in Keycloak
- Ensure mappers add claims to **access token**

### CORS errors
- Add `http://localhost:3000` to Keycloak client "Web Origins"
- Or add `+` to allow all redirect URIs

## 📚 Documentation

| File | Purpose |
|------|---------|
| `README.md` | Complete user guide |
| `SETUP.md` | Detailed setup instructions |
| `IMPLEMENTATION_SUMMARY.md` | Technical implementation details |
| `QUICKSTART.md` | This file |

## 🆘 Need Help?

1. Check browser console for errors
2. Check Keycloak Admin Console for user configuration
3. Verify backend API is running and accessible
4. Refer to `SETUP.md` for detailed troubleshooting

---

**That's it! You're ready to build your multi-tenant HRMS application! 🎉**

Happy coding! 👨‍💻👩‍💻
