#!/usr/bin/env bash
# 2_create_ami.sh
# Cria uma AMI a partir da instância fornecida e espera ela ficar disponível.
# Uso: bash 2_create_ami.sh <instance-id>
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
INSTANCE_ID="${1:-}"
if [ -z "$INSTANCE_ID" ]; then
  if [ -f last_instance.env ]; then
    source last_instance.env
    INSTANCE_ID="${INSTANCE_ID:-}"
  fi
fi
if [ -z "$INSTANCE_ID" ]; then
  echo "Uso: $0 <instance-id>"
  exit 1
fi

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
AMI_NAME="lab-ami-${INSTANCE_ID}-${TIMESTAMP}"

echo "Criando AMI ($AMI_NAME) da instância $INSTANCE_ID..."
IMAGE_ID=$(aws ec2 create-image --region "$AWS_REGION" --instance-id "$INSTANCE_ID" --name "$AMI_NAME" --no-reboot --query 'ImageId' --output text)
echo "ImageId: $IMAGE_ID"

echo "Aguardando AMI ficar 'available' (isso pode levar alguns minutos)..."
aws ec2 wait image-available --region "$AWS_REGION" --image-ids "$IMAGE_ID"

echo "AMI pronta: $IMAGE_ID"
echo "IMAGE_ID=$IMAGE_ID" > last_image.env
echo "AMI_NAME=$AMI_NAME" >> last_image.env
