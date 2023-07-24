#!/bin/bash
# This script launches an AWS Windows instance suitable for running Hyper-V.
# Ideally kola would support running automated Hyper-V tests by launching
# such an instance and driving it over SSH.

set -euo pipefail

REGION="us-east-2"
AZ="us-east-2a"
AMI_DESC="Windows_Server-2022-English-Full-Base"
# least expensive Windows metal option
INSTANCE_TYPE="m5zn.metal"
VPC="coreos-hyperv"
SG="coreos-hyperv"
INSTANCE="coreos-hyperv"
KEY_PREFIX="coreos-hyperv"
DISK_GB=100
DISP_W=1280
DISP_H=950

if [ $# != 1 ]; then
    echo "Usage: $0 <workdir>"
    exit 1
fi

dir="$1"
mkdir -p "$dir"

export AWS_DEFAULT_REGION="$REGION"
export AWS_DEFAULT_OUTPUT="json"

for req in aws jq python3 xfreerdp ; do
    if ! which "$req" &>/dev/null; then
        echo "No $req command. Can't continue." >&2
        exit 1
    fi
done

set -x

# find AMI
ami=$(aws ssm get-parameters --names "/aws/service/ami-windows-latest/$AMI_DESC" | jq -r ".Parameters[].Value")

# get or create VPC
vpc=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC" | jq -r ".Vpcs[].VpcId")
if [ -z "$vpc" ]; then
    vpc=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC}]" | jq -r ".Vpc.VpcId")
fi

# get or create Internet gateway
igw=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" | jq -r ".InternetGateways[].InternetGatewayId")
if [ -z "$igw" ]; then
    igw=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)
    aws ec2 attach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc"
fi

# get or create subnet
subnet=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" "Name=availability-zone,Values=$AZ" | jq -r ".Subnets[].SubnetId")
if [ -z "$subnet" ]; then
    octet=$(python3 -c "print(ord(\"$AZ\"[-1]) - ord('a'))")
    subnet=$(aws ec2 create-subnet --vpc-id "$vpc" --availability-zone "$AZ" --cidr-block "10.0.$octet.0/24" | jq -r ".Subnet.SubnetId")
    aws ec2 modify-subnet-attribute --subnet-id "$subnet" --map-public-ip-on-launch
fi

# get or create route table
rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$subnet" | jq -r ".RouteTables[].RouteTableId")
if [ -z "$rt" ]; then
    rt=$(aws ec2 create-route-table --vpc-id "$vpc" | jq -r ".RouteTable.RouteTableId")
    aws ec2 associate-route-table --route-table-id "$rt" --subnet-id "$subnet"
    aws ec2 create-route --route-table-id "$rt" --destination-cidr-block 0.0.0.0/0 --gateway-id "$igw"
fi

# get or create security group
sg=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" "Name=tag:Name,Values=$SG" | jq -r ".SecurityGroups[].GroupId")
if [ -z "$sg" ]; then
    sg=$(aws ec2 create-security-group --group-name "$SG" --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$SG}]" --vpc-id "$vpc" --description "Hyper-V" | jq -r ".GroupId")
    aws ec2 authorize-security-group-ingress --group-id "$sg" --protocol tcp --cidr 0.0.0.0/0 --port 3389
fi

# create temporary key pair
key_name="$KEY_PREFIX-$RANDOM"
ret=$(aws ec2 create-key-pair --key-name "$key_name")
key_id=$(jq -r ".KeyPairId" <<< $ret)
trap "aws ec2 delete-key-pair --key-pair-id $key_id" EXIT
jq -r ".KeyMaterial" <<< $ret > "$dir/key.pem"

# create userdata
cat > "$dir/userdata" <<EOF
<powershell>
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
</powershell>
EOF

# start instance
instance=$(aws ec2 run-instances --instance-type "$INSTANCE_TYPE" --image-id "$ami" --subnet-id "$subnet" --security-group-ids "$sg" --key-name "$key_name" --tag-specifications --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE}]" --block-device-mappings '[{"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": '$DISK_GB'}}]' --user-data "file://$dir/userdata" | jq -r ".Instances[].InstanceId")

# get Windows password
while true; do
    passwd=$(aws ec2 get-password-data --instance-id "$instance" --priv-launch-key "$dir/key.pem"  | jq -r .PasswordData)
    if [ -n "$passwd" ]; then
        break
    fi
    sleep 15
done
rm "$dir/key.pem"

# get IP
instance_ip=$(aws ec2 describe-instances --instance-id "$instance" | jq -r ".Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp")

# generate output
set +x
echo "$instance" > "$dir/instance-id"
echo "$instance_ip" > "$dir/ip"
mkdir -p "$dir/shared"
cat > "$dir/connect.sh" <<EOF
#!/bin/bash
exec xfreerdp /cert:tofu /v:$instance_ip /u:Administrator /p:'$passwd' /w:$DISP_W /h:$DISP_H /drive:shared,"\$(dirname \$0)/shared"
EOF
cat > "$dir/terminate.sh" <<EOF
#!/bin/bash
set -xeuo pipefail
aws --region=$REGION ec2 terminate-instances --instance-id $instance
EOF
chmod +x "$dir/connect.sh" "$dir/terminate.sh"

# explain
cat <<EOF

Wait ~20 minutes for the machine to reboot, then use $dir/connect.sh to connect.
Files in $dir/shared will be accessible via the "shared" drive under "This PC".
EOF
