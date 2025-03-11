import { RekognitionClient, DetectLabelsCommand } from "@aws-sdk/client-rekognition";
import { S3Client, CopyObjectCommand, PutObjectTaggingCommand } from "@aws-sdk/client-s3";

const rekognition = new RekognitionClient();
const s3 = new S3Client();

export const handler = async (event) => {
    // Retrieve bucket name and object key from the S3 event
    const bucketName = event.Records[0].s3.bucket.name;
    const objectKey = event.Records[0].s3.object.key;

    const eventName = event.Records[0].eventName;
    console.log(`processImage: Event received: '${eventName}':`);

    try {
        // Configure parameters for Rekognition
        const rekognitionParams = {
            Image: {
                S3Object: {
                    Bucket: bucketName,
                    Name: objectKey
                }
            },
            MaxLabels: 10,
            MinConfidence: 70
        };

        // Attempt to detect labels using Rekognition
        const command = new DetectLabelsCommand(rekognitionParams);
        const response = await rekognition.send(command);

        // Prepare metadata with human-readable names
        const metadata = {};
        response.Labels.forEach(label => {
            metadata[label.Name.replace(/\s+/g, '-')] = `${label.Confidence.toFixed(2)}%`;
        });

        // Log the labels to CloudWatch
        console.log(`Labels for '${objectKey}':`);
        response.Labels.forEach(label => {
            console.log(`- ${label.Name}: ${label.Confidence.toFixed(2)}%`);
        });

        // Copy the object with updated metadata
        const copyParams = {
            Bucket: bucketName,
            CopySource: `${bucketName}/${objectKey}`,
            Key: objectKey,
            Metadata: metadata,
            MetadataDirective: "REPLACE"
        };

        const copyCommand = new CopyObjectCommand(copyParams);
        await s3.send(copyCommand);
        console.log(`Metadata added to '${objectKey}':`, metadata);

        // Prepare tags with label and confidence scores, stripping out % sign
        const tags = response.Labels.slice(0, 10).map(label => ({
            Key: label.Name,
            Value: label.Confidence.toFixed(2) // Remove the '%' to make it a plain text number
        }));

        // Add tags to the S3 object
        const taggingParams = {
            Bucket: bucketName,
            Key: objectKey,
            Tagging: {
                TagSet: tags
            }
        };

        const taggingCommand = new PutObjectTaggingCommand(taggingParams);
        await s3.send(taggingCommand);
        console.log(`Tags added to '${objectKey}':`, tags);

    } catch (error) {
        // Log any Rekognition errors, such as unsupported file types
        console.error(`Error processing file '${objectKey}' from bucket '${bucketName}':`, error);
        
        // Log specific error for unsupported file types
        if (error.name === 'InvalidImageFormatException') {
            console.error(`Unsupported image format for file '${objectKey}'`);
        }
        
        throw error;
    }
};