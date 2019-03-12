#!/bin/bash

if [ -z "${AWS_ACCESS_KEY_ID+x}" -a -z "${AWS_SECRET_ACCESS_KEY+x}" ]; then
    echo "error: both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY needs to be set"
    echo "usage: AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY $0"
    exit 1
fi
# Taken from http://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html
BASE_AMIS=('us-east-2':'ami-0aa9ee1fc70e57450'
'us-east-1':'ami-007571470797b8ffa'
'us-west-2':'ami-0302f3ec240b9d23c'
'us-west-1':'ami-0935a5e8655c6d896'
'eu-west-2':'ami-0380c676fcff67fd5'
'eu-west-3':'ami-0b419de35e061d9df'
'eu-west-1':'ami-0b8e62ddc09226d0a'
'eu-central-1':'ami-01b63d839941375df'
'eu-north-1':'ami-03f8f3eb89dcfe553'
'ap-northeast-2':'ami-0c57dafd95a102862'
'ap-northeast-1':'ami-086ca990ae37efc1b'
'ap-southeast-2':'ami-0d28e5e0f13248294'
'ap-southeast-1':'ami-0627e2913cf6756ed'
'ca-central-1':'ami-0835b198c8a7aced4'
'ap-south-1':'ami-05de310b944d67cde'
'sa-east-1':'ami-09987452123fadc5b'
'us-gov-east-1':'ami-07dfc9cdc48d8649a'
'us-gov-west-1':'ami-914229f0'
	  )

# Mimic associative arrays using ":" to compose keys and values,
# to make them work in bash v3
function key(){
    echo  ${1%%:*}
}

function value(){
    echo  ${1#*:}
}

# Access is O(N) but .. we are mimicking maps with arrays
function get(){
    KEY=$1
    shift
    for I in $@; do
	if [ $(key $I) = "$KEY" ]; then
	    echo $(value $I)
	    return
	fi
    done
}

REGIONS=""
for I in ${BASE_AMIS[@]}; do
    REGIONS="$REGIONS $(key $I)"
done

if [ -z "$(which packer)" ]; then
    echo "error: Cannot find Packer, please make sure it's installed"
    exit 1
fi

function invoke_packer() {
    LOGFILE=$(mktemp /tmp/${1}-packer-log-weave-ecs-XXXX)
    AMI_GROUPS=""
    if [ -n "${RELEASE+x}" ]; then
	AMI_GROUPS="all"
    fi
    packer build -var "ami_groups=${AMI_GROUPS}" -var "aws_region=$1" -var "source_ami=$2" template.json > $LOGFILE
    if [ "$?" = 0 ]; then
	echo "Success: $(tail -n 1 $LOGFILE)"
	rm $LOGFILE
    else
	echo "Failure: $1: see $LOGFILE for details"
    fi
}

BUILD_FOR_REGIONS=""
if [ -n "${ONLY_REGION+x}" ]; then
    if [ -z "$(get $ONLY_REGION ${BASE_AMIS[@]})" ]; then
	echo "error: ONLY_REGION set to '$ONLY_REGION', which doesn't offer ECS yet, please set it to one from: ${REGIONS}"
	exit 1
    fi
    BUILD_FOR_REGIONS="$ONLY_REGION"
else
    BUILD_FOR_REGIONS="$REGIONS"
fi

echo
echo "Spawning parallel packer builds"
echo



for REGION in $BUILD_FOR_REGIONS; do
    AMI=$(get $REGION ${BASE_AMIS[@]})
    echo Spawning AMI build for region $REGION based on AMI $AMI
    invoke_packer "${REGION}" "${AMI}" &
done

echo
echo "Waiting for builds to finish, this will take a few minutes, please be patient"
echo

wait

echo
echo "Done"
echo
