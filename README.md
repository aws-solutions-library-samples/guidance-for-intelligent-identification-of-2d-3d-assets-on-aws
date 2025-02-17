# Guidance for AIML-powered 2D/3D Asset Identification and Management

## Table of Contents

1. [Overview](#overview)
   - [Key Features](#key-features)
   - [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
   - [Operating System](#operating-system)
   - [Tools Required](#tools-required)
   - [AWS Account Requirements](#aws-account-requirements)
3. [Deployment Steps](#deployment-steps)
4. [Deployment Validation](#deployment-validation)
   - [Outputs to Verify](#outputs-to-verify)
5. [Running the Guidance](#running-the-guidance)
   - [Expected Behavior](#expected-behavior)
   - [Outputs](#outputs)
6. [Cost](#cost)
7. [Next Steps](#next-steps)
8. [Cleanup](#cleanup)
9. [FAQ, known issues, additional considerations, and limitations](#faq-known-issues-additional-considerations-and-limitations)
    - [Known Issues](#known-issues)
10. [Notices](#notices)

## Overview 

This solution provides an automated pipeline for asset identification and management, designed specifically for game studios and traditional media industries. By leveraging AWS services, this solution allows users to process, store, and analyze both 2D and 3D assets efficiently and securely. While tailored to game studios, the solution's flexibility makes it applicable to other industries requiring robust asset management workflows.

### Key Features:
- Automated handling of asset ingestion, analysis, and metadata extraction.
- Integration with AWS services like [S3](https://aws.amazon.com/s3/), [Lambda](https://aws.amazon.com/pm/lambda/), and [DynamoDB](https://aws.amazon.com/dynamodb/) to provide a scalable and reliable architecture.
- Designed to support both 2D and 3D assets, making it versatile for different types of media.
- Fully automated workflow after deployment, requiring no additional manual intervention.

### Architecture Overview:
The solution leverages AWS’s serverless capabilities to create a highly scalable, cost-effective pipeline. Major components include:
- **Amazon S3**: For asset storage and logging.
- **AWS Lambda**: For processing assets and invoking analysis tasks.
- **Amazon DynamoDB**: For storing asset metadata.
- **Amazon Rekognition** (optional): For advanced asset analysis.

![Architecture Diagram](./assets/ArchitectureDiagram.png)

---

## Prerequisites 

### Operating System 

This deployment is optimized to work best on **Amazon Linux 2**. Deployment on other operating systems may require additional steps.

### Tools Required:
- [**AWS CLI**](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html): Ensure it is installed and configured with access to your AWS account.
- [**AWS SAM CLI**](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html): For packaging and deploying the serverless application.
- [**Node.js**](https://nodejs.org/en/download): Required for developing and testing Lambda functions locally.

### AWS Account Requirements:
- Ensure your AWS account has sufficient permissions to create and manage the following resources:
  - Amazon S3 buckets
  - AWS Lambda functions
  - Amazon DynamoDB tables
  - IAM roles

> Note: No additional resources need to be created manually beyond setting up the required AWS IAM role for deployment.

---

## Deployment Steps 

1. **Clone the Repository**:
   Clone the repository to your local machine.
   ```bash
   git clone <repository-url>
   cd guidance-for-aiml-powered-2d-3d-asset-identification-and-management
   ```

2. **Install AWS SAM CLI**:
   Ensure that the AWS SAM CLI is installed and functioning:
   ```bash
   sam --version
   ```

3. **Package the Application**:
   Package the solution using the SAM CLI. This will upload your Lambda function code to an S3 bucket.
   ```bash
   sam package \
       --template-file deployment/template.yaml \
       --s3-bucket <your-deployment-bucket> \
       --output-template-file deployment/packaged-template.yaml
   ```

4. **Deploy the Application**:
   Deploy the solution to your AWS account using SAM CLI:
   ```bash
   sam deploy \
       --template-file deployment/packaged-template.yaml \
       --stack-name <your-stack-name> \
       --capabilities CAPABILITY_IAM
   ```

Replace `<your-deployment-bucket>` and `<your-stack-name>` with appropriate values.

---

## Deployment Validation 

### Outputs to Verify:
- **S3 Buckets**: Ensure the specified asset storage and logging buckets are created.
- **Lambda Functions**: Verify that the Lambda functions (e.g., `processImage`, `processObject`, `handleLabels`) are deployed.
- **DynamoDB Table**: Confirm the presence of the metadata table in DynamoDB.
- **CloudFormation Stack**: Check the stack status in the AWS CloudFormation console to ensure it shows `CREATE_COMPLETE`.

---

## Running the Guidance 

### Expected Behavior:
Once deployed, the solution operates automatically, requiring no manual intervention:
1. **Asset Upload**:
   - Upload 2D or 3D assets to the designated S3 bucket.
2. **Automated Processing**:
   - Lambda functions will automatically process the assets, analyze their metadata, and store the results in DynamoDB.
3. **Logging**:
   - Logs for each operation are stored in the logging bucket and accessible via CloudWatch.

### Outputs:
- **Metadata**: Extracted and stored in DynamoDB.
- **Processed Assets**: Accessible in the S3 bucket.

---

## Cost 

Based on the [AWS Pricing Calculator](https://calculator.aws/), the estimated monthly cost for this solution is **$16.48**, which primarily includes:

| Service  | Reason | Cost |
| ------------- | ------------- | ------------- |
| Rekognition Image API | 16,000 API calls for label detection. This is the dominant cost factor in the solution. | $16.00 per month (97% of total costs) |
| DynamoDB On-Demand Capacity | 1 GB of storage with minimal read/write operations. | $0.26 per month (1.6% of total costs) |
| S3 Storage and Requests | 1 GB of storage and 20,000 PUT/COPY/POST requests. | $0.12 per month (0.7% of total costs) |
| Data Transfer Costs | 5 GB inbound and 5 GB outbound data transfer. | $0.10 per month (0.6% of total costs) | 
||| **$16.48** |

---

## Next Steps 

- Extend the solution to include additional analysis capabilities, such as custom ML models or other [AWS AI services](https://aws.amazon.com/ai/generative-ai/).
- Integrate with external content management systems (CMS) or game engines for seamless asset management.

---

## Cleanup 

To avoid incurring unnecessary costs, delete the resources when they are no longer needed:

1. **Delete the CloudFormation Stack**:
   Use the AWS CLI to delete the stack and all associated resources:
   ```bash
   aws cloudformation delete-stack --stack-name <your-stack-name>
   ```

2. **Empty S3 Buckets**:
   Ensure that all S3 buckets created by the solution are emptied before deletion:
   ```bash
   aws s3 rm s3://<your-bucket-name> --recursive
   ```

3. **Verify Deletion**:
   Confirm that all resources (S3 buckets, Lambda functions, DynamoDB tables) have been deleted.

---

## FAQ, known issues, additional considerations, and limitations

### Known Issues
- Ensure all regions are supported by the services in this solution.
- Verify IAM permissions to avoid deployment errors.

---

## Notices 

Customers are responsible for making their own independent assessment of the information in this Guidance. This Guidance: (a) is for informational purposes only, (b) represents AWS current product offerings and practices, which are subject to change without notice, and (c) does not create any commitments or assurances from AWS and its affiliates, suppliers, or licensors. AWS products or services are provided “as is” without warranties, representations, or conditions of any kind, whether express or implied. AWS responsibilities and liabilities to its customers are controlled by AWS agreements, and this Guidance is not part of, nor does it modify, any agreement between AWS and its customers.

