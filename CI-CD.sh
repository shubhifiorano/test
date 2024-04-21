# Provide WORKSPACE_PATH, REPO_NAME and CLONE_URL (till .git)
WORKSPACE_PATH=/actions-runner/_work/test

#REPO_NAME - slash separated after your GITLAB ACCOUNT NAME eg if your GITLAB link is  https://gitlab.com/Blitzkrieg/fiorano/esb.git then REPO_NAME = fiorano/esb

REPO_NAME=test
#WORKSPACE PATH - this is the place where it will clone the git repo and create the zips that will be imported. This workspace cannot be runtimedata/applications/repository as it will create two folders with the same name- one will be the pre-existing one and the other the checked out one. Moreover creating the zip will lead to a conflict and correct EP might not get imported. However, if the user is not going to do any development/ create EPs on the production environment and you still want to use the same path as runtimedata/applications/repository then firstly initialize that direcrory as git direcrory by running the git init command and then edit the .git/Config file to set the head correctly. Then modify the script to replace git clone with git pull (fetch + merge). And delete/ rename the zip after it has launched successfully.

CLONE_URL=https://github.com/shubhifiorano/test.git

#cd $WORKSPACE_PATH

#echo pwd


#git clone $CLONE_URL

#cd $REPO_NAME

echo $REPO_NAME

#echo pwd

#rm -rf *.yml
rev_num=`git log --pretty=format:"%H" -n 1`
echo "RevNumber is "$rev_num

readfile()
{
echo "We are in readfile"	
git diff-tree --no-commit-id --name-only --diff-filter=$1 -r $rev_num | awk -F/ '{ print $1"/"$2}' >> out.txt
sort -u out.txt > "$2"  # Sort and remove duplicates, then save to the desired filename
uniq out.txt $2
cat out.txt
rm out.txt  # Optionally remove the temporary file

}

readfile "M" "modifiedEPs.txt"
#cat out.txt
readfile "A" "modifiedEPs.txt"
#cat out.txt
#rm -rf out.txt
readfile "D" "deletedEPs.txt"
#cat out.txt
#rm -rf out.txt

echo generating API KEY

KEY=`curl -X POST "http://localhost:1980/api/fes/security/api-key" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"userName\":\"admin\",\"password\":\"passwd\",\"context\":\"ESB\",\"timeOut\":0}" | grep -Po '"SUCCESS"' | grep -o '".*"' | sed 's|"||g'`
if [ "$KEY" != "SUCCESS" ]
then
	echo Failed to generate API KEY. Exiting!
	exit 1
fi

KEY=`curl -X POST "http://localhost:1980/api/fes/security/api-key" -H "accept: application/json" -H "Content-Type: application/json" -d "{\"userName\":\"admin\",\"password\":\"passwd\",\"context\":\"ESB\",\"timeOut\":0}" | grep -Po '"response":.*?[^\\\]"' | grep -o ':.*' | grep -o '".*"' | sed 's|"||g'`
echo API KEY is $KEY

curl_commands()
{
while read LINE
do
cd $WORKSPACE_PATH/$REPO_NAME		
curl -X POST "http://localhost:1980/api/fes/applications/$LINE" -H "accept: application/json" -H "api_key: $KEY" -H "Content-Type: application/json" -d "{\"action\":\"STOP\"}"
echo Stopped
if [ "$1" == "deletedEPs.txt" ]
	then
	curl -X DELETE "http://localhost:1980/api/fes/applications/$LINE/event-process" -H "accept: application/json" -H "api_key: $KEY"	
	echo Deleted
else
    if [ "$LINE" == ".gitlab-ci.yml/" ]
    then
        continue
    fi
	zip_name=`sed 's|/|-|g' <<<$LINE` 
	cd $WORKSPACE_PATH/$REPO_NAME/$LINE/..
	echo zip_name is $zip_name and LINE is $LINE
	zip -r $zip_name@EnterpriseServer.zip *
	mv $zip_name@EnterpriseServer.zip $WORKSPACE_PATH/$zip_name@EnterpriseServer.zip


fi
	done <$1
}

   	
crc()
{
while read LINE
do
    curl -X POST "http://localhost:1980/api/fes/applications/$LINE" -H "accept: application/json" -H "api_key: $KEY" -H "Content-Type: application/json" -d "{\"action\":\"CRC\"}"
	echo Done with CRC
	curl -X POST "http://localhost:1980/api/fes/applications/$LINE" -H "accept: application/json" -H "api_key: $KEY" -H "Content-Type: application/json" -d "{\"action\":\"START\"}"
	echo Started EP		


done <$1
}


curl_commands "modifiedEPs.txt"

echo done with modified EPs 

cd $WORKSPACE_PATH/$REPO_NAME

curl_commands "deletedEPs.txt"

echo done with deleted EPs

cd $WORKSPACE_PATH

zip -r abc.zip *.zip
echo starting import of multiple EPs
curl -X POST "http://localhost:1980/api/fes/applications/import/multiple?overwriteExistingEP=true&overwriteExistingNamedConfigs=true&overwriteExistingReferredEPs=true&importWholeEPWithDependencies=true&ignoreDependencies=true&ImportAppWithLibraries=true" -H  "accept: application/json" -H  "api_key: $KEY" -H  "Content-Type: multipart/form-data" -F "file=@abc.zip;type=application/zip"
echo Done with the multiple import


cd $WORKSPACE_PATH/$REPO_NAME
crc "modifiedEPs.txt"
 
#rm -rf $WORKSPACE_PATH/$REPO_NAME

#rm -rf $WORKSPACE_PATH/*.zip



