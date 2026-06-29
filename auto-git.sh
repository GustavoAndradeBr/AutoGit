#!/bin/bash

function exit_exeption (){
    if [ $? -eq 130 ]; then
        echo "Exiting..."
        exit 1
    fi  
}

function switch_branch () {

    selected=$(git branch | fzf +m \
        --header "Select a branch to switch to:" \
        --height 40% \
        --layout reverse \
        --border \
        --preview \
            'git -c color.ui=always log --oneline $(echo {} | tr -d "* ")' \
        --color bg:#222222,preview-bg:#333333)

    exit_exeption
    
    selected=$(echo $selected | tr -d "* ")

    git switch "$selected"
}

function merge () {

    selected=$(git branch | fzf +m \
        --header "Select a branch to merge into the current branch:" \
        --height 100% \
        --layout reverse \
        --border \
        --preview \
            'git -c color.ui=always diff $(git branch | grep "^*" | tr -d "* ") $(echo {} | tr -d "* ")' \
        --color bg:#222222,preview-bg:#333333)

    exit_exeption
    
    selected=$(echo $selected | tr -d "* ")

    git merge "$selected"
}

function delete_branch () {

    selected=$(git branch | fzf +m \
        --header "Select a branch to delete:" \
        --height 40% \
        --layout reverse \
        --border \
        --preview \
            'git -c color.ui=always log --oneline $(echo {} | tr -d "* ")' \
        --color bg:#222222,preview-bg:#333333)

    exit_exeption
    
    selected=$(echo $selected | tr -d "* ")

    git branch -d "$selected"
}

function main (){

    option=(\
        "1 - Switch Branch" \
        "2 - Merge Branch" \
        "3 - Delete Branch" \
        "4 - Exit" \
    )

    selected=$(for opt in "${option[@]}"; do echo "$opt"; done | fzf +m \
        --header "Select an option:" \
        --height 40% \
        --layout reverse \
        --border \
        --color bg:#222222)

    exit_exeption

    case "$selected" in 
        ${option[0]})
            echo "Switching Branch..."
            switch_branch
            exit 0
        ;;
        ${option[1]})
            echo "Merging Branch..."
            merge
            exit 0
        ;;
        ${option[2]})
            echo "Deleting Branch..."
            delete_branch
            exit 0
        ;; 
        ${option[3]})
            echo "Exiting..."
            exit 0
        ;;
        *)
            echo "Invalid option. Exiting..."
            exit 1
        ;;
    esac      
}

main
