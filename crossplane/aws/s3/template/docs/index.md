# How to operate a Crossplane resource

This guide outlines the steps to operate a Crossplane resource, specifically an AWS S3 Bucket, using the provided template.

## Prerequisites

Before you begin, ensure you have the following:

1.  **Kubernetes Cluster:** A running Kubernetes cluster.
2.  **Crossplane Installation:** Crossplane CRDs and the AWS provider installed on your Kubernetes cluster. You can install Crossplane and its AWS provider using Helm:

    ```bash
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm repo update
    helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace
    helm install crossplane-provider-aws crossplane-stable/provider-aws --namespace crossplane-system
    ```

3.  **AWS Credentials:** Configure your AWS credentials as a Kubernetes secret. This secret will be referenced by the `ProviderConfig`.

    First, ensure you have your AWS access key ID and secret access key. You can set them as environment variables:

    ```bash
    export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
    ```

    Then, create the Kubernetes secret:

    ```bash
    kubectl create secret generic aws-secret \
      --namespace=crossplane-system \
      --from-literal=credentials="[default]
    aws_access_key_id=$AWS_ACCESS_KEY_ID
    aws_secret_access_key=$AWS_SECRET_ACCESS_KEY"
    ```

4.  **Cluster ProviderConfig:** Create a `ProviderConfig` resource that references your AWS credentials. This tells Crossplane how to authenticate with AWS.

    ```yaml
    apiVersion: aws.upbound.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: default
    spec:
      credentials:
        source: Secret
        secretRef:
          namespace: crossplane-system
          name: aws-secret
          key: credentials
    ```

    Apply this configuration to your cluster:

    ```bash
    kubectl apply -f provider-config.yaml
    ```