import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocument } from "@aws-sdk/lib-dynamodb";
import { S3 } from "@aws-sdk/client-s3";

const AWS_REGION = process.env.AWS_REGION || 'us-west-2';
const DYNAMODB_TABLE_NAME = process.env.DYNAMODB_TABLE_NAME;

if (!DYNAMODB_TABLE_NAME) {
    throw new Error("DYNAMODB_TABLE_NAME environment variable is not set.");
}

const dynamodbClient = new DynamoDBClient({ region: AWS_REGION });
const ddbDocClient = DynamoDBDocument.from(dynamodbClient);
const s3 = new S3();

export const handler = async (event, context) => {
    console.log('Lambda function triggered with event:', JSON.stringify(event, null, 2));

    try {
        for (const record of event.Records) {
            const bucketName = record.s3.bucket.name;
            const key = record.s3.object.key;

            console.log(`Processing object: ${key}`);

            if (key.endsWith('.fbx')) {
                const folderName = key.split('/').slice(0, -1).join('/');

                if (folderName.trim() === '') {
                    console.log(`Skipping ${key} as the folder name is empty.`);
                    continue;
                }

                const pngTags = await getTagsFromPNGs(bucketName, folderName);
                const metadata = await s3.headObject({ Bucket: bucketName, Key: key }).catch(error => {
                    console.error(`Error fetching metadata for ${key}:`, error);
                    throw error;
                });

                const dynamodbData = {
                    FolderID: folderName,
                    url: `https://${bucketName}.s3.amazonaws.com/${key}`,
                    size: metadata.ContentLength,
                    lastModified: metadata.LastModified.toISOString(),
                    tags: pngTags // This will now be a map
                };

                await ddbDocClient.put({
                    TableName: DYNAMODB_TABLE_NAME,
                    Item: dynamodbData
                });

                console.log(`Metadata for ${key} stored in DynamoDB.`);
            }
        }

        return {
            statusCode: 200,
            body: 'Function executed successfully.'
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: 'An error occurred.'
        };
    }
};

async function getTagsFromPNGs(bucketName, folderName) {
    console.log(`Listing PNG files in folder: ${folderName}`);

    const tagsMap = {}; // This will store each tag as a key-value pair

    const listParams = {
        Bucket: bucketName,
        Prefix: `${folderName}/`
    };

    const objects = await s3.listObjectsV2(listParams).catch(error => {
        console.error(`Error listing objects in ${folderName}:`, error);
        throw error;
    });

    const pngObjects = objects.Contents ? objects.Contents.filter(obj => obj.Key.endsWith('.png')) : [];

    for (const pngObject of pngObjects) {
        const response = await s3.getObjectTagging({
            Bucket: bucketName,
            Key: pngObject.Key
        }).catch(error => {
            console.error(`Error fetching tags for ${pngObject.Key}:`, error);
            throw error;
        });

        // Map each tag's Key to its Value
        response.TagSet.forEach(tag => {
            tagsMap[tag.Key] = tag.Value;
        });
    }

    // Return the map of tags
    return tagsMap;
}