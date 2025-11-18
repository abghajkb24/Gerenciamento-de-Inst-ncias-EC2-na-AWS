#!/usr/bin/env bash
# 4_create_ebs_and_snapshot.sh
# Cria um volume EBS, anexa a uma instância, escreve dados e cria um snapshot.
# Uso: bash 4_create_ebs_and_snapshot.sh <instance-id>
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
INSTANCE_ID="${1:-}"
: "${AVAILABILITY_ZONE:=${AWS_REGION}a}"  # ex.: us-east-1a - pode ser sobrescrito

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

# Determinar AZ da instância
AZ=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)
echo "Instância $INSTANCE_ID está em AZ: $AZ"

echo "Criando volume de 1 GiB..."
VOL_ID=$(aws ec2 create-volume --region "$AWS_REGION" --availability-zone "$AZ" --size 1 --volume-type gp2 --query 'VolumeId' --output text)
echo "Volume criado: $VOL_ID"

echo "Aguardando volume disponível..."
aws ec2 wait volume-available --region "$AWS_REGION" --volume-ids "$VOL_ID"

# Anexar ao device /dev/sdf (pode variar)
DEVICE_NAME="/dev/sdf"
echo "Anexando volume $VOL_ID ao instance $INSTANCE_ID como $DEVICE_NAME..."
aws ec2 attach-volume --region "$AWS_REGION" --volume-id "$VOL_ID" --instance-id "$INSTANCE_ID" --device "$DEVICE_NAME"
echo "Aguardando estado 'in-use'..."
for i in {1..15}; do
  state=$(aws ec2 describe-volumes --region "$AWS_REGION" --volume-ids "$VOL_ID" --query 'Volumes[0].Attachments[0].State' --output text 2>/dev/null || true)
  if [ "$state" = "attached" ] || [ "$state" = "attached" ]; then
    break
  fi
  sleep 2
done

# Monte e escreva no volume via SSH
PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Montando volume na instância via SSH (IP: $PUBLIC_IP)..."

ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY_PATH" ec2-user@"$PUBLIC_IP" <<'SSH_EOF'
sudo mkfs -t ext4 /dev/xvdf || true
sudo mkdir -p /mnt/labdata
sudo mount /dev/xvdf /mnt/labdata
sudo bash -c 'echo "Snapshot test data - $(date -u)" > /mnt/labdata/data.txt'
ls -l /mnt/labdata/data.txt
cat /mnt/labdata/data.txt
sudo umount /mnt/labdata || true
SSH_EOF

echo "Criando snapshot do volume $VOL_ID..."
SNAP_ID=$(aws ec2 create-snapshot --region "$AWS_REGION" --volume-id "$VOL_ID" --description "lab-snapshot-$VOL_ID" --query 'SnapshotId' --output text)
echo "Snapshot criado: $SNAP_ID"

echo "Aguardando snapshot completar..."
aws ec2 wait snapshot-completed --region "$AWS_REGION" --snapshot-ids "$SNAP_ID"

echo "Snapshot pronto: $SNAP_ID"
echo "VOLUME_ID=$VOL_ID" > last_volume.env
echo "SNAPSHOT_ID=$SNAP_ID" >> last_volume.env
