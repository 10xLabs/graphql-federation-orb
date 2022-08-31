#!/bin/bash
curl -sSL https://rover.apollo.dev/nix/latest | sh

sudo ln -s ~/.rover/bin/rover /usr/local/bin/rover
