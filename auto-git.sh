#!/bin/bash

function exit_exeption (){
    if [ $? -eq 130 ]; then
        echo "Exiting..."
        exit 1
    fi  
}


function switch_branch () {

    selected=$(git branch | fzf +m \
        --height 40% \
        --layout reverse \
        --border \
        --preview \
            'git log --oneline $(echo {} | tr -d "* ")' \
        --color bg:#222222,preview-bg:#333333)


    exit_exeption
    
    selected=$(echo $selected | tr -d "* ")

    echo "$selected"

    git switch "$selected"
}

switch_branch

