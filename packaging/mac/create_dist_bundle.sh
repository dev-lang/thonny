#!/bin/bash
set -e

# Should be run after new thonny package is uploaded to PyPi

PREFIX=$HOME/thonny_template_build_37
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# prepare working folder #########################################################
rm -rf build
mkdir -p build


# copy template #################################################
cp -R -H $PREFIX/Thonny.app build

# update launch scripts (might have changed after last create_base_bundle.sh) #####################
cp $SCRIPT_DIR/Thonny.app.initial_template/Contents/MacOS/* \
    build/Thonny.app/Contents/MacOS
cp $SCRIPT_DIR/Thonny.app.initial_template/Contents/Resources/* \
    build/Thonny.app/Contents/Resources
cp $SCRIPT_DIR/Thonny.app.initial_template/Contents/Info.plist \
    build/Thonny.app/Contents

FRAMEWORKS=build/Thonny.app/Contents/Frameworks
PYTHON_CURRENT=$FRAMEWORKS/Python.framework/Versions/3.7/

# install deps #####################################################
$PYTHON_CURRENT/bin/python3.7  -s -m pip install --no-cache-dir --no-binary mypy -r ../requirements-regular-bundle.txt

# install certifi #####################################################
$PYTHON_CURRENT/bin/python3.7 -s -m pip install --no-cache-dir certifi

# install thonny #####################################################
$PYTHON_CURRENT/bin/python3.7 -s -m pip install --pre --no-cache-dir thonny==3.2.6
rm $PYTHON_CURRENT/bin/thonny # because this contains absolute paths

# clean unnecessary stuff ###################################################

# delete all *.h files except one
#mv $PYTHON_CURRENT/include/python3.7m/pyconfig.h $SCRIPT_DIR # pip needs this
#find $FRAMEWORKS -name '*.h' -delete
#mv $SCRIPT_DIR/pyconfig.h $PYTHON_CURRENT/include/python3.7m # put it back

#find $FRAMEWORKS -name '*.a' -delete

rm -rf $FRAMEWORKS/Tcl.framework/Versions/8.6/Tcl_debug
rm -rf $FRAMEWORKS/Tk.framework/Versions/8.6/Tk_debug
rm -rf $FRAMEWORKS/Tk.framework/Versions/8.6/Resources/Scripts/demos
rm -rf $FRAMEWORKS/Tcl.framework/Versions/8.6/Resources/Documentation
rm -rf $FRAMEWORKS/Tk.framework/Versions/8.6/Resources/Documentation

find $PYTHON_CURRENT/lib -name '*.pyc' -delete
find $PYTHON_CURRENT/lib -name '*.exe' -delete
rm -rf $PYTHON_CURRENT/Resources/English.lproj/Documentation

rm -rf $PYTHON_CURRENT/share
rm -rf $PYTHON_CURRENT/lib/python3.7/test
rm -rf $PYTHON_CURRENT/lib/python3.7/idlelib


rm -rf $PYTHON_CURRENT/lib/python3.7/site-packages/pylint/test
rm -rf $PYTHON_CURRENT/lib/python3.7/site-packages/mypy/test

# clear bin because its scripts have absolute paths
mv $PYTHON_CURRENT/bin/python3.7 $SCRIPT_DIR # save python exe
rm -rf $PYTHON_CURRENT/bin/*
mv $SCRIPT_DIR/python3.7 $PYTHON_CURRENT/bin/

# create pip
# NB! check that pip.sh refers to correct executable!
cp $SCRIPT_DIR/../pip.sh $PYTHON_CURRENT/bin/pip3.7

# create links ###############################################################
cd $PYTHON_CURRENT/bin
ln -s python3.7 python3
ln -s pip3.7 pip3
cd $SCRIPT_DIR

# link for launcher
cd build/Thonny.app/Contents/MacOS
ln -s ../Frameworks/Python.framework/Versions/3.7/Resources/Python.app/Contents/MacOS/Python Python
cd $SCRIPT_DIR



# copy the token signifying Thonny-private Python
cp thonny_python.ini $PYTHON_CURRENT/bin 


# version info ##############################################################
VERSION=$(<$PYTHON_CURRENT/lib/python3.7/site-packages/thonny/VERSION)
ARCHITECTURE="$(uname -m)"
VERSION_NAME=thonny-$VERSION-$ARCHITECTURE 

# set version ############################################################
sed -i.bak "s/VERSION/$VERSION/" build/Thonny.app/Contents/Info.plist
rm -f build/Thonny.app/Contents/Info.plist.bak

# sign frameworks and app ##############################

SIGN_ID="Developer ID Application: Aivar Annamaa (2SA9D4CVU8)"
INSTALLER_SIGN_ID="Developer ID Installer: Aivar Annamaa (2SA9D4CVU8)"


#codesign -s "$SIGN_ID" --force --deep --timestamp --keychain ~/Library/Keychains/login.keychain-db \
#	--entitlements thonny.entitlements \
#	build/Thonny.app/Contents/Frameworks/Python.framework/Versions/3.7/lib/python3.7/lib-dynload/*.so \ 
#	build/Thonny.app/Contents/Frameworks/Python.framework/Versions/3.7/lib/*.dylib 

codesign -s "$SIGN_ID" --force --deep --timestamp --keychain ~/Library/Keychains/login.keychain-db \
	--entitlements thonny.entitlements \
	$(find build/Thonny.app -type f -name "*.so") \
	$(find build/Thonny.app -type f -name "*.dylib") 

codesign -s "$SIGN_ID" --force --timestamp --keychain ~/Library/Keychains/login.keychain-db \
	--entitlements thonny.entitlements --options runtime \
	build/Thonny.app/Contents/Frameworks/Python.framework \
	build/Thonny.app/Contents/Frameworks/Python.framework/Versions/3.7/bin/python3.7 \
	build/Thonny.app/Contents/Frameworks/Python.framework/Versions/3.7/Resources/Python.app 

# For some reason this executable needs to be signed after the others, 
# otherwise notarizer reports it as with invalid signature
codesign -s "$SIGN_ID" --force --timestamp --keychain ~/Library/Keychains/login.keychain-db \
	--entitlements thonny.entitlements --options runtime \
	build/Thonny.app/Contents/Frameworks/Python.framework/Versions/3.7/Python 
	
#build/Thonny.app/Contents/Frameworks/Python.framework/Versions/3.7/Resources/Python.app/Contents/MacOS/Python 
	
	
codesign -s "$SIGN_ID" --force --timestamp --keychain ~/Library/Keychains/login.keychain-db \
	--entitlements thonny.entitlements --options runtime \
	build/Thonny.app

# add readme #####################################################################
cp readme.txt build

# create dmg #####################################################################
mkdir -p dist
FILENAME=dist/thonny-${VERSION}.dmg
rm -f $FILENAME
#hdiutil create -srcfolder build -volname "Thonny $VERSION" -fs HFS+ -format UDBZ $FILENAME

# sign dmg ######################
#codesign -s "$SIGN_ID" --deep --timestamp --keychain ~/Library/Keychains/login.keychain-db \
#	--entitlements thonny.entitlements --options runtime \
#	$FILENAME


# create installer ################
# prepare resources
echo "Creating installer"
mkdir -p resources_build
cp resource_templates/* resources_build
sed -i '' "s/VERSION/$VERSION/g" resources_build/WELCOME.html
cp ../license-soft-wrap.txt resources_build/LICENSE.txt

echo "Creating component package"
# component
COMPONENT_PACKAGE=ThonnyComponent.pkg
rm -f $COMPONENT_PACKAGE
pkgbuild \
 	--root build \
	--component-plist Component.plist \
	--install-location /Applications\
	--scripts scripts \
	--identifier "org.thonny.Thonny.component" \
	--version $VERSION \
	--filter readme.txt \
	--sign "$INSTALLER_SIGN_ID" \
	--keychain ~/Library/Keychains/login.keychain-db \
	--timestamp \
	$COMPONENT_PACKAGE
	
echo "Creating product archive"
PRODUCT_ARCHIVE=dist/thonny-${VERSION}.pkg
rm -f $PRODUCT_ARCHIVE
productbuild \
	--identifier "org.thonny.Thonny.product" \
	--version $VERSION \
	--distribution Distribution.plist \
	--resources resources_build \
	--sign "$INSTALLER_SIGN_ID" \
	--keychain ~/Library/Keychains/login.keychain-db \
	--timestamp \
	$PRODUCT_ARCHIVE

exit 0
# xxl ####################################################################################
$PYTHON_CURRENT/bin/python3.7 -s -m pip install --no-cache-dir -r ../requirements-xxl-bundle.txt

find $PYTHON_CURRENT/lib -name '*.pyc' -delete
find $PYTHON_CURRENT/lib -name '*.exe' -delete

# sign frameworks and app ##############################
codesign --force -s "$SIGN_ID" --deep --timestamp --keychain ~/Library/Keychains/login.keychain-db \
	--entitlements thonny.entitlements --options runtime \
	build/Thonny.app/Contents/Frameworks/Python.framework
codesign --force -s "$SIGN_ID" --deep --timestamp --keychain ~/Library/Keychains/login.keychain-db \
	--entitlements thonny.entitlements --options runtime \
	build/Thonny.app


# create dmg #####################################################################
PLUS_FILENAME=dist/thonny-xxl-${VERSION}.dmg
#rm -f $PLUS_FILENAME
#hdiutil create -srcfolder build -volname "Thonny XXL $VERSION" -fs HFS+ -format UDBZ $PLUS_FILENAME

# sign dmg #######################################################################
#codesign -s "$SIGN_ID" --deep --timestamp --keychain ~/Library/Keychains/login.keychain-db \
#	--entitlements thonny.entitlements --options runtime \
#	$PLUS_FILENAME


# Notarizing #####################################################################
# https://successfulsoftware.net/2018/11/16/how-to-notarize-your-software-on-macos/
# xcrun altool -t osx --primary-bundle-id org.thonny.Thonny --notarize-app --username <apple id email> --password <generated app specific pw> --file <dmg>
# xcrun altool --notarization-info $1 --username aivar.annamaa@gmail.com --password <notarize ID>
# xcrun stapler staple <dmg>


# clean up #######################################################################
#rm -rf build

