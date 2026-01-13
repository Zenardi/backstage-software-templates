# EKS Cluster Architecture & Configuration Guide

A comprehensive guide to understanding EKS cluster components, networking, and the critical role of NAT gateways.

---

- [EKS Cluster Architecture \& Configuration Guide](#eks-cluster-architecture--configuration-guide)
  - [Overview](#overview)
    - [What is EKS?](#what-is-eks)
    - [High-Level Flow](#high-level-flow)
  - [Core Architecture](#core-architecture)
    - [Three-Layer Architecture](#three-layer-architecture)
    - [The Three Subnets Explained](#the-three-subnets-explained)
  - [Networking Deep Dive](#networking-deep-dive)
    - [The Traffic Flow Journey](#the-traffic-flow-journey)
      - [1. **Outbound Traffic (Pod → Internet)**](#1-outbound-traffic-pod--internet)
      - [2. **Inbound Traffic (Control Plane → Nodes)**](#2-inbound-traffic-control-plane--nodes)
  - [The NAT Gateway Problem](#the-nat-gateway-problem)
    - [Why Does NAT Gateway Matter for Nodes?](#why-does-nat-gateway-matter-for-nodes)
  - [Component Configuration](#component-configuration)
    - [1. VPC Configuration](#1-vpc-configuration)
    - [2. Subnets Configuration](#2-subnets-configuration)
    - [3. NAT Gateway Configuration](#3-nat-gateway-configuration)
    - [4. Route Tables \& Routes](#4-route-tables--routes)
    - [5. Internet Gateway Configuration](#5-internet-gateway-configuration)
  - [Security \& IAM](#security--iam)
    - [Security Groups Explained](#security-groups-explained)
    - [IAM Roles Explained](#iam-roles-explained)
  - [Deployment Order](#deployment-order)
  - [Quick Troubleshooting Reference](#quick-troubleshooting-reference)
  - [Summary Checklist](#summary-checklist)
  - [Key Takeaways](#key-takeaways)


---

## Overview

### What is EKS?

**Amazon EKS (Elastic Kubernetes Service)** is a managed Kubernetes control plane on AWS. You provide:
- **Worker nodes** (EC2 instances)
- **Networking** (VPC, subnets, security groups)
- **IAM permissions** (roles and policies)

AWS provides:
- **Control plane** (API server, scheduler, etcd)
- **Add-ons** (networking, DNS, monitoring)

### High-Level Flow

```
Your Application Pods
        ↓
Kubernetes Pods (run on Worker Nodes)
        ↓
EC2 Instances (Worker Nodes) in Private Subnets
        ↓
VPC with Public & Private Subnets
        ↓
NAT Gateway (in Public Subnet)
        ↓
Internet Gateway
        ↓
AWS Internet / EKS Control Plane Endpoint
```

---

## Core Architecture

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS REGION (us-east-1)                      │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              VPC (10.0.0.0/16)                            │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ PUBLIC SUBNET (10.0.1.0/24) - us-east-1a            │ │  │
│  │  │ ┌────────────────┐                                  │ │  │
│  │  │ │  NAT Gateway   │ → Route: 0.0.0.0/0 → IGW        │ │  │
│  │  │ │  (Elastic IP)  │                                  │ │  │
│  │  │ └────────────────┘                                  │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                           ↑                                 │  │
│  │                           │ egress                          │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ PRIVATE SUBNET 1 (10.0.2.0/24) - us-east-1a         │ │  │
│  │  │ ┌──────────────┐  ┌──────────────┐                 │ │  │
│  │  │ │  Worker Node │  │  Worker Node │                 │ │  │
│  │  │ │  (IP: x.x.x) │  │  (IP: y.y.y) │                 │ │  │
│  │  │ └──────────────┘  └──────────────┘                 │ │  │
│  │  │ Route: 0.0.0.0/0 → NAT Gateway                     │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ PRIVATE SUBNET 2 (10.0.3.0/24) - us-east-1b         │ │  │
│  │  │ ┌──────────────┐  ┌──────────────┐                 │ │  │
│  │  │ │  Worker Node │  │  Worker Node │                 │ │  │
│  │  │ │  (IP: z.z.z) │  │  (IP: w.w.w) │                 │ │  │
│  │  │ └──────────────┘  └──────────────┘                 │ │  │
│  │  │ Route: 0.0.0.0/0 → NAT Gateway (SAME as Subnet 1)  │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              EKS CONTROL PLANE (AWS Managed)             │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │  API Server (443)                                  │ │  │
│  │  │  Scheduler                                         │ │  │
│  │  │  Controller Manager                                │ │  │
│  │  │  etcd (State Database)                             │ │  │
│  │  └─────────────────────────────────────────────────────┘ │  │
│  │  Private Endpoint: enabled for VPC access                │  │
│  │  Public Endpoint: enabled for internet access            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                             ↑
                             │ Internet Access
                    ┌────────────────┐
                    │ Internet       │
                    │ Gateway (IGW)  │
                    └────────────────┘
```

### The Three Subnets Explained

| Subnet Type | CIDR | Availability Zone | Purpose | Route Table |
|------------|------|------------------|---------|-------------|
| **Public** | 10.0.1.0/24 | us-east-1a | Hosts NAT Gateway | IGW (0.0.0.0/0 → IGW) |
| **Private-1** | 10.0.2.0/24 | us-east-1a | Hosts Worker Nodes | NAT (0.0.0.0/0 → NAT) |
| **Private-2** | 10.0.3.0/24 | us-east-1b | Hosts Worker Nodes | NAT (0.0.0.0/0 → NAT) |

**Why 3 subnets?**
- **Public subnet**: NAT Gateway needs internet access (receives traffic from IGW)
- **Private subnets x2**: Worker nodes (security best practice - no direct internet)
- **Multi-AZ**: Subnet 2 in different AZ for high availability and resilience

---

## Networking Deep Dive

### The Traffic Flow Journey

#### 1. **Outbound Traffic (Pod → Internet)**

```
Pod (10.0.2.50) inside Worker Node
        ↓
kubelet (node daemon) sees traffic needs external destination
        ↓
Looks up route table for Private Subnet 1 (10.0.2.0/24)
        ↓
Finds: "0.0.0.0/0 → nat-xxxxx" (NAT Gateway)
        ↓
Traffic sent to NAT Gateway (in Public Subnet)
        ↓
NAT Gateway translates:
   Source IP: 10.0.2.50 → NAT Gateway Elastic IP (52.xxx.xxx.xxx)
   Destination: 8.8.8.8 (Google DNS)
        ↓
Sent via Internet Gateway to Internet
        ↓
Response comes back:
   Source: 8.8.8.8
   Destination: 52.xxx.xxx.xxx (NAT Gateway's Elastic IP)
        ↓
NAT Gateway translates back:
   Source: 8.8.8.8
   Destination: 10.0.2.50 (original pod)
        ↓
Pod receives response ✅
```

#### 2. **Inbound Traffic (Control Plane → Nodes)**

```
EKS Control Plane (Private Endpoint in VPC)
        ↓
Needs to communicate with Worker Nodes (e.g., metrics collection)
        ↓
Uses private IP route through VPC
        ↓
Security Group Rule: eks-node-sg allows port 1025-65535 from eks-cluster-sg
        ↓
Direct VPC communication (NO NAT needed, NO internet access)
        ↓
Worker Node receives on port 1025+
        ↓
Communication established ✅
```

---

## The NAT Gateway Problem

### Why Does NAT Gateway Matter for Nodes?

Worker nodes need outbound internet access to:

1. **Reach the EKS Control Plane endpoint** (even with private endpoint, initial DNS resolution needs internet sometimes)
2. **Download container images** from registries (ECR, Docker Hub)
3. **Pull OS updates** from AWS repositories
4. **Reach AWS APIs** for IAM authentication
5. **Download add-ons** (VPC CNI, CoreDNS, etc.)

**Without NAT, nodes are completely isolated and cannot bootstrap!**

---

## Component Configuration

### 1. VPC Configuration

**What it is:** Network container for all resources

```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: VPC
metadata:
  name: cheap-eks-vpc
spec:
  forProvider:
    region: us-east-1
    cidrBlock: 10.0.0.0/16  # 65,536 IP addresses
    enableDnsSupport: true   # Pods can resolve DNS ✅
    enableDnsHostnames: true # DNS names available ✅
```

**Key points:**
- **CIDR Block**: 10.0.0.0/16 gives room for 3+ subnets
- **DNS**: Must be enabled for cluster DNS (CoreDNS) to work
- **No direct internet needed**: Internet access through IGW

### 2. Subnets Configuration

```
PUBLIC SUBNET (Hosts NAT Gateway):
├─ CIDR: 10.0.1.0/24 (256 IPs, only needs 1 for NAT)
├─ AZ: us-east-1a
├─ mapPublicIpOnLaunch: true (if future resources added)
└─ Route Table: IGW (0.0.0.0/0 → IGW)

PRIVATE SUBNET 1 (Hosts Worker Nodes):
├─ CIDR: 10.0.2.0/24 (256 IPs)
├─ AZ: us-east-1a
├─ mapPublicIpOnLaunch: false (nodes should NOT have public IPs)
└─ Route Table: NAT Gateway (0.0.0.0/0 → NAT)

PRIVATE SUBNET 2 (Hosts Worker Nodes):
├─ CIDR: 10.0.3.0/24 (256 IPs)
├─ AZ: us-east-1b (DIFFERENT from Subnet 1!)
├─ mapPublicIpOnLaunch: false
└─ Route Table: NAT Gateway (0.0.0.0/0 → NAT) ← SAME as Subnet 1
```

**CRITICAL:** Both private subnets MUST use the SAME route table pointing to NAT!

### 3. NAT Gateway Configuration

**Network Address Translation** = translate private IPs to a single public IP

```
┌─────────────────────────────────────────┐
│ NAT Gateway (in Public Subnet)          │
├─ Elastic IP: 52.70.123.45 (static IP)  │
├─ Availability Zone: us-east-1a         │
├─ Status: Available (not creating)       │
└─────────────────────────────────────────┘
       ↑
       │ Outbound traffic from Private Subnets
       │
       Translates:
       10.0.2.50:54321 → 52.70.123.45:54321
       (private subnet IP → NAT's public IP)
```

```yaml
# Elastic IP for NAT
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: EIP
metadata:
  name: nat-eip
spec:
  forProvider:
    region: us-east-1
    domain: vpc  # Must be "vpc", not "standard"

---
# NAT Gateway
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: NATGateway
metadata:
  name: cheap-nat-gw
spec:
  forProvider:
    region: us-east-1
    allocationIdRef:
      name: nat-eip  # References the Elastic IP
    subnetIdRef:
      name: public-subnet-1  # MUST be in PUBLIC subnet
```

**Why EIP?** Static IP that doesn't change when NAT restarts

### 4. Route Tables & Routes

**Route Table** = set of rules determining where traffic goes

```yaml
# Route table for PRIVATE subnets
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: RouteTable
metadata:
  name: private-rt
spec:
  forProvider:
    region: us-east-1
    vpcIdRef:
      name: cheap-eks-vpc

---
# Route: default traffic to NAT
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: Route
metadata:
  name: private-route-nat
spec:
  forProvider:
    region: us-east-1
    routeTableIdRef:
      name: private-rt
    destinationCidrBlock: 0.0.0.0/0  # ALL traffic
    natGatewayIdRef:
      name: cheap-nat-gw

---
# CRITICAL: Associate route table with BOTH private subnets
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: RouteTableAssociation
metadata:
  name: private-rta-1
spec:
  forProvider:
    region: us-east-1
    subnetIdRef:
      name: private-subnet-1
    routeTableIdRef:
      name: private-rt

---
# SECOND association for Subnet 2 (THE FIX!)
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: RouteTableAssociation
metadata:
  name: private-rta-2
spec:
  forProvider:
    region: us-east-1
    subnetIdRef:
      name: private-subnet-2
    routeTableIdRef:
      name: private-rt  # SAME route table!
```

**Decision Tree:**
```
Traffic from Private Subnet
    ↓
Check Route Table association
    ↓
Is destination in 10.0.0.0/16? → Route: local (VPC internal)
Is destination 0.0.0.0/0? → Route: nat-xxxxx (NAT Gateway)
    ↓
Send to NAT Gateway ✅
```

### 5. Internet Gateway Configuration

**Internet Gateway** = connects VPC to internet

```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: InternetGateway
metadata:
  name: cheap-eks-igw
spec:
  forProvider:
    region: us-east-1
    vpcIdRef:
      name: cheap-eks-vpc

---
# Route table for PUBLIC subnet
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: RouteTable
metadata:
  name: public-rt
spec:
  forProvider:
    region: us-east-1
    vpcIdRef:
      name: cheap-eks-vpc

---
# Route: public traffic to internet
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: Route
metadata:
  name: public-route-igw
spec:
  forProvider:
    region: us-east-1
    routeTableIdRef:
      name: public-rt
    destinationCidrBlock: 0.0.0.0/0
    gatewayIdRef:
      name: cheap-eks-igw  # Direct to internet!
```

---

## Security & IAM

### Security Groups Explained

**Security Group** = firewall rules (ingress/egress)

```yaml
# Cluster Control Plane Security Group
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroup
metadata:
  name: eks-cluster-sg
spec:
  forProvider:
    name: eks-cluster-sg
    region: us-east-1
    vpcIdRef:
      name: cheap-eks-vpc

---
# Allow nodes to reach cluster API (443)
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroupRule
metadata:
  name: node-to-cluster-ingress
spec:
  forProvider:
    region: us-east-1
    type: ingress  # Inbound
    fromPort: 443
    toPort: 443
    protocol: tcp
    securityGroupIdRef:
      name: eks-cluster-sg  # Target: Cluster SG
    sourceSecurityGroupIdRef:
      name: eks-node-sg  # Source: Nodes can send
    description: "Nodes → Cluster API (443)"

---
# Worker Node Security Group
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroup
metadata:
  name: eks-node-sg
spec:
  forProvider:
    name: eks-node-sg
    region: us-east-1
    vpcIdRef:
      name: cheap-eks-vpc

---
# Allow cluster to manage nodes (1025-65535)
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroupRule
metadata:
  name: cluster-to-node-ingress
spec:
  forProvider:
    region: us-east-1
    type: ingress
    fromPort: 1025
    toPort: 65535
    protocol: tcp
    securityGroupIdRef:
      name: eks-node-sg  # Target: Node SG
    sourceSecurityGroupIdRef:
      name: eks-cluster-sg  # Source: Cluster can send
    description: "Cluster → Nodes (ephemeral ports)"

---
# Node-to-node communication (all ports)
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroupRule
metadata:
  name: node-to-node-ingress
spec:
  forProvider:
    region: us-east-1
    type: ingress
    fromPort: 0
    toPort: 65535
    protocol: "-1"  # All protocols
    securityGroupIdRef:
      name: eks-node-sg
    sourceSecurityGroupIdRef:
      name: eks-node-sg  # Source: Other nodes
    description: "Nodes ↔ Nodes (pod-to-pod networking)"

---
# Egress: All nodes can reach anywhere
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroupRule
metadata:
  name: node-egress-all
spec:
  forProvider:
    region: us-east-1
    type: egress
    fromPort: 0
    toPort: 0
    protocol: "-1"  # All
    cidrBlocks:
      - 0.0.0.0/0  # Anywhere
    securityGroupIdRef:
      name: eks-node-sg
    description: "Nodes can send anywhere (via NAT)"
```

**Security Group Flow:**

```
Pod in Node 1 → Pod in Node 2
    ↓
kubelet routes to Node 2's private IP
    ↓
Check eks-node-sg ingress rules
    ↓
Match: "node-to-node-ingress (protocol: -1)" ✅
    ↓
Traffic allowed, delivered to Node 2 ✅

Pod in Node → Internet (e.g., image pull)
    ↓
kubelet needs external IP
    ↓
Check eks-node-sg egress rules
    ↓
Match: "node-egress-all (0.0.0.0/0)" ✅
    ↓
Sent to NAT Gateway
    ↓
NAT translates to public IP
    ↓
Internet sees request from NAT's IP ✅
```

### IAM Roles Explained

**IAM Roles** = permissions for services to act

```yaml
# Cluster Role: What control plane can do
apiVersion: iam.aws.m.upbound.io/v1beta1
kind: Role
metadata:
  name: cluster-role
spec:
  forProvider:
    assumeRolePolicyDocument: |
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
          }
        ]
      }

---
# Attach cluster permissions
apiVersion: iam.aws.m.upbound.io/v1beta1
kind: RolePolicyAttachment
metadata:
  name: cluster-policy
spec:
  forProvider:
    roleRef:
      name: cluster-role
    policyArn: "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

---
# Node Role: What EC2 instances (nodes) can do
apiVersion: iam.aws.m.upbound.io/v1beta1
kind: Role
metadata:
  name: node-role
spec:
  forProvider:
    assumeRolePolicyDocument: |
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
          }
        ]
      }

---
# Node can work as Kubernetes node
apiVersion: iam.aws.m.upbound.io/v1beta1
kind: RolePolicyAttachment
metadata:
  name: node-worker-policy
spec:
  forProvider:
    roleRef:
      name: node-role
    policyArn: "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

---
# Node can manage VPC networking (CNI)
apiVersion: iam.aws.m.upbound.io/v1beta1
kind: RolePolicyAttachment
metadata:
  name: node-cni-policy
spec:
  forProvider:
    roleRef:
      name: node-role
    policyArn: "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

---
# Node can pull images from ECR
apiVersion: iam.aws.m.upbound.io/v1beta1
kind: RolePolicyAttachment
metadata:
  name: node-ecr-policy
spec:
  forProvider:
    roleRef:
      name: node-role
    policyArn: "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
```

**Permission Flow:**

```
Pod on Node needs to pull image
    ↓
Pod uses node's IAM role (automatic)
    ↓
Check: "AmazonEC2ContainerRegistryReadOnly" ✅
    ↓
ECR allows image pull ✅

Cluster needs to manage node
    ↓
Check: "AmazonEKSClusterPolicy" ✅
    ↓
Can view/manage node status ✅
```

---

## Deployment Order

**CRITICAL:** Components must be deployed in this specific order!

```
PHASE 1: Foundation (Must exist first)
├─ VPC
├─ Internet Gateway
├─ Public Subnet
├─ Private Subnets (both)
├─ Elastic IP
├─ NAT Gateway
├─ Route Tables (public & private)
├─ Routes (IGW for public, NAT for private)
├─ Route Table Associations (ALL 3 subnets!)  ← YOUR BUG WAS HERE
└─ Security Groups & Rules

PHASE 2: IAM (Must exist before cluster)
├─ Cluster Role + AmazonEKSClusterPolicy
├─ Node Role + 3 policies (Worker, CNI, ECR)
└─ Instance Profile (wraps node role)

PHASE 3: Cluster (Wait for PHASE 1 & 2)
├─ Create Cluster
│  ├─ Waits for VPC/subnets to exist
│  ├─ Waits for security groups
│  ├─ Waits for IAM cluster role
│  └─ Status: ACTIVE (5-10 mins)
└─ Enable private endpoint access ← Critical for private nodes!

PHASE 4: NodeGroup (Wait for cluster ACTIVE)
├─ Create NodeGroup
│  ├─ Waits for cluster endpoint
│  ├─ Waits for subnets to have NAT routes  ← THE FIX!
│  ├─ Launches EC2 instances
│  ├─ Instances bootstrap (10-15 mins)
│  ├─ Nodes join cluster
│  └─ Status: ACTIVE
└─ Nodes start running ✅

PHASE 5: Add-ons (Wait for nodes ACTIVE)
├─ vpc-cni (pod networking)
├─ coredns (DNS)
├─ kube-proxy (service routing)
└─ eks-pod-identity-agent (pod auth)
```

**Parallel vs Sequential:**

```
Safe to deploy in parallel:
✅ VPC + IGW (no dependencies)
✅ Public Subnet + Private Subnets (all reference VPC)
✅ EIP + NAT Gateway (reference subnets/VPC)
✅ Route Tables + Routes (can build in parallel)
✅ Security Groups (independent)
✅ IAM Roles (independent)

MUST be sequential:
❌ Don't create route table associations before route tables exist
❌ Don't create nodes before cluster is ACTIVE
❌ Don't deploy add-ons before nodes are READY
```

---

## Quick Troubleshooting Reference

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| **Nodes NotReady for 20+ mins** | No NAT route in route table | Verify both private subnets have route table association |
| **Nodes can't pull images** | No outbound internet access | Check NAT gateway exists & routes point to it |
| **Nodes can't reach cluster API** | Private endpoint disabled | Add `endpointPrivateAccess: true` to cluster vpcConfig |
| **Pods can't communicate with each other** | Security group missing node-to-node rule | Add rule: protocol=-1, self-referencing |
| **DNS resolution fails** | CoreDNS not ready or nodes can't reach NAT | Check NAT gateway + node security group egress rules |
| **Control plane can't manage nodes** | Cluster SG missing ingress rule | Add rule: 443 ingress from nodes, 1025-65535 from cluster |

---

## Summary Checklist

- [ ] **VPC** created with DNS support enabled
- [ ] **IGW** attached to VPC
- [ ] **3 Subnets** created (1 public, 2 private in different AZs)
- [ ] **EIP** created for NAT Gateway
- [ ] **NAT Gateway** in public subnet with EIP
- [ ] **Route Tables**: 1 for public (IGW), 1 for private (NAT)
- [ ] **Route Table Associations**: Public subnet to public-rt, BOTH private subnets to private-rt
- [ ] **Security Groups**: Cluster SG + Node SG with proper rules
- [ ] **IAM Roles**: Cluster role + Node role with required policies
- [ ] **Cluster**: Created with private/public endpoint access enabled
- [ ] **NodeGroup**: Created with subnets that have NAT routes
- [ ] **Add-ons**: Deployed after nodes are READY

---

## Key Takeaways

1. **NAT Gateway is NOT optional** - it's the only way private nodes reach the internet
2. **Route table associations are the glue** - without them, subnets don't know which route table to use
3. **Both private subnets MUST share the same route table** pointing to NAT (cost-efficient & simpler)
4. **Security groups are stateful** - you only need ingress rules, egress responds automatically
5. **IAM roles are attached to instances** - pods inherit node's permissions
6. **Private endpoint access must be enabled** for nodes in private subnets to reach control plane
7. **Deployment order matters** - deploying out of sequence causes confusing failures

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-13  
**EKS Version:** 1.31.x
