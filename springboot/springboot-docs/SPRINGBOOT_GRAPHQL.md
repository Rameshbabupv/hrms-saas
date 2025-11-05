# HRMS SaaS - GraphQL API Implementation

## 📋 Part 4: GraphQL for Business Operations

This document provides complete GraphQL schema and implementation for business operations (employees, departments, etc.).

---

## 🎯 GraphQL Schema Design

### **schema.graphqls** (src/main/resources/graphql/schema.graphqls)

```graphql
# ============================================
# SCALAR TYPES
# ============================================
scalar Date
scalar DateTime

# ============================================
# COMPANY QUERIES
# ============================================
type Query {
    # Get current company information
    currentCompany: Company!

    # Employee queries
    employee(id: ID!): Employee
    employees(
        status: String
        departmentId: ID
        search: String
        page: Int = 0
        size: Int = 20
    ): EmployeePage!

    # Department queries
    department(id: ID!): Department
    departments(
        status: String
        parentId: ID
    ): [Department!]!

    # User queries
    currentUser: User!
    users(userType: String, status: String): [User!]!
}

# ============================================
# MUTATIONS
# ============================================
type Mutation {
    # Employee mutations
    createEmployee(input: EmployeeInput!): Employee!
    updateEmployee(id: ID!, input: EmployeeInput!): Employee!
    deleteEmployee(id: ID!): Boolean!

    # Department mutations
    createDepartment(input: DepartmentInput!): Department!
    updateDepartment(id: ID!, input: DepartmentInput!): Department!
    deleteDepartment(id: ID!): Boolean!
}

# ============================================
# TYPES
# ============================================

type Company {
    tenantId: ID!
    companyName: String!
    companyCode: String
    email: String!
    phone: String
    address: String
    status: String!
    subscriptionPlan: String!
    createdAt: DateTime!
    updatedAt: DateTime
}

type Employee {
    id: ID!
    tenantId: ID!
    employeeCode: String!
    firstName: String!
    lastName: String!
    fullName: String!
    email: String!
    phone: String
    dateOfBirth: Date
    dateOfJoining: Date
    designation: String
    department: Department
    manager: Employee
    employmentType: String
    status: String!
    createdAt: DateTime!
    updatedAt: DateTime
}

type EmployeePage {
    content: [Employee!]!
    totalElements: Int!
    totalPages: Int!
    number: Int!
    size: Int!
}

type Department {
    id: ID!
    tenantId: ID!
    departmentCode: String!
    departmentName: String!
    description: String
    headOfDepartment: Employee
    parentDepartment: Department
    status: String!
    employees: [Employee!]
    createdAt: DateTime!
    updatedAt: DateTime
}

type User {
    id: ID!
    tenantId: ID!
    keycloakUserId: String!
    employee: Employee
    email: String!
    username: String!
    userType: String!
    status: String!
    lastLoginAt: DateTime
    createdAt: DateTime!
}

# ============================================
# INPUT TYPES
# ============================================

input EmployeeInput {
    employeeCode: String!
    firstName: String!
    lastName: String!
    email: String!
    phone: String
    dateOfBirth: Date
    dateOfJoining: Date
    designation: String
    departmentId: ID
    managerId: ID
    employmentType: String
    status: String
}

input DepartmentInput {
    departmentCode: String!
    departmentName: String!
    description: String
    headOfDepartmentId: ID
    parentDepartmentId: ID
    status: String
}
```

---

## 🔌 GraphQL Resolvers

### **1. EmployeeQueryResolver.java**

```java
package com.systech.hrms.graphql.resolver;

import com.systech.hrms.entity.Employee;
import com.systech.hrms.service.EmployeeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.stereotype.Controller;

import java.util.Map;
import java.util.UUID;

@Slf4j
@Controller
@RequiredArgsConstructor
public class EmployeeQueryResolver {

    private final EmployeeService employeeService;

    @QueryMapping
    public Employee employee(@Argument String id) {
        log.debug("GraphQL query: employee(id: {})", id);
        return employeeService.findById(UUID.fromString(id));
    }

    @QueryMapping
    public Map<String, Object> employees(
        @Argument String status,
        @Argument String departmentId,
        @Argument String search,
        @Argument Integer page,
        @Argument Integer size
    ) {
        log.debug("GraphQL query: employees(status: {}, dept: {}, search: {}, page: {}, size: {})",
            status, departmentId, search, page, size);

        PageRequest pageRequest = PageRequest.of(
            page != null ? page : 0,
            size != null ? size : 20
        );

        Page<Employee> employeePage;

        if (search != null && !search.isBlank()) {
            employeePage = employeeService.searchEmployees(search, pageRequest);
        } else if (departmentId != null) {
            employeePage = employeeService.findByDepartmentId(
                UUID.fromString(departmentId), pageRequest
            );
        } else if (status != null) {
            employeePage = employeeService.findByStatus(status, pageRequest);
        } else {
            employeePage = employeeService.findAll(pageRequest);
        }

        return Map.of(
            "content", employeePage.getContent(),
            "totalElements", employeePage.getTotalElements(),
            "totalPages", employeePage.getTotalPages(),
            "number", employeePage.getNumber(),
            "size", employeePage.getSize()
        );
    }
}
```

### **2. EmployeeMutationResolver.java**

```java
package com.systech.hrms.graphql.resolver;

import com.systech.hrms.dto.graphql.EmployeeInput;
import com.systech.hrms.entity.Employee;
import com.systech.hrms.service.EmployeeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.MutationMapping;
import org.springframework.stereotype.Controller;

import java.util.UUID;

@Slf4j
@Controller
@RequiredArgsConstructor
public class EmployeeMutationResolver {

    private final EmployeeService employeeService;

    @MutationMapping
    public Employee createEmployee(@Argument EmployeeInput input) {
        log.info("GraphQL mutation: createEmployee(email: {})", input.getEmail());
        return employeeService.create(input);
    }

    @MutationMapping
    public Employee updateEmployee(@Argument String id, @Argument EmployeeInput input) {
        log.info("GraphQL mutation: updateEmployee(id: {})", id);
        return employeeService.update(UUID.fromString(id), input);
    }

    @MutationMapping
    public Boolean deleteEmployee(@Argument String id) {
        log.info("GraphQL mutation: deleteEmployee(id: {})", id);
        employeeService.delete(UUID.fromString(id));
        return true;
    }
}
```

### **3. CompanyQueryResolver.java**

```java
package com.systech.hrms.graphql.resolver;

import com.systech.hrms.entity.CompanyMaster;
import com.systech.hrms.security.TenantContext;
import com.systech.hrms.service.TenantService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.stereotype.Controller;

@Slf4j
@Controller
@RequiredArgsConstructor
public class CompanyQueryResolver {

    private final TenantService tenantService;

    @QueryMapping
    public CompanyMaster currentCompany() {
        String tenantId = TenantContext.getCurrentTenant();
        log.debug("GraphQL query: currentCompany() for tenant: {}", tenantId);
        return tenantService.findByTenantId(tenantId);
    }
}
```

---

## 🎯 Service Layer

### **EmployeeService.java**

```java
package com.systech.hrms.service;

import com.systech.hrms.dto.graphql.EmployeeInput;
import com.systech.hrms.entity.Employee;
import com.systech.hrms.exception.TenantNotFoundException;
import com.systech.hrms.repository.EmployeeRepository;
import com.systech.hrms.security.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmployeeService {

    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public Employee findById(UUID id) {
        return employeeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Employee not found: " + id));
    }

    @Transactional(readOnly = true)
    public Page<Employee> findAll(Pageable pageable) {
        // RLS automatically filters by tenant_id
        return employeeRepository.findAll(pageable);
    }

    @Transactional(readOnly = true)
    public Page<Employee> findByStatus(String status, Pageable pageable) {
        return employeeRepository.findByStatus(status, pageable);
    }

    @Transactional(readOnly = true)
    public Page<Employee> findByDepartmentId(UUID departmentId, Pageable pageable) {
        return employeeRepository.findByDepartmentId(departmentId, pageable);
    }

    @Transactional(readOnly = true)
    public Page<Employee> searchEmployees(String search, Pageable pageable) {
        return employeeRepository.searchEmployees(search, pageable);
    }

    @Transactional
    public Employee create(EmployeeInput input) {
        String tenantId = TenantContext.getCurrentTenant();
        if (tenantId == null) {
            throw new TenantNotFoundException("Tenant context not found");
        }

        log.info("Creating employee: {} {} for tenant: {}",
            input.getFirstName(), input.getLastName(), tenantId);

        Employee employee = Employee.builder()
            .tenantId(tenantId)
            .employeeCode(input.getEmployeeCode())
            .firstName(input.getFirstName())
            .lastName(input.getLastName())
            .email(input.getEmail())
            .phone(input.getPhone())
            .dateOfBirth(input.getDateOfBirth())
            .dateOfJoining(input.getDateOfJoining())
            .designation(input.getDesignation())
            .departmentId(input.getDepartmentId() != null ?
                UUID.fromString(input.getDepartmentId()) : null)
            .managerId(input.getManagerId() != null ?
                UUID.fromString(input.getManagerId()) : null)
            .employmentType(input.getEmploymentType())
            .status(input.getStatus() != null ? input.getStatus() : "ACTIVE")
            .createdBy(TenantContext.getCurrentTenant())
            .build();

        return employeeRepository.save(employee);
    }

    @Transactional
    public Employee update(UUID id, EmployeeInput input) {
        Employee employee = findById(id);

        log.info("Updating employee: {} for tenant: {}",
            id, TenantContext.getCurrentTenant());

        employee.setEmployeeCode(input.getEmployeeCode());
        employee.setFirstName(input.getFirstName());
        employee.setLastName(input.getLastName());
        employee.setEmail(input.getEmail());
        employee.setPhone(input.getPhone());
        employee.setDateOfBirth(input.getDateOfBirth());
        employee.setDateOfJoining(input.getDateOfJoining());
        employee.setDesignation(input.getDesignation());
        employee.setDepartmentId(input.getDepartmentId() != null ?
            UUID.fromString(input.getDepartmentId()) : null);
        employee.setManagerId(input.getManagerId() != null ?
            UUID.fromString(input.getManagerId()) : null);
        employee.setEmploymentType(input.getEmploymentType());
        if (input.getStatus() != null) {
            employee.setStatus(input.getStatus());
        }

        return employeeRepository.save(employee);
    }

    @Transactional
    public void delete(UUID id) {
        Employee employee = findById(id);
        log.info("Deleting employee: {} for tenant: {}",
            id, TenantContext.getCurrentTenant());
        employeeRepository.delete(employee);
    }
}
```

---

## 📦 GraphQL Input DTOs

### **EmployeeInput.java**

```java
package com.systech.hrms.dto.graphql;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeInput {
    private String employeeCode;
    private String firstName;
    private String lastName;
    private String email;
    private String phone;
    private LocalDate dateOfBirth;
    private LocalDate dateOfJoining;
    private String designation;
    private String departmentId;
    private String managerId;
    private String employmentType;
    private String status;
}
```

---

## 🧪 Testing GraphQL with GraphiQL

### **Access GraphiQL Interface:**
```
http://localhost:8081/graphiql
```

### **Example Queries:**

**1. Get Current Company:**
```graphql
query {
  currentCompany {
    tenantId
    companyName
    email
    status
    subscriptionPlan
  }
}
```

**2. List All Employees:**
```graphql
query {
  employees(page: 0, size: 10) {
    content {
      id
      employeeCode
      firstName
      lastName
      fullName
      email
      designation
      status
      department {
        departmentName
      }
    }
    totalElements
    totalPages
  }
}
```

**3. Search Employees:**
```graphql
query {
  employees(search: "john", page: 0, size: 10) {
    content {
      id
      fullName
      email
      designation
    }
    totalElements
  }
}
```

**4. Get Employee by ID:**
```graphql
query {
  employee(id: "a1b2c3d4-uuid") {
    id
    fullName
    email
    designation
    department {
      departmentName
    }
    manager {
      fullName
    }
  }
}
```

**5. Create Employee:**
```graphql
mutation {
  createEmployee(input: {
    employeeCode: "EMP001"
    firstName: "John"
    lastName: "Doe"
    email: "john.doe@example.com"
    phone: "+1234567890"
    designation: "Software Engineer"
    employmentType: "FULL_TIME"
    status: "ACTIVE"
  }) {
    id
    fullName
    email
    employeeCode
  }
}
```

**6. Update Employee:**
```graphql
mutation {
  updateEmployee(
    id: "a1b2c3d4-uuid"
    input: {
      employeeCode: "EMP001"
      firstName: "John"
      lastName: "Smith"
      email: "john.smith@example.com"
      designation: "Senior Software Engineer"
      status: "ACTIVE"
    }
  ) {
    id
    fullName
    designation
  }
}
```

---

## 🔒 GraphQL Security

### **Adding Authentication to GraphQL Requests:**

```javascript
// React App - GraphQL Query with JWT
const query = `
  query {
    employees(page: 0, size: 10) {
      content {
        id
        fullName
        email
      }
    }
  }
`;

const response = await fetch('http://localhost:8081/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${jwtToken}`,  // JWT from Keycloak
  },
  body: JSON.stringify({ query }),
});

const data = await response.json();
```

### **GraphQL Error Handling:**

```java
package com.systech.hrms.graphql;

import graphql.GraphQLError;
import graphql.GraphqlErrorBuilder;
import graphql.schema.DataFetchingEnvironment;
import lombok.extern.slf4j.Slf4j;
import org.springframework.graphql.execution.DataFetcherExceptionResolverAdapter;
import org.springframework.graphql.execution.ErrorType;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class GraphQLExceptionHandler extends DataFetcherExceptionResolverAdapter {

    @Override
    protected GraphQLError resolveToSingleError(
        Throwable ex,
        DataFetchingEnvironment env
    ) {
        log.error("GraphQL error: {}", ex.getMessage(), ex);

        if (ex instanceof TenantNotFoundException) {
            return GraphqlErrorBuilder.newError()
                .errorType(ErrorType.NOT_FOUND)
                .message("Tenant not found")
                .path(env.getExecutionStepInfo().getPath())
                .location(env.getField().getSourceLocation())
                .build();
        }

        if (ex instanceof AccessDeniedException) {
            return GraphqlErrorBuilder.newError()
                .errorType(ErrorType.FORBIDDEN)
                .message("Access denied")
                .path(env.getExecutionStepInfo().getPath())
                .location(env.getField().getSourceLocation())
                .build();
        }

        return GraphqlErrorBuilder.newError()
            .errorType(ErrorType.INTERNAL_ERROR)
            .message("Internal server error")
            .path(env.getExecutionStepInfo().getPath())
            .location(env.getField().getSourceLocation())
            .build();
    }
}
```

---

**Continued in SPRINGBOOT_DOCKER.md for Docker Compose setup...**
