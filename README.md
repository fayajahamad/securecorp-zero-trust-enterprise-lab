# SecureCorp — Zero Trust Enterprise Security Lab

## Project Overview
A Docker-based Zero Trust enterprise access lab
demonstrating identity verification, MFA,
policy-based application access, network segmentation,
centralized logging, and security alerting.

## Technologies
- Docker and Docker networking
- Keycloak — identity and MFA
- Pomerium — identity-aware access gateway
- HR Portal — protected demonstration application
- Grafana — monitoring dashboards and alerting
- Loki — log storage and querying
- Grafana Alloy — log collection
- PowerShell and Windows Task Scheduler — automation

## Demonstrated Functionality
- Authorized HR account accesses the HR Portal.
- Contractor account is denied by access policy.
- Keycloak failed-login events are collected in Loki.
- Grafana displays authentication and authorization events.
- A failed-login alert was triggered and delivered by email.
- Log collection continues after Windows startup.
- Docker networks separate identity, HR, and monitoring services.

## Network Design
- zt-identity: Keycloak and Pomerium
- zt-hr-private: Pomerium and HR Portal
- securecorp-monitoring_default: Grafana, Loki, Alloy

## Security Limitations
This is a local demonstration, not a production deployment.

- Browser-facing HTTPS trust is not fully configured.
- Keycloak uses HTTP for its current login page.
- Administrator hardening requires final review.
- No real company or employee information should be used.
- Never commit credentials, private keys, or log data.

## Project Status
Functional local lab; production hardening outstanding.
