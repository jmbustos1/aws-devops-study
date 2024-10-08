
#!/bin/bash

# Cargar las variables de entorno desde el archivo .env
source .env

aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME \
  --launch-template LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version=1 \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 1 \
  --vpc-zone-identifier $VPC_ZONE_IDENTIFIER \
  --region $REGION

