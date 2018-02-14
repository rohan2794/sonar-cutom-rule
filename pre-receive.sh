#!/usr/bin/env bash
zero_commit="0000000000000000000000000000000000000000"
result=0
# Do not traverse over commits that are already in the repository
# (e.g. in a different branch)
# This prevents funny errors if pre-receive hooks got enabled after some
# commits got already in and then somebody tries to create a new branch
# If this is unwanted behavior, just set the variable to empty
excludeExisting="--not --all"
#hook gets its arguments from stdin, in the form <oldrev> <newrev> <refname>.
#Since these arguments are coming from stdin, not from a command line argument, you need to use  read instead of $1 $2 $3
#hook can receive multiple branches at once (for example if someone does a git push --all), so we also need to wrap the read in a while loop.
#refname-point to current HEAD
#oldrev-last successful commit id which is pushed to remote bitbucket repo
#newrev-current commit id which is pushed but still it is not updated in remote bitbucket repo
while read oldrev newrev refname; do
  # echo "payload"
  echo $refname $oldrev $newrev

  # branch or tag get deleted
  if [ "$newrev" = "$zero_commit" ]; then
    continue
  fi

  # Check for new branch or tag
  if [ "$oldrev" = "$zero_commit" ]; then
  #git rev-list $old_ref..$new_ref will give us all commits between the two refs, even if they are already known to the repository.
    span=$(git rev-list $newrev $excludeExisting)
  else
    span=$(git rev-list $oldrev..$newrev $excludeExisting)
  fi
for COMMIT in $span;
  do
    cd /var/atlassian/application-data/bitbucket/shared/data/repositories/1
    mkdir -p /home/techm/archive/$COMMIT
	#while creating archive we have to change owner of archive to atlbitbucket by running this command :chown -R atlbitbucket:atlbitbucket archive
    git archive $COMMIT | (cd /home/techm/archive/$COMMIT; tar x)
    cd /home/techm/archive/$COMMIT
    status=$(sonar-scanner |grep -e 'EXECUTION SUCCESS' -e 'http://10.53.67.38:9000/api/ce/task?')
	echo "status:= $status"
      if [ -n "$status" ];then
        url=$(echo $status|cut -d ' ' -f8)
			if [ -n "$url" ]; then
			  echo "For more sonar updates check"$url
			  status2=$(curl -u admin:admin $url |jq .task.status|sed -e 's/^"//'  -e 's/"$//')
			   while [ "$status2" == "IN_PROGRESS" ] || [ "$status2" == "PENDING" ];do
			   sleep 5s
				status2=$(curl -u admin:admin $url |jq .task.status|sed -e 's/^"//'  -e 's/"$//')
			   done
				  if [[ "$status2" == "SUCCESS" ]]; then
					  analysisID=$(curl -u admin:admin $url |jq '.task.analysisId'|sed -e 's/^"//'  -e 's/"$//')
					  analysisUrl="http://10.53.67.38:9000/api/qualitygates/project_status?analysisId="
					  quality_gate_status=$(curl -u admin:admin $analysisUrl${analysisID} |jq '.projectStatus.status'|sed -e 's/^"//'  -e 's/"$//')
						  if [[ "$quality_gate_status" != "OK" ]]; then
							  echo "$COMMIT returned quality gate status: $quality_gate_status"
							  exit 1
						  fi
					else
						  echo "$COMMIT Sonar run returned status: $status2"
						  exit 1
				  fi
			else
			echo "Sonar URL is empty: $url"
			exit 1
		   fi
      else
      echo "SONAR analysis failed"

           done
          if [[ "$status2" == "SUCCESS" ]]; then
              analysisID=$(curl -u admin:admin $url |jq '.task.analysisId'|sed -e 's/^"//'  -e 's/"$//')
              analysisUrl="http://10.53.67.38:9000/api/qualitygates/project_status?analysisId="
              quality_gate_status=$(curl -u admin:admin $analysisUrl${analysisID} |jq '.projectStatus.status'|sed -e 's/^"//'  -e 's/"$//')
                  if [[ "$quality_gate_status" != "OK" ]]; then
                      echo "$COMMIT returned quality gate status: $quality_gate_status"
                      exit 1
                  fi
                  else
              echo "$COMMIT Sonar run returned status: $status2"
              exit 1
          fi
        else
        echo "Sonar URL is empty: $url"
        exit 1
       fi
      else
      echo "SONAR analysis failed"
      result=1
     fi
    rm -rf /home/techm/archive/$COMMIT
  done
done
exit $result
	  
	  
