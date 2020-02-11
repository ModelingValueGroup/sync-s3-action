#!/bin/bash
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## (C) Copyright 2018-2019 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
##                                                                                                                     ~
## Licensed under the GNU Lesser General Public License v3.0 (the 'License'). You may not use this file except in      ~
## compliance with the License. You may obtain a copy of the License at: https://choosealicense.com/licenses/lgpl-3.0  ~
## Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on ~
## an 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the  ~
## specific language governing permissions and limitations under the License.                                          ~
##                                                                                                                     ~
## Maintainers:                                                                                                        ~
##     Wim Bast, Tom Brus, Ronald Krijgsheld                                                                           ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Carel Bast                                                                                           ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [[ "${INPUT_TRACE:-false}" == "true" ]]; then
    # shellcheck disable=SC2207
    INPUT_VARS=( $(env | grep '^INPUT_' | sed 's/^INPUT_//;s/=.*//') )
    for name in "${INPUT_VARS[@]}"; do
        printf "# %16s = %s\n" "$name" "$(eval "echo \${INPUT_$name:-}")"
    done
    set -x
fi

. "$(dirname "${BASH_SOURCE[0]}")/buildToolsMeme.sh"
includeBuildTools "$INPUT_TOKEN"
. "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

main \
  "$INPUT_ACCESS_KEY" \
  "$INPUT_SECRET_KEY" \
  "$INPUT_TRIGGER_TOKEN" \
  "$INPUT_CMD" \
  "$INPUT_BUCKET" \
  "$INPUT_LOCAL_DIR" \
  "$INPUT_S3_DIR" \
  "$INPUT_S3_DIR_BRANCHED" \
  "$INPUT_HOST" \
  "$INPUT_REGION"
