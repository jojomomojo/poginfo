#1 /usr/bin/env sh

set -e

# wait for poginfo
kubectl rollout status deployment/poginfo --timeout=3m

# test poginfo
helm test poginfo
