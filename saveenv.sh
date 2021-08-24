#!/bin/bash

# change to the proper directory
cd $(dirname $0)

echo '#!/bin/bash' > aks_baseline.env
echo '' >> aks_baseline.env

IFS=$'\n'

for var in $(env | grep -E '_AKS_BASELINE' | sort | sed "s/=/='/")
do
  echo "export ${var}'" >> aks_baseline.env
done

cat aks_baseline.env
