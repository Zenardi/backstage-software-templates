# AWS ECR Repository Management Guide

## Overview

This document provides comprehensive guidance on managing AWS Elastic Container Registry (ECR) repositories provisioned through Crossplane using the Backstage Software Template.

## What is ECR?

Amazon Elastic Container Registry (ECR) is a fully managed container registry that makes it easy to store, manage, share, and deploy container images. This template automates the creation and configuration of ECR repositories using Crossplane, an open-source Kubernetes add-on that enables declarative infrastructure management.

## Resources Created

When you use this template, the following resources are deployed:

### 1. **ECR Repository**
- **Kind**: `Repository` (ecr.aws.m.upbound.io/v1beta1)
- **Purpose**: Stores your container images
- **Configuration**:
  - Image scanning enabled on push
  - AES256 encryption
  - Mutable image tags
  - Automatic tagging with team and system information

### 2. **ECR Lifecycle Policy**
- **Kind**: `LifecyclePolicy` (ecr.aws.m.upbound.io/v1beta1)
- **Purpose**: Automatically manages image retention
- **Default Behavior**: Keeps the last 10 images and expires older ones

## Template Parameters

When creating an ECR repository through Backstage, you will need to provide:

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| **ECR Repository Name** | Unique name for your ECR repository | Yes | `my-app-registry` |
| **AWS Region** | AWS region where the repository will be created | Yes | `us-east-1` |
| **Description** | Brief description of the repository purpose | Yes | `Docker images for my application` |
| **Team Responsible** | Team that owns this resource | Yes | `platform-engineering` |
| **System or Project** | System this resource belongs to | Yes | `spacetech` |
| **Repository URL** | GitHub repository for your application code | Yes | `github.com/org/repo` |
| **Kubernetes Cluster** | Target cluster for ArgoCD deployment | Yes | Select from available clusters |

## How to Use This Template

### Step 1: Access the Template in Backstage
1. Navigate to Backstage and go to the "Create" section
2. Search for "Create AWS ECR Repository"
3. Click on the template

### Step 2: Fill in the Parameters
Complete the form with the required information:
- Choose a descriptive repository name (lowercase, hyphens allowed)
- Select the appropriate AWS region
- Provide a clear description of the repository's purpose
- Select your team and system from the dropdowns
- Point to your GitHub repository

### Step 3: Review and Create
- Review your selections
- Click "Create" to provision the repository

### Step 4: Monitor Deployment
The template will:
1. Create the Crossplane resources
2. Publish them to your GitHub repository
3. Register the catalog entry in Backstage
4. Trigger ArgoCD to sync the resources to your Kubernetes cluster

## Managing Your ECR Repository

### Viewing Your Repository

Once created, you can access your ECR repository in multiple ways:

**Via AWS Console:**
1. Log in to AWS Management Console
2. Navigate to ECR service
3. Find your repository by the name you specified

**Via AWS CLI:**
```bash
aws ecr describe-repositories --region <region> --query "repositories[?repositoryName=='<repo_name>']"
```

**Via kubectl/Crossplane:**
```bash
kubectl get repositories.ecr.aws.m.upbound.io -n crossplane-system
kubectl describe repository <repo_name> -n crossplane-system
```

### Pushing Images

To push Docker images to your ECR repository:

```bash
# Authenticate with ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Tag your image
docker tag my-app:latest <account-id>.dkr.ecr.<region>.amazonaws.com/<repo_name>:latest

# Push the image
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/<repo_name>:latest
```

### Managing Images

**View Images:**
```bash
aws ecr describe-images --repository-name <repo_name> --region <region>
```

**Delete Image:**
```bash
aws ecr batch-delete-image --repository-name <repo_name> --image-ids imageTag=<tag> --region <region>
```

**Scan Images:**
- Image scanning is automatically enabled on push
- Results are available in AWS Console under "Image scanning results"

## Lifecycle Policy Management

### Default Policy
The default lifecycle policy retains the last 10 images:
- Older images are automatically expired (deleted)
- Useful for storage cost optimization
- Prevents accumulation of unused image versions

### Customizing the Policy

To modify the lifecycle policy, edit the `LifecyclePolicy` resource in your deployed Crossplane manifests:

```yaml
policy: |
  {
    "rules": [
      {
        "rulePriority": 1,
        "description": "Keep last X images",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": <X>
        },
        "action": {
          "type": "expire"
        }
      }
    ]
  }
```

Update `<X>` with your desired image count.

## Best Practices

### Security
- ✅ Enable image scanning (enabled by default)
- ✅ Use image tags instead of `latest` when possible
- ✅ Implement repository policies to control access
- ✅ Enable encryption (enabled by default with AES256)
- ✅ Regularly review image scan results

### Cost Optimization
- ✅ Set appropriate lifecycle policies
- ✅ Delete unused images regularly
- ✅ Monitor repository storage usage
- ✅ Use image tags to identify deployable versions

### Operational Excellence
- ✅ Use meaningful repository names
- ✅ Tag images with version numbers or commit SHAs
- ✅ Document image contents in repository description
- ✅ Keep team information up-to-date
- ✅ Monitor push/pull rates

## Troubleshooting

### Repository Not Created
**Issue**: Crossplane resource doesn't create the repository

**Solutions**:
1. Verify AWS credentials are properly configured in the cluster
2. Check the ClusterProviderConfig has access to the specified region
3. Review Crossplane logs: `kubectl logs -n crossplane-system deployment/crossplane`
4. Check the Repository resource status: `kubectl describe repository <repo_name>`

### Cannot Push Images
**Issue**: Docker push fails with authentication error

**Solutions**:
1. Re-authenticate with ECR: `aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com`
2. Verify IAM permissions include `ecr:*` actions
3. Ensure the repository exists and is in the correct region

### Image Scanning Not Working
**Issue**: Images are not being scanned after push

**Solutions**:
1. Verify image scanning is enabled in the Repository resource
2. Check that the image is in a supported format
3. Review CloudWatch logs for scan job failures

### Lifecycle Policy Not Applying
**Issue**: Old images are not being deleted

**Solutions**:
1. Verify the LifecyclePolicy resource exists: `kubectl get lifecyclepolicy -n crossplane-system`
2. Check the policy syntax in the resource
3. Review the policy rules and ensure countNumber is appropriate
4. Wait for the next policy evaluation cycle (can take up to 24 hours)

## Accessing the Repository

### From Your Application
Use the following URI format to reference images in your application manifests:

```
<account-id>.dkr.ecr.<region>.amazonaws.com/<repo_name>:<tag>
```

Example:
```yaml
image: 123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:v1.0.0
```

## Integration with CI/CD

### GitHub Actions
Use the ECR URI in your GitHub Actions workflows:

```yaml
- name: Build and Push Image
  run: |
    aws ecr get-login-password --region ${{ env.AWS_REGION }} | docker login --username AWS --password-stdin ${{ env.ECR_REGISTRY }}
    docker build -t ${{ env.ECR_REGISTRY }}/${{ env.REPO_NAME }}:${{ github.sha }} .
    docker push ${{ env.ECR_REGISTRY }}/${{ env.REPO_NAME }}:${{ github.sha }}
```

## Monitoring and Alerts

### CloudWatch Metrics
ECR publishes metrics to CloudWatch including:
- PutImage count
- PullImage count
- Image scan findings

### Setting Up Alerts
Create CloudWatch alarms for:
- Failed image pushes
- Scan findings (HIGH/CRITICAL severity)
- Unusual image pull patterns

## Cleanup and Deletion

### Delete Repository
When you no longer need the repository:

1. Remove the Crossplane resources from your Git repository
2. ArgoCD will automatically delete the ECR repository and lifecycle policy
3. Any remaining images will be deleted (this is permanent)

**Warning**: Deleting an ECR repository is irreversible. Ensure all images have been backed up if needed.

## Additional Resources

- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Crossplane Provider AWS Documentation](https://marketplace.upbound.io/providers/upbound/provider-aws/)
- [Backstage Software Templates Guide](https://backstage.io/docs/features/software-templates)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## Support

For issues or questions regarding:
- **Backstage Template**: Contact your platform engineering team
- **AWS ECR**: Refer to AWS support or documentation
- **Crossplane**: Check the Crossplane community resources

---

**Last Updated**: January 2026  
**Maintained By**: Platform Engineering Team
