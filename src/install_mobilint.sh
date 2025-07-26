#!/bin/bash

echo; echo '** install maccel **'
if [ -d "$HOME/.maccel" ]; then
    cd "$HOME/.maccel" || exit 1
    git pull
else
    git clone https://git.mobilint.com/sdk/runtime/maccel "$HOME/.maccel"
fi

rm -rf "$HOME/.maccel/build"
mkdir -p "$HOME/.maccel/build"
cd "$HOME/.maccel/build"

cmake .. -DPRODUCT=aries2-v4 -DDRIVER_TYPE=aries2 -DVENDOR=mobilint -DINCLUDE_JSON=True
make -j16

shopt -s nullglob  # 매칭되는 파일이 없으면 빈 배열이 됩니다.
wheels=( "$HOME/.maccel/build/src/maccel/maccel-"*.whl )
if [ ${#wheels[@]} -gt 0 ]; then
    python -m pip install "${wheels[@]}"
else
    echo "wheel file for maccel is not found"
fi