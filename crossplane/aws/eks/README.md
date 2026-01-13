# AWS EKS Cluster - Backstage Template

A production-ready Backstage template for deploying fully-managed Amazon EKS clusters using Crossplane. This template automates the creation of secure, multi-AZ Kubernetes clusters with optimized networking, security, and cost configurations.

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Using the Template](#using-the-template)
5. [Template Parameters](#template-parameters)
6. [Resource Architecture](#resource-architecture)
7. [Managing Crossplane Resources](#managing-crossplane-resources)
8. [Troubleshooting](#troubleshooting)
9. [Cost Optimization](#cost-optimization)
10. [Advanced Configuration](#advanced-configuration)
11. [Cleanup](#cleanup)

---

## Overview

This Backstage template deploys a complete AWS EKS cluster using Crossplane providers. Instead of managing infrastructure manually or writing CloudFormation templates, users can self-service EKS clusters through the Backstage UI.

**What Gets Created:**
- ✅ VPC with public and private subnets across 2 availability zones
- ✅ NAT Gateway for private subnet egress
- ✅ Internet Gateway for public internet access
- ✅ EKS cluster with configurable Kubernetes version
- ✅ Node group with auto-scaling and Spot instance support
- ✅ Security groups with proper ingress/egress rules
- ✅ IAM roles for cluster and node permissions
- ✅ EKS add-ons: VPC CNI, CoreDNS, Kube-Proxy, Pod Identity Agent
- ✅ Backstage catalog entry for cluster management

**Deployment Time:** 15-25 minutes (most time is EKS/EC2 provisioning)

---

## Features

### 🔒 Security
- **Private Node Subnets:** Worker nodes in private subnets with no direct internet
- **Security Groups:** Strict ingress/egress rules for cluster-node communication
- **IAM Roles:** Least-privilege permissions for cluster and nodes
- **Multi-AZ:** Resources distributed across 2 availability zones for HA

### 🚀 Performance
- **Private Endpoint Access:** Cluster accessible from within VPC
- **Public Endpoint Access:** Cluster accessible from internet (configurable)
- **VPC CNI:** AWS-native networking for pod-to-pod communication
- **Kube-Proxy:** Efficient service routing

### 💰 Cost Optimization
- **Spot Instances:** 70% cheaper than on-demand
- **Bottlerocket OS:** Minimal OS, auto-updating, 50% less resources
- **Instance Type Fallbacks:** Automatically tries alternative types if Spot capacity unavailable
- **Single NAT Gateway:** Shared across both private subnets (vs one per AZ)
- **t3.medium as Default:** Most cost-effective general-purpose instance

### 🎛️ Flexibility
- **Customizable Kubernetes Version:** Choose 1.31, 1.32, 1.33, or 1.34
- **Region Selection:** Deploy to any AWS region
- **AMI Type:** Bottlerocket or AL2 Linux options
- **Capacity Type:** Spot or On-Demand instances
- **Node Scaling:** Configure desired, min, and max sizes

### 📊 Observability
- **Backstage Integration:** Cluster appears in catalog with metadata
- **Direct AWS Console Link:** Quick access to cluster in AWS Console
- **ArgoCD Integration:** Links to GitOps deployments
- **Resource Tagging:** All resources tagged for cost tracking

---

## Prerequisites

### Required Infrastructure
- **Crossplane Installation:** Must be installed in your cluster with AWS providers
- **AWS Providers:** `upbound-provider-aws-eks`, `upbound-provider-aws-ec2`, `upbound-provider-aws-iam` (v2.3.0+)
- **AWS Account:** With sufficient IAM permissions to create EKS, EC2, VPC, IAM resources
- **AWS Credentials:** Configured in Crossplane `ClusterProviderConfig`

### Backstage Setup
- **Backstage Instance:** Running 1.0+
- **GitHub Integration:** For repository creation
- **Scaffolder Plugin:** Enabled for template execution

### Permission Requirements
The AWS IAM user/role must have permissions for:
```
eks:CreateCluster
eks:CreateNodegroup
eks:DescribeCluster
eks:DescribeNodegroup
eks:CreateAddon
ec2:CreateVpc
ec2:CreateSubnet
ec2:CreateSecurityGroup
ec2:CreateNatGateway
ec2:CreateInternetGateway
ec2:CreateRouteTable
ec2:CreateRoute
iam:CreateRole
iam:AttachRolePolicy
```

---

## Using the Template

### Step 1: Access the Template

In Backstage, navigate to:
```
Create → AWS EKS Cluster
```

Or directly: `https://your-backstage.com/create?templateName=crossplane-aws-eks-cluster`

### Step 2: Fill in Cluster Details

**Required Fields:**

| Field | Example | Options |
|-------|---------|---------|
| **Cluster Name** | `my-app-cluster` | Any DNS-valid name |
| **Application Description** | `Production EKS for my-app` | Free text |
| **Team** | `Platform Engineering` | Select from Backstage teams |
| **System** | `Infrastructure` | Select from Backstage systems |
| **Kubernetes Version** | `1.34` | 1.31, 1.32, 1.33, 1.34 |
| **AWS Region** | `us-east-1` | us-east-1, eu-west-1, ap-northeast-1, etc |

### Step 3: Configure Node Group

| Field | Default | Options |
|-------|---------|---------|
| **AMI Type** | `BOTTLEROCKET_x86_64` | BOTTLEROCKET_x86_64, AL2_x86_64, AL2_ARM_64 |
| **Instance Type** | `t3.medium` | t3.medium, t3.large, m5.large, etc |
| **Capacity Type** | `SPOT` | SPOT, ON_DEMAND |
| **Desired Size** | `2` | 1-10 |
| **Min Size** | `1` | 1-5 |
| **Max Size** | `3` | 2-10 |

### Step 4: Choose Repository

Select or create a GitHub repository for infrastructure-as-code storage.

### Step 5: Review & Create

Backstage displays a summary of all parameters. Click **Create** to start provisioning.

### Step 6: Monitor Progress

Backstage shows:
1. ✓ Template fetched
2. ✓ Repository created
3. ✓ Resources registered in catalog
4. ✓ Links to GitHub repo and catalog entry

**Full deployment takes 15-25 minutes.** Watch progress in Crossplane:

```bash
# Monitor resource creation
kubectl get cluster.eks.aws.m.upbound.io -n eks-demo -w
kubectl get nodegroup.eks.aws.m.upbound.io -n eks-demo -w

# Check for errors
kubectl describe cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo
kubectl logs -n crossplane-system -l app.kubernetes.io/name=crossplane-provider-aws-eks
```

---

## Template Parameters

### Cluster Details Section

#### `cluster_name` (String, Required)
- **Purpose:** Unique identifier for the cluster and all related resources
- **Example:** `production-api`, `staging-web`, `data-pipeline`
- **Validation:** DNS-1123 subdomain (lowercase letters, numbers, hyphens)
- **Impact:** Used in VPC name, security groups, route tables, NAT gateway, node group
- **Naming Pattern:** `<cluster_name>-vpc`, `<cluster_name>-nodegroup`, etc.

#### `app_description` (String, Required)
- **Purpose:** Human-readable description for team members
- **Example:** `Production EKS cluster for microservices`, `Development cluster for testing`
- **Impact:** Appears in Backstage catalog and AWS tags
- **Max Length:** 255 characters

#### `team` (EntityPicker, Required)
- **Purpose:** Assign ownership for Backstage RBAC and tracking
- **Example:** `Platform Engineering`, `DevOps Team`
- **Impact:** Sets metadata ownership for monitoring and cost allocation
- **Filter:** Only shows Group entities with type: team

#### `system` (EntityPicker, Required)
- **Purpose:** Organizational system assignment
- **Example:** `Infrastructure`, `Data Platform`, `Customer APIs`
- **Impact:** Groups related resources in Backstage architecture view
- **Filter:** Only shows Group entities with type: system

#### `kubernetes_version` (Enum, Required)
- **Purpose:** EKS cluster Kubernetes version
- **Options:** `1.31`, `1.32`, `1.33`, `1.34`
- **Default:** `1.34`
- **Impact:** All nodes run this version; add-ons versioned accordingly
- **Upgrade Path:** Nodes can be upgraded later via Crossplane updates

#### `eks_region` (Enum, Required)
- **Purpose:** AWS region for all resources
- **Options:** us-east-1, us-east-2, us-west-1, us-west-2, eu-west-1, eu-central-1, ap-southeast-1, ap-southeast-2, ap-northeast-1
- **Default:** `us-east-1`
- **Impact:** VPC, subnets, NAT gateway, instances all created in this region
- **Availability Zones:** Automatically uses `{region}a` and `{region}b`

### Node Group Configuration Section

#### `ami_type` (Enum, Required)
- **Purpose:** Operating system for worker nodes
- **Options:**
  - `BOTTLEROCKET_x86_64` - Minimal Linux, auto-updating (recommended)
  - `AL2_x86_64` - Amazon Linux 2, x86
  - `AL2_ARM_64` - Amazon Linux 2, ARM (Graviton)
  - `BOTTLEROCKET_ARM_64` - Bottlerocket, ARM
- **Default:** `BOTTLEROCKET_x86_64`
- **Impact:** Affects node startup time, security patches, resource usage
- **Bottlerocket Benefits:** 50% less storage, faster boot, auto-updates

#### `instance_type` (Enum, Required)
- **Purpose:** Primary EC2 instance type for nodes
- **Options:** t3.medium, t3.large, t3.xlarge, t3.2xlarge, m5.large, m5.xlarge, m5.2xlarge
- **Default:** `t3.medium`
- **Fallbacks:** Automatically tries t3a.medium, t2.medium, m5.large if primary unavailable
- **Impact:** CPU/memory per node, hourly cost
- **Recommendation:** t3.medium for dev/staging, m5.large+ for production

#### `capacity_type` (Enum, Required)
- **Purpose:** Instance purchasing option
- **Options:**
  - `SPOT` - Up to 70% cheaper but can be interrupted
  - `ON_DEMAND` - Stable pricing, always available
- **Default:** `SPOT`
- **Impact:** Cost vs. availability tradeoff
- **Use Cases:**
  - SPOT: Dev/staging, batch jobs, fault-tolerant workloads
  - ON_DEMAND: Production stateful services, critical infrastructure

#### `desired_size` (Integer, Required)
- **Purpose:** Target number of running nodes
- **Range:** 1-10
- **Default:** `2`
- **Impact:** Current node count; cluster will scale to this after creation
- **Example:** Create with desired_size=2, nodes scale up/down to this target

#### `min_size` (Integer, Required)
- **Purpose:** Minimum nodes for autoscaling
- **Range:** 1-5
- **Default:** `1`
- **Impact:** Cluster never scales below this
- **Use Case:** Ensure always-available capacity

#### `max_size` (Integer, Required)
- **Purpose:** Maximum nodes for autoscaling
- **Range:** 2-10
- **Default:** `3`
- **Impact:** Cluster never scales above this (cost control)
- **Example:** Set max_size=5 to prevent runaway costs

### Repository Section

#### `repoUrl` (RepoUrlPicker, Required)
- **Purpose:** GitHub repository destination
- **Format:** `github.com/owner/repo-name`
- **Impact:** Infrastructure code stored here for GitOps/auditing
- **Permissions:** Backstage must have write access to organization

---

## Resource Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│         AWS Region (e.g., us-east-1)                        │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  VPC: 10.0.0.0/16 (cluster-name-vpc)                │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ PUBLIC SUBNET 1 (10.0.1.0/24)                 │  │   │
│  │  │ Availability Zone: region-a                   │  │   │
│  │  │ ┌──────────────────┐                          │  │   │
│  │  │ │ NAT Gateway      │ ← Elastic IP             │  │   │
│  │  │ │ (cluster-nat-gw) │   (52.xxx.xxx.xxx)       │  │   │
│  │  │ └──────────────────┘                          │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │         ↑ (IGW route: 0.0.0.0/0)                     │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ PRIVATE SUBNET 1 (10.0.2.0/24)                │  │   │
│  │  │ Availability Zone: region-a                   │  │   │
│  │  │ ┌──────────────┐  ┌──────────────┐            │  │   │
│  │  │ │  Worker Node │  │  Worker Node │            │  │   │
│  │  │ │  (10.0.2.x)  │  │  (10.0.2.y)  │            │  │   │
│  │  │ └──────────────┘  └──────────────┘            │  │   │
│  │  │ Route: 0.0.0.0/0 → NAT Gateway                │  │   │
│  │  │ Security Group: cluster-name-node-sg          │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ PRIVATE SUBNET 2 (10.0.3.0/24)                │  │   │
│  │  │ Availability Zone: region-b                   │  │   │
│  │  │ ┌──────────────┐  ┌──────────────┐            │  │   │
│  │  │ │  Worker Node │  │  Worker Node │            │  │   │
│  │  │ │  (10.0.3.x)  │  │  (10.0.3.y)  │            │  │   │
│  │  │ └──────────────┘  └──────────────┘            │  │   │
│  │  │ Route: 0.0.0.0/0 → NAT Gateway (same as Subnet 1) │   │
│  │  │ Security Group: cluster-name-node-sg          │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ EKS CONTROL PLANE                              │  │   │
│  │  │ ├─ Private Endpoint: ✓ Enabled                 │  │   │
│  │  │ ├─ Public Endpoint: ✓ Enabled                  │  │   │
│  │  │ ├─ API Server (443)                            │  │   │
│  │  │ ├─ etcd (State DB)                             │  │   │
│  │  │ └─ Security Group: cluster-name-cluster-sg     │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
             ↑ (Internet Gateway)
      ┌──────────────┐
      │  Internet    │
      └──────────────┘
```

### Resource Dependencies

```
Order of Creation:
1. VPC (foundation)
2. IGW, Subnets (network)
3. EIP, NAT Gateway (egress)
4. Route Tables, Routes (routing)
5. Security Groups (access control)
6. IAM Roles (permissions)
7. EKS Cluster (control plane)
8. NodeGroup (worker nodes)
9. Add-ons (system pods)
```

---

## Managing Crossplane Resources

### View Cluster Status

**Check Cluster:**
```bash
kubectl get cluster.eks.aws.m.upbound.io -n eks-demo -o wide
kubectl describe cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo
```

**Expected Output:**
```
SYNCED   READY   EXTERNAL-NAME      STATUS
True     True    my-app-cluster     ACTIVE
```

### View NodeGroup Status

**Check Nodes:**
```bash
kubectl get nodegroup.eks.aws.m.upbound.io -n eks-demo -o wide
kubectl describe nodegroup.eks.aws.m.upbound.io <cluster-name>-nodegroup -n eks-demo
```

**Expected Output:**
```
SYNCED   READY   EXTERNAL-NAME             STATUS
True     True    my-app-cluster-nodegroup  ACTIVE
```

### Connect to Cluster

**Get Kubeconfig:**
```bash
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region <region>
```

**Switch Context:**
```bash
kubectl config use-context arn:aws:eks:<region>:<account>:cluster/<cluster-name>
```

**Verify Access:**
```bash
kubectl get nodes
kubectl get pods -A
```

### Scale NodeGroup

**Edit Desired Size:**
```bash
kubectl patch nodegroup <cluster-name>-nodegroup \
  -n eks-demo \
  --type merge \
  -p '{"spec":{"forProvider":{"scalingConfig":{"desiredSize":4}}}}'
```

**Monitor Scaling:**
```bash
watch -n 5 'kubectl get nodes'
```

### Update Kubernetes Version

**Edit Cluster Version:**
```bash
kubectl patch cluster.eks.aws.m.upbound.io <cluster-name> \
  -n eks-demo \
  --type merge \
  -p '{"spec":{"forProvider":{"version":"1.34"}}}'
```

**Monitor Update (5-15 mins):**
```bash
watch -n 10 'kubectl get cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo'
```

### Add/Remove Add-ons

**Deploy Additional Add-ons:**
```yaml
apiVersion: eks.aws.m.upbound.io/v1beta1
kind: Addon
metadata:
  name: addon-ebs-csi
spec:
  forProvider:
    region: <region>
    clusterNameRef:
      name: <cluster-name>
    addonName: aws-ebs-csi-driver
    resolveConflictsOnCreate: OVERWRITE
    resolveConflictsOnUpdate: OVERWRITE
```

**Remove Add-on:**
```bash
kubectl delete addon.eks.aws.m.upbound.io addon-ebs-csi -n eks-demo
```

### Monitor Events and Logs

**Resource Events:**
```bash
kubectl describe cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo | tail -20
```

**Provider Logs:**
```bash
kubectl logs -n crossplane-system -l app.kubernetes.io/name=crossplane-provider-aws-eks -f
```

**Common Events:**
- `CreatedExternalResource` - Cluster creation started
- `AsyncCreateSuccess` - Creation completed
- `LastAsyncOperationSynced` - No pending operations

---

## Troubleshooting

### Issue: Nodes Not Joining Cluster

**Symptoms:** NodeGroup stuck in "Creating" state for 20+ minutes

**Root Cause:** No NAT gateway route in private subnet

**Solution:**
```bash
# Verify route table has NAT route
aws ec2 describe-route-tables --region <region> \
  --query 'RouteTables[*].[RouteTableId, Associations[*].SubnetId]'

# Should show 0.0.0.0/0 → nat-xxxxx for both private subnets
```

**Prevention:** Template includes both route table associations

### Issue: Nodes NotReady

**Symptoms:** Nodes appear but stuck in NotReady

**Root Cause:** Security group ingress rules missing

**Solution:**
```bash
# Check security group rules
aws ec2 describe-security-groups --region <region> \
  --group-names <cluster-name>-node-sg \
  --query 'SecurityGroups[0].IpPermissions'

# Must include:
# - 443 ingress from cluster-sg
# - 1025-65535 ingress from cluster-sg
# - All egress (0.0.0.0/0)
```

### Issue: Cannot Access Cluster

**Symptoms:** `kubectl: error connecting to the server`

**Root Cause:** Endpoint not accessible or wrong IAM permissions

**Solution:**
```bash
# Verify cluster endpoint
kubectl cluster-info

# Check IAM permissions
aws eks describe-cluster --name <cluster-name> --region <region>

# Verify kubeconfig has correct IAM principal
aws sts get-caller-identity
```

### Issue: Add-ons Stuck in Creating

**Symptoms:** Add-on status shows "Creating" for 10+ minutes

**Root Cause:** Nodes not ready yet

**Solution:**
```bash
# Wait for all nodes to be Ready
kubectl get nodes -w

# Check add-on events
kubectl describe addon.eks.aws.m.upbound.io addon-vpc-cni -n eks-demo
```

### Issue: Terraform/Crossplane Drift

**Symptoms:** External changes made in AWS Console not reflected in Crossplane

**Solution:**
```bash
# Force reconciliation
kubectl delete nodegroup.eks.aws.m.upbound.io <cluster-name>-nodegroup \
  -n eks-demo --grace-period=0 --force

# Reapply resource
kubectl apply -f eks.yaml -n eks-demo

# Monitor
kubectl get nodegroup.eks.aws.m.upbound.io -w
```

---

## Cost Optimization

### Current Strategy

**Monthly Cost Estimate (us-east-1, 2x t3.medium Spot):**

| Component | Cost | Notes |
|-----------|------|-------|
| 2x t3.medium (Spot) | ~$10 | 70% savings vs ON_DEMAND |
| NAT Gateway | ~$30 | Data processing charges apply |
| EBS (root volumes) | ~$4 | 20GB per node |
| **Total** | **~$44/month** | Small dev cluster |

### Ways to Reduce Further

1. **Single Node Cluster (Dev)**
   ```yaml
   desiredSize: 1
   minSize: 1
   maxSize: 2
   ```
   - Saves ~50% node costs
   - Not HA, suitable for development only

2. **On-Demand (If Spot Unreliable)**
   ```yaml
   capacityType: SPOT  # or ON_DEMAND
   ```
   - Trade off cost for stability
   - ON_DEMAND: ~$35/month per t3.medium

3. **Smaller Instance Type (t3.small)**
   ```yaml
   instanceType: t3.small  # 2 CPU, 2GB RAM
   ```
   - Not recommended for production
   - Limited for container workloads

4. **Remove Unused Add-ons**
   ```bash
   kubectl delete addon addon-coredns -n eks-demo
   ```
   - Most add-ons are minimal cost
   - Not recommended

### Ways to Increase Reliability

1. **3-Node Cluster (Production)**
   ```yaml
   desiredSize: 3
   minSize: 2
   maxSize: 5
   ```
   - Better fault tolerance
   - Increased cost: ~$65/month

2. **Larger Instances**
   ```yaml
   instanceType: m5.large  # 2 CPU, 8GB RAM
   ```
   - Better for complex workloads
   - Increased cost: ~$50/month per instance

3. **Mixed Capacity Types**
   - Use Spot + On-Demand mix
   - Requires Karpenter setup (not in template)

---

## Advanced Configuration

### Enable Public IP on Nodes (NOT RECOMMENDED)

Edit `networking.yaml` before deploying:
```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: Subnet
metadata:
  name: private-subnet-1
spec:
  forProvider:
    mapPublicIpOnLaunch: true  # NOT recommended for nodes
```

### Enable NAT Gateway per AZ (HIGH COST)

Edit `networking.yaml`:
```yaml
# Create second NAT Gateway for Subnet 2
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: NATGateway
metadata:
  name: ${{ values.cluster_name }}-nat-gw-2
spec:
  forProvider:
    subnetIdRef:
      name: public-subnet-2  # Second subnet
```

Cost impact: +$30/month (NAT gateway is most expensive component)

### Custom Security Group Rules

Edit `security-groups.yaml` to add ingress from specific IPs:
```yaml
apiVersion: ec2.aws.m.upbound.io/v1beta1
kind: SecurityGroupRule
metadata:
  name: custom-app-ingress
spec:
  forProvider:
    type: ingress
    fromPort: 8080
    toPort: 8080
    protocol: tcp
    cidrBlocks:
      - 203.0.113.0/24  # Your office IP
    securityGroupIdRef:
      name: eks-cluster-sg
```

### Use Different CIDR Block

Edit `networking.yaml` for custom CIDR:
```yaml
cidrBlock: 172.16.0.0/16  # Instead of 10.0.0.0/16
# Update subnet CIDRs accordingly:
# - 172.16.1.0/24 (public)
# - 172.16.2.0/24 (private-1)
# - 172.16.3.0/24 (private-2)
```

---

## Cleanup

### Delete Specific Resources

**Remove NodeGroup Only (keep cluster):**
```bash
kubectl delete nodegroup.eks.aws.m.upbound.io <cluster-name>-nodegroup -n eks-demo
```

**Remove Add-ons Only:**
```bash
kubectl delete addon.eks.aws.m.upbound.io addon-vpc-cni -n eks-demo
kubectl delete addon.eks.aws.m.upbound.io addon-coredns -n eks-demo
kubectl delete addon.eks.aws.m.upbound.io addon-kube-proxy -n eks-demo
kubectl delete addon.eks.aws.m.upbound.io addon-pod-identity -n eks-demo
```

### Delete Entire Cluster

**WARNING:** This destroys all resources including storage

```bash
# Delete from kubectl
kubectl delete cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo

# Monitor deletion (takes 5-10 minutes)
kubectl get cluster.eks.aws.m.upbound.io -w

# Or delete via GitHub
# Remove all .yaml files from repository, commit
```

**Manual Cleanup (if automatic fails):**
```bash
# List resources
kubectl get eks.aws.m.upbound.io -n eks-demo
kubectl get ec2.aws.m.upbound.io -n eks-demo
kubectl get iam.aws.m.upbound.io -n eks-demo

# Delete with finalizers
kubectl patch cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo \
  -p '{"metadata":{"finalizers":[]}}' --type merge

kubectl delete cluster.eks.aws.m.upbound.io <cluster-name> -n eks-demo
```

### Remove from Backstage Catalog

```bash
# Delete catalog entry
kubectl delete component <cluster-name> -n backstage

# Or manually remove from Backstage UI
```

---

## Support & Maintenance

### Getting Help

1. **Check EKS Architecture Guide:** [EKS_ARCHITECTURE_GUIDE.md](EKS_ARCHITECTURE_GUIDE.md)
2. **Check Cluster Status:** [CLUSTER_STATUS.md](CLUSTER_STATUS.md)
3. **Template Conversion Guide:** [TEMPLATE_CONVERSION_SUMMARY.md](TEMPLATE_CONVERSION_SUMMARY.md)

### Known Limitations

- **Spot Instance Interruption:** Nodes may be terminated with 2-minute notice
- **Single NAT Gateway:** Outbound traffic bottleneck for high throughput
- **Manual Upgrades:** EKS cluster and node group versions must be updated via Crossplane
- **Add-on Versions:** Fixed in template; can be customized in YAML

### Future Enhancements

- [ ] Cluster autoscaler integration
- [ ] Advanced networking (CNI alternatives)
- [ ] Monitoring stack (CloudWatch/Prometheus)
- [ ] Multi-region setup
- [ ] GitOps auto-deployment

---

## Related Resources

- **AWS EKS Documentation:** https://docs.aws.amazon.com/eks/
- **Crossplane AWS Provider:** https://doc.crds.dev/github.com/crossplane/provider-aws
- **Backstage Scaffolder:** https://backstage.io/docs/features/software-templates/
- **Kubernetes Best Practices:** https://kubernetes.io/docs/concepts/configuration/overview/

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-13  
**Template Status:** Production Ready  
**Tested On:** EKS 1.31-1.34, Crossplane 1.13+
