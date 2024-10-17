# Cargar las variables de entorno desde el archivo .env
source .env

aws ec2 create-launch-template \
    --launch-template-name my-launch-template \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\":\"$IMAGE_ID\",
        \"InstanceType\":\"t2.micro\",
        \"KeyName\":\"$KEY_NAME\",
        \"SecurityGroupIds\":[\"$SECURITY_GROUP_IDS\"],
        \"TagSpecifications\":[
            {
                \"ResourceType\":\"instance\",
                \"Tags\":[
                    {\"Key\":\"Name\",\"Value\":\"MyAutoScalingInstance\"}
                ]
            }
        ]
    }" \
