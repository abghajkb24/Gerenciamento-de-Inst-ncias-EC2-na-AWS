 Laboratório: Gerenciamento de Instâncias EC2, AMIs e Snapshots EBS

 Descrição
Neste laboratório, os participantes irão praticar conceitos fundamentais de gerenciamento de instâncias EC2 na AWS, com foco em criação e utilização de AMIs (Amazon Machine Images) e Snapshots EBS. Você irá:
- Criar uma instância EC2.
- Customizar a instância (adicionar arquivo/exemplo).
- Criar uma AMI a partir dessa instância.
- Inicializar nova instância a partir da AMI e validar que as customizações persistem.
- Criar um volume EBS de dados, povoá-lo, criar um snapshot e restaurar esse snapshot em outro volume.
- Limpar recursos criados.

 Objetivos de aprendizagem
- Entender o ciclo de vida de uma AMI.
- Saber criar e usar snapshots EBS para backup e restauração de volumes.
- Automatizar tarefas comuns usando AWS CLI.

 Pré-requisitos
- Conta AWS com permissões EC2 (ex.: política exemplo `iam-policy.json` incluída).
- AWS CLI instalada e configurada (`aws configure`).
- `jq` instalado (opcional, usado nos scripts para parse de JSON).
- Uma key-pair EC2 já criada na região usada (nome: variável `KEY_NAME` nos scripts).
- Sistema local com bash.

Região sugerida: us-east-1 (ou ajuste variáveis nos scripts).

 Estrutura dos arquivos
- scripts/*.sh — scripts bash numerados para cada etapa.
- iam-policy.json — política mínima recomendada.
- lab_description.md — este documento.

 Variáveis e preparação
Antes de rodar os scripts, configure:
- AWS_REGION (ex.: us-east-1)
- KEY_NAME — nome do key pair existente na AWS
- SSH_PRIVATE_KEY_PATH — caminho para o .pem
- INSTANCE_TYPE — ex.: t3.micro
- BASE_AMI — AMI base para inicializar (ex.: Amazon Linux 2 AMI ID na região)
- SECURITY_GROUP_ID — ID do security group permitindo SSH (22) e ICMP se desejar
- SUBNET_ID (opcional) — subnet para a instância

Exemplo de export:
```bash
export AWS_REGION=us-east-1
export KEY_NAME=minha-key
export SSH_PRIVATE_KEY_PATH=~/.ssh/minha-key.pem
export INSTANCE_TYPE=t3.micro
export BASE_AMI=ami-0abcdef1234567890   # substitua pelo AMI Amazon Linux 2 da sua região
export SECURITY_GROUP_ID=sg-0abc1234def567890
export SUBNET_ID=subnet-0123456789abcdef0
```

Os scripts assumem que AWS CLI está autenticada e que `jq` está disponível. Eles exibem IDs (instance, image, snapshot, volume) e esperam que o usuário confirme quando necessário.

 Passos do laboratório (resumo)
1. Executar 1_launch_instance.sh — cria instância EC2 e escreve um arquivo de teste em /home/ec2-user/labfile.txt.
2. Conectar via SSH para inspecionar (opcional) ou seguir para criar AMI.
3. Executar 2_create_ami.sh — cria AMI da instância, aguarda disponibilidade.
4. Executar 3_launch_from_ami.sh — lança uma nova instância a partir da AMI e verifica o arquivo criado.
5. Executar 4_create_ebs_and_snapshot.sh — cria volume EBS, anexa, escreve dados, cria snapshot.
6. Executar 5_restore_volume_from_snapshot.sh — cria novo volume a partir do snapshot, anexa, verifica dados.
7. Executar cleanup.sh — termina instâncias, deleta volumes, snapshots e regista AMI (opcional: desregistra AMI).

---

 Scripts incluídos (como usar)
Cada script tem comentários e instruções no topo. Exemplos rápidos:

Criar instância:
```bash
bash scripts/1_launch_instance.sh
```

Criar AMI da instância:
```bash
bash scripts/2_create_ami.sh <instance-id>
```

Lançar instância da AMI:
```bash
bash scripts/3_launch_from_ami.sh <image-id>
```

Criar EBS + snapshot:
```bash
bash scripts/4_create_ebs_and_snapshot.sh <instance-id>
```

Restaurar volume a partir do snapshot:
```bash
bash scripts/5_restore_volume_from_snapshot.sh <snapshot-id> <target-instance-id>
```

Limpeza:
```bash
bash scripts/cleanup.sh
```

---

 Boas práticas / notas
- Sempre verifique custos: instâncias, snapshots e volumes geram custo.
- Remova recursos quando terminar.
- Ao criar AMIs que contenham dados sensíveis, proteja o acesso ao AMI e snapshots.
- Para ambientes complexos, use Automation (SSM), CloudFormation ou Terraform.

---

 Resultados esperados
- Nova AMI registrada que representa o estado da instância (inclui arquivo /home/ec2-user/labfile.txt).
- Instância lançada a partir da AMI que tem a mesma customização.
- Snapshot EBS contendo o conteúdo do volume de dados.
- Volume restaurado com os dados do snapshot.
