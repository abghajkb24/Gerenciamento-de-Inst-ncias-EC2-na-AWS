#!/usr/bin/env bash
# 1_launch_instance.sh
# Lança uma instância EC2 base (Amazon Linux 2 por padrão) e cria um arquivo de teste.
# Uso: bash 1_launch_instance.sh
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
: "${KEY_NAME:?set KEY_NAME}"
: "${SECURITY_GROUP_ID:?set SECURITY_GROUP_ID}"
: "${SUBNET_ID:=}"     # opcional
: "${INSTANCE_TYPE:=t3.micro}"
: "${BASE_AMI:?set BASE_AMI}"
: "${SSH_PRIVATE_KEY_PATH:?set SSH_PRIVATE_KEY_PATH}"

echo "Região: $AWS_REGION"
echo "AMI base: $BASE_AMI"
echo "Instance type: $INSTANCE_TYPE"

LAUNCH_ARGS=(--image-id "$BASE_AMI" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --security-group-ids "$SECURITY_GROUP_ID" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=lab-ec2-instance}]")

if [ -n "$SUBNET_ID" ]; then
  LAUNCH_ARGS+=(--subnet-id "$SUBNET_ID")
fi

echo "Lançando instância..."
RUN_OUTPUT=$(aws ec2 run-instances --region "$AWS_REGION" "${LAUNCH_ARGS[@]}" --query 'Instances[0].InstanceId' --output text)
INSTANCE_ID="$RUN_OUTPUT"
echo "Instância lançada: $INSTANCE_ID"

echo "Aguardando instância ficar 'running'..."
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Instância pública: $PUBLIC_IP"

echo "Aguardando SSH disponível (até 3 minutos)..."
for i in {1..30}; do
  if nc -z -w 2 "$PUBLIC_IP" 22 2>/dev/null; then
    echo "SSH disponível"
    break
  fi
  sleep 6
done

echo "Conectando via SSH para configurar arquivo de teste..."
ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY_PATH" ec2-user@"$PUBLIC_IP" <<'SSH_EOF'
sudo bash -c 'echo "Lab file - created at $(date -u)" > /home/ec2-user/labfile.txt; chown ec2-user:ec2-user /home/ec2-user/labfile.txt'
ls -l /home/ec2-user/labfile.txt
cat /home/ec2-user/labfile.txt
SSH_EOF

echo "Instância configurada com /home/ec2-user/labfile.txt"
echo "INSTANCE_ID=$INSTANCE_ID" > last_instance.env
echo "PUBLIC_IP=$PUBLIC_IP" >> last_instance.env
echo "Pronto."
