#! /bin/bash
echo "Fetch the stages from input file ..."

#stages=$(yq -r .stages stage-input.yml)
stages=$(yq -r '.stages| to_entries | .[] | .key' stage-input.yml | xargs | sed -e 's/ /,/g')

if [[ -z "$stages" ]]; then
  echo "ERROR: Please specify the stages in the input file....."
  exit 1
else 
  git clone https://github.com/OpsMx/yaml-stages.git 2> /tmp/tmp.log
  reponame=yaml-stages
  cd $reponame/stages
  rm -rf ../list
  touch ../list
  IFS=","
  for liststages in $stages
  do
    existone=waitstage,manualjudgement,deploymanifest
    loopcount=$(echo $existone | tr ',' ' ' | wc -w)
    initcount=1
    IFS=","
    for checkstages in $existone
    do
      if [ "$liststages" == "$checkstages" ]
      then
        echo "Yes stage matches $liststages = $checkstages"
        ls | grep $checkstages >> ../list
        if [ "$?" != "0" ]
        then
          echo "The stage name:--> $liststages not found .." 
        fi
        filestg=$(ls | grep $checkstages)
	dynaparm=$(yq -r '.stages.'"$liststages"'' ../../stage-input.yml -o json)
	if [ "$dynaparm" != "null" ]
	then
	  echo It has params
          jq --argjson param "$dynaparm" '. += $param' $filestg > duplicate.json
	  rm -rf $filestg
	  mv duplicate.json $filestg
        fi
      else
        if [ "$loopcount" == "$initcount" ]
        then
          echo "The stage name:--> $liststages not found .."
	  exit 1
        fi
        initcount=$((initcount+1))
      fi
    done
  done
  stageid=
  refid=1
  IFS=","
  while read -r filestg; do
    echo value is $filestg
    jq  --argjson stage "$(<$filestg)" '.stages += [$stage]' plain_pipeline_template.json > formulate.json
    if [[ -z "$stageid" ]]; then
    jq --argjson refstage '{"refId":"'$refid'","requisiteStageRefIds":['"$stageid"']}' '.stages['"$stageid"'] += $refstage' formulate.json > inter.json
    else
    jq --argjson refstage '{"refId":"'$refid'","requisiteStageRefIds":["'"$stageid"'"]}' '.stages['"$stageid"'] += $refstage' formulate.json > inter.json
    fi
    if [ $? != 0 ]; then
      echo "Error occured in YAML processing, please check the logs"
      exit 1
    fi
    rm -rf plain_pipeline_template.json formulate.json final_pipeline.json
    mv inter.json plain_pipeline_template.json
    rm -rf inter.json
    filestg=manualjudgement_stage.json
    refid=$((refid+1))
    stageid=$((stageid+1))
  done < ../list
  rm -rf ../list
  rm -rf ../../complete_pipeline.json
  cp plain_pipeline_template.json ../../complete_pipeline.json
  echo "Complete Pipeline json"
  echo "============================================================="
  cat ../../complete_pipeline.json
  echo "============================================================="
  cd ../../
  rm -rf $reponame
fi
