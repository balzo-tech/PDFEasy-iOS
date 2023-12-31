#!/bin/sh

#  ci_post_clone.sh
#  PdfExpert
#
#  Created by Leonardo Passeri on 19/07/23.
#  

echo "POST CLONE-Xcode Build started"

BasePath=${CI_WORKSPACE}/PdfExpert

# GoogleService-Info.plist

CurrentFilePath=${BasePath}/Resources/Staging/GoogleService-Info.plist
touch "${CurrentFilePath}"
echo $CUSTOM_GOOGLE_SERVICE_INFO >"${CurrentFilePath}"

CurrentFilePath=${BasePath}/Resources/Production/GoogleService-Info.plist
touch "${CurrentFilePath}"
echo $CUSTOM_GOOGLE_SERVICE_INFO >"${CurrentFilePath}"

# Info.plist

CurrentFilePath=${BasePath}/Resources/Staging/Info.plist
touch "${CurrentFilePath}"
echo $CUSTOM_GOOGLE_SERVICE_INFO >"${CurrentFilePath}"

CurrentFilePath=${BasePath}/Resources/Production/Info.plist
touch "${CurrentFilePath}"
echo $CUSTOM_GOOGLE_SERVICE_INFO >"${CurrentFilePath}"

# ProjectInfo.plist

CurrentFilePath=${BasePath}/Resources/ProjectInfo.plist
touch "${CurrentFilePath}"
echo $CUSTOM_PROJECT_INFO >"${CurrentFilePath}"

echo "POST CLONE-Xcode Build finished"

exit 0
