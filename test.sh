set -ue

for js in js/*.js
do
    if [[ "$js" =~ "while" ]]; then
        echo $js : skip...
        continue
    fi
    if [[ "$js" =~ "continue" ]]; then
        echo $js : skip...
        continue
    fi
    if [[ "$js" =~ "anon" ]]; then
        echo $js : skip...
        continue
    fi
    echo $js
    ./bin/jetspider $js
    ./bin/jsvm ${js}c
done
