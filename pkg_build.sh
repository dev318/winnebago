#!/bin/bash
#set -x
declare -x awk="/usr/bin/awk"
declare -x chown="/usr/sbin/chown"
declare -x cp="/bin/cp"
declare -x git="/usr/local/git/bin/git"
declare -x mv="/bin/mv"
declare -x mkdir="/bin/mkdir"
declare -x xcodebuild="/usr/bin/xcodebuild"
declare -x pkgbuild="/usr/bin/pkgbuild"

declare -x SCRIPT="${0##*/}" ; SCRIPT_NAME="${Script%%\.*}"
declare -x SCRIPT_PATH="$0" RUN_DIRECTORY="${0%/*}"

declare -x PROJECT_COMPANY="Winnebago"
declare -x PROJECT_DOMAIN="com.github.winnebago"

declare -xa PROJECT_NAME[0]="Winnebago"
declare -xa PACKAGE_NAME[0]="winnebago"
declare -xa TARGET_NAME[0]="${PROJECT_NAME[0]}.app"
declare -xa INSTALL_SUFFIX[0]="/Library/Application Support/Winnebago"

declare -xa PROJECT_NAME[1]="LaunchDItem"
declare -xa PACKAGE_NAME[1]="winnebago"
declare -xa TARGET_NAME[1]="$PROJECT_DOMAIN.plist"
declare -xa INSTALL_SUFFIX[1]="/Library/LaunchDaemons"

declare -x COMMIT="$(cd "$RUN_DIRECTORY"; $git log | $awk '/commit/{print substr($2,1,10);exit}')"

declare -x TMP_PATH="/private/tmp/${PROJECT_NAME}-$COMMIT-$$$RANDOM"
declare -x PACKAGE_IDENT="$PROJECT_DOMAIN.${PACKAGE_NAME}.$COMMIT"


for (( N = 1 ; N <=${#PACKAGE_NAME[@]}; N++ )) ; do
  declare -ix CONFIG=$(( $N -1 ))
  echo "Processing configuration $N which is array value $CONFIG"
  # This bypasses Install.app trying to be smart at upgrades which is less then perfect
  $mkdir -p "$TMP_PATH/${INSTALL_SUFFIX[$CONFIG]}"

  # Build Xcode Project
  XCODE_PROJECT="$RUN_DIRECTORY/${PROJECT_NAME[$CONFIG]}/${PROJECT_NAME[$CONFIG]}.xcodeproj"
  if [ -e "$XCODE_PROJECT" ] ; then
    $xcodebuild -project "$RUN_DIRECTORY/${PROJECT_NAME[$CONFIG]}/${PROJECT_NAME[$CONFIG]}.xcodeproj" clean build
    $mv -v "$RUN_DIRECTORY/${PROJECT_NAME[$CONFIG]}/build/Release/${TARGET_NAME[$CONFIG]}" "${TMP_PATH}/${INSTALL_SUFFIX[$CONFIG]}/"
  fi
  if [ "${INSTALL_SUFFIX[$CONFIG]}" == "/Library/LaunchDaemons" ] ; then
    $cp -Rvp "$RUN_DIRECTORY/pkg_build/${PACKAGE_NAME[$CONFIG]}_launchd/${TARGET_NAME[$CONFIG]}" "${TMP_PATH}/${INSTALL_SUFFIX[$CONFIG]}/"
  fi

  $chown -Rv 0:0 "$TMP_PATH/${INSTALL_SUFFIX[$CONFIG]}/"

done
$pkgbuild --identifier "$PACKAGE_IDENT" \
--root "$TMP_PATH/" \
--scripts "$RUN_DIRECTORY/pkg_build/${PACKAGE_NAME}_scripts" \
"$RUN_DIRECTORY/pkg_build/${PACKAGE_NAME}_$COMMIT.pkg"
