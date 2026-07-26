# Disaster recovery and resilience

## Objectives

- Tier 1 identity, tenancy and publishing metadata: RPO 15 minutes; RTO 60 minutes.
- Tier 2 generated artefacts and reporting: RPO 24 hours; RTO 8 hours.

## Required exercises

Quarterly exercises cover database point-in-time recovery, accidental tenant deletion, regional loss, object-storage unavailability, queue backlog, credential compromise, and rollback from a failed migration. Each exercise records timestamps, data loss, customer impact, decisions, evidence, and corrective actions.

A recovery is successful only when tenant isolation, critical record counts, audit continuity, checksums, application health, and a representative publishing workflow are verified.
