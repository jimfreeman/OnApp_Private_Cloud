#!/usr/bin/env bash

set -e

SKIP_CP_PACKAGE=0
SKIP_STORAGE_PACKAGE=0

while true; do
  case "$1" in
  	-l | --license )      LICENSE_KEY="$2"; shift 2;;
    --skip-cp-package ) SKIP_CP_PACKAGE=1; shift;;
    --skip-storage-package ) SKIP_STORAGE_PACKAGE=1; shift;;
    -- ) shift; break;;
     * ) break;;
  esac
done

echo "STEP 1. CHECKING SELINUX STATUS"

if [ -f /selinux/enforce ];
then
  SELINUX=`cat /selinux/enforce`
  echo "No problem! SELinux is already disabled."
  if [ "$SELINUX" == 1 ];
  then
    echo "Looks like SELinux is still enabled, disabling..."
    sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    setenforce Permissive
    echo "A reboot is needed to completely disable SELinux. Once the system is rebooted please relaunch the deploy script."
    echo -e "\a\033[33;5;7mPRESS ENTER TO REBOOT\033[0m"
    read
    reboot
  fi
fi

echo "STEP 2. CONFIGURE REPOSITORY"

rpm -Uvh http://rpm.repo.onapp.com/repo/onapp-repo.noarch.rpm || true
echo "OnApp Repository has been added."

echo "STEP 3. INSTALL CP PACKAGE"

if [ $SKIP_CP_PACKAGE -eq 1 ]; then
  echo "Skipping..."
else
  rm -f /onapp/onapp-cp-install/onapp-cp-install.sh
  rm -f /onapp/onapp-cp-install/onapp-cp-install.conf
  yum clean all
  yum remove -y onapp-cp-install
  yum install -y onapp-cp-install
  cp -f /onapp/onapp-cp-install/onapp-cp-install.sh /onapp/onapp-cp-install/onapp-cp-install.sh.bak
  cp -f /onapp/onapp-cp-install/onapp-cp-install.conf /onapp/onapp-cp-install/onapp-cp-install.conf.bak
  /onapp/onapp-cp-install/onapp-cp-install.sh -a
fi

echo "STEP 4. INSTALL STORAGE PACKAGE"

if [ $SKIP_STORAGE_PACKAGE -eq 1 ]; then
  echo "Skipping..."
else
  CLOUDBOOT_PASSWORD="$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c12)"
  yum clean all
  yum remove -y onapp-store-install
  yum install -y onapp-store-install
  echo "$CLOUDBOOT_PASSWORD" | /onapp/onapp-store-install/onapp-store-install.sh
  echo "For your information, the Cloudboot root password is $CLOUDBOOT_PASSWORD"
fi

echo "STEP 5. ADDITIONAL CONFIGURATION"

ex +g/license_key/d -cwq /onapp/interface/config/on_app.yml
echo "license_key: $LICENSE_KEY" >> /onapp/interface/config/on_app.yml

echo "STEP 6. RESTARTING SERVICES"

service onapp stop
service httpd stop
service httpd start
service onapp start

echo "COMPLETE"
