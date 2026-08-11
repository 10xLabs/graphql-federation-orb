#!/bin/bash
set -eo pipefail
curl -sSL --fail --retry 3 "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q -o awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws
