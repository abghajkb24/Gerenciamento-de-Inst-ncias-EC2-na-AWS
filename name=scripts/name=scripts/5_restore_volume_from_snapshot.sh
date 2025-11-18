#!/usr/bin/env bash
# 5_restore_volume_from_snapshot.sh
# Cria um novo volume a partir do snapshot e anexa a instância alvo para verificação de dados.
# Uso: bash 5_restore_volume_from_snapshot.sh <snapshot-id> <target-instance-id>
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
SNAPSHOT_ID="${1:-}"
TARGET_INSTANCE_ID="${2:-}"

if [ -z "$SNAPSHOT_ID" ]; then
  if [ -f last_volume.env ]; then
    source last_volume.env
    SNAPSHOT_ID="${SNAPSHOT_ID:-}"
  fi
fi

if [ -z "$TARGET_INSTANCE_ID" ]; then
  if [ -f last_instance.env ]; then
    source last_instance.env
    TARGET_INSTANCE_ID="${INSTANCE_ID:-}"
  fi
fi

if [ -z "$SNAPSHOT_ID" ] || [ -z "$TARGET_INSTANCE_ID" ]; then
  echo "Uso: $0 <snapshot-id> <target-instance-id>"
  exit 1
fi

AZ=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$TARGET_INSTANCE_ID" --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)
echo "Criando volume a partir do snapshot $SNAPSHOT_ID na AZ $AZ..."
NEW_VOL_ID=$(aws ec2 create-volume --region "$AWS_REGION" --snapshot-id "$SNAPSHOT_ID" --availability-zone "$AZ" --query 'VolumeId' --output text)
echo "Novo volume: $NEW_VOL_ID"

echo "Aguardando volume disponível..."
aws ec2 wait volume-available --region "$AWS_REGION" --volume-ids "$NEW_VOL_ID"

DEVICE_NAME="/dev/sdg"
echo "Anexando volume $NEW_VOL_ID a $TARGET_INSTANCE_ID em $DEVICE_NAME..."
aws ec2 attach-volume --region "$AWS_REGION" --volume-id "$NEW_VOL_ID" --instance-id "$TARGET_INSTANCE_ID" --device "$DEVICE_NAME"

echo "Esperando anexo..."
sleep 6

PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$TARGET_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Montando e verificando dados via SSH no IP: $PUBLIC_IP"

ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY_PATH" ec2-user@"$PUBLIC_IP" <<'SSH_EOF'
sudo mkdir -p /mnt/restored
sudo mount /dev/xvdg /mnt/restored || sudo mount /dev/sdg /mnt/restored || true
echo "Conteúdo de /mnt/restored:"
ls -l /mnt/restored || true
cat /mnt/restored/data.txt || true
sudo umount /mnt/restored || true
SSH_EOF

echo "NEW_RESTORED_VOLUME=$NEW_VOL_ID" > last_restored_volume.env
