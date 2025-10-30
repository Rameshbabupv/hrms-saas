# Keycloak Setup - Complete Index

**Quick Navigation:** This file provides links to all documentation and scripts.

---

## 📖 Documentation Files

| File | Description | When to Read |
|------|-------------|--------------|
| [README.md](README.md) | **START HERE** - Main documentation with everything | First time setup |
| [QUICK_START.md](QUICK_START.md) | Quick reference guide | Daily reference |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Complete project summary | Project overview |
| [INDEX.md](INDEX.md) | This file - Navigation index | Quick navigation |

### Detailed Documentation

| File | Description |
|------|-------------|
| [docs/SETUP_COMPLETE_README.md](docs/SETUP_COMPLETE_README.md) | Complete setup guide with manual steps |
| [docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md](docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md) | Full reference (200+ sections) |
| [docs/KEYCLOAK_NOTES.md](docs/KEYCLOAK_NOTES.md) | Team-specific quick notes |

---

## 🔧 Management Scripts

### Essential Scripts (Use These Daily)

```bash
# Start Keycloak
./scripts/start-keycloak.sh

# Check status
./scripts/status-keycloak.sh

# Stop Keycloak
./scripts/stop-keycloak.sh
```

| Script | Purpose | Usage |
|--------|---------|-------|
| `start-keycloak.sh` | ⭐ Start Keycloak service | `./start-keycloak.sh` |
| `stop-keycloak.sh` | ⭐ Stop Keycloak service | `./stop-keycloak.sh` |
| `status-keycloak.sh` | ⭐ Check service status | `./status-keycloak.sh` |

### Setup Scripts (One-Time Use)

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-keycloak.sh` | Create realm and client | `./setup-keycloak.sh` |
| `create-mappers.sh` | Create JWT mappers | `./create-mappers.sh` |
| `create-test-users.sh` | Create test users | `./create-test-users.sh` |
| `run-all.sh` | Complete automated setup | `./run-all.sh` |

### Testing & Utility Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `test-token.sh` | Test JWT token generation | `./test-token.sh employee` |
| `fix-user-attributes.sh` | Fix user attributes | `./fix-user-attributes.sh` |

---

## 📁 Configuration Files

| File | Purpose | Share With |
|------|---------|------------|
| `config/keycloak-config.env` | Environment variables | Backend Team |
| `config/test-users.txt` | Test user credentials | QA Team |
| `config/tokens-*.json` | Sample JWT tokens | Backend Team |

---

## 🔐 Quick Access Information

### Keycloak Admin Console
- **URL:** http://localhost:8090/admin
- **Username:** `admin`
- **Password:** `secret`
- **Realm:** `hrms-saas`

### Client Credentials
- **Client ID:** `hrms-web-app`
- **Client Secret:** `AhuaZRTwH4wsXHFrmMEciDjo1Kc8aS0M`

### Test Users
- **Admin:** admin@testcompany.com / TestAdmin@123
- **Employee:** john.doe@testcompany.com / TestUser@123

---

## 🎯 Common Tasks

### Start Working
```bash
cd scripts
./start-keycloak.sh
./status-keycloak.sh
```

### Test Setup
```bash
./test-token.sh employee
```

### Stop Working
```bash
./stop-keycloak.sh
```

### Re-run Complete Setup
```bash
./run-all.sh
```

---

## 📋 Integration Checklists

### Backend Team Checklist
- [ ] Read `config/keycloak-config.env`
- [ ] Read `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` Section 11
- [ ] Implement JWT validation
- [ ] Extract `company_id` claim
- [ ] Set PostgreSQL tenant context
- [ ] Test with `./test-token.sh`

### Frontend Team Checklist
- [ ] Read `QUICK_START.md` Integration section
- [ ] Read `docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md` Section 11
- [ ] Install keycloak-js libraries
- [ ] Configure Keycloak provider
- [ ] Implement login/logout flows
- [ ] Test with test users

### QA Team Checklist
- [ ] Read `config/test-users.txt`
- [ ] Use `./test-token.sh` for validation
- [ ] Test authentication flows
- [ ] Verify multi-tenant isolation
- [ ] Test token refresh

---

## 🚨 Troubleshooting Quick Links

| Issue | Solution Link |
|-------|---------------|
| Service won't start | [README.md](README.md#troubleshooting) → "Keycloak Won't Start" |
| Can't access console | [README.md](README.md#troubleshooting) → "Can't Access Admin Console" |
| Missing JWT claims | [README.md](README.md#troubleshooting) → "Custom Claims Missing" |
| Auth fails | [README.md](README.md#troubleshooting) → "Authentication Fails" |

---

## 📞 Need Help?

1. **Check documentation:** Start with [README.md](README.md)
2. **Check status:** Run `./scripts/status-keycloak.sh`
3. **Check logs:** `podman logs nexus-keycloak-dev`
4. **Check scripts:** All scripts in `scripts/` directory

---

## 📚 Learning Path

### For Beginners
1. Read [QUICK_START.md](QUICK_START.md)
2. Run `./scripts/status-keycloak.sh`
3. Access Admin Console
4. Read [README.md](README.md) "Quick Start" section

### For Integration
1. Read your team's checklist (above)
2. Read [docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md](docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md) Section 11
3. Review `config/keycloak-config.env`
4. Test with `./scripts/test-token.sh`

### For Deep Dive
1. Read [README.md](README.md) completely
2. Read [docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md](docs/KEYCLOAK_IMPLEMENTATION_GUIDE.md)
3. Review all scripts in `scripts/`
4. Read [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)

---

**Last Updated:** October 30, 2025
**Status:** ✅ All documentation complete

---
