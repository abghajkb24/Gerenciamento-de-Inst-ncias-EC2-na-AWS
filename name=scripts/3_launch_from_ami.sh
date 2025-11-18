#!/usr/bin/env bash
# 3_launch_from_ami.sh
# Lança uma instância a partir da AMI criada e verifica o arquivo de teste.
# Uso: bash 3_launch_from_ami.sh <image-id>
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
: "${KEY_NAME:?set KEY_NAME}"
: "${SECURITY_GROUP_ID:?set SECURITY_GROUP_ID}"
: "${SSH_PRIVATE_KEY_PATH:?set SSH_PRIVATE_KEY_PATH}"
: "${INSTANCE_TYPE:=t3.micro}"
IMAGE_ID="${1:-}"
if [ -z "$IMAGE_ID" ]; then
  if [ -f last_image.env ]; then
    source last_image.env
    IMAGE_ID="${IMAGE_ID:-}"
  fi
fi
if [ -z "$IMAGE_ID" ]; then
  echo "Uso: $0 <image-id>"
  exit 1
fi

LAUNCH_ARGS=(--image-id "$IMAGE_ID" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SECURITY_GROUP_ID" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=lab-ec2-from-ami}]")

echo "Lançando instância a partir da AMI $IMAGE_ID..."
NEW_INSTANCE_ID=$(aws ec2 run-instances --region "$AWS_REGION" "${LAUNCH_ARGS[@]}" --query 'Instances[0].InstanceId' --output text)
echo "Instância: $NEW_INSTANCE_ID"

echo "Aguardando running..."
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$NEW_INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$NEW_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "IP público: $PUBLIC_IP"

echo "Aguardando SSH..."
for i in {1..30}; do
  if nc -z -w 2 "$PUBLIC_IP" 22 2>/dev/null; then
    echo "SSH disponível"
    break
  fi
  sleep 6
done

echo "Conectando e verificando /home/ec2-user/labfile.txt..."
ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY_PATH" ec2-user@"$PUBLIC_IP" 'cat /home/ec2-user/labfile.txt || echo "Arquivo não encontrado"'

echo "NEW_INSTANCE_ID=$NEW_INSTANCE_ID" > last_inst_from_ami.env
