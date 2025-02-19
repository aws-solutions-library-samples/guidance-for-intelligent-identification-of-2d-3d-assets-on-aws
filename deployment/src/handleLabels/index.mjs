import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { S3Client, GetObjectTaggingCommand } from "@aws-sdk/client-s3";

const dynamoDB = new DynamoDBClient();
const s3 = new S3Client();

export const handler = async (event) => {
    console.log("Event received:", JSON.stringify(event, null, 2));  // Log the entire event for debugging

    const bucketName = event.Records[0].s3.bucket.name;
    const objectKey = event.Records[0].s3.object.key;
    const tableName = process.env.LABEL_DATA_TABLE;

    console.log(`Processing object '${objectKey}' in bucket '${bucketName}'`);
    console.log(`DynamoDB Table Name (from environment): ${tableName}`);

    try {
        // Retrieve tags from the S3 object
        const tagParams = {
            Bucket: bucketName,
            Key: objectKey
        };
        const tagCommand = new GetObjectTaggingCommand(tagParams);
        const tagResponse = await s3.send(tagCommand);

        // Log the tags retrieved from the S3 object
        console.log(`Tags retrieved for '${objectKey}':`, JSON.stringify(tagResponse.TagSet, null, 2));

        // Insert each tag as an item in DynamoDB
        for (const tag of tagResponse.TagSet) {
            const putParams = {
                TableName: tableName,
                Item: {
                    LabelId: { S: `${objectKey}-${tag.Key}` },  // Unique ID for each tag based on object key and tag key
                    ObjectKey: { S: objectKey },
                    BucketName: { S: bucketName },
                    TagKey: { S: tag.Key },
                    TagValue: { S: tag.Value }
                }
            };

            console.log(`Inserting tag '${tag.Key}' with value '${tag.Value}' into DynamoDB`);
            const putCommand = new PutItemCommand(putParams);
            await dynamoDB.send(putCommand);
            console.log(`Successfully added tag '${tag.Key}' to DynamoDB`);
        }

    } catch (error) {
        console.error(`Failed to process tags for file '${objectKey}' in bucket '${bucketName}':`, error);
        throw error;
    }

    console.log(`Processing completed for object '${objectKey}' in bucket '${bucketName}'`);
};