#!/usr/bin/env bash
# cleanup.sh
# Termina instâncias, deleta volumes e snapshots e desregistra AMIs criadas pelo laboratório.
# Uso: bash cleanup.sh
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"

# Terminar instâncias com tag Name containing lab-ec2
echo "Procurando instâncias de laboratório..."
INST_IDS=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:Name,Values=lab-ec2-instance,lab-ec2-from-ami" --query 'Reservations[].Instances[].InstanceId' --output text || true)
if [ -n "$INST_IDS" ]; then
  echo "Terminando instâncias: $INST_IDS"
  aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids $INST_IDS
  aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids $INST_IDS || true
else
  echo "Nenhuma instância de laboratório encontrada."
fi

# Deletar volumes criados registrados em last_volume.env / last_restored_volume.env
for f in last_volume.env last_restored_volume.env last_volume.env; do
  if [ -f "$f" ]; then
    source "$f"
  fi
done

VOLS=""
[ -n "${VOLUME_ID:-}" ] && VOLS="$VOLS $VOLUME_ID"
[ -n "${NEW_RESTORED_VOLUME:-}" ] && VOLS="$VOLS $NEW_RESTORED_VOLUME"

for v in $VOLS; do
  if [ -n "$v" ] && [ "$v" != " " ]; then
    echo "Deletando volume $v..."
    aws ec2 delete-volume --region "$AWS_REGION" --volume-id "$v" || true
  fi
done

# Deletar snapshot
if [ -n "${SNAPSHOT_ID:-}" ]; then
  echo "Deletando snapshot $SNAPSHOT_ID..."
  aws ec2 delete-snapshot --region "$AWS_REGION" --snapshot-id "$SNAPSHOT_ID" || true
fi

# Desregistrar AMI criada
if [ -f last_image.env ]; then
  source last_image.env
  if [ -n "${IMAGE_ID:-}" ]; then
    echo "Desregistrando AMI $IMAGE_ID..."
    aws ec2 deregister-image --region "$AWS_REGION" --image-id "$IMAGE_ID" || true
    # opcional: deletar snapshots associados (não está listado aqui automaticamente)
  fi
fi

echo "Limpeza concluída. Verifique o console AWS para confirmar."
